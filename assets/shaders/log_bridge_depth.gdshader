shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform vec2 camera=vec2(0.0);
uniform sampler2D ravine : filter_linear_mipmap;
uniform sampler2D mountain_contour : filter_linear;
uniform float opacity = 1.0;
uniform float destination_ink = 0.22;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280.0,720.0);
 // One continuous tall gorge. UVs depend only on camera position; landing
 // on the bank never changes the plate, sampling window or exposure.
 // The house and its supporting ridge share the same distant world plane.
 vec2 uv=vec2((p.x+camera.x*0.015)/1280.0,(p.y+camera.y*0.10+30.0)/720.0);
 uv=clamp(uv,vec2(0.002),vec2(0.998));
 vec2 texel=1.0/vec2(textureSize(ravine,0));
 vec3 rock=texture(ravine,uv).rgb*0.28;
 rock+=(texture(ravine,uv+vec2(texel.x*5.0,0)).rgb+texture(ravine,uv-vec2(texel.x*5.0,0)).rgb)*0.18;
 rock+=(texture(ravine,uv+vec2(0,texel.y*5.0)).rgb+texture(ravine,uv-vec2(0,texel.y*5.0)).rgb)*0.18;
 float v=dot(rock,vec3(0.333333));
 // Keep all distant stone in atmospheric gray. Pure black belongs to the
 // actual cliff and player, never a large painted background patch.
 float shoulder=texture(mountain_contour,vec2(uv.x,0.5)).r;
 float grounded_mass=smoothstep(shoulder-0.007,shoulder+0.007,uv.y);
 v=mix(clamp(v*0.82+0.025,0.22,0.80),destination_ink,grounded_mass);
 float n=noise(vec2(p.x*0.003-clock*0.009,(p.y+camera.y*0.3)*0.004));
 float mist=0.045*n;
 v=mix(v,0.62,mist*(1.0-grounded_mass));
 // A quiet exposure opening behind the destination, restricted to its
 // distant backdrop so the cabin/tree/ground stay the same gray mass.
 vec2 destination=(uv-vec2(0.824,0.365))*vec2(1280.0,720.0);
 float opening=exp(-dot(destination/vec2(160.0,110.0),destination/vec2(160.0,110.0)));
 v=mix(v,0.65,opening*smoothstep(0.48,0.65,dot(rock,vec3(0.333333)))*0.30*(1.0-grounded_mass));
 COLOR=vec4(vec3(v),opacity);
}
