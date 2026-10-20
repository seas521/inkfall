extends SceneTree

const SOURCE_DIR := "res://assets/art/actors/crooked_tower/source"
const OUTPUT_DIR := "res://assets/art/actors/crooked_tower"
const CELL_SIZE := Vector2i(224, 224)
const ROOT_Y := 198
const TARGET_HEIGHT := 156.0

const STRIPS: Array[Dictionary] = [
	{"name": "idle", "frames": 8},
	{"name": "walk", "frames": 12},
	{"name": "jump", "frames": 12, "preserve_air": true},
	{"name": "throw", "frames": 12},
	{"name": "shield", "frames": 8},
	{"name": "sword", "frames": 8},
	{"name": "push", "frames": 12},
	{"name": "hit_fall", "frames": 12},
]

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	for strip in STRIPS:
		var strip_name := String(strip["name"])
		var frame_count := int(strip["frames"])
		var source := Image.load_from_file("%s/%s.png" % [SOURCE_DIR, strip_name])
		if source == null or source.is_empty():
			push_error("Unable to load GPT Image strip: %s" % strip_name)
			quit(1)
			return
		var boxes := _detect_boxes(source, frame_count)
		var heights: Array[int] = []
		var source_floor := 0
		for box in boxes:
			heights.append(box.size.y)
			source_floor = maxi(source_floor, box.end.y)
		heights.sort()
		var median_height := float(heights[heights.size() / 2])
		var scale_factor := TARGET_HEIGHT / maxf(1.0, median_height)
		var atlas := Image.create(CELL_SIZE.x * frame_count, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for frame_index in range(frame_count):
			_write_frame(
				source,
				atlas,
				frame_index,
				frame_count,
				boxes[frame_index],
				source_floor,
				scale_factor,
				bool(strip.get("preserve_air", false)),
				strip_name
			)
		var output_path := "%s/%s.png" % [OUTPUT_DIR, strip_name]
		var save_error := atlas.save_png(output_path)
		if save_error != OK:
			push_error("Unable to save processed actor atlas: %s" % output_path)
			quit(1)
			return
		print("Built ", output_path, " with ", frame_count, " frames")
	quit(0)

func _detect_boxes(source: Image, frame_count: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for frame_index in range(frame_count):
		var x0 := int(round(float(frame_index) * float(source.get_width()) / float(frame_count)))
		var x1 := int(round(float(frame_index + 1) * float(source.get_width()) / float(frame_count)))
		var safe_margin := maxi(2, int(round(float(x1 - x0) * 0.055)))
		x0 += safe_margin
		x1 -= safe_margin
		var min_x := x1
		var min_y := source.get_height()
		var max_x := x0
		var max_y := 0
		for y in range(source.get_height()):
			for x in range(x0, x1):
				if _key_alpha(source.get_pixel(x, y)) <= 0.08:
					continue
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
		if max_x <= min_x or max_y <= min_y:
			result.append(Rect2i(x0, 0, maxi(1, x1 - x0), source.get_height()))
			continue
		var box := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
		box = box.grow(3).intersection(Rect2i(0, 0, source.get_width(), source.get_height()))
		result.append(box)
	return result

func _write_frame(
	source: Image,
	atlas: Image,
	frame_index: int,
	frame_count: int,
	box: Rect2i,
	source_floor: int,
	scale_factor: float,
	preserve_air: bool,
	strip_name: String
) -> void:
	var keyed := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	keyed.fill(Color.TRANSPARENT)
	for y in range(box.size.y):
		for x in range(box.size.x):
			var source_color := source.get_pixel(box.position.x + x, box.position.y + y)
			var alpha := _key_alpha(source_color)
			if alpha <= 0.01:
				continue
			var output_color := Color(0.002, 0.003, 0.004, alpha)
			if source_color.r > 0.30 and source_color.r > source_color.g * 1.18:
				output_color = Color(
					clampf(source_color.r * 1.06, 0.0, 1.0),
					clampf(source_color.g * 0.96, 0.0, 1.0),
					clampf(source_color.b * 0.82, 0.0, 1.0),
					alpha
				)
			keyed.set_pixel(x, y, output_color)
	var scaled_size := Vector2i(
		maxi(1, int(round(float(keyed.get_width()) * scale_factor))),
		maxi(1, int(round(float(keyed.get_height()) * scale_factor)))
	)
	keyed.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_BILINEAR)
	_clean_scaled_edges(keyed)
	var main_bounds := _remove_isolated_fragments(keyed, strip_name == "throw")
	var head_center_x := _find_helmet_center_x(keyed, main_bounds)
	var source_air_gap := source_floor - box.end.y if preserve_air else 0
	var destination := Vector2i(
		frame_index * CELL_SIZE.x + CELL_SIZE.x / 2 - head_center_x,
		ROOT_Y - main_bounds.end.y - int(round(float(source_air_gap) * scale_factor))
	)
	atlas.blit_rect(keyed, Rect2i(Vector2i.ZERO, keyed.get_size()), destination)

func _clean_scaled_edges(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.26:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var cleaned_alpha := smoothstep(0.26, 0.76, color.a)
			if color.r > 0.30 and color.r > color.g * 1.16 and color.b < 0.36:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, cleaned_alpha))
			else:
				image.set_pixel(x, y, Color(0.002, 0.003, 0.004, cleaned_alpha))

func _remove_isolated_fragments(image: Image, allow_detached_object: bool) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var components: Array[Array] = []
	for y in range(height):
		for x in range(width):
			var flat_index := y * width + x
			if visited[flat_index] != 0 or image.get_pixel(x, y).a <= 0.42:
				continue
			var points: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			visited[flat_index] = 1
			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				points.append(point)
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						var neighbor: Vector2i = point + Vector2i(offset_x, offset_y)
						if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
							continue
						var neighbor_index: int = neighbor.y * width + neighbor.x
						if visited[neighbor_index] != 0 or image.get_pixelv(neighbor).a <= 0.42:
							continue
						visited[neighbor_index] = 1
						stack.append(neighbor)
			components.append(points)
	if components.is_empty():
		return Rect2i(0, 0, width, height)
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var main: Array = components[0]
	var main_bounds := _points_bounds(main)
	var keep := PackedByteArray()
	keep.resize(width * height)
	for component_index in range(components.size()):
		var component: Array = components[component_index]
		var bounds := _points_bounds(component)
		var preserve := component_index == 0
		if not preserve and component.size() >= 6:
			preserve = _rect_gap(main_bounds, bounds) <= 10.0
		if not preserve and allow_detached_object and component.size() >= 18:
			preserve = _rect_gap(main_bounds, bounds) <= 82.0
		if not preserve:
			for point in component:
				var color := image.get_pixelv(point)
				if color.r > 0.30 and color.r > color.g * 1.16:
					preserve = true
					break
		if preserve:
			for point in component:
				keep[point.y * width + point.x] = 1
	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.0 and keep[y * width + x] == 0:
				image.set_pixel(x, y, Color.TRANSPARENT)
	return main_bounds

func _points_bounds(points: Array) -> Rect2i:
	var min_x := 1000000
	var min_y := 1000000
	var max_x := -1
	var max_y := -1
	for point in points:
		min_x = mini(min_x, point.x)
		min_y = mini(min_y, point.y)
		max_x = maxi(max_x, point.x)
		max_y = maxi(max_y, point.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _rect_gap(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(0, maxi(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxi(0, maxi(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(float(dx), float(dy)).length()

func _find_helmet_center_x(image: Image, main_bounds: Rect2i) -> int:
	var scan_end := main_bounds.position.y + int(round(float(main_bounds.size.y) * 0.62))
	var best_width := 0
	var best_center := main_bounds.get_center().x
	for y in range(main_bounds.position.y, mini(image.get_height(), scan_end)):
		var row_min := image.get_width()
		var row_max := -1
		for x in range(main_bounds.position.x, main_bounds.end.x):
			if image.get_pixel(x, y).a <= 0.42:
				continue
			row_min = mini(row_min, x)
			row_max = maxi(row_max, x)
		if row_max - row_min > best_width:
			best_width = row_max - row_min
			best_center = (row_min + row_max) / 2
	return best_center

func _key_alpha(color: Color) -> float:
	var green_excess := color.g - maxf(color.r, color.b)
	return 1.0 - smoothstep(0.12, 0.42, green_excess)
