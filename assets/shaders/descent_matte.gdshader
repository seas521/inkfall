shader_type canvas_item;
render_mode unshaded;
uniform sampler2D plate_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D silhouette_mask : filter_linear, repeat_disable;
uniform int plane = 0;
uniform int scene_id = 0;
uniform vec2 pan = vec2(0.0);
uniform float clock = 0.0;
uniform vec4 ink : source_color = vec4(0.012,0.013,0.013,1.0);

vec3 soft_plate(vec2 uv, vec2 px, float lod) {
	vec2 d=px*exp2(lod)*0.55;
	vec3 c=textureLod(plate_texture,uv,lod).rgb*0.25;
	c+=(textureLod(plate_texture,uv+vec2(d.x,0),lod).rgb+textureLod(plate_texture,uv-vec2(d.x,0),lod).rgb+textureLod(plate_texture,uv+vec2(0,d.y),lod).rgb+textureLod(plate_texture,uv-vec2(0,d.y),lod).rgb)*0.125;
	c+=(textureLod(plate_texture,uv+d,lod).rgb+textureLod(plate_texture,uv-d,lod).rgb+textureLod(plate_texture,uv+vec2(d.x,-d.y),lod).rgb+textureLod(plate_texture,uv+vec2(-d.x,d.y),lod).rgb)*0.0625;
	return c;
}
void fragment() {
	vec2 uv=clamp(UV+pan,vec2(0.001),vec2(0.999));
	if(plane==2) {
		// A connected natural contour mask, with small material holes removed.
		// NEVER sample the photographed colour on the player's contact plane.
		vec2 px=1.0/vec2(textureSize(silhouette_mask,0));
		float a=texture(silhouette_mask,uv).r*0.50;
		a+=(texture(silhouette_mask,uv+vec2(px.x,0)*0.45).r+texture(silhouette_mask,uv-vec2(px.x,0)*0.45).r+texture(silhouette_mask,uv+vec2(0,px.y)*0.45).r+texture(silhouette_mask,uv-vec2(0,px.y)*0.45).r)*0.125;
		COLOR=vec4(ink.rgb,a);
	} else {
		vec2 px=1.0/vec2(textureSize(plate_texture,0));
		vec3 c=soft_plate(uv,px,plane==0 ? 2.6 : 1.8);
		float l=pow(max(dot(c,vec3(0.299,0.587,0.114)),0.0),1.0/2.2);
		// A few broad grey masses; texture does not survive the optical filter.
		float value=mix(0.16,0.73,smoothstep(0.10,0.92,l));
		float a=plane==0 ? 1.0 : 1.0-smoothstep(0.30,0.62,l);
		COLOR=vec4(vec3(pow(value,2.2)),a);
	}
}
