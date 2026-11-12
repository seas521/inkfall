shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float camera_y = 0.0;
uniform float strength = 1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280,720);
 float world_y=p.y+camera_y;
 float a=noise(vec2(p.x*0.002-clock*0.016,world_y*0.006));
 float b=noise(vec2(p.x*0.004+clock*0.025,world_y*0.009+7.0));
 float bank=0.5+0.5*sin(world_y*0.019+a*3.0+clock*0.08);
 float density=smoothstep(0.30,0.83,a*0.5+b*0.25+bank*0.25);
 COLOR=vec4(vec3(0.55),density*0.43*strength);
}
