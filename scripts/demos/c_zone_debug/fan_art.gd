extends Node2D

var ink := Color("161616")
var leaf_outline := PackedVector2Array()
var swing_bend := 0.0
var leaf_material: ShaderMaterial
var leaf_node: Polygon2D
var fist := false  # carried in his hand: the stalk is left open where his fist is, so his own hand closes on it

func set_swing_pose(progress: float) -> void:
	# The grip stays rigid while the broad blade lags behind the power stroke.
	swing_bend = sin(smoothstep(0.30,0.70,progress)*PI) * -9.0 if progress > 0.0 else 0.0
	if leaf_material:
		leaf_material.set_shader_parameter("bend", swing_bend)
	queue_redraw()

# Carried, the stalk is drawn in front of him, left open for a few pixels where his own fist is (the actor draws the fist,
# so the stalk passes THROUGH the hand), and the blade behind his head (its own depth, below the stalk's). Otherwise the
# stalk disappears behind his body and the fan looks stuck to him. (A fist drawn here as well, on top, showed as a
# severed hand floating in the air whenever the handle was not exactly at his hand.)
func set_grip(blade_behind: bool, show_fist: bool) -> void:
	if leaf_node != null:
		leaf_node.z_index = -3 if blade_behind else 0
	if show_fist != fist:
		fist = show_fist
		queue_redraw()

# The blade flexes: its tip lags behind the handle (the spring is in the hooded boy's actor).
func set_bend(value: float) -> void:
	if is_equal_approx(value, swing_bend):
		return
	swing_bend = value
	if leaf_material:
		leaf_material.set_shader_parameter("bend", swing_bend)
	queue_redraw()

func _bent(point: Vector2) -> Vector2:
	var weight := pow(clampf((-point.y-28.0)/105.0,0.0,1.0),2.0)
	return point + Vector2(swing_bend * weight,0)

func _ready() -> void:
	var leaf := Polygon2D.new()
	var outline := _leaf_outline()
	leaf_outline = outline
	leaf.polygon = outline
	leaf.antialiased = true
	leaf.color = ink
	leaf.show_behind_parent = true
	leaf_node = leaf
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	varying vec2 leaf_position;
uniform float bend = 0.0;
uniform float light = 1.0;
void vertex() {
 leaf_position = VERTEX;
 float weight=pow(clamp((-VERTEX.y-28.0)/105.0,0.0,1.0),2.0);
 VERTEX.x+=bend*weight;
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p=leaf_position;
 float crease=sin(p.y*0.40+abs(p.x)*0.25)*0.009;
 float grain=(hash(floor(p*2.0))-0.5)*0.022;
 float fold=exp(-abs(p.x-(p.y+105.0)*-0.035)*0.20)*0.018;
 COLOR.rgb=clamp(COLOR.rgb+vec3(crease+grain+fold),vec3(0.0),vec3(1.0));
 // Light from behind and above: the blade is thin, so the light shows through at the edges and along the veins,
 // brightest on the side turned to the light and towards the tip.
 float t = clamp((-29.0 - p.y) / 108.0, 0.0, 1.0);
 float mid = 3.0 * sin(t * 3.14159) + 7.0 * t * t;
 float width = max(41.0 * pow(max(sin(3.14159 * (0.04 + 0.92 * t)), 0.0), 0.8), 1.0);
 float across = (p.x - mid) / width;
 float rim = smoothstep(0.42, 1.0, abs(across));
 float lit = smoothstep(-0.35, 1.0, across);
 float veins = pow(max(sin(p.y * 0.62 + abs(across) * 7.0), 0.0), 6.0);
 vec3 glow = vec3(0.07, 0.078, 0.068) * rim * (0.30 + 0.70 * lit);
 glow += vec3(0.02, 0.022, 0.019) * veins * (1.0 - rim * 0.6) * (0.4 + 0.6 * lit);
 glow += vec3(0.022, 0.025, 0.02) * smoothstep(0.55, 1.0, t) * (0.3 + 0.7 * lit);
 COLOR.rgb = clamp(COLOR.rgb + glow * light, vec3(0.0), vec3(1.0));
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	leaf_material = material_value
	leaf.material = material_value
	add_child(leaf)

func _curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	for i in 12:
		var t := float(i)/12.0
		points.append(a.bezier_interpolate(b,c,d,t))

# A banana leaf: a long blade, wider on one side, the midrib bending a little towards the tip, and the edges torn into
# narrow slits that run in along the side veins. (The old outline was a smooth egg: it read as a sticker.)
const LEAF_BASE := -29.0
const LEAF_TOP := -137.0
const SLITS_RIGHT := [[0.22, 13.0], [0.34, 16.0], [0.47, 12.0], [0.60, 17.0], [0.72, 11.0], [0.84, 8.0]]
const SLITS_LEFT := [[0.28, 12.0], [0.41, 15.0], [0.54, 13.0], [0.66, 16.0], [0.78, 10.0]]

func _t_of(y: float) -> float:
	return clampf((LEAF_BASE - y) / (LEAF_BASE - LEAF_TOP), 0.0, 1.0)

func _mid_x(y: float) -> float:
	var t := _t_of(y)
	return 3.0 * sin(t * PI) + 7.0 * t * t

func _half_width(t: float, side: float, with_slits: bool) -> float:
	var width := 41.0 * pow(maxf(sin(PI * (0.04 + 0.92 * t)), 0.0), 0.8)
	if side < 0.0:
		width *= 0.88
	if with_slits:
		for slit in (SLITS_RIGHT if side > 0.0 else SLITS_LEFT):
			width -= float(slit[1]) * exp(-pow((t - float(slit[0])) / 0.014, 2.0))
	return maxf(width, 1.5)

func _leaf_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 72
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(LEAF_BASE, LEAF_TOP, t)
		points.append(Vector2(_mid_x(y) + _half_width(t, 1.0, true), y))
	points.append(Vector2(_mid_x(LEAF_TOP) + 2.0, LEAF_TOP - 4.0))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var y := lerpf(LEAF_BASE, LEAF_TOP, t)
		points.append(Vector2(_mid_x(y) - _half_width(t, -1.0, true), y))
	return points

func _draw() -> void:
	var stem := Color(ink.r*0.85,ink.g*0.85,ink.b*0.85)
	var stalk := PackedVector2Array()
	# the handle runs on below the origin (where the hand is): held, it passes through the fist and comes out the other side
	for point in [Vector2(1,36),Vector2(0,14),Vector2(-2,-16),Vector2(1,-32),Vector2(_mid_x(-68.0),-68),Vector2(_mid_x(-108.0),-108),Vector2(_mid_x(-133.0),-133)]:
		stalk.append(_bent(point))
	if fist:
		var lower := PackedVector2Array()
		var upper := PackedVector2Array()
		for point in stalk:
			if point.y > 5.0:
				lower.append(point)
			elif point.y < -5.0:
				upper.append(point)
		lower.append(Vector2(0.5, 5.0))
		upper.insert(0, Vector2(0.0, -5.0))
		draw_polyline(lower, stem, 3.6, true)
		draw_polyline(upper, stem, 3.6, true)
	else:
		draw_polyline(stalk,stem,3.6,true)
	var vein := ink.lightened(0.07)
	draw_polyline(PackedVector2Array([_bent(Vector2(1,-32)),_bent(Vector2(_mid_x(-68.0),-68)),_bent(Vector2(_mid_x(-108.0),-108)),_bent(Vector2(_mid_x(-133.0),-133))]),vein,1.15,true)
	# side veins from the midrib to the edge, slanting towards the tip
	for i in 14:
		var y := -38.0-float(i)*7.2
		var t := _t_of(y)
		for side in [-1.0,1.0]:
			var reach := _half_width(t, side, false)
			var points := PackedVector2Array()
			var mid := Vector2(_mid_x(y), y)
			_curve(points,mid,mid+Vector2(side*reach*0.30,-2),mid+Vector2(side*reach*0.8,-7),mid+Vector2(side*reach,-13))
			var clipped := PackedVector2Array()
			for point in points:
				if not Geometry2D.is_point_in_polygon(point,leaf_outline): break
				clipped.append(_bent(point))
			if clipped.size()>1:
				draw_polyline(clipped,Color(vein,0.5),0.7,true)
	# a faint light along the upper edge gives the blade some roundness
	var rim := PackedVector2Array()
	for i in range(0, 73):
		var t := float(i) / 72.0
		var y := lerpf(LEAF_BASE, LEAF_TOP, t)
		rim.append(_bent(Vector2(_mid_x(y) + _half_width(t, 1.0, true) - 0.8, y)))
	draw_polyline(rim, Color(0.55, 0.57, 0.52, 0.09), 1.0, true)

