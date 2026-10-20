# Preserved broken-crate prototype. Develop the replacement raft separately.
extends RefCounted

# Probe the visible sole, not the transparent canvas or the character's head.
# Cached texture-local points never change the frame scale or horizontal root.
var sole_cache: Dictionary = {}

func sole_points(texture: Texture2D) -> PackedVector2Array:
	var key := texture.get_instance_id()
	if sole_cache.has(key):
		return sole_cache[key]
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bounds := image.get_used_rect()
	var points := PackedVector2Array()
	var bottom := bounds.end.y - 1
	for x in range(bounds.position.x, bounds.end.x, 3):
		for y in range(bottom, maxi(bounds.position.y, bottom - 12) - 1, -1):
			if image.get_pixel(x, y).a > 0.6:
				points.append(Vector2(x + 0.5, y + 1.0))
				break
	sole_cache[key] = points
	return points

func solve(sprite: AnimatedSprite2D, body: CharacterBody2D) -> Dictionary:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var space := body.get_world_2d().direct_space_state
	var best := INF
	var contact := Vector2.ZERO
	for pixel in sole_points(texture):
		var foot := sprite.to_global(pixel)
		var query := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 12), foot + Vector2(0, 18), body.collision_mask, [body.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or Vector2(hit.normal).dot(Vector2.UP) < cos(body.floor_max_angle):
			continue
		var gap: float = hit.position.y - foot.y
		if gap < best:
			best = gap
			contact = hit.position
	return {"valid": best != INF, "offset": clampf(best, -8.0, 12.0) if best != INF else 0.0, "point": contact}
