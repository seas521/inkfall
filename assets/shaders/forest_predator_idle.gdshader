shader_type canvas_item;
// A small hinged rotation of the rest lower jaw. The head/stem stay fixed;
// source-video translation is never used for ambient breathing.
uniform float closure : hint_range(0.0,1.0)=0.0;
uniform vec4 rest_rect=vec4(85.0,90.0,207.0,274.0);
float jaw_mask(vec2 p){
 float boundary=400.0+40.0*smoothstep(250.0,330.0,p.x)-10.0*smoothstep(420.0,540.0,p.x);
 float mask=smoothstep(boundary-2.0,boundary+2.0,p.y);
 mask*=1.0-smoothstep(520.0,600.0,p.x);
 mask*=1.0-smoothstep(600.0,620.0,p.y);
 return mask;
}
void fragment(){
 vec2 canvas=rest_rect.xy+UV*rest_rect.zw;
 vec2 source=(canvas-vec2(0.0,2.0))/0.4;
 // Positive screen-space rotation lifts the left-facing lower jaw.
 vec2 hinge=vec2(565.0,515.0);
 float angle=-closure*0.06;
 float c=cos(angle),s=sin(angle);
 vec2 d=source-hinge;
 vec2 jaw_source=hinge+vec2(c*d.x-s*d.y,s*d.x+c*d.y);
 vec2 jaw_uv=(jaw_source*0.4+vec2(0.0,2.0)-rest_rect.xy)/rest_rect.zw;
 float inside=step(0.0,jaw_uv.x)*step(0.0,jaw_uv.y)*step(jaw_uv.x,1.0)*step(jaw_uv.y,1.0);
 vec4 rest=texture(TEXTURE,UV);
 float body=rest.a*(1.0-jaw_mask(source));
 float jaw=texture(TEXTURE,jaw_uv).a*jaw_mask(jaw_source)*inside;
 COLOR=vec4(rest.rgb,clamp(body+jaw,0.0,1.0));
}
