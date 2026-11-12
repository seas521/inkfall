shader_type canvas_item;
uniform sampler2D ground_profile:filter_linear,repeat_disable;
uniform sampler2D ceiling_profile:filter_linear,repeat_disable;
uniform float profile_left;
uniform float profile_right;
uniform float entrance;
uniform float exit_x;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float u=clamp((world.x-profile_left)/(profile_right-profile_left),0.,1.);
 float floor_y=texture(ground_profile,vec2(u,.5)).r;
 float roof=texture(ceiling_profile,vec2(u,.5)).r;
 // The rear wall is opaque stone/air, never the exterior forest seen through.
 // Extend above the visible opening so the foreground rim hides its boundary.
 float sides=smoothstep(entrance-90.,entrance+18.,world.x)*(1.-smoothstep(exit_x-12.,exit_x+90.,world.x));
 float vertical=smoothstep(roof-340.,roof-270.,world.y)*(1.-smoothstep(floor_y+1.,floor_y+8.,world.y));
 float depth=smoothstep(entrance+100.,entrance+360.,world.x)*(1.-smoothstep(exit_x-270.,exit_x-40.,world.x));
 float y=clamp((floor_y-world.y)/max(roof-floor_y,-170.),-1.,0.);
 float grain=sin(world.x*.009+world.y*.016-TIME*.08)*sin(world.x*.017+TIME*.05);
 float value=mix(.43,.34,depth)+grain*.008+y*.012;
 COLOR=vec4(vec3(value),sides*vertical);
}
