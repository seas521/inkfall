shader_type canvas_item;
render_mode unshaded;
uniform float flicker=1.0;
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 float l=dot(source.rgb,vec3(0.299,0.587,0.114));
 // Only a small charcoal recess, not a new lit room or a detailed rock overlay.
 float rim=pow(max(l-0.012,0.0),0.85)*0.52*flicker;
 float feather=smoothstep(0.0,0.13,UV.x)*(1.0-smoothstep(0.87,1.0,UV.x));
 feather*=smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.87,1.0,UV.y));
 COLOR=vec4(vec3(min(rim,0.17)),source.a*feather);
}
