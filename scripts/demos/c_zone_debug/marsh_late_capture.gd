extends SceneTree

# Live capture of the last stretch: the tilting rope-hung deck and the crumbling spires.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	level.checkpoint = 3
	level.restore_checkpoint()
	await _frames(4)
	var deck: Rect2 = level.HANG_DECK
	await _stand(Vector2(deck.position.x + 14.0, deck.position.y - 57.0), 26, "deck-left")
	level.restore_checkpoint()
	await _stand(Vector2(deck.end.x - 30.0, deck.position.y - 57.0), 26, "deck-right")
	var cap: Rect2 = level.FRAGILE_CAPS[0]
	level.restore_checkpoint()
	level.player.position = Vector2(cap.get_center().x - 13.0, cap.position.y - 58.0)
	level.player.velocity = Vector2.ZERO
	await _frames(14)
	await _snap("spire-cracking")
	await _frames(22)
	await _snap("spire-falling")
	level.set_physics_process(false)
	level.restore_checkpoint()
	level.player.position = Vector2(5560.0, 380.0)
	level.camera_x = 5300.0
	level.camera.position = Vector2(5940.0, 360.0)
	level._present(0.0)
	await _frames(3)
	await _snap("spires-still")
	quit(0)

func _stand(at: Vector2, frames: int, label: String) -> void:
	level.player.position = at
	level.player.velocity = Vector2.ZERO
	await _frames(frames)
	await _snap(label)

func _snap(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/late-%s.png" % label)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
