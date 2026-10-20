extends Node2D

const INK := Color("0a0c0c")

func _draw() -> void:
	_limb([Vector2(-18,12),Vector2(-5,-20),Vector2(-23,-66),Vector2(-43,-105),Vector2(-46,-143),Vector2(-24,-177),Vector2(22,-210),Vector2(92,-232),Vector2(178,-246),Vector2(247,-262),Vector2(298,-264)],[21,18,16,14,12,10,8,6,4,2.5,0.8])
	_limb([Vector2(-43,-126),Vector2(-86,-168),Vector2(-96,-205),Vector2(-89,-226)],[8,5,2,0.4])
	_limb([Vector2(-85,-167),Vector2(-118,-176),Vector2(-133,-198)],[4,2,0.3])
	_limb([Vector2(54,-221),Vector2(49,-260),Vector2(71,-294),Vector2(95,-307)],[6,4,2,0.4])
	_limb([Vector2(51,-262),Vector2(30,-281),Vector2(22,-303)],[3,1.5,0.3])
	_limb([Vector2(181,-247),Vector2(211,-227),Vector2(252,-222),Vector2(272,-229)],[3,2,1,0.3])
	_limb([Vector2(-7,-7),Vector2(23,13),Vector2(48,30)],[15,7,0.5])
	_limb([Vector2(-11,-9),Vector2(-33,6),Vector2(-52,1)],[11,5,0.5])
	# Overlapping dry leaves conceal the tool among the branch's natural shapes.
	_limb([Vector2(244,-259),Vector2(266,-276),Vector2(286,-278)],[2.8,1.3,0.2])
	_limb([Vector2(276,-263),Vector2(291,-251),Vector2(296,-244)],[2.0,1.0,0.3])
	for spec in [Vector4(211,-254,-1.18,0.78),Vector4(237,-260,-0.68,0.92),Vector4(261,-271,0.95,0.70),Vector4(284,-277,-0.32,0.66),Vector4(289,-251,1.86,0.63)]:
		_draw_dry_leaf(Vector2(spec.x,spec.y),spec.z,spec.w)

func _draw_dry_leaf(origin: Vector2, angle: float, size_value: float) -> void:
	var outline := PackedVector2Array()
	for i in 18:
		var t := float(i)/17.0
		var edge := Vector2(-sin(t*PI)*13.0,-t*58.0)
		outline.append(origin+edge.rotated(angle)*size_value)
	for i in 18:
		var t := 1.0-float(i)/17.0
		var edge := Vector2(sin(t*PI)*9.0,-t*58.0)
		outline.append(origin+edge.rotated(angle)*size_value)
	draw_colored_polygon(outline,Color("101313"))

func _limb(points: Array, widths: Array) -> void:
	var spine: Array[Vector2] = []
	var thickness: Array[float] = []
	for i in points.size()-1:
		var a: Vector2 = points[i]
		var d: Vector2 = points[i+1]
		var b: Vector2 = a+(d-Vector2(points[maxi(0,i-1)]))/6.0
		var c: Vector2 = d-(Vector2(points[mini(points.size()-1,i+2)])-a)/6.0
		for sample in 8:
			var t := float(sample)/8.0
			spine.append(a.bezier_interpolate(b,c,d,t))
			thickness.append(lerpf(widths[i],widths[i+1],t)*(1.0+sin((i+t)*7.4)*0.035))
	spine.append(points.back())
	thickness.append(widths.back())
	var outline := PackedVector2Array()
	for side in [1.0,-1.0]:
		for step in spine.size():
			var i: int = step if side>0 else spine.size()-1-step
			var direction: Vector2 = spine[mini(i+1,spine.size()-1)]-spine[maxi(0,i-1)]
			var normal := Vector2(-direction.y,direction.x).normalized()
			outline.append(spine[i]+normal*thickness[i]*side)
	draw_colored_polygon(outline,INK)
