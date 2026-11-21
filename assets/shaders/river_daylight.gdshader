shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D blockers:filter_linear,repeat_disable;
uniform vec4 bounds=vec4(-900.,-1500.,4700.,3300.);
#include "res://assets/shaders/chapter_sun_apertures.gdshaderinc"
float opacity_at(vec2 p){
 vec2 uv=(p-bounds.xy)/bounds.zw;
 if(min(min(uv.x,uv.y),min(1.-uv.x,1.-uv.y))<0.)return 0.;
 return texture(blockers,uv).a;
}
void fragment(){
 vec2 p=bounds.xy+UV*bounds.zw;
 vec2 toward=normalize(vec2(.48,-1.));
 vec2 across=vec2(-toward.y,toward.x);
 float visibility=1.;
 for(int i=0;i<56;i++){
  float t=float(i)/55.;float distance=9.+t*t*1850.;
  float spread=2.+distance*.010;
  vec2 at=p+toward*distance;
  float opacity=opacity_at(at)*.5+opacity_at(at+across*spread)*.25+opacity_at(at-across*spread)*.25;
  visibility=min(visibility,1.-opacity);
  if(visibility<.003)break;
 }
 float incident=chapter_river_incident(p);
 COLOR=vec4(incident*visibility,visibility,incident,1.);
}
