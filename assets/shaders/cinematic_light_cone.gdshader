shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float intensity = 0.34;
uniform vec3 light_tint : source_color = vec3(0.73, 0.76, 0.73);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = UV;
	float y = p.y;
	float half_width = mix(0.035, 0.48, smoothstep(0.0, 0.96, y));
	float side = abs(p.x - 0.5);
	float edge = 1.0 - smoothstep(half_width * 0.70, half_width, side);
	float top_fade = smoothstep(0.015, 0.11, y);
	float floor_fade = 1.0 - smoothstep(0.82, 1.0, y);

	vec2 flow_uv = vec2(p.x * 3.2 + seed * 7.0, p.y * 5.3 - clock * 0.12);
	float broad = noise(flow_uv);
	float detail = noise(flow_uv * 2.3 + vec2(clock * 0.035, seed * 11.0));
	float black_veil = smoothstep(0.20, 0.82, broad * 0.72 + detail * 0.28);
	float vertical_bands = 0.82 + sin(p.y * 19.0 + broad * 3.0 - clock * 0.22) * 0.08;
	float center_density = 1.0 - smoothstep(0.0, half_width, side) * 0.16;

	float density = edge * top_fade * floor_fade;
	density *= mix(0.34, 1.0, black_veil) * vertical_bands * center_density;
	density *= intensity;

	COLOR = vec4(light_tint * density, density);
}
