shader_type canvas_item;
render_mode unshaded;
uniform float lamp_left=0.0;
uniform float lamp_right=0.0;
uniform float idle_strength=.025;
float arrow_distance(vec2 p){
 // A broad shaft overlaps a solid triangular head: a weighty, readable
 // direction mark rather than a thin UI chevron.
 vec2 b=abs(p-vec2(-3.,0.))-vec2(5.,2.4);
 float shaft=length(max(b,vec2(0.)))+min(max(b.x,b.y),0.);
 float head=max(-p.x-1.,(p.x+abs(p.y)*1.333333-7.)/1.666667);
 return min(shaft,head);
}
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float v=dot(c.rgb,vec3(.299,.587,.114));
 vec2 p=(UV-vec2(.5,.55))*vec2(82.,52.);
 float dl=arrow_distance(vec2(-(p.x+12.),p.y));
 float dr=arrow_distance(vec2(p.x-12.,p.y));
 float left_face=1.-smoothstep(-.7,.8,dl);
 float right_face=1.-smoothstep(-.7,.8,dr);
 float left_halo=exp(-pow(max(dl,0.),2.)/6.);
 float right_halo=exp(-pow(max(dr,0.),2.)/6.);
 float uneven=.94+.035*sin(p.y*.9+p.x*.2)+.025*cos(p.x*1.3);
 float iron=.00012+min(v*v*.010,.0012);
 // Dim translucent paint remains readable before either sign energizes.
 float emboss=(left_face+right_face)*idle_strength;
 float emission=lamp_left*(left_face*.44*uneven+left_halo*.035)+lamp_right*(right_face*.44*uneven+right_halo*.035);
 COLOR=vec4(vec3(iron+emboss+emission),smoothstep(.08,.96,c.a));
}
