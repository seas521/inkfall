shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec2 p=UV*vec2(1914.,822.);
 float water=smoothstep(180.,390.,p.x)*(1.-smoothstep(1100.,1310.,p.x));
 float height=exp(-pow((p.y-562.)/47.,2.));
 float threads=.7+.15*sin(p.x*.009+TIME*.16+p.y*.035)+.15*sin(p.x*.021-TIME*.11);
 float lower=exp(-pow((p.y-605.)/95.,2.))*.3;
 COLOR=vec4(vec3(.83),water*(height+lower)*threads*.17);
}
