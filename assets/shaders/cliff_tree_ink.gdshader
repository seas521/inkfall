shader_type canvas_item;
render_mode unshaded;
uniform vec4 cut_rect;
uniform bool branch = false;
uniform bool damaged = false;
uniform float stress = 0.0;
uniform bool split_twig = false;
uniform bool twig_only = false;
uniform vec4 twig_rect;
uniform int twig_count = 0;
uniform vec2 twig_outline[16];
uniform int cut_count = 0;
uniform vec2 cut_outline[24];
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 bool inside=UV.x>=cut_rect.x && UV.x<=cut_rect.z && UV.y>=cut_rect.y && UV.y<=cut_rect.w;
 if(cut_count>0){
  inside=false;
  for(int i=0;i<24;i++){
   if(i>=cut_count)break;
   int j=(i+1)%cut_count;
   vec2 a=cut_outline[i]; vec2 b=cut_outline[j];
   if((a.y>UV.y)!=(b.y>UV.y)){
    float crossing=a.x+(UV.y-a.y)*(b.x-a.x)/(b.y-a.y);
    if(UV.x<crossing)inside=!inside;
   }
  }
 }
 // Overlap the stationary socket beneath the moving bough. Complementary
 // zero-width masks exposed a bright zigzag when the bough rotated.
 float seam=10000.0;
 vec2 pixel=UV*vec2(textureSize(TEXTURE,0));
 if(cut_count==0){
  vec2 lo=cut_rect.xy*vec2(textureSize(TEXTURE,0));
  vec2 hi=cut_rect.zw*vec2(textureSize(TEXTURE,0));
  seam=min(min(abs(pixel.x-lo.x),abs(pixel.x-hi.x)),min(abs(pixel.y-lo.y),abs(pixel.y-hi.y)));
 }
 if(cut_count>0){
  for(int i=0;i<24;i++){
   if(i>=cut_count)break;
   vec2 a=cut_outline[i]*vec2(textureSize(TEXTURE,0));
   vec2 b=cut_outline[(i+1)%cut_count]*vec2(textureSize(TEXTURE,0));
   vec2 d=b-a;
   seam=min(seam,length(pixel-(a+d*clamp(dot(pixel-a,d)/max(dot(d,d),0.001),0.0,1.0))));
  }
 }
 if(!twig_only){
  if(branch && !inside)discard;
  if(!branch && inside && seam>14.0)discard;
 }
 bool twig=UV.x>=twig_rect.x && UV.x<=twig_rect.z && UV.y>=twig_rect.y && UV.y<=twig_rect.w;
 if(twig_count>0){
  twig=false;
  for(int i=0;i<16;i++){
   if(i>=twig_count)break;
   vec2 a=twig_outline[i]; vec2 b=twig_outline[(i+1)%twig_count];
   if((a.y>UV.y)!=(b.y>UV.y)){
    if(UV.x<a.x+(UV.y-a.y)*(b.x-a.x)/(b.y-a.y))twig=!twig;
   }
  }
 }
 if(split_twig){
  if(twig_only && !twig)discard;
  if(!twig_only && twig)discard;
 }
 // Keep the existing scene's deep ink; texture never becomes a gray mass.
 // Match the actor's dense ink. This is linear HDR, not an sRGB swatch;
 // the former .004 became a gray wooden face once the bough was in focus.
 float tone=0.00012;
 // Generated cutout interiors carried residual transparency and leaked the bright valley.
 // A small optical edge, without lifting black wood or blurring its interior.
 vec2 edge_step=TEXTURE_PIXEL_SIZE*1.4;
 float alpha=source.a*0.40;
 alpha+=texture(TEXTURE,UV+vec2(edge_step.x,0)).a*0.15;
 alpha+=texture(TEXTURE,UV-vec2(edge_step.x,0)).a*0.15;
 alpha+=texture(TEXTURE,UV+vec2(0,edge_step.y)).a*0.15;
 alpha+=texture(TEXTURE,UV-vec2(0,edge_step.y)).a*0.15;
 float coverage=smoothstep(0.025,0.80,alpha);
 COLOR=vec4(vec3(tone),coverage);
}
