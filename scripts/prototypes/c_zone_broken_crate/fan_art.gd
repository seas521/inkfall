# Preserved broken-crate prototype. Develop the replacement raft separately.
extends Node2D

var ink := Color("080909")

# Temporary tool silhouette. Replace alongside a dedicated fan animation clip.
func _draw() -> void:
	draw_line(Vector2(0, 10), Vector2(1, -39), ink, 4.5, true)
	var outline := PackedVector2Array([
		Vector2(1, -16), Vector2(-12, -26), Vector2(-19, -44),
		Vector2(-15, -63), Vector2(-7, -77), Vector2(4, -84),
		Vector2(15, -76), Vector2(21, -59), Vector2(19, -46),
		Vector2(13, -29), Vector2(1, -16)
	])
	draw_colored_polygon(outline, ink)
	for i in range(5):
		var y := -32.0 - i * 8.0
		draw_line(Vector2(2, y + 4), Vector2(14, y), Color(0.30, 0.30, 0.30, 0.32), 1.0, true)
