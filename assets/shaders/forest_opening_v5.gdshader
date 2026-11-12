shader_type canvas_item;
uniform sampler2D forest_plate : filter_linear_mipmap, repeat_disable;
uniform sampler2D right_plate : filter_linear_mipmap, repeat_disable;
uniform float scroll = -9840.0;
uniform float clock = 0.0;
uniform float ground_y = 550.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280.0,720.0);
 // An oversized, world-anchored shot; no texture repeat or camera-centred lamp.
 vec2 q=vec2((p.x+265.0+(scroll+9840.0)*0.55)/1900.0,(p.y-ground_y+540.0)/1000.0);
 vec3 col=vec3(0.0);
 float total=0.0;
 for(int y=-2;y<=2;y++){
  for(int x=-2;x<=2;x++){
   float w=exp(-float(x*x+y*y)/3.0);
   vec2 tap_uv=q+vec2(float(x),float(y))*vec2(0.0018,0.0028);
   vec3 sample_color=texture(forest_plate,tap_uv).rgb;
   if(tap_uv.x>0.64) sample_color=mix(sample_color,texture(right_plate,tap_uv).rgb,smoothstep(0.64,0.70,tap_uv.x));
   col+=sample_color*w;
   total+=w;
  }
 }
 float value=dot(col/total,vec3(0.299,0.587,0.114));
 // The plate contains near trunks as well as air. Preserve dark silhouettes
 // before lighting; raw display samples otherwise lift these trunks to gray.
 value=pow(smoothstep(0.12,0.58,value),1.30)*0.85;
 // Canopy occlusion is anchored to the forest, with unequal light openings.
 // Preserve the sampled trunks; shade the air between them instead of lifting it all.
 float axis=p.x+(scroll+9840.0)*0.55+(p.y-220.0)*0.32;
 float gap_a=exp(-pow((axis-330.0)/105.0,2.0));
 float gap_b=exp(-pow((axis-960.0)/155.0,2.0));
 float broken=noise(vec2(axis*0.008,q.y*3.0+7.0));
 float window=max(gap_a*0.64,gap_b)*(0.65+0.35*broken);
 float height=exp(-pow((p.y-(ground_y-240.0))/300.0,2.0));
 float transmission=0.78+0.22*window*height;
 value*=mix(1.0,transmission,smoothstep(0.07,0.32,value));
 // Gentle highlight shoulder: retain luminous gaps without a clipped white patch.
 if(value>0.45){value=0.45+0.28*(1.0-exp(-(value-0.45)/0.28));}
 // Unequal canopy apertures: compact luminous cores, weaker scattered halos.
 // Source luminance gates the light so solid trunks cannot become emissive.
 float main_core=exp(-dot((q-vec2(0.60,0.235))/vec2(0.035,0.080),(q-vec2(0.60,0.235))/vec2(0.035,0.080)));
 float main_halo=exp(-dot((q-vec2(0.60,0.235))/vec2(0.085,0.16),(q-vec2(0.60,0.235))/vec2(0.085,0.16)));
 float side_core=exp(-dot((q-vec2(0.225,0.21))/vec2(0.027,0.055),(q-vec2(0.225,0.21))/vec2(0.027,0.055)));
 float source_air=smoothstep(0.32,0.58,dot(col/total,vec3(0.299,0.587,0.114)));
 value=min(0.82,value+source_air*(0.38*main_core+0.10*main_halo+0.12*side_core));
 // Moving air only modulates the luminous gaps, leaving the black masses black.
 float air=noise(q*vec2(8.0,5.0)+vec2(clock*0.012,-clock*0.009));
 float fine=noise(q*vec2(17.0,11.0)+vec2(-clock*0.007,clock*0.005));
 float lit=smoothstep(0.06,0.46,value);
 value*=1.0-lit*(0.08*air+0.04*fine);
 // Broad irregular understory shadow joins the trunks to the ground behind the path.
 float understory=ground_y-155.0+(noise(vec2(q.x*9.0,4.0))-0.5)*95.0;
 value*=1.0-0.42*smoothstep(understory,ground_y+80.0,p.y);
 float edge=-8200.0+(noise(vec2(q.y*5.0,2.0))-0.5)*160.0;
 float keep=1.0-smoothstep(edge-350.0,edge+350.0,scroll+p.x);
 COLOR=vec4(vec3(value),keep);
}
