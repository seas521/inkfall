shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/chapter_surface_response.gdshaderinc"
varying vec4 surface_tint;
varying vec2 surface_world;
void vertex(){
 surface_tint=COLOR;
 surface_world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy+source_world_offset;
}
void fragment(){
 vec4 source=texture(TEXTURE,UV)*surface_tint;
 COLOR=vec4(source.rgb+vec3(chapter_surface_light(surface_world))*source.a,source.a);
}
