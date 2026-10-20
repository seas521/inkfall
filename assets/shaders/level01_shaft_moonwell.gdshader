shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float clock = 0.0;
uniform float depth = 0.0;
uniform float intensity = 0.32;
uniform vec3 light_tint : source_color = vec3(0.72);

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
	float world_depth = depth + p.y * 720.0;
	float depth_fade = mix(1.0, 0.48, smoothstep(0.0, 3000.0, world_depth));
	float half_width = mix(0.18, 0.48, smoothstep(0.0, 0.88, p.y));
	float side = abs(p.x - 0.5);
	float edge = 1.0 - smoothstep(half_width * 0.68, half_width, side);
	float top_fade = smoothstep(0.0, 0.10, p.y);
	float floor_fade = 1.0 - smoothstep(0.84, 1.0, p.y);

	vec2 broad_uv = vec2(p.x * 2.6 + depth * 0.0007, p.y * 4.2 - clock * 0.055);
	float broad = noise(broad_uv);
	float detail = noise(broad_uv * 2.45 + vec2(clock * 0.018, -clock * 0.035));
	float rain_shadow = 0.82 + sin(p.y * 31.0 + broad * 4.0 - clock * 0.18) * 0.06;
	float density = edge * top_fade * floor_fade * depth_fade;
	density *= mix(0.42, 1.0, broad * 0.72 + detail * 0.28) * rain_shadow;
	density *= intensity;

	COLOR = vec4(light_tint * density, density);
}
