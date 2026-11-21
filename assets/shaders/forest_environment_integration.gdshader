shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex:hint_screen_texture,filter_linear,repeat_disable;
uniform sampler2D coverage:filter_linear,repeat_disable;
uniform vec2 world_origin;
uniform vec2 world_x;
uniform vec2 world_y;
uniform vec2 contact_point;
uniform float grounded_contact=0.0;
uniform float strength=0.0;
// Valley relighting is suspended pending the next art direction pass.
uniform bool valley_relighting=false;
uniform float fusion_gain:hint_range(1.0,4.0)=3.0;
uniform vec2 valley_preview_offset=vec2(0.0);
#include "res://assets/shaders/chapter_sun_apertures.gdshaderinc"
uniform int lamp_count=0;
uniform vec4 lamps[12];
uniform vec2 lamp_axes[12];
uniform vec4 decks[4];
uniform sampler2D forest_profile:filter_linear,repeat_disable;
uniform sampler2D mine_profile:filter_linear,repeat_disable;
uniform sampler2D valley_profile:filter_linear,repeat_disable;
uniform vec3 mine_sampling;
uniform vec3 valley_sampling;

float aperture(vec2 p,float opening_x,float width_scale){
	// The opening is above the bright clearing, and its widening penumbra
	// continues all the way down to the actual terrain. No detached light
	// circles or frame-relative character highlights.
	float depth=p.y+4860.0;
	float axis=opening_x+depth*.36;
	float width=(78.0+max(depth,0.0)*.16)*width_scale;
	float across=abs(p.x-axis)/width;
	return exp(-pow(across,4.0))*smoothstep(-5050.,-4800.,p.y);
}

float opening_energy(vec2 p){
	return max(aperture(p,-9410.,1.1)*.65,
		max(aperture(p,-7370.,.9)*.8,aperture(p,-6710.,1.0)));
}

float lamp_energy(vec2 p){
	float result=0.0;
	for(int i=0;i<12;i++){
		if(i>=lamp_count)break;
		vec4 lamp=lamps[i];vec2 d=p-lamp.xy;
		float reach=dot(d,d)/(lamp.z*lamp.z);
		if(reach>1.21)continue;
		float along=dot(d,lamp_axes[i]);
		float across=abs(d.x*lamp_axes[i].y-d.y*lamp_axes[i].x);
		float cone=(1.-smoothstep(.35,1.30,across/max(along,26.)))*smoothstep(-12.,25.,along);
		float power=lamp.w*cone*exp(-reach*1.6)*(1.-smoothstep(.6724,1.21,reach));
		for(int j=0;j<2;j++){
			vec4 deck=decks[j];
			if(deck.y>deck.x && lamp.y<deck.z-3. && p.y>deck.z+3.){
				float t=(deck.z-lamp.y)/max(p.y-lamp.y,.001);
				float x=mix(lamp.x,p.x,t);
				float blocked=smoothstep(deck.x-deck.w,deck.x+deck.w,x)*(1.-smoothstep(deck.y-deck.w,deck.y+deck.w,x));
				power*=1.-blocked*.96;
			}
		}
		result+=power;
	}
	return min(result,1.);
}

void fragment(){
	vec2 uv=SCREEN_UV;
	vec3 scene=texture(screen_tex,uv).rgb;
	vec2 world=world_origin+world_x*uv.x+world_y*uv.y;
	vec2 valley_world=world-valley_preview_offset;
	vec4 profile=vec4(0.,0.,1.,100000.);
	// Depth identity belongs to the WORLD point, not the player's current
	// controller/region. Both sides of a handoff can coexist in one view.
	if(valley_world.y> -1000. && valley_world.x> -800.){
		profile=texture(valley_profile,vec2(((valley_world.x-valley_sampling.x)/valley_sampling.y+.5)/valley_sampling.z,.5));
		profile.r+=valley_preview_offset.y;
		if(profile.a<99999.)profile.a+=valley_preview_offset.y;
	}else if(world.y< -4000. && world.x< -3300.){
		profile.r=texture(forest_profile,vec2(clamp((world.x+9800.)/6500.,0.,1.),.5)).r;
	}else if(world.y> -3560.){
		profile=texture(mine_profile,vec2(((world.x-mine_sampling.x)/mine_sampling.y+.5)/mine_sampling.z,.5));
		// Never interpolate a real lower floor with the 100000 "no floor"
		// sentinel: it creates a bogus depth plane and a vertical lit strip.
		// Blend only actual floor heights over a soft transition at deck ends.
		int centre=int(round((world.x-mine_sampling.x)/mine_sampling.y));
		float lower_height=0.;float lower_weight=0.;
		for(int k=-2;k<=2;k++){
			int index=clamp(centre+k*8,0,int(mine_sampling.z)-1);
			float h=texelFetch(mine_profile,ivec2(index,0),0).a;
			float w=k==0?.36:(abs(k)==1?.24:.08);
			if(h<99999.){lower_height+=h*w;lower_weight+=w;}
		}
		if(lower_weight>0. && world.y>profile.r+8.)profile.r=mix(profile.r,lower_height/lower_weight,lower_weight);
		profile.a=100000.;
		// The mine floor does not describe the high cliff above it.
		profile.b*=smoothstep(-3560.,-3450.,world.y);
	}else{profile=vec4(-3400.,0.,0.,100000.);}
	if(profile.a<99999. && world.y>profile.r+8.)profile.r=profile.a;
	float ground=profile.r;
	float depth=world.y-ground;
	float forest_zone=(1.-smoothstep(-4150.,-3800.,world.y))*(1.-smoothstep(-3450.,-3100.,world.x));
	float energy=opening_energy(world)*forest_zone+lamp_energy(world);
	if(valley_relighting)energy+=chapter_valley_sun(valley_world)*smoothstep(-600.,-300.,valley_world.y)*smoothstep(-800.,-300.,valley_world.x);
	energy=min(energy,1.)*strength;
	// Water changes transport/material response, not whether a world-space
	// sun exists. Keep both shore transitions continuous rather than cutting
	// the entire incoming field at a terrain/water classification boundary.
	float submerged=max(world.y-ground,0.);
	float solid_transmission=mix(1.,exp(-submerged/80.),profile.g);
	float air_transmission=mix(1.,exp(-submerged/8.),profile.g);
	float solid=texture(coverage,uv).a;
	float luma=dot(scene,vec3(.2126,.7152,.0722));
	// Terrain reflects on its exposed shoulder, then quickly occludes
	// light inside the buried mass. Keep the transition smooth rather than
	// painting either a bright turf stripe or a translucent gray earth slab.
	float exposed_rock=smoothstep(-600.,-300.,valley_world.y)*(1.-profile.g);
	float face_depth=mix(70.,90.,exposed_rock);
	float surface=1.-smoothstep(25.,face_depth,depth);
	float ground_valid=clamp(profile.b,0.,1.);
	// Unknown/no-floor profiles are not exposed solid faces. In particular
	// the gorge wall cannot become an unlimited receiving plane.
	surface*=ground_valid;
	float receiving=solid*surface*(1.-smoothstep(.025,.16,luma))*solid_transmission;
	// Only a weak local contact penumbra under the visible grounded sole.
	// The old 85% suppression around the physics capsule drew a black line
	// between two lit shapes, especially after surface fitting on slopes.
	vec2 contact=(world-contact_point)/vec2(5.,4.);
	float planted=exp(-dot(contact,contact))*grounded_contact*smoothstep(-3.,3.,world.y-contact_point.y);
	float face_progress=smoothstep(0.,face_depth,depth);
	// Light reflects from exposed surfaces; it does not illuminate a
	// translucent 260px slab of soil. Leave the buried mass dense.
	float soil_response=mix(1.,.16,smoothstep(-8.,24.,depth)*ground_valid);
	float receiver_gain=mix(fusion_gain,mix(fusion_gain,1.35,face_progress),ground_valid);
	float bounce=.009*energy*receiving*soil_response*(1.-planted*.12)*receiver_gain;
	// Air and surfaces read the SAME aperture. Existing bright air admits
	// the scattering; opaque foreground silhouettes are not washed gray.
	// Dark unregistered rock is not luminous air. Some cliff masses
	// intentionally stay outside the focal mask; never scatter over them.
	float air=(1.-solid)*smoothstep(.07,.20,luma)*air_transmission;
	// Ray-tested river light continues through near air, with the same
 // canopy and branch shadows used by the boy, boat and rooted grass.
 float river=valley_relighting?chapter_river_region(valley_world)*smoothstep(-600.,-300.,valley_world.y):0.;
 float scatter=.032*energy*air*mix(1.0,fusion_gain,.65)*mix(1.,.72,river);
	COLOR=vec4(scene+vec3(bounce+scatter),1.0);
}
