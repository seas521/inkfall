shader_type canvas_item;
render_mode unshaded;

// Registered concept plate: dark exposed soil, original submerged transmission.
// This is independent of camera defocus and must use live depth in gameplay.
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec2 pixel = UV * vec2(1914.0, 822.0);
 float below_bank = pixel.y - (525.0 + 0.17 * pixel.x);
 float dry = (1.0 - smoothstep(8.0, 85.0, below_bank))
           * (1.0 - smoothstep(190.0, 440.0, pixel.x));
 source.rgb = mix(source.rgb, vec3(0.006), dry * 0.97);
 COLOR = source;
}
