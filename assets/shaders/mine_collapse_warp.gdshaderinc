// Same analytic displacement as MineChamberArt's CPU contact functions.
// The geometry stays resident; a physics tick changes only these two clocks.
uniform float collapse_clock=-1.0;
uniform int chamber_section=0;
float mine_collapse_weight(float x,int section){
 if(section==0)return smoothstep(-3100.0,-2985.0,x)*(1.0-smoothstep(-2450.0,-2340.0,x));
 return smoothstep(-2220.0,-2130.0,x)*(1.0-smoothstep(-1540.0,-1420.0,x));
}
float mine_local_age(float x,int section){
 return section==0?collapse_clock:collapse_clock-(1.3+max(0.0,x+2340.0)/310.0);
}
float mine_floor_warp_section(float x,int section){
 if(collapse_clock<0.0)return 0.0;
 float t=max(0.0,mine_local_age(x,section));
 float slump=smoothstep(.24,1.25,t)*(18.0+9.0*sin((x+2900.0)*.011));
 float shock=sin((x+3000.0)*.037-t*37.0)*3.8*exp(-max(0.0,t-.25)*3.0)*smoothstep(0.0,.15,t);
 return mine_collapse_weight(x,section)*(slump+shock);
}
float mine_floor_warp(float x){return mine_floor_warp_section(x,0)+mine_floor_warp_section(x,1);}
float mine_roof_warp(float x){
 if(collapse_clock<0.0)return 0.0;
 float delay=.08+abs(x+2620.0)*.00018;
 float t=max(0.0,mine_local_age(x,chamber_section)-delay);
 return mine_collapse_weight(x,chamber_section)*(smoothstep(0.0,.65,t)*24.0+smoothstep(.32,1.25,t)*(200.0+18.0*sin(x*.012)));
}
