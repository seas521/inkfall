shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float origin_x = 0.0;
uniform vec2 extent = vec2(160.0,385.0);
uniform bool river = false;
uniform bool waterfall_active = true;
uniform bool mask_start_ledge = true;
uniform bool monochrome = false;
uniform sampler2D rock_texture : filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

float water_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float water_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(water_hash(i),water_hash(i+vec2(1,0)),f.x),mix(water_hash(i+vec2(0,1)),water_hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=UV*extent;
	float wx=p.x+origin_x;
	vec3 color;
	float alpha;
	if (river) {
		// Long horizontal crests, short depth spacing: a surface, never a vertical curtain.
		float bank=6.0+3.5*sin(wx*0.014)+2.0*water_noise(vec2(wx*0.035,clock*0.12));
		float y=p.y-bank;
		float perspective=0.65+UV.y*1.5;
		vec2 q=vec2(wx*0.012-clock*0.24,y*0.20/perspective);
		float flow_phase=fract(clock*0.13);
		float flow_blend=abs(flow_phase*2.0-1.0);
		float swell_a=water_noise(q+vec2(flow_phase*1.8,clock*0.18));
		float swell_b=water_noise(q+vec2(fract(flow_phase+0.5)*1.8,clock*0.18+7.3));
		float swell=mix(swell_a,swell_b,flow_blend);
		float wave=sin(y*0.42/perspective+swell*3.8-clock*1.8);
		float broken=water_noise(vec2(wx*0.036+clock*0.27,y*0.15));
		float crest=pow(max(wave,0.0),16.0)*smoothstep(0.35,0.68,broken);
		float broad=water_noise(vec2(wx*0.006-clock*0.1,y*0.10));
		color=mix(vec3(0.02,0.07,0.14),vec3(0.02,0.31,0.47),broad);
		color+=vec3(0.16,0.78,1.0)*crest*(0.45+UV.y*0.3);
		vec2 refract_offset=vec2(
			(swell-0.5)*2.4+sin(wx*0.021-clock)*0.7,
			(water_noise(vec2(wx*0.019,clock*0.25))-0.5)*1.4
		)*SCREEN_PIXEL_SIZE;
		vec3 scene_color=textureLod(screen_texture,SCREEN_UV+refract_offset,1.2).rgb;
		color=mix(scene_color*0.72,color,0.64);
		float active_flow=waterfall_active?1.0:0.0;
		float impact=exp(-pow((wx-716.0)/86.0,2.0))*exp(-pow((y-13.0)/15.0,2.0))*active_flow;
		color+=vec3(0.12,0.58,0.78)*impact;
		float reflection=exp(-pow((wx-716.0)/58.0,2.0))*(1.0-smoothstep(0.12,0.86,UV.y))*active_flow;
		float reflection_break=0.38+0.62*water_noise(vec2(wx*0.052-clock*0.36,y*0.19));
		color+=vec3(0.36,0.76,0.92)*reflection*reflection_break*0.48;
		float impact_foam=impact*smoothstep(0.46,0.72,water_noise(vec2(wx*0.065-clock*0.4,y*0.24)));
		color+=vec3(0.65,0.90,0.96)*impact_foam*0.34;
		float banks=smoothstep(-320.0,-240.0,wx)*(1.0-smoothstep(3670.0,3780.0,wx));
		alpha=smoothstep(-3.0,9.0,y)*(1.0-smoothstep(extent.y*0.60,extent.y*1.10,p.y))*banks*0.9;
		// The river continues behind the starting ledge, not on top of its rock face.
		vec2 ledge_uv=vec2((wx-60.0)/520.0,(605.0+p.y-560.0)/80.0);
		if (mask_start_ledge && ledge_uv.x>=0.0 && ledge_uv.x<=1.0 && ledge_uv.y>=0.0 && ledge_uv.y<=1.0) {
			vec2 source_uv=(vec2(77,323)+ledge_uv*vec2(1620,287))/vec2(textureSize(rock_texture,0));
			alpha*=1.0-texture(rock_texture,source_uv).a;
		}
	} else {
		float h=UV.y;
		// Two phase-offset flow samples hide the reset of the falling pattern.
		float travel=(sqrt(4900.0+1800.0*p.y)-70.0)/900.0;
		float phase=fract(clock*0.42);
		float phase_b=fract(phase+0.5);
		float blend=abs(phase*2.0-1.0);
		float n_a=water_noise(vec2(UV.x*19.0+phase*0.7,travel*7.0-phase*6.0));
		float n_b=water_noise(vec2(UV.x*19.0+phase_b*0.7+11.0,travel*7.0-phase_b*6.0));
		float fine_a=water_noise(vec2(UV.x*61.0-phase*1.4,travel*27.0-phase*17.0));
		float fine_b=water_noise(vec2(UV.x*61.0-phase_b*1.4+23.0,travel*27.0-phase_b*17.0));
		float n=mix(n_a,n_b,blend);
		float fine=mix(fine_a,fine_b,blend);
		float sway=sin(h*10.0-clock*1.35)*0.009+sin(h*23.0+clock*0.8)*0.003;
		float half_width=mix(0.23,0.46,smoothstep(0.0,0.30,h));
		half_width-=0.024*n;
		float side=abs(UV.x-0.5-sway);
		float edge_noise=(water_noise(vec2(h*11.0-clock*0.8,UV.x*7.0))-0.5)*0.035;
		float edge=1.0-smoothstep(half_width-0.060,half_width+edge_noise,side);
		float strand=smoothstep(0.14,0.84,n*0.72+fine*0.28);
		float glint=smoothstep(0.79,0.96,fine)*smoothstep(0.5,0.9,n);
		float light=(0.38+0.34*(1.0-h))*(0.72+0.28*(1.0-UV.x));
		vec2 fall_refraction=vec2((n-0.5)*2.8+sin(h*18.0-clock)*0.8,(fine-0.5)*0.6)*SCREEN_PIXEL_SIZE;
		vec3 scene_color=textureLod(screen_texture,SCREEN_UV+fall_refraction,1.4).rgb;
		vec3 water_tint=mix(vec3(0.04,0.12,0.22),vec3(0.30,0.72,0.88),strand*light);
		color=mix(scene_color*0.82,water_tint,0.58);
		color+=vec3(0.66,0.90,1.0)*glint*light;
		float foam_thread=smoothstep(0.62,0.86,n)*smoothstep(0.28,0.94,h);
		color+=vec3(0.46,0.82,0.94)*foam_thread*0.17;
		float end=1.0-smoothstep(0.86+fine*0.05,1.0,h);
		float top= smoothstep(0.0,0.035+fine*0.018,h);
		alpha=edge*end*top*(0.24+strand*0.43+glint*0.17+foam_thread*0.08);
	}
	if (monochrome) {
		if (river) {
			float flow = waterfall_active ? 1.0 : 0.0;
			float waterfall_reflection = exp(-pow((wx - 716.0) / 260.0, 2.0)) * flow;
			float lift_reflection = exp(-pow((wx - 3190.0) / 210.0, 2.0)) * 0.70;
			float local_light = waterfall_reflection + lift_reflection;
			float broad_noise = water_noise(vec2(wx * 0.006 - clock * 0.045, p.y * 0.055));
			float soft_ripple = pow(max(sin(p.y * 0.18 + broad_noise * 3.2 - clock * 0.34), 0.0), 18.0);
			float value = 0.018 + local_light * (0.050 + soft_ripple * 0.095);
			color = vec3(value);
			alpha *= 0.74;
		} else {
			// The monochrome waterfall is a single breathing fog volume, not a
			// bundle of high-frequency bright threads.
			float fog = water_noise(vec2(UV.x * 4.2 + clock * 0.025, UV.y * 7.0 - clock * 0.09));
			float side = abs(UV.x - 0.5 + sin(UV.y * 5.0 - clock * 0.16) * 0.008);
			float half_width = mix(0.24, 0.43, smoothstep(0.0, 0.42, UV.y));
			half_width += (fog - 0.5) * 0.025;
			float soft_edge = 1.0 - smoothstep(half_width * 0.70, half_width, side);
			float vertical = smoothstep(0.01, 0.09, UV.y) * (1.0 - smoothstep(0.76, 1.0, UV.y));
			float density = 0.52 + fog * 0.48;
			float streak_noise = water_noise(vec2(UV.x * 13.0 + clock * 0.018, UV.y * 2.4 - clock * 0.14));
			float soft_streaks = smoothstep(0.46, 0.78, streak_noise);
			color = vec3(0.20 + density * 0.14 + soft_streaks * 0.085);
			alpha = soft_edge * vertical * (0.10 + density * 0.12 + soft_streaks * 0.055);
		}
	}
	COLOR=vec4(color,clamp(alpha,0.0,1.0));
}
