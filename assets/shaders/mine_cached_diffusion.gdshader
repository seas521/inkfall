shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform vec2 direction=vec2(1.0,0.0);
uniform float sigma=1.35;
uniform bool preserve_residual=false;
void fragment(){
 // Cached HDR view textures are already premultiplied. Blur color and
 // coverage together, avoiding pale rims or dark repeated alpha fringes.
 vec4 sum=vec4(0.0);float total=0.0;float strongest=0.0;
 for(int i=-8;i<=8;i++){
  float distance=float(i)*sigma*.4;
  float weight=exp(-.5*distance*distance/(sigma*sigma));
  vec4 sample_value=texture(TEXTURE,UV+TEXTURE_PIXEL_SIZE*direction*distance);
  sum+=sample_value*weight;strongest=max(strongest,sample_value.a);
  total+=weight;
 }
 vec4 original=texture(TEXTURE,UV);
 // Registered mattes also contain faint reconstruction corrections.
 // Keep those intact rather than diffusing them into bright seam lines.
 COLOR=mix(original,sum/total,preserve_residual?smoothstep(.25,.65,strongest):1.0);
}
