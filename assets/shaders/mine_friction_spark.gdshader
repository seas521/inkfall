shader_type canvas_item;
render_mode unshaded, blend_add;
varying vec3 particle;
void vertex(){particle=COLOR.rgb;}
void fragment(){
 float strength=particle.r;
 float intensity;
 if(particle.b>.5){
  vec2 p=(UV-.5)*vec2(1.0,1.45);
  intensity=.23*exp(-dot(p*4.4,p*4.4))+.90*exp(-dot(p*12.0,p*12.0));
 }else{
  float y=abs(UV.y-.5);
  float edge=smoothstep(0.0,.16,UV.x)*(1.0-smoothstep(.86,1.0,UV.x));
  float core=exp(-pow(y/.10,2.0));
  float bloom=.16*exp(-pow(y/.32,2.0));
  float hot= .62+.38*smoothstep(.1,.8,UV.x);
  intensity=(core*hot+bloom)*edge;
 }
 COLOR=vec4(vec3(1.0),clamp(intensity*strength,0.0,1.0));
}
