extends CanvasLayer
# One receiving plane for C's air, terrain and props, under the foreground
# framing and common film lens. No collisions, light nodes or extra viewports.
const SHADER=preload("res://assets/shaders/valley_player_light.gdshader")
const X0:=-640.0
const STEP:=4.0
const COUNT:=3961
var level:Node2D
var rect:ColorRect
var light_material:ShaderMaterial
var ground_texture:ImageTexture
func _ready()->void:
 layer=13
 var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
 add_child(copy)
 rect=ColorRect.new();rect.set_anchors_preset(Control.PRESET_FULL_RECT)
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 light_material=ShaderMaterial.new();light_material.shader=SHADER
 rect.material=light_material;add_child(rect);hide()
func setup(host:Node2D)->void:
 level=host
 var image:=Image.create(COUNT,1,false,Image.FORMAT_RGBAF)
 for i in COUNT:image.set_pixel(i,0,_surface(X0+i*STEP))
 ground_texture=ImageTexture.create_from_image(image)
 light_material.set_shader_parameter("ground_profile",ground_texture)
func _surface(x:float)->Color:
 if x<2780.0:
  var ground:float=level.ground_y(x)
  var water:bool=ground>575.0 and x>1090.0 and x<2110.0
  return Color(minf(ground,575.0)/1024.0,1.0 if water else 0.0,1.0,1.0)
 for profile in level.MARSH_LANDS:
  if x<profile[0].x or x>profile[-1].x:continue
  for i in range(profile.size()-1):
   if x<=profile[i+1].x:
    var a:Vector2=profile[i];var b:Vector2=profile[i+1]
    return Color(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))/1024.0,0,1,1)
 # Open gaps have air but no surface on which to invent a glowing floor.
 return Color(430.0/1024.0,0,0,1)
func sync(enabled:bool,field:Texture2D,camera:Vector2,time:float)->void:
 visible=enabled
 if not enabled:return
 var canvas:Transform2D=level.get_canvas_transform()
 var inverse:=canvas.affine_inverse()
 var size:Vector2=level.get_viewport_rect().size
 var origin:=inverse*Vector2.ZERO
 light_material.set_shader_parameter("forest_light_texture",field)
 light_material.set_shader_parameter("forest_light_camera",camera)
 light_material.set_shader_parameter("forest_light_clock",time)
 light_material.set_shader_parameter("world_origin",origin)
 light_material.set_shader_parameter("world_axis_x",inverse*Vector2(size.x,0)-origin)
 light_material.set_shader_parameter("world_axis_y",inverse*Vector2(0,size.y)-origin)
 light_material.set_shader_parameter("light_screen_step",canvas.basis_xform(Vector2(.62,-.78))/size)
