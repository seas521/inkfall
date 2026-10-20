shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float clock = 0.0;
uniform float intensity = 0.28;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(91.7, 213.5))) * 43758.5453);
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
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.26);
	float radius = length(p);
	float radial = 1.0 - smoothstep(0.08, 0.50, radius);
	float floor_fade = 1.0 - smoothstep(0.66, 1.0, UV.y);
	float flicker = 0.92 + sin(clock * 2.7) * 0.035 + sin(clock * 6.1 + 1.8) * 0.018;
	float smoke = mix(0.72, 1.0, noise(UV * vec2(4.0, 6.0) + vec2(0.0, -clock * 0.10)));
	float density = radial * floor_fade * smoke * intensity * flicker;

	COLOR = vec4(vec3(0.82) * density, density);
}
