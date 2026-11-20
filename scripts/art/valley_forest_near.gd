extends Node2D
# Unlike the atmospheric planes these trees occupy real bank positions.
# No collision: near trunks sit behind play, foreground stems frame the banks.
const KIT=preload("res://scripts/art/valley_forest_depth.gd")
# The existing route props provide the player-plane silhouettes. Add no rear
# trunks; only one foreground accent frames the wide bank. Hazards stay clear.
const REAR_SPECS=[]
const FRONT_SPECS=[Vector3(2460,1,1540)]
var level:Node2D
var front:=false
var trees:Array=[]
func _ready()->void:
 var specs=FRONT_SPECS if front else REAR_SPECS
 for spec in specs:
  var atlas=AtlasTexture.new();atlas.atlas=KIT.ATLAS;atlas.region=KIT.REGIONS[int(spec.y)];atlas.filter_clip=true
  var tree=Sprite2D.new();tree.texture=atlas;tree.scale=Vector2(.55 if front else .66,1.)*(spec.z/960.)
  tree.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  tree.flip_h=int(spec.x)%3==0
  var mat=ShaderMaterial.new();mat.shader=KIT.INK
  mat.set_shader_parameter("tone",.0007 if front else .002)
  mat.set_shader_parameter("softness",1.6 if front else 1.)
  mat.set_shader_parameter("strength",1.);mat.set_shader_parameter("root_haze",0.)
  tree.material=mat;add_child(tree)
  # Bury the flare beneath the existing earth, never fade a near tree's roots.
  var root_y=_bank_y(spec.x)+(235. if front else 170.)
  trees.append({"sprite":tree,"at":Vector2(spec.x,root_y-spec.z*.5)})
func _bank_y(x:float)->float:
 for profile in level.MARSH_LANDS:
  if x>=profile[0].x and x<=profile[-1].x:
   for i in profile.size()-1:
    if x<=profile[i+1].x:return lerpf(profile[i].y,profile[i+1].y,(x-profile[i].x)/(profile[i+1].x-profile[i].x))
 return level.ground_y(x)
func sync(cx:float,cy:float,enabled:bool)->void:
 visible=enabled
 if not enabled:return
 for item in trees:
  var tree:Sprite2D=item.sprite
  tree.position=item.at-Vector2(cx,cy) if front else item.at
  tree.visible=absf(item.at.x-cx-640.)<1120.
