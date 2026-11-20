extends Node2D
# Independent submerged banks: open deep channel, no continuous gravel strip.
const BANK=preload("res://assets/art/c_zone_debug/river-v50/submerged-banks.png")
const OPTICS=preload("res://assets/shaders/river_bed_v50.gdshader")
var water_materials:Array[ShaderMaterial]=[]
func _ready()->void:
 material=_material(false)
 _bank(Rect2(0,0,1050,1024),Vector2(1040,360),.42)
 _bank(Rect2(1040,0,496,1024),Vector2(1845,185),.5)
 queue_redraw()
func _material(image:bool)->ShaderMaterial:
 var mat:=ShaderMaterial.new();mat.shader=OPTICS
 mat.set_shader_parameter("image_mode",image)
 water_materials.append(mat)
 return mat
func _bank(region:Rect2,at:Vector2,size:float)->void:
 # Extend the image's opaque base below the camera. Cropping must never
 # introduce a rectangular bottom or a hard edge in the open water.
 var shape:=Polygon2D.new();shape.texture=BANK
 shape.polygon=PackedVector2Array([Vector2.ZERO,Vector2(region.size.x,0),Vector2(region.size.x,1536),Vector2(0,1536)])
 shape.uv=PackedVector2Array([region.position,Vector2(region.end.x,0),Vector2(region.end.x,1536),Vector2(region.position.x,1536)])
 shape.position=at;shape.scale=Vector2.ONE*size
 shape.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 shape.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
 var mat:=_material(true)
 mat.set_shader_parameter("crop_x",Vector2(region.position.x/BANK.get_width(),region.end.x/BANK.get_width()))
 shape.material=mat;add_child(shape)
func set_water(wave:Texture2D,time:float)->void:
 for mat in water_materials:
  mat.set_shader_parameter("waves",wave);mat.set_shader_parameter("clock",time)
func _draw()->void:
 draw_rect(Rect2(1000,552,1200,428),Color.WHITE)
