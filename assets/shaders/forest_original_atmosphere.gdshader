shader_type canvas_item;
uniform float scroll=0.0;
uniform float clock=0.0;
uniform float level=.6;
uniform float shaft=0.0;
uniform float shaft_x=640.0;
uniform float horizon=520.0;
uniform float reveal_edge=2.0;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float a=.5;float s=0.;for(int i=0;i<4;i++){s+=a*noise(p);p=p*2.03+17.;a*=.5;}return s;}
void fragment(){
 vec2 p=SCREEN_UV*vec2(1280.,720.);
 float up=clamp((horizon-p.y)/horizon,0.,1.);
 float patch=fbm(vec2((p.x+scroll*.07)*.003,p.y*.0042));
 float streak=noise(vec2((p.x+scroll*.20)*.010,.5));
 // A bounded light pocket viewed through the trunks, not a luminous backdrop
 // spread across the whole frame. World-space drift keeps the light grounded.
 float opening_x=590.+100.*sin(scroll*.00031);
 float aperture=exp(-pow((p.x-opening_x)/400.,2.));
 float elevation=exp(-pow((p.y-(horizon-205.))/220.,2.));
 float v=level*(.16+.24*patch+.48*aperture*elevation)*(.86+.14*streak);
 v*=mix(1.,.32,smoothstep(.30,1.,up));
 float gaps=fbm(vec2((p.x+scroll*.12)*.006,p.y*.010)+9.);
 v+=level*.13*smoothstep(.45,.85,gaps)*smoothstep(.25,.8,up)*aperture;
 float sx=p.x-shaft_x+(p.y-horizon)*.34;
 float width=70.+.16*(horizon-p.y);
 float beam=exp(-pow(sx/max(width,1.),2.));
 beam*=.62+.38*noise(vec2(p.y*.018-clock*.08,2.));
 float halo=exp(-pow(sx/(width*2.8),2.));
 v+=shaft*(beam*.20+halo*.055);
 float early=1.-smoothstep(-9300.,-8300.,scroll);
 float canopy_light=exp(-pow((p.x-750.+(p.y-170.)*.32)/130.,2.));
 v+=early*level*.26*canopy_light*exp(-pow((p.y-235.)/190.,2.));
 // Unequal, soft shafts through canopy openings; tree plates in front of this
 // light field interrupt the light, rather than rays painting over trunks.
 float ray_axis=p.x+scroll*.09+(p.y-160.)*.42;
 float slit_a=exp(-pow((ray_axis-(floor(ray_axis/1100.)*1100.+260.))/62.,2.));
 float slit_b=exp(-pow((ray_axis-(floor(ray_axis/1100.)*1100.+690.))/110.,2.));
 float ray_depth=exp(-pow((p.y-(horizon-240.))/240.,2.));
 v+=level*(slit_a*.23+slit_b*.12)*ray_depth*(.55+.45*patch);
 float pocket=1.-smoothstep(200.,640.,abs(p.x-500.));
 v+=level*.12*pocket*smoothstep(0.,.55,1.-abs(p.y-(horizon-100.))/240.);
 // Broad uneven shade at the feet; no narrow horizontal mist/ground ribbon.
 float ground_shade=smoothstep(horizon-140.+(patch-.5)*65.,horizon+80.,p.y);
 v*=1.-ground_shade*.48;
 v*=mix(1.,.45,smoothstep(.48,1.,abs(SCREEN_UV.x-.5)*2.));
 v=clamp(v,0.,.68)+(hash21(p+vec2(fract(clock)*37.,0.))-.5)*.006;
 float world=(p.x+scroll)/1280.;
 float columns=(noise(vec2(world*16.,1.))-.5)*.20+(noise(vec2(world*5.,UV.y*3.))-.5)*.14;
 float front=reveal_edge+(noise(vec2(UV.y*5.,3.))-.5)*.28+(UV.y-.5)*.18;
 float keep=1.-smoothstep(front-.34,front+.34,SCREEN_UV.x+columns);
 COLOR=vec4(vec3(v),keep);
}
