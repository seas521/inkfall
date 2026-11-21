shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 vec2 p=UV*vec2(1914.,822.);
 float water=smoothstep(235.,420.,p.x)*(1.-smoothstep(1070.,1260.,p.x));
 float low=smoothstep(370.,510.,p.y)*(1.-smoothstep(570.,600.,p.y));
 c.rgb+=(vec3(1.)-c.rgb)*water*low*.13;
 COLOR=c;
}
