uniform sampler2D approved_tex:source_color,filter_linear,repeat_disable;
uniform sampler2D clean_tex:source_color,filter_linear,repeat_disable;
uniform sampler2D structure_mask:filter_linear,repeat_disable;
uniform sampler2D foreground_mask:filter_linear,repeat_disable;
uniform sampler2D gallery_mask:filter_linear,repeat_disable;
uniform sampler2D supports_mask:filter_linear,repeat_disable;
uniform sampler2D props_mask:filter_linear,repeat_disable;
float source_luma(vec3 c){return dot(c,vec3(.299,.587,.114));}
float grown(sampler2D plate,vec2 uv,float radius){
 vec2 d=vec2(radius)/vec2(1672,941);
 float a=texture(plate,uv).a;
 a=max(a,texture(plate,uv+vec2(d.x,0)).a);a=max(a,texture(plate,uv-vec2(d.x,0)).a);
 a=max(a,texture(plate,uv+vec2(0,d.y)).a);a=max(a,texture(plate,uv-vec2(0,d.y)).a);
 return a;
}
float box_coverage(vec2 p,vec4 bounds,float feather){
 vec2 center=bounds.xy+bounds.zw*.5;
 vec2 q=abs(p-center)-bounds.zw*.5;
 return 1.0-smoothstep(-feather,feather,max(q.x,q.y));
}
float actor_cut(vec2 p,float l){return box_coverage(p,vec4(696,433,53,81),2.0)*(1.0-smoothstep(.11,.24,l));}
vec3 lamp_data(int i){
 if(i==0)return vec3(258,152,45);
 if(i==1)return vec3(846,375,195);
 if(i==2)return vec3(515,686,545);
 if(i==3)return vec3(1539,451,300);
 if(i==4)return vec3(959,205,125);
 return vec3(790,710,660);
}
float lamp_coverage(vec2 p,float l,int i){
 vec3 lamp=lamp_data(i);float dx=abs(p.x-lamp.x);
 float dark=1.0-smoothstep(i>=4?.25:.075,i>=4?.55:.20,l);
 float hood=box_coverage(p,vec4(lamp.x-25.0,lamp.y-31.0,50,35),1.5)*dark;
 float bulb=1.0-smoothstep(.72,1.05,length((p-lamp.xy)/vec2(10.0,3.4)));
 float wire=(1.0-smoothstep(1.0,2.2,dx))*step(lamp.z,p.y)*(1.0-step(lamp.y-22.0,p.y))*dark;
 return max(max(hood,bulb),wire);
}
float layer_coverage(int role,vec2 uv,float l){
 float near_key=1.0-smoothstep(.018,.13,l);
 vec2 pixel=uv*vec2(1672,941);
 // Both fixed ladders are climbed on the camera-facing side. The broad
 // rock matte must not accidentally put their rails, treads or adjacent
 // deck supports in front of the boy during a top-down entry. Reassign
 // that same source color to the structure plane; never cut a hole in it.
 float ladder_lane=max(box_coverage(pixel,vec4(202,347,39,166),.8),box_coverage(pixel,vec4(253,500,48,355),.8));
 // The restraint's fixed upright belongs behind the cart through its
 // wheel contact at the rail. Keep the deeper ground matte intact.
 // Reassign source pixels instead of erasing
 // them or lifting the entire cart above unrelated near scenery.
 float rear_lane=max(ladder_lane,box_coverage(pixel,vec4(1287,439,92,217),1.2));
 float foreground=smoothstep(.02,.92,grown(foreground_mask,uv,20.0))*near_key;
 if(role==1)return foreground*(1.0-rear_lane);
 if(role==2)return max(smoothstep(.02,.92,grown(structure_mask,uv,16.0))*near_key,foreground*rear_lane);
 float rear_key=smoothstep(.022,.065,l);
 if(role==3)return grown(gallery_mask,uv,18.0)*rear_key;
 if(role==4)return grown(supports_mask,uv,28.0)*rear_key;
 return 0.0;
}
float prop_coverage(vec2 uv,float l){
 // Whole moving objects are removed from the residual plate. The kit
 // supplies complete independent bodies, including the unobscured carts.
 float a=grown(props_mask,uv,18.0);
 return a*(1.0-smoothstep(.06,.16,l));
}

vec2 source_owner(vec2 uv,float l){
 for(int role=1;role<=4;role++){
  float coverage=layer_coverage(role,uv,l);
  if(coverage>.008)return vec2(float(role),coverage);
 }
 return vec2(0.0);
}
float required_alpha(vec3 s,vec3 b){
 vec3 dark=max(vec3(0.0),(b-s)/max(b,vec3(.0001)));
 vec3 light=max(vec3(0.0),(s-b)/max(vec3(1.0)-b,vec3(.0001)));
 return max(max(max(dark.r,dark.g),dark.b),max(max(light.r,light.g),light.b));
}
