shader_type canvas_item;
render_mode unshaded;
uniform float exposure=0.72;
uniform float softness=0.6;
uniform float contrast=1.08;
uniform bool feather_entry=true;
uniform bool background=false;
uniform bool silhouette=false;
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*softness;
 vec4 c=texture(TEXTURE,UV);vec3 rgb=c.rgb*c.a*.5;float a=c.a*.5;
 vec4 s=texture(TEXTURE,UV+vec2(d.x,0));rgb+=s.rgb*s.a*.125;a+=s.a*.125;
 s=texture(TEXTURE,UV-vec2(d.x,0));rgb+=s.rgb*s.a*.125;a+=s.a*.125;
 s=texture(TEXTURE,UV+vec2(0,d.y));rgb+=s.rgb*s.a*.125;a+=s.a*.125;
 s=texture(TEXTURE,UV-vec2(0,d.y));rgb+=s.rgb*s.a*.125;a+=s.a*.125;
 float l=dot(rgb/max(a,.00001),vec3(.299,.587,.114));
 float tone=pow(l,contrast)*exposure;
 // The near plane reads through its alpha silhouette and negative spaces,
 // not through photographed grain, bevels or bright painted rim lines.
 // Compress all source shading into a very narrow near-black interval;
 // retain the original edge alpha and the independent far-plane lighting.
 if(silhouette)tone=.0025+.0065*smoothstep(.66,.97,l);
 if(background)tone*=smoothstep(0.0,.07,UV.y)*(1.0-smoothstep(.88,.99,UV.y))*(1.0-smoothstep(.92,1.0,UV.x));
 float entry=feather_entry?smoothstep(0.0,.075,UV.x):1.0;
 COLOR=vec4(vec3(tone),a*entry);
}
