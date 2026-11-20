shader_type canvas_item;
render_mode unshaded;
uniform sampler2D occluders : filter_linear, repeat_disable;
uniform float scroll=0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280.,720.);
 vec2 ray=vec2(.38,.925);
 float transmission=1.;float integral=0.;
 // Trace towards the canopy through the actual background tree alpha mask.
 // A trunk blocks the light beyond it; nearer silhouettes render after this pass.
 for(int i=0;i<14;i++){
  vec2 q=p-ray*(float(i)+.5)*43.;
  float inside=step(0.,q.x)*step(q.x,1280.)*step(0.,q.y)*step(q.y,720.);
  float hit=texture(occluders,clamp(q/vec2(1280.,720.),vec2(0.),vec2(1.))).a*inside;
  transmission*=1.-hit*.62;
  integral+=transmission;
 }
 float axis=p.x-p.y*.411+scroll*.22;
 float slit=noise(vec2(axis*.008,5.));
 float aperture=smoothstep(.33,.70,slit);
 float spread=exp(-pow((p.y-305.)/315.,2.));
 float air=.68+.32*noise(vec2((p.x+scroll*.12)*.003,p.y*.007));
 float energy=aperture*spread*air*(integral/14.)*.43;
 energy*=smoothstep(0.,95.,p.y)*(1.-smoothstep(490.,740.,p.y));
 COLOR=vec4(vec3(.58),energy);
}
