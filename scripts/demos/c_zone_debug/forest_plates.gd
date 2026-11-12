extends Node2D

# Versioned old-growth silhouettes; pre-change source is saved under
# artifacts/forest-primeval-v2/baseline/forest_plates.gd.txt.
const MUL_SHADER := """shader_type canvas_item;
render_mode blend_mul;
uniform float tone = 0.32;
uniform float strength = 1.0;
uniform float soft = 3.0;
uniform float ground_limit = 1000000.0;
uniform float root_haze = 0.55;
void fragment() {
 // `soft` is a source-pixel radius, not a forced mip level. Enlarging a high
 // mip made the old tree contour visibly blocky in a large window.
 vec2 d = TEXTURE_PIXEL_SIZE * soft;
 vec3 weights = vec3(0.299, 0.587, 0.114);
 float l = dot(texture(TEXTURE, UV).rgb, weights) * 0.25;
 l += (dot(texture(TEXTURE, clamp(UV + vec2(d.x, 0.0), vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV - vec2(d.x, 0.0), vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV + vec2(0.0, d.y), vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV - vec2(0.0, d.y), vec2(0.0), vec2(1.0))).rgb, weights)) * 0.125;
 l += (dot(texture(TEXTURE, clamp(UV + d, vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV - d, vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV + vec2(d.x, -d.y), vec2(0.0), vec2(1.0))).rgb, weights)
  + dot(texture(TEXTURE, clamp(UV + vec2(-d.x, d.y), vec2(0.0), vec2(1.0))).rgb, weights)) * 0.0625;
 float m = 1.0 - clamp(l, 0.0, 1.0);
 // Fade only lateral plate boundaries, never expose a vertical cut in a trunk.
 m *= smoothstep(0.0,0.045,UV.x)*(1.0-smoothstep(0.955,1.0,UV.x));
 m *= 1.0 - smoothstep(0.955, 0.965, UV.y);
 m *= 1.0 - root_haze * smoothstep(0.62, 0.94, UV.y);
 m *= 1.0-smoothstep(ground_limit-90.0,ground_limit,SCREEN_UV.x*1280.0);
 COLOR = vec4(vec3(mix(1.0, tone, m * strength)), 1.0);
}
"""
const KEY_SHADER := """shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.012, 0.013, 0.013, 1.0);
uniform float strength = 1.0;
uniform float ground_limit = 1000000.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float l = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float support=1.0-smoothstep(ground_limit-90.0,ground_limit,SCREEN_UV.x*1280.0);
	COLOR = vec4(ink.rgb, (1.0-smoothstep(0.20,0.80,l))*source.a*strength*support);
}"""

# flat black silhouettes on white (generated): [texture, scale]
const MID_PLATES := [
	[preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png"), 0.80],
	[preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png"), 0.90],
	[preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png"), 0.76],
	[preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png"), 0.86],
	[preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png"), 0.83],
]
const DEPTH_PLATE = preload("res://assets/art/c_zone_debug/forest/forest_optical_giants_v4.png")
const NEAR_PLATES := [
	preload("res://assets/art/c_zone_debug/forest/forest_sil_near_a.jpg"),
	preload("res://assets/art/c_zone_debug/forest/forest_sil_near_b.jpg"),
]
const INITIAL_TRUNK=preload("res://assets/art/c_zone_debug/forest/initial-foreground-trunk-v1.png")

var initial_index:=-10
var root_guard:Callable
var root_ground:Callable
var ground_reference:=-4300.0
var allowed_roots:Dictionary={}
var kind:=&"mid"
var parallax:=.32
var spacing:=1250.0
var plate_width:=1500.0
var base_strength:=1.0
var fade:=1.0
var ground_limit:=1000000.0
var sprites:Array[Sprite2D]=[]
var close_texture:AtlasTexture

func setup(new_kind:StringName,new_parallax:float,new_spacing:float,new_size:float,strength:=1.0,tone:=.32)->void:
	kind=new_kind;parallax=new_parallax;spacing=new_spacing;plate_width=new_size;base_strength=strength
	if kind==&"close":
		close_texture=AtlasTexture.new()
		close_texture.atlas=MID_PLATES[0][0]
		var source_size:Vector2=close_texture.atlas.get_size()
		close_texture.region=Rect2(0,0,source_size.x*0.31,source_size.y)
		close_texture.filter_clip=true
	var shader:=Shader.new();shader.code=KEY_SHADER if kind==&"near" else MUL_SHADER
	for i in 5:
		var sprite:=Sprite2D.new();sprite.centered=false
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat:=ShaderMaterial.new();mat.shader=shader;sprite.material=mat
		if kind!=&"near":
			mat.set_shader_parameter("strength",strength)
			mat.set_shader_parameter("tone",tone)
			mat.set_shader_parameter("soft",19.0 if kind==&"far" else (2.8 if kind==&"close" else 7.0))
			mat.set_shader_parameter("root_haze",0.12 if kind==&"close" else (0.64 if kind==&"far" else 0.40))
		sprite.visible=false;add_child(sprite);sprites.append(sprite)

func set_fade(value:float)->void:
	fade=clampf(value,0,1);visible=fade>.01
	for sprite in sprites:
		if kind==&"near":sprite.modulate.a=fade
		(sprite.material as ShaderMaterial).set_shader_parameter("strength",fade if kind==&"near" else fade*base_strength)

func set_ground_limit(value:float)->void:
	ground_limit=value
	for sprite in sprites:(sprite.material as ShaderMaterial).set_shader_parameter("ground_limit",value)

func sync(camera_x:float,ground_y:float,u_max:float)->void:
	var first:=int(floor(camera_x*parallax/spacing))-2
	for k in sprites.size():
		var i:=first+k;var sprite:=sprites[k]
		var rng:=RandomNumberGenerator.new();rng.seed=i*9973+(7 if kind==&"near" else (13 if kind==&"far" else 3))
		var u:=i*spacing+rng.randf_range(0,spacing*.25)
		var present:=rng.randf()<(.95 if kind==&"near" else 1.0)
		if kind==&"near" and root_guard.is_valid():
			if not allowed_roots.has(i):allowed_roots[i]=root_guard.call(u/parallax-320,u/parallax+1280*(1-1/parallax)+320)
			present=present and allowed_roots[i]
		var texture:Texture2D
		var extra:=1.0
		if kind==&"near":
			texture=NEAR_PLATES[rng.randi()%NEAR_PLATES.size()]
			if i==initial_index:texture=INITIAL_TRUNK
		else:
			var entry:Array=MID_PLATES[rng.randi()%MID_PLATES.size()]
			texture=entry[0];extra=entry[1]
			if kind==&"far":
				texture=DEPTH_PLATE
				extra*=1.10
			elif kind==&"close":
				texture=close_texture
		var flip:=rng.randf()<.5
		var factor:float=(plate_width/texture.get_height() if kind==&"near" else plate_width/texture.get_width())*rng.randf_range(.92,1.12)*extra
		# An interior view of cropped giants; no vertical squash to show crowns.
		var plate_scale:=Vector2.ONE*factor
		if kind!=&"near":plate_scale.y=maxf(plate_scale.y,1000.0/texture.get_height())
		var display:=texture.get_size()*plate_scale;var x:=u-camera_x*parallax
		sprite.visible=present and u<=u_max and x> -display.x and x<1280+display.x*.2
		if not sprite.visible:continue
		sprite.texture=texture;sprite.flip_h=flip;sprite.scale=plate_scale
		if kind==&"near":
			var root_y:=ground_y
			if root_ground.is_valid():root_y+=float(root_ground.call(camera_x+x))-ground_reference
			sprite.position=Vector2(x-display.x*.5,root_y+95-display.y)
		else:
			# Continue the trunk behind the lowest visible foreground/water bed.
			# Source root silhouettes and the plate base remain buried, with no
			# extra terrain ribbon or grass/fog strip added to the scene.
			sprite.position=Vector2(x,ground_y-display.y*.955+170.0)
