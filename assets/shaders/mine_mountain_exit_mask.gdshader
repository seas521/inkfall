shader_type canvas_item;
render_mode unshaded;
varying float world_x;
void vertex(){world_x=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).x;}
void fragment(){COLOR.a*=1.-smoothstep(1550.,1930.,world_x);}
