shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float clock = 0.0;
uniform float intensity = 0.38;
uniform float seed = 0.0;

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
	float y = UV.y;
	float beam_center = 0.20 + y * 0.22;
	float half_width = mix(0.10, 0.52, smoothstep(0.0, 0.92, y));
	float side = abs(UV.x - beam_center);
	float edge = 1.0 - smoothstep(half_width * 0.58, half_width, side);
	float top_fade = smoothstep(0.01, 0.13, y);
	float bottom_fade = 1.0 - smoothstep(0.78, 1.0, y);

	vec2 flow = vec2(UV.x * 3.1 + seed, UV.y * 5.2 - clock * 0.055);
	float broad = noise(flow);
	float detail = noise(flow * 2.15 + vec2(seed * 2.7, clock * 0.025));
	float density_variation = mix(0.54, 1.0, broad * 0.72 + detail * 0.28);
	float density = edge * top_fade * bottom_fade * density_variation * intensity;

	COLOR = vec4(vec3(0.78) * density, density);
}
