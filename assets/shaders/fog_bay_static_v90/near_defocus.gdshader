shader_type canvas_item;
render_mode unshaded;
uniform float radius : hint_range(0.0,24.0) = 12.0;
uniform vec2 direction=vec2(1.0,0.0);
void fragment(){
 if(radius<0.01){COLOR=texture(TEXTURE,UV);}
 else {
  vec3 premult=vec3(0.0);float alpha=0.0;float total=0.0;
  float sigma=max(radius*0.5,0.5);
  // Dense, separable Gaussian: thin reeds must blur, not become shifted copies.
  for(int i=-18;i<=18;i++){
   float distance_px=float(i);
   float weight=exp(-distance_px*distance_px/(2.0*sigma*sigma));
   vec2 uv=UV+direction*TEXTURE_PIXEL_SIZE*distance_px;
   vec4 c=texture(TEXTURE,uv);
   premult+=c.rgb*c.a*weight;alpha+=c.a*weight;total+=weight;
  }
  COLOR=vec4(premult/max(alpha,0.00001),alpha/total);
 }
}
