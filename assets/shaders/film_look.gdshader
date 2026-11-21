shader_type canvas_item;
render_mode unshaded;

// A whole-screen "old film" pass, in the spirit of Limbo: a little softness (nothing is ever
// pin-sharp), a halo around the bright fog, heavier shadows, a fine moving grain, a darkened frame,
// a faint flicker, and the odd scratch or speck of dust. The screen texture already holds display
// values, so every strength here means what it would in a photo editor.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float softness : hint_range(0.0, 1.0) = 0.54;
uniform float environment_softness : hint_range(0.0, 1.0) = 0.0;
// Background optics retain the route's soft envelope. Actual gameplay
// coverage opts out of that broad diffusion in every chapter region.
uniform float route_softness : hint_range(0.0, 1.0) = 0.0;
uniform float mine_atmosphere : hint_range(0.0, 1.0) = 0.0;
uniform float player_plane_focus=0.0;
uniform sampler2D player_coverage : filter_linear,repeat_disable;
uniform vec2 player_focus_center=vec2(.5,.65);
uniform vec2 player_focus_span=vec2(.50,.50);
uniform float bloom : hint_range(0.0, 1.0) = 0.24;
uniform float grain : hint_range(0.0, 0.3) = 0.022;
uniform float vignette : hint_range(0.0, 1.0) = 0.24;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;
uniform float contrast : hint_range(0.0, 1.0) = 0.12;
uniform float iris_strength : hint_range(0.0, 1.0) = 0.93;
uniform float scratches : hint_range(0.0, 1.0) = 0.2;

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

float lens_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float plane_compatibility(vec2 uv,float centre){
	if(player_plane_focus<=0.0)return 1.0;
	float peer=texture(player_coverage,uv).a;
	float same=1.0-abs(peer-centre);
	// Coverage-guided gathering, not a claim of a full 3D depth buffer.
	// Keep antialiased edge coverage, but reject most samples across planes.
	return max(.035,same*same);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	// Preserve cinematic softness as resolution rises, but grow it sub-linearly.
	// A fixed physical radius looked too digitally sharp at 4K; a fixed 720p
	// design radius looked like an enlarged low-resolution image.  Square-root
	// scaling keeps the soft photographic envelope without magnifying blockiness.
	float resolution_scale = sqrt(max(screen_size.x / 1280.0, screen_size.y / 720.0));
	vec2 dp = SCREEN_PIXEL_SIZE * resolution_scale;
	float optical_profile=max(route_softness,mine_atmosphere);
	float diffusion=max(environment_softness,optical_profile*.88);
	vec2 optical_dp=dp*mix(1.0,1.65,diffusion)*mix(1.0,1.45,optical_profile);
	float near_focus=0.0;
	if(player_plane_focus>0.0){
		// Coverage comes from actual gameplay silhouettes, not background
		// luminance: the distant trees remain soft even behind the player.
		vec2 edge=vec2(1.5/1280.0,1.5/720.0);
		float coverage=texture(player_coverage,uv).a;
		coverage=max(coverage,texture(player_coverage,uv+vec2(edge.x,0)).a);
		coverage=max(coverage,texture(player_coverage,uv-vec2(edge.x,0)).a);
		coverage=max(coverage,texture(player_coverage,uv+vec2(0,edge.y)).a);
		coverage=max(coverage,texture(player_coverage,uv-vec2(0,edge.y)).a);
		// A broad activity region, intersected with actual playing geometry.
		// Backgrounds never turn sharp inside a screen-space spotlight.
		vec2 q=abs((uv-player_focus_center)/max(player_focus_span,vec2(.05)));
		float reach=sqrt(length(q*q));
		float activity=1.0-smoothstep(.30,1.55,reach);
		near_focus=player_plane_focus*smoothstep(.04,.62,coverage)*mix(.18,1.0,activity);
		optical_dp=mix(optical_dp,dp*.90,near_focus);
	}
	vec3 base = tap(uv);

	// Optical diffusion, not a flat blur: retain most of the original exposure and
	// mix two light rings around it, like a slightly aged lens and film emulsion.
	vec3 soft = base * 0.16;
	float soft_weight=.16;
	float centre_plane=player_plane_focus>0.0?texture(player_coverage,uv).a:0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982 + 0.4;
		vec2 d = vec2(cos(a), sin(a));
		vec2 inner_uv=uv+d*1.45*optical_dp;
		vec2 outer_uv=uv+d*3.15*optical_dp;
		float inner_weight=.07*plane_compatibility(inner_uv,centre_plane);
		float outer_weight=.035*plane_compatibility(outer_uv,centre_plane);
		soft += tap(inner_uv)*inner_weight;
		soft += tap(outer_uv)*outer_weight;
		soft_weight+=inner_weight+outer_weight;
	}
	soft/=soft_weight;
	vec3 col = mix(base, soft, mix(mix(softness,0.90,diffusion),.40,near_focus));

	// Halation: only what is already bright spills over, so the fog glows against the silhouettes.
	vec3 glow = vec3(0.0);
	float bloom_threshold=.62;
	for (int i = 0; i < 10; i++) {
		float a = float(i) * 0.6283185 + 0.2;
		for (int r = 1; r <= 3; r++) {
			vec3 c = tap(uv + vec2(cos(a + float(r)), sin(a + float(r))) * float(r) * 6.0 * dp);
			glow += max(c - vec3(bloom_threshold), vec3(0.0));
		}
	}
	glow /= 30.0;
	col += glow * bloom * 1.6 * mix(1.0,.74,mine_atmosphere);

	// Heavier film contrast: shadows sink, the fog stays creamy.
	col = mix(col, smoothstep(0.0, 1.0, col), contrast);
	// Keep luminous bulbs and their brightest pools, while settling the
	// broad middle grays into the surrounding black mineral silhouettes.
	vec3 mine_tone=col*mix(vec3(.78),vec3(1.0),smoothstep(vec3(.18),vec3(.68),col));
	col=mix(col,mine_tone,mine_atmosphere);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float frame_t = floor(TIME * 24.0);

	// Film grain has fine silver grains plus a faint larger emulsion clump. Its
	// apparent size grows gently with resolution instead of turning into 4K digital noise.
	vec2 cell = floor(FRAGCOORD.xy / (1.35 * resolution_scale));
	float fine_grain = hash21(cell + frame_t * vec2(17.0, 31.0)) - 0.5;
	float emulsion = hash21(floor(cell / 3.0) + frame_t * vec2(7.0, 13.0)) - 0.5;
	float n = fine_grain * 0.78 + emulsion * 0.22;
	float weight = 0.5 + 0.5 * (1.0 - pow(abs(luma - 0.5) * 2.0, 2.0));
	// Linear HDR addition used to lift absolute black into crawling gray
	// pepper after display transfer. Keep emulsion in exposed midtones;
	// silhouettes stay dense rather than acquiring a second moving texture.
	float emulsion_exposure=mix(1.0,smoothstep(.001,.045,max(luma,0.0)),route_softness);
	col += n * grain * weight * emulsion_exposure;
	// Frame: the corners fall away, a little more at the top and bottom.
	vec2 q = (uv - 0.5) * vec2(1.0, 1.15);
	float v = smoothstep(0.28, 0.82, length(q) * 1.35);
	col *= 1.0 - vignette * v;

	// Fixed, broad falloff. Vary both its reach and its density so the outer
	// pixels retain some scene light instead of joining into a solid black frame.
	vec2 iris_uv=(uv-vec2(0.50,0.52))/vec2(0.54,0.46);
	float broad=lens_noise(uv*vec2(4.2,3.1)+vec2(2.7,5.4));
	float fine=lens_noise(uv*vec2(10.0,7.0)+vec2(3.7,8.2));
	float drift=(broad-0.5)*0.22+(fine-0.5)*0.065;
	float iris=smoothstep(0.34,1.20,length(iris_uv)+drift);
	float density=mix(0.70,1.0,broad*0.72+fine*0.28);
	col *= 1.0-iris*iris_strength*density;

	// Projector flicker.
	col *= 1.0 + (hash11(floor(TIME * 12.0) + 3.0) - 0.5) * 2.0 * flicker * mix(1.0,.35,route_softness);

	// Scratches and dust: rare, thin, and light.
	float t8 = floor(TIME * 7.0);
	float sx = hash11(t8 * 1.7 + 1.0);
	float on = step(0.82, hash11(t8 * 2.3 + 5.0));
	float line = (1.0 - smoothstep(0.0, dp.x * 1.15, abs(uv.x - sx))) * on;
	line *= 0.35 + 0.65 * hash21(vec2(floor(uv.y * 36.0), t8));
	col += line * 0.10 * scratches * mix(1.0,.30,route_softness);
	float dust = 0.0;
	for (int k = 0; k < 3; k++) {
		float seed = floor(TIME * 12.0) * 3.0 + float(k);
		vec2 p = vec2(hash11(seed * 1.3 + 7.0), hash11(seed * 2.9 + 11.0));
		float show = step(0.55, hash11(seed * 4.1 + 2.0));
		float d = length((uv - p) * screen_size);
		dust += (1.0 - smoothstep(0.8, 2.2, d)) * show;
	}
	col -= dust * 0.22 * scratches * (0.3 + luma);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
