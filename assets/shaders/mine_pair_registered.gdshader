shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/mine_pair_source_masks.gdshaderinc"
uniform int layer_role=0;
uniform int lamp_id=0;
uniform float left_feather=0.0;
void fragment(){
 vec3 source=texture(approved_tex,UV).rgb;
 float l=source_luma(source);vec2 pixel=UV*vec2(1672,941);
 float a=1.0;
 if(layer_role==6){
  a=lamp_coverage(pixel,l,lamp_id);
 }else{
  vec3 clean=texture(clean_tex,UV).rgb;
  vec4 alphas=vec4(layer_coverage(1,UV,l),layer_coverage(2,UV,l),layer_coverage(3,UV,l),layer_coverage(4,UV,l));
  float remaining=(1.0-alphas.x)*(1.0-alphas.y)*(1.0-alphas.z)*(1.0-alphas.w);
  float strongest=max(max(alphas.x,alphas.y),max(alphas.z,alphas.w));
  float need=min(1.0,required_alpha(source,clean)+.001);
  if(strongest>.008 && 1.0-remaining<need){
   int selected=0;
   for(int i=1;i<4;i++)if(alphas[i]>alphas[selected])selected=i;
   float other=1.0;
   for(int i=0;i<4;i++)if(i!=selected)other*=1.0-alphas[i];
   alphas[selected]=clamp(1.0-(1.0-need)/max(other,.0001),0.0,1.0);
   remaining=(1.0-alphas.x)*(1.0-alphas.y)*(1.0-alphas.z)*(1.0-alphas.w);
  }
  if(layer_role==0){
   source=strongest>.008?clean:source;
  }else if(strongest>.008){
   // All overlapping plates share the same unassociated foreground color.
   // Overlap is intentional: disjoint masks cause bright seams when the
   // cached planes are bilinearly sampled at a different window size.
   a=alphas[layer_role-1];
   source=clamp((source-clean*remaining)/max(1.0-remaining,.0001),vec3(0),vec3(1));
  }else{a=0.0;}
 }
 if(left_feather>0.0)a*=smoothstep(0.0,left_feather,UV.x);
 // The playing plane shares the boy's dense silhouette. Rear galleries,
 // cavern air, lamps and their pools retain their independent values.
 if(layer_role==1 || layer_role==2)source=min(source,vec3(.00012));
 // The gantry upright sits behind the cart. A restrained dark reflected
 // value separates overlapping black silhouettes without outlining them.
 if(layer_role==2){
  float upright=box_coverage(pixel,vec4(1297,441,69,214),1.2);
  source=mix(source,max(source,vec3(.0035)),upright);
 }
 COLOR=vec4(source,a);
}
