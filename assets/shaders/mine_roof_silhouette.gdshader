shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 rock=texture(TEXTURE,UV);
 float l=dot(rock.rgb,vec3(.299,.587,.114));
 // The generator's pale semitransparent padding is not rock. Key it out
 // before styling the atlas; never render the cell rectangle as a fragment.
 float solid=(1.0-smoothstep(.14,.42,l))*rock.a;
 COLOR=vec4(vec3(.003),solid);
}
