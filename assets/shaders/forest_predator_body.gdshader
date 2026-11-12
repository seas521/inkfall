shader_type canvas_item;
uniform float closure=0.0;
uniform bool closed_pose=false;
uniform float pose_weight=0.0;
uniform float swelling=0.0;
uniform float swallow_age=-1.0;
void vertex(){
 vec2 root=vec2(265.0,640.0);
 vec2 p=VERTEX/0.35+root;
 // One stable lip band: never deform the outer contour column by column
 // around individual teeth. The whole upper/lower mass closes together.
 vec2 lips=vec2(130.0,320.0);
 float middle=(lips.x+lips.y)*0.5;
 float sealed_y=p.y;
 if(p.y<=lips.x)sealed_y+=middle-lips.x;
 else if(p.y>=lips.y)sealed_y+=middle-lips.y;
 else sealed_y=middle;
 float neck_fade=1.0-smoothstep(310.0,365.0,p.y);
 float hinge_fade=1.0-smoothstep(330.0,395.0,p.x);
 if(!closed_pose)p.y=mix(p.y,sealed_y,min(closure,0.40)*neck_fade*hinge_fade);
 // Small local fullness followed by a travelling throat contraction.
 vec2 head=vec2(246.0,218.0);
 vec2 h=(p-head)/vec2(240.0,200.0);
 float head_weight=exp(-dot(h,h)*1.5);
 p+=(p-head)*swelling*head_weight;
 float travel=smoothstep(0.35,2.1,max(0.0,swallow_age));
 vec2 throat=vec2(mix(398.0,282.0,travel),mix(320.0,555.0,travel));
 vec2 n=(p-throat)/vec2(95.0,92.0);
 float wave=exp(-dot(n,n)*1.6)*swelling*2.5;
 p.x+=(p.x-throat.x)*wave;
 p.y+=wave*6.0;
 float rooted=1.0-smoothstep(590.0,640.0,p.y);
 VERTEX=mix(VERTEX,(p-root)*0.35,rooted);
}
void fragment(){
 float a=smoothstep(0.05,0.95,texture(TEXTURE,UV).a);
 vec2 p=UV*vec2(1536.0,1024.0)-vec2(1024.0,300.0);
 a*=closed_pose?pose_weight:1.0-pose_weight;
 COLOR=vec4(vec3(0.003),a);
}
