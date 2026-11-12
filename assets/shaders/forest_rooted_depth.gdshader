shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D tree_0 : filter_linear_mipmap;
uniform sampler2D tree_1 : filter_linear_mipmap;
uniform sampler2D tree_2 : filter_linear_mipmap;
uniform sampler2D tree_3 : filter_linear_mipmap;
uniform sampler2D tree_4 : filter_linear_mipmap;
uniform vec4 trees[5]; // plane x, buried source foot, width, height
uniform float flips[5];
uniform float plane_scroll=0.0;
uniform float ground_base=520.0;
uniform float ground_limit=1000000.0;
uniform float seed=31.0;
uniform float tone=.3;
uniform float strength=1.0;
uniform float soft=2.0;
float hash(float x){return fract(sin(x*127.1+seed)*43758.5453);}
float noise(float x){float i=floor(x);float f=fract(x);f=f*f*(3.0-2.0*f);return mix(hash(i),hash(i+1.0),f);}
float land(float x){return ground_base+(noise(x/620.0)-.5)*88.0+(noise(x/170.0+61.0)-.5)*22.0+(noise(x/31.0+121.0)-.5)*2.0;}
vec4 sample_tree(int i,vec2 uv){
 if(i==0){return textureLod(tree_0,uv,soft);}
 if(i==1){return textureLod(tree_1,uv,soft);}
 if(i==2){return textureLod(tree_2,uv,soft);}
 if(i==3){return textureLod(tree_3,uv,soft);}
 return textureLod(tree_4,uv,soft);
}
void fragment(){
 vec2 p=SCREEN_UV*vec2(1280.0,720.0);float wx=p.x+plane_scroll;
 float surface=land(wx);
 // One mass: soil conceals ALL root shapes below the shared land contour.
 float soil=smoothstep(-2.0,3.0,p.y-surface);
 float forest=0.0;
 for(int i=0;i<5;i++){
  vec4 r=trees[i];
  if(r.z<1.0){continue;}
  vec2 uv=vec2((wx-r.x)/r.z,(p.y-surface)/r.w+r.y);
  if(uv.x<0.0||uv.x>1.0||uv.y<0.0||uv.y>r.y+.01){continue;}
  if(flips[i]>.5){uv.x=1.0-uv.x;}
  vec4 c=sample_tree(i,uv);
  float l=dot(c.rgb,vec3(.299,.587,.114));
  float shape=(1.0-smoothstep(.12,.88,l))*c.a;
  forest=max(forest,shape);
 }
 // The lower trunk and its soil share a value; no pasted root silhouette,
 // pale grass stripe, or double-dark plate intersection can be exposed.
 float mass=max(soil,forest);
 mass*=1.0-smoothstep(ground_limit-140.0,ground_limit,p.x);
 COLOR=vec4(vec3(mix(1.0,tone,mass*strength)),1.0);
}
