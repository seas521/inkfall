shader_type canvas_item;
render_mode unshaded;
uniform float tone=.08;
uniform float opacity=.5;
uniform float radius=5.;
uniform float root_mist=.3;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*radius;
 float a=0.,weight=0.;
 // Dense Gaussian coverage avoids displaced duplicate edges in the far blur.
 for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){
  float w=exp(-float(x*x+y*y)*.5);
  a+=texture(TEXTURE,UV+vec2(float(x),float(y))*d).a*w;weight+=w;
 }
 a=a/weight*opacity*(1.-root_mist*smoothstep(.66,1.,UV.y));
 COLOR=vec4(vec3(tone),a);
}
