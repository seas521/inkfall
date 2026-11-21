shader_type canvas_item;
render_mode unshaded;
uniform float water_y=565.0;
varying vec2 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 vec4 c=COLOR;
 float depth=world_position.y-water_y;
 float wet=smoothstep(-1.,5.,depth);
 c.rgb=mix(c.rgb,vec3(.29),wet*.22);
 c.a*=1.-smoothstep(-.5,7.,depth);
 COLOR=c;
}
