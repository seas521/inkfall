shader_type canvas_item;
render_mode unshaded;
void fragment(){
 // Only the source silhouette is used: no gray cloth/skin, glow or outlines.
 vec4 source=texture(TEXTURE,UV);
 COLOR=vec4(vec3(0.002),source.a*COLOR.a);
}
