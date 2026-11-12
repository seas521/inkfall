shader_type canvas_item;
// Small optical edge spread in logical pixels; interiors stay solid ink.
uniform vec4 ink : source_color = vec4(0.012, 0.013, 0.013, 1.0);
uniform bool key_white = true;
uniform float edge_softness = 1.1;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec2 step_uv = fwidth(UV) * (1.0 / SCREEN_PIXEL_SIZE.y) / 720.0 * edge_softness;
 float alpha = 0.0;
 float total = 0.0;
 for(int y=-2;y<=2;y++) {
  for(int x=-2;x<=2;x++) {
   float weight=exp(-float(x*x+y*y)/1.6);
   vec4 sample_color=texture(TEXTURE,clamp(UV+vec2(float(x),float(y))*step_uv,vec2(0.0),vec2(1.0)));
   float coverage=sample_color.a;
   if(key_white) coverage*=1.0-smoothstep(0.20,0.80,dot(sample_color.rgb,vec3(0.299,0.587,0.114)));
   alpha+=coverage*weight;
   total+=weight;
  }
 }
 COLOR=vec4(ink.rgb,ink.a*alpha/total)*vertex_tint;
}
