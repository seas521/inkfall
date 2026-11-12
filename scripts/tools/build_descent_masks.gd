extends SceneTree

# Derive reusable opacity masks for game rendering; never modify the source art.
# Connected silhouettes replace the old rectangular shader selection windows.
const ROOT := "res://assets/art/descent/"
const SOURCES := ["01-broken-walkway-v2.png","02-wet-recess-v2.png","03-hoist-station-v2.png","04-scree-chute-v2.png","05-bat-cavern-v2.png"]
const SEEDS := [
	[Vector2(0.10,0.5),Vector2(0.4,0.72),Vector2(0.67,0.52),Vector2(0.73,0.48),Vector2(0.2,0.1)],
	[Vector2(0.1,0.5),Vector2(0.25,0.1),Vector2(0.45,0.77),Vector2(0.646,0.55)],
	[Vector2(0.1,0.5),Vector2(0.18,0.4),Vector2(0.5,0.21),Vector2(0.73,0.23),Vector2(0.51,0.65),Vector2(0.73,0.85),Vector2(0.25,0.54),Vector2(0.71,0.5)],
	[Vector2(0.5,0.9),Vector2(0.1,0.4),Vector2(0.9,0.23),Vector2(0.65,0.7)],
	[Vector2(0.5,0.9),Vector2(0.5,0.1),Vector2(0.07,0.5)],
]
const W := 640
const H := 360

func _initialize() -> void:
	call_deferred("_run")

func _morph(src: PackedByteArray, dilate: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(W*H)
	for y in H:
		for x in W:
			var result := 0 if dilate else 1
			for dy in range(-1,2):
				for dx in range(-1,2):
					var value := src[clampi(y+dy,0,H-1)*W+clampi(x+dx,0,W-1)]
					result = maxi(result,value) if dilate else mini(result,value)
			out[y*W+x] = result
	return out

func _nearest(src: PackedByteArray, at: Vector2) -> int:
	var x := clampi(int(at.x*W),0,W-1)
	var y := clampi(int(at.y*H),0,H-1)
	for radius in range(25):
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				if radius > 0 and absi(dx) != radius and absi(dy) != radius:
					continue
				var idx := clampi(y+dy,0,H-1)*W+clampi(x+dx,0,W-1)
				if src[idx] > 0:
					return idx
	return -1

func _component(src: PackedByteArray, out: PackedByteArray, first: int) -> void:
	if first < 0 or out[first] > 0:
		return
	var queue := PackedInt32Array([first])
	out[first] = 1
	var cursor := 0
	while cursor < queue.size():
		var idx := queue[cursor]
		cursor += 1
		var x := idx%W
		var y := idx/W
		for offset in [-1,1,-W,W]:
			if (offset == -1 and x == 0) or (offset == 1 and x == W-1) or (offset == -W and y == 0) or (offset == W and y == H-1):
				continue
			var n: int = idx+int(offset)
			if src[n] > 0 and out[n] == 0:
				out[n] = 1
				queue.append(n)

func _fill_small_holes(mask: PackedByteArray) -> void:
	var visited := PackedByteArray()
	visited.resize(W*H)
	for first in range(W*H):
		if mask[first] > 0 or visited[first] > 0:
			continue
		var queue := PackedInt32Array([first])
		visited[first] = 1
		var cursor := 0
		var border := false
		while cursor < queue.size():
			var idx := queue[cursor]
			cursor += 1
			var x := idx%W
			var y := idx/W
			if x == 0 or y == 0 or x == W-1 or y == H-1:
				border = true
			for offset in [-1,1,-W,W]:
				if (offset == -1 and x == 0) or (offset == 1 and x == W-1) or (offset == -W and y == 0) or (offset == W and y == H-1):
					continue
				var n: int = idx+int(offset)
				if mask[n] == 0 and visited[n] == 0:
					visited[n] = 1
					queue.append(n)
		if not border and queue.size() <= 350:
			for idx in queue:
				mask[idx] = 1

func _run() -> void:
	for i in range(SOURCES.size()):
		var src := Image.load_from_file(ROOT+SOURCES[i])
		assert(src != null)
		src.resize(W,H,Image.INTERPOLATE_LANCZOS)
		var dark := PackedByteArray()
		dark.resize(W*H)
		for y in H:
			for x in W:
				var c := src.get_pixel(x,y)
				dark[y*W+x] = 1 if c.r*0.299+c.g*0.587+c.b*0.114 < 0.36 else 0
		# Close material grain before identifying the main near-plane components.
		dark = _morph(_morph(dark,true),false)
		var selected := PackedByteArray()
		selected.resize(W*H)
		for seed_value in SEEDS[i]:
			_component(dark,selected,_nearest(dark,seed_value))
		_fill_small_holes(selected)
		var mask := Image.create(W,H,false,Image.FORMAT_L8)
		for y in H:
			for x in W:
				var value := float(selected[y*W+x])
				mask.set_pixel(x,y,Color(value,value,value))
		mask.resize(1280,720,Image.INTERPOLATE_CUBIC)
		var path := ROOT+"%02d-foreground-mask.png" % (i+1)
		assert(mask.save_png(path) == OK)
		print("MASK ",i+1," ",path)
	quit(0)
