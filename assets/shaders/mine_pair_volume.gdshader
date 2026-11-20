shader_type canvas_item;
render_mode unshaded;
uniform float exposure=1.0;
uniform float softness=1.0;
uniform bool background=false;
float lamp_pool(vec2 p,vec2 lamp){
 float down=p.y-lamp.y;
 float width=48.0+max(down,0.0)*.62;
 float spread=exp(-pow((p.x-lamp.x)/width,2.0)*1.6);
 return spread*smoothstep(-18.0,22.0,down)*(1.0-smoothstep(90.0,355.0,down));
}
void fragment(){
 // Filter premultiplied coverage so dark structural edges never acquire
 // pale fringes. The broad illumination is rendered from actual geometry.
 vec2 d=TEXTURE_PIXEL_SIZE*softness;
 vec4 c=texture(TEXTURE,UV);vec3 p=c.rgb*c.a*.4;float a=c.a*.4;
 for(int y=-1;y<=1;y++){
  for(int x=-1;x<=1;x++){
   if(x==0&&y==0)continue;
   vec4 tap=texture(TEXTURE,UV+vec2(float(x),float(y))*d);
   p+=tap.rgb*tap.a*.075;a+=tap.a*.075;
  }
 }
 float l=dot(p/max(a,.00001),vec3(.299,.587,.114));
 float tone=l*exposure;
 // A gentle shoulder retains side/top-plane separation without white rims.
 tone=.48*(1.0-exp(-tone/.48));
 if(background){
  vec2 p=UV*vec2(1671.0,941.0);
  float pool=max(max(lamp_pool(p,vec2(290,135)),lamp_pool(p,vec2(755,325))),max(lamp_pool(p,vec2(525,665)),lamp_pool(p,vec2(1475,555))));
  // Light is received by the wall under practical lamps; unlit pockets
  // stay dark. No global gray lift and no painted glowing outlines.
  tone*=mix(.14,1.0,pool);
 }
 if(background)tone*=smoothstep(0.0,.065,UV.y)*(1.0-smoothstep(.90,1.0,UV.y))*(1.0-smoothstep(.95,1.0,UV.x));
 float entry=smoothstep(0.0,.075,UV.x);
 COLOR=vec4(vec3(tone),a*entry);
}
