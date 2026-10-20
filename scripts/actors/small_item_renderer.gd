extends Node2D

var item_kind: StringName = &""
var item_radius := 8.0

func configure(next_kind: StringName, next_radius: float) -> void:
	var normalized_radius := maxf(4.0, next_radius)
	if item_kind == next_kind and is_equal_approx(item_radius, normalized_radius):
		return
	item_kind = next_kind
	item_radius = normalized_radius
	queue_redraw()

func _draw() -> void:
	match item_kind:
		&"stone":
			_draw_stone()
		&"ink_stone":
			_draw_ink_stone()
		&"wood":
			_draw_wood()
		&"scrap":
			_draw_scrap()
		&"bottle":
			_draw_bottle()
		&"key":
			_draw_key()
		_:
			_draw_orb()

func _draw_orb() -> void:
	draw_circle(Vector2.ZERO, item_radius + 2.0, Color(0.0, 0.0, 0.0, 0.18), true, -1.0, true)
	draw_circle(Vector2.ZERO, item_radius, Color("080b0c"), true, -1.0, true)
	draw_circle(
		Vector2(item_radius * 0.18, -item_radius * 0.16),
		item_radius * 0.45,
		Color(0.88, 0.34, 0.08, 0.12),
		true,
		-1.0,
		true
	)
	draw_circle(
		Vector2(item_radius * 0.18, -item_radius * 0.16),
		item_radius * 0.21,
		Color(0.94, 0.45, 0.11, 0.88),
		true,
		-1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		item_radius * 0.66,
		-1.15,
		1.40,
		14,
		Color(0.82, 0.46, 0.18, 0.62),
		maxf(1.2, item_radius * 0.15),
		true
	)

func _draw_stone() -> void:
	var points := PackedVector2Array([
		Vector2(-item_radius, item_radius * 0.24),
		Vector2(-item_radius * 0.54, -item_radius * 0.84),
		Vector2(item_radius * 0.44, -item_radius),
		Vector2(item_radius, -item_radius * 0.08),
		Vector2(item_radius * 0.56, item_radius * 0.82),
		Vector2(-item_radius * 0.48, item_radius),
	])
	draw_colored_polygon(points, Color("07090a"))
	draw_polyline(points, Color(0.34, 0.36, 0.33, 0.34), maxf(1.4, item_radius * 0.13), true)
	draw_line(
		Vector2(-item_radius * 0.42, -item_radius * 0.24),
		Vector2(item_radius * 0.34, -item_radius * 0.44),
		Color(0.36, 0.38, 0.35, 0.42),
		maxf(1.0, item_radius * 0.10),
		true
	)
	draw_circle(
		Vector2(item_radius * 0.34, -item_radius * 0.42),
		maxf(1.2, item_radius * 0.14),
		Color(0.94, 0.45, 0.11, 0.82),
		true,
		-1.0,
		true
	)

# A plain black stone: the silhouette of a worn river pebble and nothing else, no rim and no spark.
# The outline is one continuous curve with a few unequal swellings, a flatter belly and a single
# shallow chip, so it never reads as a polygon.
func _draw_ink_stone() -> void:
	var points := PackedVector2Array()
	var count := 28
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var r := 1.0 + 0.11 * sin(2.0 * a + 1.1) + 0.075 * sin(3.0 * a + 0.4) + 0.045 * sin(5.0 * a + 2.2) + 0.022 * sin(7.0 * a + 0.9)
		# A shallow chip knocked out of the upper right.
		r -= 0.12 * exp(-pow((a - 5.35) / 0.28, 2.0))
		var x := cos(a) * r * item_radius * 1.04
		var y := sin(a) * r * item_radius * 0.9
		# The belly that rested on the ground is flatter.
		if y > 0.0:
			y *= 0.9
		points.append(Vector2(x, y))
	# The land is drawn with a softened edge; a hard-edged polygon beside it looks pasted on. Two
	# translucent, slightly larger copies give the stone the same soft rim.
	var ink := Color("050606")
	for ring in [[1.16, 0.16], [1.08, 0.32]]:
		var grown := PackedVector2Array()
		for point in points:
			grown.append(point * float(ring[0]))
		draw_colored_polygon(grown, Color(ink.r, ink.g, ink.b, float(ring[1])))
	draw_colored_polygon(points, ink)

func _draw_wood() -> void:
	var start := Vector2(-item_radius, item_radius * 0.42)
	var finish := Vector2(item_radius, -item_radius * 0.42)
	var bundle_offset := Vector2(0.0, item_radius * 0.34)
	draw_line(start - bundle_offset, finish - bundle_offset, Color("060809"), maxf(5.0, item_radius * 0.48), true)
	draw_line(start, finish, Color("060809"), maxf(6.0, item_radius * 0.52), true)
	draw_line(start + bundle_offset, finish + bundle_offset, Color("060809"), maxf(5.0, item_radius * 0.48), true)
	draw_line(start, finish, Color(0.32, 0.31, 0.27, 0.52), maxf(1.5, item_radius * 0.14), true)
	draw_line(
		Vector2(item_radius * 0.22, -item_radius * 0.08),
		Vector2(item_radius * 0.58, -item_radius * 0.62),
		Color("07090a"),
		maxf(2.4, item_radius * 0.22),
		true
	)
	draw_circle(
		Vector2(-item_radius * 0.20, item_radius * 0.08),
		maxf(1.2, item_radius * 0.13),
		Color(0.91, 0.42, 0.10, 0.78),
		true,
		-1.0,
		true
	)

func _draw_scrap() -> void:
	var points := PackedVector2Array([
		Vector2(-item_radius * 0.92, -item_radius * 0.48),
		Vector2(-item_radius * 0.28, -item_radius * 0.72),
		Vector2(item_radius * 0.90, -item_radius * 0.38),
		Vector2(item_radius * 0.72, item_radius * 0.62),
		Vector2(-item_radius * 0.54, item_radius * 0.56),
	])
	draw_colored_polygon(points, Color("060809"))
	draw_polyline(points, Color(0.33, 0.36, 0.34, 0.36), maxf(1.4, item_radius * 0.13), true)
	draw_line(
		Vector2(-item_radius * 0.45, -item_radius * 0.30),
		Vector2(item_radius * 0.48, item_radius * 0.30),
		Color(0.34, 0.38, 0.36, 0.48),
		maxf(1.5, item_radius * 0.14),
		true
	)
	draw_circle(
		Vector2(item_radius * 0.42, item_radius * 0.20),
		maxf(1.2, item_radius * 0.13),
		Color(0.93, 0.44, 0.11, 0.82),
		true,
		-1.0,
		true
	)

func _draw_bottle() -> void:
	var body := PackedVector2Array([
		Vector2(-item_radius * 0.70, -item_radius * 0.28),
		Vector2(-item_radius * 0.40, -item_radius * 0.58),
		Vector2(item_radius * 0.40, -item_radius * 0.58),
		Vector2(item_radius * 0.70, -item_radius * 0.28),
		Vector2(item_radius * 0.62, item_radius * 0.82),
		Vector2(-item_radius * 0.62, item_radius * 0.82),
	])
	draw_colored_polygon(body, Color("060809"))
	draw_polyline(body, Color(0.34, 0.37, 0.34, 0.34), maxf(1.3, item_radius * 0.12), true)
	draw_rect(
		Rect2(
			Vector2(-item_radius * 0.22, -item_radius * 0.88),
			Vector2(item_radius * 0.44, item_radius * 0.56)
		),
		Color("050708")
	)
	draw_circle(
		Vector2(item_radius * 0.15, item_radius * 0.26),
		maxf(1.2, item_radius * 0.14),
		Color(0.94, 0.45, 0.11, 0.80),
		true,
		-1.0,
		true
	)

func _draw_key() -> void:
	var line_width := maxf(4.2, item_radius * 0.40)
	var color := Color("060809")
	var bow_center := Vector2(-item_radius * 0.48, 0.0)
	var bow := PackedVector2Array([
		bow_center + Vector2(-item_radius * 0.78, -item_radius * 0.20),
		bow_center + Vector2(-item_radius * 0.42, -item_radius * 0.68),
		bow_center + Vector2(item_radius * 0.34, -item_radius * 0.72),
		bow_center + Vector2(item_radius * 0.70, -item_radius * 0.10),
		bow_center + Vector2(item_radius * 0.38, item_radius * 0.66),
		bow_center + Vector2(-item_radius * 0.54, item_radius * 0.62),
	])
	draw_colored_polygon(bow, color)
	var inset := PackedVector2Array([
		bow_center + Vector2(-item_radius * 0.28, -item_radius * 0.12),
		bow_center + Vector2(0.0, -item_radius * 0.30),
		bow_center + Vector2(item_radius * 0.26, -item_radius * 0.04),
		bow_center + Vector2(item_radius * 0.06, item_radius * 0.28),
		bow_center + Vector2(-item_radius * 0.26, item_radius * 0.18),
	])
	draw_colored_polygon(inset, Color(0.26, 0.28, 0.26, 0.54))
	draw_circle(
		Vector2(-item_radius * 0.56, -item_radius * 0.12),
		maxf(1.1, item_radius * 0.12),
		Color(0.94, 0.45, 0.11, 0.82),
		true,
		-1.0,
		true
	)
	draw_line(
		Vector2(-item_radius * 0.08, 0.0),
		Vector2(item_radius * 0.86, 0.0),
		color,
		line_width,
		true
	)
	draw_line(
		Vector2(item_radius * 0.42, 0.0),
		Vector2(item_radius * 0.42, item_radius * 0.38),
		color,
		line_width,
		true
	)
	draw_line(
		Vector2(item_radius * 0.72, 0.0),
		Vector2(item_radius * 0.72, item_radius * 0.28),
		color,
		line_width,
		true
	)
