shader_type canvas_item;
render_mode unshaded;
uniform float energy=1.0;
void fragment(){
 vec4 t=texture(TEXTURE,UV);
 float l=dot(t.rgb,vec3(0.299,0.587,0.114));
 // Dense opaque metal, with a restrained rim. Only the bulb emits light.
 float bulb=(1.0-smoothstep(.13,.29,abs(UV.x-.5)))*smoothstep(.73,.81,UV.y)*(1.0-smoothstep(.92,.98,UV.y))*smoothstep(.22,.52,l);
 float metal=.006+pow(l,1.65)*.23;
 float value=mix(metal,mix(.025,.9,energy),bulb);
 COLOR=vec4(vec3(value),smoothstep(.12,.88,t.a));
}
