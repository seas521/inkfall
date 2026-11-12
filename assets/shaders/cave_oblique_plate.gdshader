shader_type canvas_item;
uniform sampler2D plate:filter_linear,repeat_disable;
uniform sampler2D floor_profile:filter_linear,repeat_disable;
uniform sampler2D roof_profile:filter_linear,repeat_disable;
uniform sampler2D source_floor:filter_linear,repeat_disable;
uniform sampler2D source_roof:filter_linear,repeat_disable;
uniform sampler2D cheek_profile:filter_linear,repeat_disable;
uniform float scale_y=.52;
uniform bool fit_roof=false;
uniform bool foreground=false;
uniform bool reverse_cover=false;
uniform float world_left=0.;
uniform float slope_cap=0.;
uniform float entry_join;
uniform float exit_join;
uniform float exit_edge;
uniform float exit_mouth;
uniform float cave_middle;
uniform vec2 mouth_bounds;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;}
void fragment(){
 float floor_y=texture(floor_profile,vec2(UV.x,.5)).r;
 float roof_y=texture(roof_profile,vec2(UV.x,.5)).r;
 float sf=texture(source_floor,vec2(UV.x,.5)).r;
 float sr=texture(source_roof,vec2(UV.x,.5)).r;
 float lift=floor_y-world.y;
 float h=max(1.,floor_y-roof_y);
 float sy=sf-lift/scale_y;
 if(fit_roof)sy=lift<h?sf-lift/h*(sf-sr):sr-(lift-h)/scale_y;
 float sx=UV.x*1536.;
 // Calibrate the painted opening to the same headroom as the actor route.
 // Previously only the floor was registered: the low painted rock nose
 // covered the actor before the visible aperture even began.
 if(!fit_roof){
  float aperture=reverse_cover?smoothstep(375.,410.,sx)*(1.-smoothstep(700.,755.,sx)):smoothstep(945.,975.,sx)*(1.-smoothstep(1200.,1250.,sx));
  float registered=lift<h?sf-lift/h*(sf-sr):sr-(lift-h)/scale_y;
  // Registration is local to the fissure lip; the outer cliff silhouette
  // must not be stretched into spikes by the narrow source aperture.
  sy=mix(sy,registered,aperture*(1.-smoothstep(h+8.,h+48.,lift)));
 }
 if(!fit_roof && sy<0.)sx+=(sy*.55+sin(sy*.017)*9.)*(reverse_cover?-1.:1.);
 vec2 q=vec2(clamp(sx/1536.,0.,1.),clamp(sy/1024.,.001,.999));
 vec4 ink=texture(plate,q);
 vec2 d=vec2(5./1536.,5./1024.);
 vec3 macro=ink.rgb*.28;
 macro+=(texture(plate,q+vec2(d.x,0.)).rgb+texture(plate,q-vec2(d.x,0.)).rgb+texture(plate,q+vec2(0.,d.y)).rgb+texture(plate,q-vec2(0.,d.y)).rgb)*.18;
 float a=smoothstep(.02,.97,ink.a);
 float channel=smoothstep(roof_y-1.,roof_y+2.,world.y)*(1.-smoothstep(floor_y+1.,floor_y+5.,world.y));
 if(!fit_roof && !foreground && !reverse_cover){
  // A shallow opaque vestibule closes the tiny sliver of forest between
  // the painted outer lip and the rear chamber. It is air behind the
  // player, never a translucent rock face laid over the body.
  float vestibule=smoothstep(mouth_bounds.x-18.,mouth_bounds.x+12.,sx)*(1.-smoothstep(mouth_bounds.y-15.,mouth_bounds.y+20.,sx));
  a=max(a,vestibule*channel);
 }
 if(fit_roof){
  float bank_left=min(world_left+max(0.,lift-250.)*.65,slope_cap);
  a*=smoothstep(bank_left,bank_left+12.,world.x);
  float end=exit_edge-max(0.,lift)*.33+sin(lift*.053)*4.;
  a*=1.-smoothstep(end-2.,end+2.,world.x);
  if(foreground)a*=1.-smoothstep(roof_y-1.,roof_y+1.,world.y);
 }else{
  // The entry cheek hands off to an OPAQUE rear cave, not the forest.
  // A sloping occluder boundary exposes the head before the feet.
  float join=reverse_cover?exit_join+max(lift,0.)*.21:entry_join-max(lift,0.)*.22;
  float cut=reverse_cover?1.-smoothstep(join-2.,join+2.,world.x):smoothstep(join-2.,join+2.,world.x);
  a*=1.-channel*cut;
  if(reverse_cover && !foreground){
   // Outdoor scenery is visible THROUGH the real exit gap. Rock above,
   // soil below and the near cheek remain opaque and occlude the actor.
   float opening=smoothstep(sr+3.,sr+9.,sy)*(1.-smoothstep(sf-4.,sf+2.,sy));
   a*=1.-opening*smoothstep(exit_mouth-65.,exit_mouth+15.,world.x);
  }
  if(foreground){
   float cheek=texture(cheek_profile,vec2(clamp(sy/1024.,0.,1.),.5)).r;
   float cover=smoothstep(cheek-1.8,cheek+1.8,sx);
   if(reverse_cover)cover=1.-cover;
   float in_mouth=step(mouth_bounds.x,sx)*(1.-step(mouth_bounds.y,sx));
   float roof_lip=1.-smoothstep(sr-1.7,sr+1.7,sy);
   a*=max(cover,in_mouth*roof_lip);
  }
 }
 float material=dot(macro,vec3(.299,.587,.114));
 // Silhouette palette: a black mass and restrained charcoal depth shapes.
 // Source surface grain and roots never become a gray wash across the hill.
 // The near face shares the forest ground's black point. Only the air
 // inside the opening carries the restrained source-image luminance.
 float v=mix(.001,.012,smoothstep(.018,.16,material));
 if(!fit_roof && !foreground){
  float recess=smoothstep(sr+5.,sr+20.,sy)*(1.-smoothstep(sf-18.,sf-3.,sy));
  float mouth=reverse_cover?smoothstep(400.,440.,sx)*(1.-smoothstep(650.,710.,sx)):smoothstep(970.,1000.,sx)*(1.-smoothstep(1170.,1210.,sx));
  v=mix(v,.018+material*.22,recess*mouth);
 }
 if(fit_roof){
  float scatter1=exp(-pow((world.x-(cave_middle-240.))/(24.+lift*.22),2.));
  float scatter2=exp(-pow((world.x-(cave_middle+100.))/(20.+lift*.20),2.));
  float rear_light=(scatter1*.065+scatter2*.075)*smoothstep(18.,55.,lift);
  rear_light*=smoothstep(.014,.12,material);
  v=world.y<roof_y-2.?.001:max(.003+material*.025,rear_light);
 }
 // Soil is always matte black: there is no lit strip along the walking line.
 v=mix(.001,v,smoothstep(3.,20.,lift));
 if(!fit_roof && sy<0.)v=.001;
 a*=1.-smoothstep(3.,17.,world.y-floor_y);
 a*=1.-step(1024.,sy);
 COLOR=vec4(vec3(v),a);
}
