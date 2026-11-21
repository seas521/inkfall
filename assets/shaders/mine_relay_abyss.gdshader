shader_type canvas_item;
render_mode unshaded;
// Continue the registered far wall below its old image boundary. The
// foreground cliff still occludes this sheet; it is not a light on the cart.
varying float world_x;
void vertex(){world_x=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).x;}
void fragment(){
 float source_y=clamp(.94+UV.y,.94,.997);
 vec3 c=texture(TEXTURE,vec2(UV.x,source_y)).rgb;
 float depth=max(0.0,UV.y-.043);
 float strata=.5+.5*sin(UV.x*19.0+sin(UV.y*4.1)*.7);
 float distant_rock=1.0-.16*pow(strata,3.0)*smoothstep(.02,.20,UV.y);
 c*=exp(-depth*1.35)*distant_rock;
 COLOR=vec4(c,smoothstep(0.0,.025,UV.y)*(1.-smoothstep(1740.,2260.,world_x)));
}
