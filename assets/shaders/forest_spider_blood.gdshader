shader_type canvas_item;
// Cohesive fluid contours: nearby parcels join into ribbons and pinch off
// into uneven drops, rather than rendering short vector streaks.
uniform vec4 blobs[96]; // centre xy, elliptical radii zw, in local pixels
uniform vec2 axes[96];
uniform int blob_count=0;
uniform vec2 extent=vec2(440.0,280.0);
void fragment(){
 vec2 p=UV*extent;
 float density=0.0;
 for(int i=0;i<96;i++){
  if(i>=blob_count)break;
  vec2 d=p-blobs[i].xy;
  vec2 a=axes[i];
  vec2 q=vec2(dot(d,a),dot(d,vec2(-a.y,a.x)))/max(blobs[i].zw,vec2(0.1));
  float kernel=max(0.0,1.0-dot(q,q));
  density+=kernel*kernel;
 }
 float edge=max(0.025,fwidth(density)*0.8);
 float alpha=smoothstep(0.30-edge,0.30+edge,density);
 COLOR=vec4(vec3(0.018),alpha);
}
