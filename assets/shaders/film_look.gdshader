shader_type canvas_item;
render_mode unshaded;

// A whole-screen "old film" pass, in the spirit of Limbo: a little softness (nothing is ever
// pin-sharp), a halo around the bright fog, heavier shadows, a fine moving grain, a darkened frame,
// a faint flicker, and the odd scratch or speck of dust. The screen texture already holds display
// values, so every strength here means what it would in a photo editor.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform float bloom : hint_range(0.0, 1.0) = 0.20;
uniform float grain : hint_range(0.0, 0.3) = 0.016;
uniform float vignette : hint_range(0.0, 1.0) = 0.32;
uniform float flicker : hint_range(0.0, 0.1) = 0.010;
uniform float contrast : hint_range(0.0, 1.0) = 0.12;
uniform float scratches : hint_range(0.0, 1.0) = 0.2;

const vec2 DESIGN = vec2(1280.0, 720.0);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 tap(vec2 uv) {
	return texture(screen_tex, uv).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dp = 1.0 / DESIGN;
	vec3 base = tap(uv);

	// Soft focus: two rings of neighbours, so every edge on screen (the character's too) is a soft
	// gradient a couple of pixels wide instead of a digital step.
	vec3 soft = base * 0.16;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982 + 0.4;
		vec2 d = vec2(cos(a), sin(a));
		soft += tap(uv + d * 1.3 * dp) * 0.07;
		soft += tap(uv + d * 2.7 * dp) * 0.035;
	}
	vec3 col = mix(base, soft, softness);

	// Halation: only what is already bright spills over, so the fog glows against the silhouettes.
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float a = float(i) * 0.6283185 + 0.2;
		for (int r = 1; r <= 3; r++) {
			vec3 c = tap(uv + vec2(cos(a + float(r)), sin(a + float(r))) * float(r) * 6.0 * dp);
			glow += max(c - vec3(0.62), vec3(0.0));
		}
	}
	glow /= 30.0;
	col += glow * bloom * 1.6;

	// Heavier film contrast: shadows sink, the fog stays creamy.
	col = mix(col, smoothstep(0.0, 1.0, col), contrast);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float frame_t = floor(TIME * 24.0);

	// Grain: very fine, re-rolled every frame, a little stronger in the mid-greys.
	// Grain is tied to physical pixels, so a bigger window or a bigger screen never makes it coarser.
	vec2 cell = floor(FRAGCOORD.xy / 1.5);
	float n = hash21(cell + frame_t * vec2(17.0, 31.0)) - 0.5;
	float weight = 0.5 + 0.5 * (1.0 - pow(abs(luma - 0.5) * 2.0, 2.0));
	col += n * grain * weight;
	// Frame: the corners fall away, a little more at the top and bottom.
	vec2 q = (uv - 0.5) * vec2(1.0, 1.15);
	float v = smoothstep(0.28, 0.82, length(q) * 1.35);
	col *= 1.0 - vignette * v;

	// Projector flicker.
	col *= 1.0 + (hash11(floor(TIME * 12.0) + 3.0) - 0.5) * 2.0 * flicker;

	// Scratches and dust: rare, thin, and light.
	float t8 = floor(TIME * 7.0);
	float sx = hash11(t8 * 1.7 + 1.0);
	float on = step(0.82, hash11(t8 * 2.3 + 5.0));
	float line = (1.0 - smoothstep(0.0, 0.0009, abs(uv.x - sx))) * on;
	line *= 0.35 + 0.65 * hash21(vec2(floor(uv.y * 36.0), t8));
	col += line * 0.10 * scratches;
	float dust = 0.0;
	for (int k = 0; k < 3; k++) {
		float seed = floor(TIME * 12.0) * 3.0 + float(k);
		vec2 p = vec2(hash11(seed * 1.3 + 7.0), hash11(seed * 2.9 + 11.0));
		float show = step(0.55, hash11(seed * 4.1 + 2.0));
		float d = length((uv - p) * DESIGN);
		dust += (1.0 - smoothstep(0.8, 2.2, d)) * show;
	}
	col -= dust * 0.22 * scratches * (0.3 + luma);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
