shader_type canvas_item;
render_mode unshaded;
uniform bool image_mode=false;
uniform sampler2D waves : filter_linear, repeat_disable;
uniform float clock=0.0;
uniform vec2 crop_x=vec2(0.0,1.0);
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 float swell=texture(waves,vec2(((world.x-1100.0)/4.0+.5)/264.0,.5)).r;
 float water_y=575.0+sin(world.x*.035+clock*1.6)*.55-swell;
 if(world.y<water_y){discard;}
 float depth=world.y-water_y;
 if(image_mode){
  vec2 d=TEXTURE_PIXEL_SIZE*.65;
  vec4 c=texture(TEXTURE,UV)*.40;
  c+=(texture(TEXTURE,UV+vec2(d.x,0))+texture(TEXTURE,UV-vec2(d.x,0))+texture(TEXTURE,UV+vec2(0,d.y))+texture(TEXTURE,UV-vec2(0,d.y)))*.15;
  float l=dot(c.rgb,vec3(.299,.587,.114));
  float alpha=smoothstep(.12,.88,c.a);
  float local_x=(UV.x-crop_x.x)/(crop_x.y-crop_x.x);
  alpha*=smoothstep(0.0,.16,local_x)*(1.0-smoothstep(.84,1.0,local_x));
  alpha*=1.0-smoothstep(130.0,340.0,depth)*.75;
  // Keep broad received light and volume, suppress generated pale outlines.
  float ink=.045+min(l*.75,.19);
  COLOR=vec4(vec3(ink),alpha*.9);
 }else{
  float air_light=exp(-pow((world.x-1810.0)/600.0,2.0));
  float tone=mix(.32,.36,air_light)*(1.0-smoothstep(50.0,390.0,depth)*.22);
  COLOR=vec4(vec3(tone),1.0);
 }
}
