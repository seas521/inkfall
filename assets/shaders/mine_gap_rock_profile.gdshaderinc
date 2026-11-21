// Shared world profile for every cached layer and solid fill of the bank.
uniform bool gap_rock_enabled=false;
uniform vec2 gap_rock_points[16];
uniform int gap_rock_count=0;
float mine_gap_rock_coverage(vec2 p){
 if(!gap_rock_enabled || gap_rock_count<2 || p.y<=-3100.)return 1.;
 float face_weight=smoothstep(-3100.,-3045.,p.y);
 if(p.x> -500.)return 1.;
 if(p.x< -700.)return 1.-face_weight;
 float edge=gap_rock_points[0].x;
 for(int i=1;i<16;i++){
  if(i>=gap_rock_count)break;
  vec2 a=gap_rock_points[i-1],b=gap_rock_points[i];
  if(p.y>=a.y){
   float t=clamp((p.y-a.y)/max(b.y-a.y,.001),0.,1.);
   edge=mix(a.x,b.x,mix(t,smoothstep(0.,1.,t),i>4?.55:0.));
  }
 }
 float feather=max(1.1,fwidth(p.x)*.9);
 return mix(1.,smoothstep(edge-feather,edge+feather,p.x),face_weight);
}
