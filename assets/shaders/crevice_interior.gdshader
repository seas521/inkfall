shader_type canvas_item;
uniform float left_edge;
uniform float right_edge;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float a=smoothstep(left_edge,left_edge+42.,world.x)*(1.-smoothstep(right_edge-42.,right_edge,world.x));
 float mist=.49+.025*sin(world.x*.012+world.y*.006+TIME*.08);
 COLOR=vec4(vec3(mist),a*.9);
}
