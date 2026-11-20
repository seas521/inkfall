shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float strength=0.0;
uniform float seed=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float h=1.0-UV.y;
 float n=noise(vec2(UV.x*5.0+seed,UV.y*7.0+clock*6.0));
 float sway=sin(h*8.0-clock*11.0+seed)*h*0.075;
 float width=mix(0.36,0.03,h);
 float core=1.0-smoothstep(width*0.4,width,abs(UV.x-0.5+sway));
 float top=1.0-smoothstep(0.65+0.13*n,1.0,h);
 float bottom=smoothstep(0.0,0.08,h);
 float body=core*top*bottom*(0.55+n*0.45);
 COLOR=vec4(vec3(0.52+0.15*n),body*strength*0.86);
}
