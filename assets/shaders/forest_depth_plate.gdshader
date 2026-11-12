shader_type canvas_item;
uniform sampler2D forest:filter_linear,repeat_disable;
uniform float scroll=0.;
uniform float clock=0.;
uniform float horizon=580.;
uniform float strength=.8;
uniform float reveal_edge=2.;
varying vec2 p;
void fragment(){
 vec2 px=SCREEN_UV*vec2(1280.,720.);
 float x=(px.x+scroll*.18)/2389.;
 // Mirror at remote panorama boundaries: continuous edges, no per-frame asset load.
 float u=1.-abs(mod(x,2.)-1.);
 float v=clamp((px.y-(horizon-710.))/796.,0.,1.);
 vec3 ink=texture(forest,vec2(u,v)).rgb;
 float drifting=sin(px.x*.004+clock*.06)*sin(px.y*.006-clock*.04)*.012;
 float alpha=(1.-smoothstep(-5200.,-4500.,scroll+px.x))*strength*(1.-smoothstep(reveal_edge-.34,reveal_edge+.34,SCREEN_UV.x));
 COLOR=vec4(ink*.76+drifting*.6,alpha);
}
