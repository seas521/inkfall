shader_type canvas_item;
render_mode unshaded;
uniform vec2 lamp_a;
uniform vec2 lamp_b;
uniform float exit_light = 0.0;
uniform float row = 0.0;
uniform float second_strength=0.55;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
float pool(vec2 p,vec2 lamp,float strength){
 vec2 d=p-lamp;
 float spread=26.0+max(d.y,0.0)*0.52;
 return strength*exp(-pow(d.x/spread,2.0)*1.3)*exp(-max(d.y,0.0)/230.0)*smoothstep(-8.0,22.0,d.y);
}
void fragment(){
 vec2 lo=vec2(0.001,row/3.0+0.002), hi=vec2(0.999,(row+1.0)/3.0-0.002);
 vec3 source=vec3(0.0);float total=0.0;
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  float w=(x==0&&y==0)?4.0:1.0;
  source+=texture(TEXTURE,clamp(UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*2.2,lo,hi)).rgb*w;total+=w;
 }}
 float l=pow(dot(source/total,vec3(0.299,0.587,0.114)),0.65);
 float light=pool(world,lamp_a,1.0)+pool(world,lamp_b,second_strength);
 float stone=smoothstep(0.006,0.085,l);
 float tone=l*0.72+light*0.55*stone;
 tone+=exit_light*smoothstep(0.46,0.94,UV.x)*l*0.35;
 float ground=smoothstep(mix(0.70,0.91,UV.x)-0.015,mix(0.70,0.91,UV.x)+0.035,UV.y*3.0-row);
 tone*=mix(1.0,0.16,ground);
 float edge=(row<0.5)?smoothstep(0.0,0.035,UV.x):1.0;
 COLOR=vec4(vec3(min(tone,0.65)),edge);
}
