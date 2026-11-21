shader_type canvas_item;
render_mode unshaded;
uniform float left_feather=.12;
uniform vec2 lamp=vec2(1065.0,-3250.0);
uniform float lamp_angle=0.0;
uniform vec2 origin=vec2(780.0,-3490.0);
uniform vec2 extent=vec2(2200.0,733.333);
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*.85;
 vec4 c=texture(TEXTURE,UV)*.4;
 c+=texture(TEXTURE,UV+vec2(d.x,d.y))*.15;
 c+=texture(TEXTURE,UV+vec2(-d.x,d.y))*.15;
 c+=texture(TEXTURE,UV+vec2(d.x,-d.y))*.15;
 c+=texture(TEXTURE,UV-d)*.15;
 vec2 world=origin+UV*extent;
 vec2 q=world-lamp;
 float shift=sin(lamp_angle)*max(q.y,0.0);
 float pool=exp(-pow((q.x-shift)/210.0,2.0))*smoothstep(-20.0,80.0,q.y)*(1.0-smoothstep(330.0,680.0,q.y));
 float dim=1.0-.12*exp(-pow((q.x+shift*1.8)/260.0,2.0))+.2*pool;
 COLOR=vec4(c.rgb*dim,c.a*smoothstep(0.0,left_feather,UV.x)*(1.0-smoothstep(1740.0,2260.0,world.x)));
}
