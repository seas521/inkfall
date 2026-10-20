extends RefCounted

const Palette = preload("res://scripts/shared/inkfall_palette.gd")

static func draw_hut_forecourt(canvas: CanvasItem, base: Vector2, scale_factor: float, tree_hits: int, axe_state: String, elapsed: float, swing_time: float) -> void:
	draw_tree(canvas, base + Vector2(-720.0, 0.0) * scale_factor, scale_factor, tree_hits, elapsed, swing_time)
	draw_fire(canvas, base + Vector2(-300.0, -5.0) * scale_factor, scale_factor, elapsed)
	draw_house(canvas, base, scale_factor, elapsed)
	draw_backyard(canvas, base, scale_factor, axe_state)
	if axe_state == "stuck":
		draw_axe(canvas, base + Vector2(-695.0, -92.0) * scale_factor, -0.18, scale_factor)

static func draw_backyard(canvas: CanvasItem, base: Vector2, scale_factor: float, axe_state: String) -> void:
	var fence_start := base + Vector2(300.0, 0.0) * scale_factor
	var fence_end := base + Vector2(760.0, 0.0) * scale_factor
	canvas.draw_line(fence_start + Vector2(0.0, -54.0) * scale_factor, fence_end + Vector2(0.0, -54.0) * scale_factor, Color(Palette.INK, 0.7), maxf(2.0, 6.0 * scale_factor), true)
	for post_index in range(5):
		var post_x: float = fence_start.x + float(post_index) * 112.0 * scale_factor
		canvas.draw_line(Vector2(post_x, fence_start.y), Vector2(post_x, fence_start.y - 92.0 * scale_factor), Palette.INK, maxf(3.0, 8.0 * scale_factor), true)
	var rake_base := base + Vector2(390.0, -5.0) * scale_factor
	canvas.draw_line(rake_base, rake_base + Vector2(18.0, -126.0) * scale_factor, Palette.HEMP, maxf(2.0, 5.0 * scale_factor), true)
	for tine_index in range(4):
		var tine_origin := rake_base + Vector2(5.0 + float(tine_index) * 9.0, -125.0) * scale_factor
		canvas.draw_line(tine_origin, tine_origin + Vector2(0.0, -20.0) * scale_factor, Palette.INK, maxf(1.0, 3.0 * scale_factor), true)
	var spade_base := base + Vector2(475.0, -4.0) * scale_factor
	canvas.draw_line(spade_base, spade_base + Vector2(-14.0, -118.0) * scale_factor, Palette.HEMP, maxf(2.0, 5.0 * scale_factor), true)
	canvas.draw_circle(spade_base + Vector2(-15.0, -126.0) * scale_factor, 13.0 * scale_factor, Palette.PALE)
	if axe_state == "ground":
		draw_axe(canvas, base + Vector2(620.0, -18.0) * scale_factor, -1.02, scale_factor)
	for log_index in range(7):
		var row: int = int(log_index / 4)
		var column: int = log_index % 4
		var log_center := base + Vector2(545.0 + float(column) * 43.0 + float(row) * 18.0, -18.0 - float(row) * 34.0) * scale_factor
		canvas.draw_circle(log_center, 18.0 * scale_factor, Palette.HEMP)
		canvas.draw_circle(log_center, 18.0 * scale_factor, Palette.INK, false, maxf(1.0, 3.0 * scale_factor), true)
		canvas.draw_circle(log_center, 7.0 * scale_factor, Color(Palette.INK, 0.28), false, maxf(1.0, 2.0 * scale_factor), true)

static func draw_house(canvas: CanvasItem, base: Vector2, scale_factor: float, elapsed: float) -> void:
	var wall := Rect2(base + Vector2(0.0, -132.0) * scale_factor, Vector2(210.0, 132.0) * scale_factor)
	canvas.draw_rect(wall, Palette.PAPER)
	canvas.draw_rect(wall, Palette.INK, false, maxf(2.0, 4.0 * scale_factor))
	for plank_index in range(5):
		var plank_x: float = base.x + (24.0 + float(plank_index) * 39.0) * scale_factor
		canvas.draw_line(Vector2(plank_x, wall.position.y + 8.0 * scale_factor), Vector2(plank_x - 4.0 * scale_factor, base.y), Color(Palette.INK, 0.22), maxf(1.0, 2.0 * scale_factor), true)
	var roof := PackedVector2Array([
		base + Vector2(-25.0, -124.0) * scale_factor,
		base + Vector2(96.0, -204.0) * scale_factor,
		base + Vector2(229.0, -124.0) * scale_factor,
	])
	canvas.draw_polygon(roof, PackedColorArray([Palette.INK]))
	canvas.draw_polyline(roof, Color(Palette.PAPER, 0.7), maxf(1.0, 2.0 * scale_factor), true)
	var chimney := Rect2(base + Vector2(153.0, -218.0) * scale_factor, Vector2(28.0, 72.0) * scale_factor)
	canvas.draw_rect(chimney, Palette.INK)
	var door := Rect2(base + Vector2(126.0, -82.0) * scale_factor, Vector2(48.0, 82.0) * scale_factor)
	canvas.draw_rect(door, Palette.INK)
	canvas.draw_circle(door.position + Vector2(11.0, 42.0) * scale_factor, maxf(1.5, 3.0 * scale_factor), Palette.GOLD)
	var window := Rect2(base + Vector2(34.0, -91.0) * scale_factor, Vector2(54.0, 46.0) * scale_factor)
	canvas.draw_rect(window, Color("b9dbe0"))
	canvas.draw_rect(window, Palette.INK, false, maxf(1.5, 3.0 * scale_factor))
	canvas.draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), Palette.INK, maxf(1.0, 2.0 * scale_factor))
	canvas.draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y), Palette.INK, maxf(1.0, 2.0 * scale_factor))
	var crescent_center := window.get_center()
	canvas.draw_circle(crescent_center, 9.0 * scale_factor, Color("dbe8df"))
	canvas.draw_circle(crescent_center + Vector2(4.0, -2.0) * scale_factor, 8.0 * scale_factor, Color("b9dbe0"))
	for smoke_index in range(3):
		var smoke_ratio: float = fmod(elapsed * 0.18 + float(smoke_index) * 0.31, 1.0)
		var smoke_center := chimney.position + Vector2(14.0, -12.0 - smoke_ratio * 70.0) * scale_factor
		canvas.draw_circle(smoke_center, (7.0 + smoke_ratio * 8.0) * scale_factor, Color(Palette.MID, (1.0 - smoke_ratio) * 0.22))

static func draw_tree(canvas: CanvasItem, base: Vector2, scale_factor: float, tree_hits: int, elapsed: float, swing_time: float) -> void:
	var sway: float = sin(elapsed * 18.0) * float(tree_hits) * 1.2 * scale_factor if swing_time > 0.0 else 0.0
	var trunk_top := base + Vector2(sway, -205.0 * scale_factor)
	canvas.draw_line(base, trunk_top, Palette.INK, maxf(6.0, 18.0 * scale_factor), true)
	canvas.draw_line(base + Vector2(-4.0, -94.0) * scale_factor, base + Vector2(-86.0 + sway, -151.0) * scale_factor, Palette.INK, maxf(4.0, 11.0 * scale_factor), true)
	canvas.draw_line(base + Vector2(2.0, -135.0) * scale_factor, base + Vector2(92.0 + sway, -190.0) * scale_factor, Palette.INK, maxf(4.0, 10.0 * scale_factor), true)
	canvas.draw_line(trunk_top, base + Vector2(30.0 + sway, -250.0) * scale_factor, Palette.INK, maxf(3.0, 8.0 * scale_factor), true)
	for crown_index in range(7):
		var angle: float = float(crown_index) * TAU / 7.0
		var crown_center := trunk_top + Vector2(cos(angle) * 48.0, sin(angle) * 31.0) * scale_factor
		canvas.draw_circle(crown_center, 32.0 * scale_factor, Palette.PAPER)
		canvas.draw_circle(crown_center, 32.0 * scale_factor, Palette.INK, false, maxf(1.5, 3.0 * scale_factor), true)
	for cut_index in range(tree_hits):
		var cut_y: float = base.y - (45.0 + float(cut_index) * 9.0) * scale_factor
		canvas.draw_line(Vector2(base.x - 11.0 * scale_factor, cut_y), Vector2(base.x + 12.0 * scale_factor, cut_y - 7.0 * scale_factor), Palette.FIRE, maxf(2.0, 4.0 * scale_factor), true)

static func draw_axe(canvas: CanvasItem, origin: Vector2, rotation: float, scale_factor: float) -> void:
	var handle_end := origin + Vector2(46.0, 0.0).rotated(rotation) * scale_factor
	canvas.draw_line(origin, handle_end, Palette.HEMP, maxf(2.0, 6.0 * scale_factor), true)
	var blade_center := handle_end + Vector2(2.0, -2.0).rotated(rotation) * scale_factor
	var blade := PackedVector2Array([
		blade_center + Vector2(-2.0, -13.0).rotated(rotation) * scale_factor,
		blade_center + Vector2(18.0, -9.0).rotated(rotation) * scale_factor,
		blade_center + Vector2(19.0, 10.0).rotated(rotation) * scale_factor,
		blade_center + Vector2(-2.0, 12.0).rotated(rotation) * scale_factor,
	])
	canvas.draw_polygon(blade, PackedColorArray([Palette.PALE]))
	canvas.draw_polyline(blade, Palette.INK, maxf(1.0, 2.0 * scale_factor), true)

static func draw_fire(canvas: CanvasItem, origin: Vector2, scale_factor: float, elapsed: float) -> void:
	canvas.draw_line(origin + Vector2(-25.0, 0.0) * scale_factor, origin + Vector2(25.0, 0.0) * scale_factor, Palette.INK, maxf(2.0, 5.0 * scale_factor), true)
	for flame_index in range(4):
		var flame_x: float = (-15.0 + float(flame_index) * 10.0) * scale_factor
		var flame_height: float = (25.0 + sin(elapsed * 9.0 + float(flame_index)) * 7.0) * scale_factor
		var flame := PackedVector2Array([
			origin + Vector2(flame_x - 7.0 * scale_factor, 0.0),
			origin + Vector2(flame_x, -flame_height),
			origin + Vector2(flame_x + 7.0 * scale_factor, 0.0),
		])
		canvas.draw_polygon(flame, PackedColorArray([Palette.FIRE]))
		canvas.draw_polyline(flame, Palette.INK, maxf(1.0, 2.0 * scale_factor), true)
