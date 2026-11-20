shader_type canvas_item;
render_mode unshaded,blend_premul_alpha;
uniform bool receives_light=false;
// Bulb positions in the registered source; z is actual suspension angle.
uniform vec3 lamps[6];
const vec2 REST[6]=vec2[6](vec2(258,152),vec2(846,375),vec2(515,686),vec2(1539,451),vec2(959,205),vec2(790,710));
float pool(vec2 p,vec2 origin,float angle){
 vec2 d=p-origin;
 vec2 q=vec2(cos(angle)*d.x+sin(angle)*d.y,-sin(angle)*d.x+cos(angle)*d.y);
 float reach=smoothstep(-18.0,18.0,q.y)*(1.0-smoothstep(340.0,650.0,q.y));
 float width=35.0+max(0.0,q.y)*.43;
 return exp(-1.5*q.x*q.x/(width*width))*reach;
}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 if(receives_light){
  vec2 p=UV*vec2(1672,941);
  float rest=.24;float moved=.24;
  for(int i=0;i<6;i++){
   if(abs(p.x-REST[i].x)>560.0)continue;
   float strength=i>=4?.26:.60;
   rest+=pool(p,REST[i],0.0)*strength;
   moved+=pool(p,lamps[i].xy,lamps[i].z)*strength;
  }
  // Modulate the approved light values; never paint white cones over the
  // near silhouettes or re-render the expensive cached layer mattes.
  tex.rgb*=clamp(moved/rest,.64,1.24);
 }
 COLOR=tex;
}
