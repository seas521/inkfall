shader_type canvas_item;
render_mode unshaded;
uniform float value_scale=1.0;
uniform float flat_ink_tone=-1.0;
uniform float softness=.65;
uniform bool near_ink=false;
uniform float left_feather=0.0;
uniform bool round_crop=false;
uniform vec2 crop_center=vec2(.5);
uniform float crop_radius=44.0;
uniform int part_mask=0;
// Opt-in reflected light for the basket's near wall. It must remain
// distinguishable from the black load seen through its open slats.
uniform bool basket_wall=false;
uniform vec2 basket_mouth=vec2(0.0);
uniform vec2 basket_lamp=vec2(0.0);
varying vec2 world_vertex;
void vertex(){world_vertex=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*softness;
 vec4 c=texture(TEXTURE,UV);
 vec3 p=c.rgb*c.a*.6;float a=c.a*.6;
 for(int i=0;i<4;i++){
  vec2 direction=vec2((i==0||i==3)?-1.0:1.0,i<2?-1.0:1.0);
  vec4 t=texture(TEXTURE,UV+direction*d);
  p+=t.rgb*t.a*.1;a+=t.a*.1;
 }
 float l=dot(p/max(a,.00001),vec3(.299,.587,.114));
 float tone=l*value_scale;
 // Display texture sampling already converts sRGB to linear in HDR 2D.
 // Only this authored playing plane is inked; background light is retained.
 if(near_ink)tone=min(tone,.00012);
 if(flat_ink_tone>=0.0)tone=flat_ink_tone;
 if(basket_wall){
  vec2 to_lamp=basket_lamp-world_vertex;
  float incident=max(0.0,-normalize(to_lamp+vec2(.001)).y);
  float falloff=1.0/(1.0+dot(to_lamp,to_lamp)/180000.0);
  float depth=max(0.0,world_vertex.y-basket_mouth.y);
  tone=.00012+.006*incident*falloff*exp(-depth/15.0);
 }
 vec2 pixel=UV/TEXTURE_PIXEL_SIZE;
 if(round_crop)a*=1.0-smoothstep(crop_radius-.6,crop_radius+.6,length(pixel-crop_center));
 if(part_mask==1 && pixel.y<542.0 && abs(pixel.x-1187.0)>22.0)a=0.0;
 if(part_mask==3 && pixel.x>840.0 && pixel.x<931.0 && pixel.y>480.0 && pixel.y<513.0)a=0.0;
 // Replace the entire old wheel/rope fringe with the independently
 // mounted sheave and bearing, not just its central spokes.
 if(part_mask==2 && pixel.x<1046.0)a=0.0;
 float edge=left_feather>0.0?smoothstep(0.0,left_feather,UV.x):1.0;
 COLOR=vec4(vec3(tone),smoothstep(.008,.992,a)*edge);
}
