shader_type canvas_item;
render_mode unshaded, blend_mul;
uniform vec4 sources[8];
uniform int source_count = 0;
uniform float depth = 0.0;
void fragment() {
	vec2 pixel = UV*vec2(1280,720);
	float illumination = 0.0;
	vec3 warmth = vec3(0.0);
	for (int i=0;i<8;i++) {
		if (i>=source_count) { break; }
		float radius = max(1.0,sources[i].z);
		float d = length((pixel-sources[i].xy)/vec2(1.0,0.8))/radius;
		float light = exp(-d*d*3.3)*sources[i].w;
		illumination += light;
		warmth += vec3(0.31,0.12,0.015)*light;
	}
	float shaft_light = exp(-pow((pixel.x-640.0)/155.0,2.0))*0.23*exp(-(pixel.y+depth)/2400.0);
	vec3 exposure = vec3(0.57,0.60,0.64)+vec3(shaft_light)+vec3(0.44)*min(illumination,1.4)+warmth;
	// HUD is still drawn by the root canvas; protect its top/bottom bands.
	float scene_mask = smoothstep(64.0,110.0,pixel.y)*(1.0-smoothstep(642.0,690.0,pixel.y));
	COLOR = vec4(mix(vec3(1.0),exposure,scene_mask),1.0);
}
