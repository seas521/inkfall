shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float clock = 0.0;
uniform float depth = 0.0;
uniform float intensity = 0.62;
uniform float seed = 0.0;
uniform vec3 rain_tint : source_color = vec3(0.64);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float streak_layer(
	vec2 uv,
	vec2 grid,
	float speed,
	float length_value,
	float width_value,
	float slant,
	float layer_seed
) {
	vec2 slanted = uv;
	slanted.x += uv.y * slant * 0.55;
	vec2 cells = slanted * grid;
	vec2 cell_id = floor(cells);
	vec2 local = fract(cells) - 0.5;
	float random_value = hash(cell_id + vec2(layer_seed, depth * 0.0021));
	float phase = fract(clock * speed + random_value + depth * 0.00023);
	local.y = fract(local.y - phase + 0.5) - 0.5;
	local.x += (random_value - 0.5) * 0.58;
	local.x += local.y * slant;
	local.x += sin(local.y * 8.0 + random_value * 11.0 + clock * 0.7) * 0.035 * slant;

	float varied_length = length_value * mix(0.62, 1.18, random_value);
	float core = 1.0 - smoothstep(width_value, width_value * 4.2, abs(local.x));
	float body = 1.0 - smoothstep(varied_length * 0.26, varied_length, abs(local.y));
	float head = exp(-pow((local.y - length_value * 0.23) / max(0.018, length_value * 0.16), 2.0));
	float bead = exp(-pow(local.x / max(0.012, width_value * 4.8), 2.0));
	bead *= exp(-pow((local.y - varied_length * 0.31) / 0.052, 2.0));
	float dropout = smoothstep(0.18, 0.82, random_value);
	return (core * body * (0.10 + head * 0.32) + bead * 0.72) * dropout;
}

void fragment() {
	vec2 uv = UV;
	float far_rain = streak_layer(uv, vec2(72.0, 28.0), 0.52, 0.10, 0.020, 0.70, seed + 1.7);
	float mid_rain = streak_layer(uv, vec2(50.0, 20.0), 0.76, 0.12, 0.025, 1.20, seed + 9.1);
	float near_rain = streak_layer(uv, vec2(34.0, 14.0), 1.04, 0.14, 0.030, 1.80, seed + 17.3);

	float broad_modulation = 0.72 + 0.28 * sin((uv.x * 2.7 + uv.y) * 5.0 + clock * 0.11);
	float center_air = mix(0.58, 1.0, 1.0 - smoothstep(0.0, 0.50, abs(uv.x - 0.5)));
	float density = far_rain * 0.15 + mid_rain * 0.25 + near_rain * 0.23;
	density *= intensity * broad_modulation * center_air;

	float veil = exp(-pow((uv.y - 0.58) / 0.46, 2.0)) * 0.006 * intensity;
	COLOR = vec4(rain_tint * (density + veil), density + veil);
}
