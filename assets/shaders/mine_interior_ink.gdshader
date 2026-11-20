shader_type canvas_item;
render_mode unshaded;
void fragment(){
 // Only the distant wall is defocused. Independent wood/rails stay legible.
 vec3 rear=vec3(0.0);
 float weight=0.0;
 for(int y=-2;y<=2;y++){
  for(int x=-2;x<=2;x++){
   float w=exp(-float(x*x+y*y)*0.42);
   rear+=texture(TEXTURE,UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*6.0).rgb*w;
   weight+=w;
  }
 }
 rear/=weight;
 float entry=smoothstep(0.0,0.095,UV.x);
 // Directional illumination belongs to rear stone and timbers; the surrounding
 // rock and the running surface remain dark instead of a flat luminous strip.
 float luminance=dot(rear,vec3(0.299,0.587,0.114));
 float tone=min(0.30,pow(luminance,0.60)*0.60);
 // The plate's lit floor is not a luminous strip under the actual rails.
 float floor_y=mix(0.58,0.88,UV.x);
 tone*=mix(1.0,0.28,smoothstep(floor_y-0.025,floor_y+0.035,UV.y));
 COLOR=vec4(vec3(tone),entry);
}
