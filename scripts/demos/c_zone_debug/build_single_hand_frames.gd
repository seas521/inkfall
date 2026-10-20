extends SceneTree

const Source = preload("res://scripts/actors/seedance_actor_manifest.gd")
const Hand = preload("res://scripts/demos/c_zone_debug/single_hand_manifest.gd")
const CANDIDATE := "res://artifacts/c-zone-fan/single-hand-grip/empty-grip-candidate-v1.png"
var arm_outline := PackedVector2Array([Vector2(128,161),Vector2(140,165),Vector2(154,174),Vector2(160,174),Vector2(160,170),Vector2(170,169),Vector2(177,174),Vector2(178,182),Vector2(173,190),Vector2(164,192),Vector2(150,188),Vector2(136,183),Vector2(128,178)])

func _initialize() -> void:
	var candidate := Image.load_from_file(CANDIDATE)
	candidate.resize(256,256,Image.INTERPOLATE_LANCZOS)
	var sheet := Image.create(2048,1792,false,Image.FORMAT_RGBA8)
	sheet.fill(Color(0.60,0.60,0.60))
	var n := 0
	for clip in Hand.CLIPS:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [Hand.FRAME_ROOT,clip])
		for index in int(Source.CLIPS[clip].frames):
			var texture := load(Source.frame_path(clip,index)) as Texture2D
			var original := texture.get_image()
			if original.is_compressed():
				original.decompress()
			original.convert(Image.FORMAT_RGBA8)
			var result := original.duplicate() as Image
			var marker: Vector2 = Source.small_item_anchor(clip,index)-Source.SMALL_ITEM_CENTER_OFFSET
			var pickup_index := 7-index if clip == &"put_down" else index
			var detached := clip in [&"pickup",&"put_down"] and pickup_index<2
			# Remove only the old prop/near-hand region. Heads, free arms, roots and
			# original leg frames are retained; the replacement is baked, not puppeted.
			for y in range(maxi(0,int(marker.y)-16),mini(256,int(marker.y)+40)):
				for x in range(maxi(0,int(marker.x)-30),mini(256,int(marker.x)+35)):
					var p := Vector2(x,y)-marker
					var left := -29.0 if detached else -14.0
					var top := -15.0 if detached else lerpf(-12.0,-4.0,clampf((p.x+12.0)/30.0,0,1))
					var inside_prop := ((p-Vector2(-4,9))/Vector2(26,25)).length()<1.0
					var supporting_foot := y>=214 and x<=143
					if p.x>=left and p.y>=top and inside_prop and not supporting_foot:
						result.set_pixel(x,y,Color.TRANSPARENT)
			var transform := Hand.arm_transform(clip,index)
			var inverse := transform.affine_inverse()
			for y in range(130,230):
				for x in range(95,205):
					var from := inverse*Vector2(x,y)+Hand.ARM_ROOT
					if not Geometry2D.is_point_in_polygon(from,arm_outline):
						continue
					var color := candidate.get_pixelv(Vector2i(from.round()))
					if color.a>0.01:
						color = Color(0.004,0.006,0.006,color.a)
						result.set_pixel(x,y,result.get_pixel(x,y).blend(color))
			assert(result.save_png(Hand.frame_path(clip,index))==OK)
			sheet.blend_rect(result,Rect2i(0,0,256,256),Vector2i(n%8*256,n/8*256))
			n+=1
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-fan/single-hand-grip")
	sheet.save_png("res://artifacts/c-zone-fan/single-hand-grip/frame-review.png")
	print("Built %d complete single-hand trial frames; shared sources unchanged." % n)
	quit()
