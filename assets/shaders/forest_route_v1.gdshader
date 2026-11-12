shader_type canvas_item;
uniform sampler2D forest_plate : filter_linear_mipmap, repeat_disable;
uniform float scroll = -9840.0;
uniform float clock = 0.0;
uniform float ground_y = 550.0;
uniform float reveal_edge = 2.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(1280.0,720.0);
 // An oversized, world-anchored shot; no texture repeat or camera-centred lamp.
 vec2 q=vec2((p.x+(scroll+9200.0)*0.55)/3900.0,(p.y-ground_y+760.0)/1300.0);
 vec3 col=vec3(0.0);
 float total=0.0;
 for(int y=-2;y<=2;y++){
  for(int x=-2;x<=2;x++){
   float w=exp(-float(x*x+y*y)/3.0);
   col+=texture(forest_plate,q+vec2(float(x),float(y))*vec2(0.0009,0.0021)).rgb*w;
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
 // Moving air only modulates the luminous gaps, leaving the black masses black.
 float air=noise(q*vec2(8.0,5.0)+vec2(clock*0.012,-clock*0.009));
 float fine=noise(q*vec2(17.0,11.0)+vec2(-clock*0.007,clock*0.005));
 float lit=smoothstep(0.06,0.46,value);
 value*=1.0-lit*(0.08*air+0.04*fine);
 // Broad irregular understory shadow joins the trunks to the ground behind the path.
 float understory=ground_y-155.0+(noise(vec2(q.x*9.0,4.0))-0.5)*95.0;
 value*=1.0-0.42*smoothstep(understory,ground_y+80.0,p.y);
 // Reveal the established valley through the same world-anchored forest edge.
 float front=reveal_edge+(noise(vec2(UV.y*5.0,3.0))-0.5)*0.28+(UV.y-0.5)*0.18;
 float world=(p.x+scroll)/1280.0;
 float columns=(noise(vec2(world*16.0,1.0))-0.5)*0.20+(noise(vec2(world*5.0,UV.y*3.0))-0.5)*0.14;
 float keep=1.0-smoothstep(front-0.34,front+0.34,SCREEN_UV.x+columns);
 // Background trunks retain one low, constant exposure so the black
 // shelter and hazards remain distinct in front; never a root gradient.
 value=0.045+value*0.92;
 COLOR=vec4(vec3(value),keep);
}
