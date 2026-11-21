extends Node2D
# Registered static art only. No physics, actor, boat, lighting controller or old demo geometry.
const ART_ROOT="res://assets/art/fog_bay_static_v90/"
const CANVAS=Vector2i(1914,822)
const LAYERS=[
 "00-distant-atmosphere.png",
 "10-water-reflection.png",
 "20-left-shoal.png",
 "30-right-bank-tree.png",
 "40-near-foliage.png",
]
@export var configure_window:=true
@export_range(0.0,24.0) var foreground_defocus:=12.0
var plates:Array[Sprite2D]=[]
var foreground_cache:SubViewport
var horizontal_material:ShaderMaterial
func _ready()->void:
 if configure_window:
  get_window().title="Inkfall · 雾湾静态资源 / 概念图对应构图"
  get_window().content_scale_size=CANVAS
  get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
  get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 get_viewport().use_hdr_2d=false
 RenderingServer.set_default_clear_color(Color.BLACK)
 for i in LAYERS.size():
  var plate:=Sprite2D.new();plate.name=String(LAYERS[i]).get_basename().replace("-","_")
  plate.centered=false;plate.texture=load(ART_ROOT+LAYERS[i]);plate.z_index=i*10
  plate.scale=Vector2(CANVAS)/Vector2(plate.texture.get_size())
  plate.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  var material_value:=CanvasItemMaterial.new();material_value.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;plate.material=material_value
  if i==2:
   var shoal:=ShaderMaterial.new();shoal.shader=preload("res://assets/shaders/fog_bay_static_v90/shoal_material.gdshader");plate.material=shoal
  if i==3:
   var immersion:=ShaderMaterial.new();immersion.shader=preload("res://assets/shaders/fog_bay_static_v90/shore_immersion.gdshader");plate.material=immersion
   immersion.set_shader_parameter("volume_source",load(ART_ROOT+"right-bank-volume-source.png"))
  if i==4:
   foreground_cache=SubViewport.new();foreground_cache.size=CANVAS;foreground_cache.transparent_bg=true
   foreground_cache.world_2d=World2D.new();foreground_cache.disable_3d=true;foreground_cache.use_hdr_2d=false
   foreground_cache.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(foreground_cache)
   var sharp:=Sprite2D.new();sharp.centered=false;sharp.texture=plate.texture;sharp.scale=plate.scale
   horizontal_material=ShaderMaterial.new();horizontal_material.shader=preload("res://assets/shaders/fog_bay_static_v90/near_defocus.gdshader")
   horizontal_material.set_shader_parameter("radius",foreground_defocus);horizontal_material.set_shader_parameter("direction",Vector2.RIGHT)
   sharp.material=horizontal_material;foreground_cache.add_child(sharp)
   plate.texture=foreground_cache.get_texture();plate.scale=Vector2.ONE
   var optical:=ShaderMaterial.new();optical.shader=horizontal_material.shader
   optical.set_shader_parameter("radius",foreground_defocus);optical.set_shader_parameter("direction",Vector2.DOWN);plate.material=optical
  add_child(plate);plates.append(plate)

func set_foreground_defocus(value:float)->void:
 foreground_defocus=clampf(value,0.,24.)
 horizontal_material.set_shader_parameter("radius",foreground_defocus)
 plates[4].material.set_shader_parameter("radius",foreground_defocus)
 foreground_cache.render_target_update_mode=SubViewport.UPDATE_ONCE
