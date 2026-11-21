shader_type canvas_item;
render_mode unshaded;
// Water-contact attenuation is independent of the sharp, dark solid source.
// Registered to this static concept camera; future live water supplies its surface/depth.
uniform sampler2D volume_source : source_color, filter_linear_mipmap;
uniform float fade_start=495.0;
uniform float fade_end=582.0;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float y=UV.y*822.0;
 // Low-frequency form only: suppress bark and stone detail, keep dark masses.
 float form=0.0;
 float weight=0.0;
 for(int j=-2;j<=2;j++){
  for(int i=-2;i<=2;i++){
   vec4 sample_value=texture(volume_source,UV+vec2(float(i)*7.0/1914.0,float(j)*7.0/822.0));
   form+=sample_value.r*sample_value.a;
   weight+=sample_value.a;
  }
 }
 form/=max(weight,0.001);
 float water_air=smoothstep(400.0,562.0,y);
 c.rgb=vec3(0.004+form*0.26+water_air*0.025);
 c.a*=1.0-smoothstep(fade_start,fade_end,y);
 COLOR=c;
}
