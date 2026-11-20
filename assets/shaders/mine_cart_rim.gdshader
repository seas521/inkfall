shader_type canvas_item;
render_mode unshaded;
uniform float illumination=1.0;
uniform float highlight_x=0.43;
uniform float silhouette_tone=0.001;
void fragment(){
 vec4 body=texture(TEXTURE,UV);
 float above=texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y*1.1)).a;
 float rim=max(0.0,body.a-above)*(1.0-smoothstep(0.30,0.75,UV.y));
 // A short, feathered reflection, not an outline of the entire cart lip.
 float patch=exp(-pow((UV.x-highlight_x)/0.085,2.0));
 patch+=0.22*exp(-pow((UV.x-0.58)/0.045,2.0));
 float reflection=rim*patch*0.16;
 float shoulder=body.a*exp(-pow((UV.x-0.44)/0.10,2.0))*exp(-pow((UV.y-0.38)/0.045,2.0))*0.002;
 COLOR=vec4(vec3(silhouette_tone+(reflection+shoulder)*illumination),body.a);
}
