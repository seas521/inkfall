shader_type canvas_item;
render_mode unshaded;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void fragment(){
 float n=noise(UV*vec2(3.5,9.0)+vec2(TIME*0.018,-TIME*0.006));
 float veil=noise(UV*vec2(2.0,5.0)-vec2(TIME*0.009,0));
 float edge=smoothstep(0.0,0.16,UV.x)*(1.0-smoothstep(0.84,1.0,UV.x))*smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.85,1.0,UV.y));
 COLOR=vec4(vec3(0.42),smoothstep(0.32,0.78,n*0.65+veil*0.35)*0.16*edge);
}
