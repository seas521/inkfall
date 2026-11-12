extends Node2D

# One source-sized emissive feature for every player clip. The frame's eye
# landmark, not an independent head puppet, places and occludes it.
const CORE_COLOR := Color(1.0,0.49,0.065,1.0)
var light:ColorRect

func _ready()->void:
	light=ColorRect.new()
	light.position=Vector2(-9,-11)
	light.size=Vector2(18,22)
	light.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform vec4 eye_color : source_color = vec4(1.0,0.49,0.065,1.0);
uniform bool monochrome=false;
uniform float softness=0.0;
void fragment(){
 vec2 p=(UV-0.5)*vec2(18.0,22.0);
 float d=length(p/vec2(2.6,3.6));
 float core=1.0-smoothstep(0.62,1.18+softness*0.09,d);
 float halo=exp(-dot(p/vec2(5.5,7.0),p/vec2(5.5,7.0)))*0.075;
 vec3 tone=eye_color.rgb;
 if(monochrome)tone=vec3(dot(tone,vec3(0.299,0.587,0.114)));
 COLOR=vec4(tone,max(core,halo)*eye_color.a);
}
"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("eye_color",CORE_COLOR)
	light.material=mat
	add_child(light)
	hide()

func sync_eye(track:Array,is_monochrome:bool,blur:float)->void:
	visible=not track.is_empty() and float(track[3])>0.0
	if not visible:return
	position=Vector2(float(track[0]),float(track[1]))
	rotation=float(track[2])
	(light.material as ShaderMaterial).set_shader_parameter("monochrome",is_monochrome)
	(light.material as ShaderMaterial).set_shader_parameter("softness",blur)
