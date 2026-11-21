// Authored valley openings in WORLD coordinates. No camera, player, screen
// UV, animation clock or per-region switch can move these sunlight bands.
float chapter_sun_window(float p,float centre,float width){
	float d=(p-centre)/width;
	return exp(-d*d*d*d);
}
float chapter_valley_sun_base(vec2 world){
	float p=world.x+.48*(world.y-400.);
	float light=chapter_sun_window(p,500.,230.);
	light=max(light,chapter_sun_window(p,1480.,320.));
	light=max(light,chapter_sun_window(p,2470.,210.));
	light=max(light,chapter_sun_window(p,3600.,235.));
	light=max(light,chapter_sun_window(p,4250.,210.));
	light=max(light,chapter_sun_window(p,5290.,230.));
	light=max(light,chapter_sun_window(p,6290.,240.));
	light=max(light,chapter_sun_window(p,7200.,220.));
	light=max(light,chapter_sun_window(p,8560.,250.));
	light=max(light,chapter_sun_window(p,10020.,260.));
	light=max(light,chapter_sun_window(p,11600.,260.));
	light=max(light,chapter_sun_window(p,13320.,270.));
	light=max(light,chapter_sun_window(p,14800.,280.));
	return light;
}

// River sun enters from upper right. These unequal offscreen canopy gaps
// are in the SAME ray coordinate as the light; they cannot slide with a camera.
float chapter_river_region(vec2 p){
 return smoothstep(-750.,-300.,p.x)*(1.-smoothstep(2300.,2900.,p.x));
}
float chapter_canopy_gap(vec2 p){
 float u=p.x+.48*(p.y-400.);
 float penumbra=22.+max(p.y+850.,0.)*.018;
 // Broad soft canopy penumbrae, not opaque parallel stripe masks.
 float a=exp(-pow((u-290.)/(40.+penumbra),2.))*.46;
 float b=exp(-pow((u-560.)/(25.+penumbra*.65),2.))*.50;
 float c=exp(-pow((u-1240.)/(65.+penumbra),2.))*.42;
 return max(.2,1.-max(a,max(b,c)));
}
float chapter_river_incident(vec2 p){
 float u=p.x+.48*(p.y-400.);
 float opening=max(exp(-pow((u-450.)/155.,2.))*.94,exp(-pow((u-1510.)/290.,2.))*.76);
 opening=max(opening,exp(-pow((u-725.)/78.,2.))*.58);
 float height=mix(1.,.68,smoothstep(-650.,650.,p.y));
 float river=opening*chapter_canopy_gap(p)*height;
 return mix(chapter_valley_sun_base(p),river,chapter_river_region(p));
}
uniform sampler2D river_daylight:filter_linear,repeat_disable;
uniform vec4 river_daylight_rect=vec4(-900.,-1500.,4700.,3300.);
uniform float river_daylight_ready=0.;
float chapter_valley_sun(vec2 p){
 vec2 uv=(p-river_daylight_rect.xy)/river_daylight_rect.zw;
 float edge=smoothstep(0.,.025,min(min(uv.x,uv.y),min(1.-uv.x,1.-uv.y)));
 return mix(chapter_valley_sun_base(p),texture(river_daylight,clamp(uv,vec2(0),vec2(1))).r,river_daylight_ready*edge*chapter_river_region(p));
}
