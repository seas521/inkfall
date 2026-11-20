shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/mine_collapse_warp.gdshaderinc"
#include "res://assets/shaders/mine_lamp_pool.gdshaderinc"
uniform vec2 lamp0=vec2(1000000.0);
uniform vec2 lamp1=vec2(1000000.0);
uniform vec2 lamp2=vec2(1000000.0);
uniform vec2 lamp3=vec2(1000000.0);
uniform float angle0=0.0;
uniform float angle1=0.0;
uniform float angle2=0.0;
uniform float angle3=0.0;
uniform float power0=1.0;
uniform float power1=1.0;
uniform float power2=1.0;
uniform float power3=1.0;
varying vec2 world;
varying vec2 iron;
void vertex(){
 iron=COLOR.rg;
 float x=(MODEL_MATRIX*vec4(VERTEX,0,1)).x;VERTEX.y+=mine_floor_warp(x);
 world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy;
}
void fragment(){
 float light=mine_entry_lamp_pool(world,lamp0,angle0)*power0;
 light=max(light,mine_lamp_pool(world,lamp1,angle1)*power1);
 light=max(light,mine_lamp_pool(world,lamp2,angle2)*power2);
 light=max(light,mine_stop_lamp_pool(world,lamp3,angle3)*power3);
 COLOR=vec4(vec3(iron.x+iron.y*min(light,1.0)),1.0);
}
