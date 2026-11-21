shader_type canvas_item;
render_mode unshaded;
void fragment(){
 float depth=UV.y*822.0-565.0;
 vec2 reflected=vec2(UV.x,(1130.0-UV.y*822.0)/822.0);
 reflected.x+=sin(depth*.18+TIME*1.6)*0.0007*smoothstep(0.,70.,depth);
 vec4 c=vec4(0.0);
 for(int i=-2;i<=2;i++){
  vec4 s=texture(TEXTURE,reflected+vec2(float(i)*.00065,float(i)*.0004));
  c.rgb+=s.rgb*s.a/5.;c.a+=s.a/5.;
 }
 c.rgb/=max(c.a,.001);
 c.rgb=mix(c.rgb,vec3(.25),.2);
 c.a*=step(0.,depth)*(1.-smoothstep(25.,290.,depth))*.25;
 COLOR=c;
}
