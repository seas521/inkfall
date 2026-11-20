extends RefCounted
# The same separable Gaussian approach as the forest, baked once for
# static geology. No whole-screen blur or per-frame offscreen redraw.
const DIFFUSION=preload("res://assets/shaders/mine_cached_diffusion.gdshader")
const PREMULTIPLIED=preload("res://assets/shaders/mine_cached_premultiplied.gdshader")
static func view(parent:Node,size:Vector2i)->SubViewport:
 var target:=SubViewport.new();target.size=size
 target.transparent_bg=true;target.use_hdr_2d=true;target.disable_3d=true
 target.world_2d=World2D.new();target.render_target_update_mode=SubViewport.UPDATE_ONCE
 parent.add_child(target);return target
static func texture(parent:Node,source:Texture2D,sigma:float,preserve_residual:bool=false)->Texture2D:
 var current:=source
 for direction:Vector2 in [Vector2.RIGHT,Vector2.DOWN]:
  var target:=view(parent,Vector2i(source.get_size()))
  var pass_sprite:=Sprite2D.new();pass_sprite.centered=false;pass_sprite.texture=current
  pass_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  var ink:=ShaderMaterial.new();ink.shader=DIFFUSION
  ink.set_shader_parameter("direction",direction);ink.set_shader_parameter("sigma",sigma)
  ink.set_shader_parameter("preserve_residual",preserve_residual)
  pass_sprite.material=ink;target.add_child(pass_sprite);current=target.get_texture()
 return current
static func node(parent:Node2D,source:Node2D,bounds:Rect2,sigma:float,depth:int)->Sprite2D:
 bounds=bounds.grow(ceilf(sigma*3.2)+2.0)
 bounds.position=bounds.position.floor();bounds.size=bounds.size.ceil()
 var target:=view(parent,Vector2i(bounds.size))
 target.canvas_transform=Transform2D(0,-bounds.position)
 if source.get_parent()!=null:source.reparent(target,false)
 else:target.add_child(source)
 var sprite:=Sprite2D.new();sprite.centered=false
 sprite.texture=texture(parent,target.get_texture(),sigma);sprite.position=bounds.position
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 sprite.z_as_relative=false;sprite.z_index=depth
 var ink:=ShaderMaterial.new();ink.shader=PREMULTIPLIED;sprite.material=ink
 parent.add_child(sprite);return sprite
static func polygon(parent:Node2D,points:PackedVector2Array,color:Color,sigma:float,depth:int)->Sprite2D:
 var source:=Polygon2D.new();source.polygon=points;source.color=color
 var bounds:=Rect2(points[0],Vector2.ZERO)
 for point in points:bounds=bounds.expand(point)
 return node(parent,source,bounds,sigma,depth)
