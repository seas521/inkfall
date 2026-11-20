shader_type canvas_item;
render_mode unshaded;
uniform float flicker=1.0;
void fragment(){
 vec4 s=texture(TEXTURE,UV);
 float l=dot(s.rgb,vec3(0.299,0.587,0.114));
 float rim=exp(-pow((UV.y-0.23)/0.055,2.0));
 // The iron shares the scene's dark values; only the bowl catches its own fire.
 COLOR=vec4(vec3(l*(0.15+0.15*rim*flicker)),s.a);
}
