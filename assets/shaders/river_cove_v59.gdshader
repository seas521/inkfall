shader_type canvas_item;
render_mode unshaded;
uniform vec2 world_origin=vec2(0.);
uniform vec2 world_axis_x=vec2(1280.,0.);
uniform vec2 world_axis_y=vec2(0.,720.);
uniform float clock=0.;
void fragment(){
 vec2 world=world_origin+SCREEN_UV.x*world_axis_x+SCREEN_UV.y*world_axis_y;
 float lake=smoothstep(700.,1100.,world.x)*(1.-smoothstep(2060.,2700.,world.x));
 // Air only. All water is now rendered by river_plane_v69 in one pass.
 float mist=exp(-pow((world.y-492.)/30.,2.))*lake*.13;
 COLOR=vec4(vec3(.34),mist);
}
