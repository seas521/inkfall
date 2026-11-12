shader_type canvas_item;
uniform sampler2D wall_image:filter_linear,repeat_disable;
uniform sampler2D ground_profile:filter_linear,repeat_disable;
uniform sampler2D source_floor_profile:filter_linear,repeat_disable;
uniform float source_width=2172.;
uniform float source_height=724.;
uniform float image_scale_y=1.4;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float floor_y=texture(ground_profile,vec2(UV.x,.5)).r;
 float source_floor=texture(source_floor_profile,vec2(UV.x,.5)).r;
 float sy=(world.y-floor_y)/image_scale_y+source_floor;
 vec4 ink=texture(wall_image,vec2(UV.x,clamp(sy/source_height,.001,.999)));
 // Preserve the cleaned RGBA edge in a single composite. Never turn
 // luminance/film grain into separate overlapping alpha masks.
 float value=max(ink.r,max(ink.g,ink.b));
 ink.rgb=mix(vec3(.004),ink.rgb,smoothstep(.065,.12,value));
 COLOR=vec4(ink.rgb,ink.a*(1.-step(source_height,sy)));
}
