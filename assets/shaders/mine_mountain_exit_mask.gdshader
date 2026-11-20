shader_type canvas_item;
render_mode unshaded;
varying float world_x;
void vertex(){world_x=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).x;}
void fragment(){COLOR.a*=1.-smoothstep(2050.,2780.,world_x);}
