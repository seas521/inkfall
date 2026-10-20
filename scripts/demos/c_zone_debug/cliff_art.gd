extends RefCounted

# Ink drawing for act three. These helpers draw into the second act's layers (the stage that gives
# every silhouette its soft edge), so the cliff, the ropes and the stones belong to the same picture.
# `art` is the marsh art node; `Cliff` is the act logic with the shared coordinates.

const Cliff = preload("res://scripts/demos/c_zone_debug/cliff_act.gd")
const INK := Color("050606")

# ------------------------------------------------------------------ static ink

static func draw_static(art) -> void:
	_draw_cliff_mass(art)
	_draw_guide_rail(art)
	_draw_pin(art)
	_draw_gallows(art)
	_draw_hinge(art)
	_draw_dressing(art)

static func _ramp_y(x: float) -> float:
	return Cliff.ramp_y(x)

static func _draw_cliff_mass(art) -> void:
	var land: Node2D = art.land
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var outline := PackedVector2Array()
	outline.append(Vector2(Cliff.CLIFF_X - 60.0, 980.0))
	outline.append(Vector2(Cliff.CLIFF_X - 60.0, 520.0))
	# A sheer face that goes up and up. Large, slow lumps and a scatter of stepped ledges that jut out
	# toward the lift: strata of different hardness, so it reads as rock and not a cut wall. The
	# collider is a plain wall; the ledges are only outline.
	var ledges := [
		Vector3(356.0, 12.0, 14.0), Vector3(292.0, 10.0, 9.0), Vector3(214.0, 14.0, 16.0), Vector3(150.0, 10.0, 10.0),
		Vector3(60.0, 12.0, 14.0), Vector3(-20.0, 10.0, 9.0), Vector3(-96.0, 14.0, 15.0), Vector3(-170.0, 10.0, 10.0), Vector3(-246.0, 12.0, 13.0),
	]
	var y := 520.0
	while y > Cliff.DOCK_Y + 14.0:
		var slow: float = art.noise.get_noise_1d(y * 0.55 + 4100.0) * 11.0
		var fine: float = art.noise.get_noise_1d(y * 2.3 + 700.0) * 2.4
		var step := 0.0
		for ledge in ledges:
			# A ledge: the face leans out, then undercuts just below it.
			var d: float = y - ledge.x
			if d > -ledge.y and d <= 0.0:
				step += ledge.z * (1.0 + d / ledge.y) * 0.9
			elif d > 0.0 and d < 12.0:
				step -= 6.0 * (1.0 - d / 12.0)
		var face_x: float = Cliff.CLIFF_X + 4.0 - maxf(0.0, slow) - step + fine
		if y > 372.0:
			face_x = minf(face_x, Cliff.CLIFF_X - 2.0)
		outline.append(Vector2(face_x, y))
		y -= 7.0
	# The lip at the top of the face, then the slope: a gentle, lumpy climb, then level ground that
	# runs on into the fog.
	outline.append(Vector2(Cliff.CLIFF_X - 6.0, Cliff.DOCK_Y + 14.0))
	outline.append(Vector2(Cliff.CLIFF_X - 4.0, Cliff.DOCK_Y + 3.0))
	var x := Cliff.CLIFF_X
	while x < Cliff.WORLD_END + 120.0:
		outline.append(Vector2(x, _ramp_y(x) - 1.4 + art.noise.get_noise_1d(x * 1.1 + 900.0) * 2.0 + art.noise.get_noise_1d(x * 4.0) * 0.8))
		x += 6.0
	outline.append(Vector2(Cliff.WORLD_END + 120.0, 980.0))
	land.draw_colored_polygon(outline, INK)
	# Dead roots grow out of the ledges and the lip and hang down over the fog.
	for spec in [Vector2(356.0, 90.0), Vector2(292.0, 120.0), Vector2(214.0, 110.0), Vector2(150.0, 100.0), Vector2(60.0, 120.0), Vector2(-20.0, 90.0), Vector2(-96.0, 130.0), Vector2(-170.0, 100.0), Vector2(-246.0, 120.0), Vector2(Cliff.DOCK_Y + 14.0, 110.0)]:
		var rx := Cliff.CLIFF_X - 6.0 + rng.randf_range(-3.0, 3.0)
		var ry: float = spec.x + rng.randf_range(-2.0, 6.0)
		art._limb(land, [
			Vector2(rx + 6.0, ry), Vector2(rx - rng.randf_range(2.0, 9.0), ry + spec.y * 0.3),
			Vector2(rx - rng.randf_range(0.0, 12.0), ry + spec.y * 0.65), Vector2(rx - rng.randf_range(-2.0, 8.0), ry + spec.y),
		], [rng.randf_range(2.8, 4.2), 2.2, 1.3, 0.3])
	# Dead twigs and a few half-buried stones along the slope.
	for spec in [Vector2(7140.0, 34.0), Vector2(7218.0, 44.0), Vector2(7292.0, 30.0), Vector2(7366.0, 40.0), Vector2(7452.0, 36.0)]:
		art._twig_fan(land, Vector2(spec.x, _ramp_y(spec.x) + 2.0), spec.y, int(spec.x))
	for n in range(5):
		var sx := Cliff.CLIFF_X + 50.0 + float(n) * 76.0 + rng.randf_range(-12.0, 12.0)
		var w := rng.randf_range(8.0, 18.0)
		var stone := PackedVector2Array()
		for q in range(13):
			var angle := PI + PI * float(q) / 12.0
			stone.append(Vector2(sx + cos(angle) * w, _ramp_y(sx) + 2.0 + sin(angle) * rng.randf_range(3.0, 6.0)))
		land.draw_colored_polygon(stone, INK)
	# A tumble of fallen blocks at the foot of the face, outside the cage's path.
	for n in range(4):
		var r := rng.randf_range(14.0, 30.0)
		land.draw_colored_polygon(art._xform(art._rock_shape(520 + n, r), Vector2(Cliff.CLIFF_X + 10.0 + float(n) * 23.0, 392.0 - r * 0.2), float(n) * 1.1), INK)

static func _draw_guide_rail(art) -> void:
	var land: Node2D = art.land
	var x := Cliff.LIFT_X - 4.0
	art._beam(land, Vector2(x, 396.0), Vector2(x + 1.5, -1700.0), 5.4, 3.0)
	# Cross ties back to the ground and short braces: it is bolted to the rock, not floating.
	art._beam(land, Vector2(x, 380.0), Vector2(x - 22.0, 396.0), 3.2, 5.0)
	art._beam(land, Vector2(x + 1.0, 330.0), Vector2(x - 14.0, 392.0), 3.0, 6.0)
	var y := 300.0
	while y > -1650.0:
		art._beam(land, Vector2(x, y), Vector2(x + 14.0, y - 10.0), 2.6, y)
		y -= 86.0

static func _draw_pin(art) -> void:
	var land: Node2D = art.land
	var ground: float = _ground(art, Cliff.STACK_X)
	var top: float = ground - Cliff.SLAB_H
	var rng := RandomNumberGenerator.new()
	rng.seed = 6906
	var outline := PackedVector2Array([Vector2(Cliff.STACK_X - 50.0, ground + 6.0), Vector2(Cliff.STACK_X - 47.0, top + 2.0)])
	for n in range(1, 9):
		outline.append(Vector2(Cliff.STACK_X - 47.0 + float(n) * 11.8, top + rng.randf_range(-1.6, 0.6)))
	outline.append(Vector2(Cliff.STACK_X + 48.0, top + 3.0))
	outline.append(Vector2(Cliff.STACK_X + 51.0, ground + 6.0))
	land.draw_colored_polygon(outline, INK)
	land.draw_arc(Vector2(Cliff.STACK_X - 38.0, top - 2.0), 5.5, 0.0, TAU, 14, INK, 2.6, true)

static func _draw_gallows(art) -> void:
	var land: Node2D = art.land
	# The far bank's dead tree: a boom reaches out over the gap and the bridge rope hangs from its tip.
	art._limb(land, [Vector2(6458.0, 400.0), Vector2(6452.0, 330.0), Vector2(6448.0, 240.0), Vector2(6449.0, 150.0), Vector2(6448.0, 80.0), Vector2(6452.0, 40.0)], [15.0, 13.0, 11.0, 9.0, 7.0, 4.0])
	art._limb(land, [Vector2(6449.0, 74.0), Vector2(6432.0, 64.0), Vector2(6416.0, 58.0), Vector2(Cliff.BRIDGE_ANCHOR.x, Cliff.BRIDGE_ANCHOR.y - 1.0)], [6.0, 4.6, 3.2, 1.8])
	art._limb(land, [Vector2(6451.0, 120.0), Vector2(6466.0, 100.0), Vector2(6470.0, 74.0), Vector2(6482.0, 56.0)], [5.0, 3.6, 2.4, 0.5])
	art._limb(land, [Vector2(6456.0, 392.0), Vector2(6486.0, 398.0), Vector2(6512.0, 412.0)], [9.0, 5.0, 1.0])
	art._limb(land, [Vector2(6450.0, 388.0), Vector2(6422.0, 396.0), Vector2(6414.0, 410.0)], [8.0, 4.0, 1.0])
	land.draw_circle(Cliff.BRIDGE_ANCHOR, 4.0, INK, true, -1.0, true)

static func _draw_hinge(art) -> void:
	var land: Node2D = art.land
	# The bridge turns on a stout log laid in the lip of the near bank.
	var h := Cliff.BRIDGE_HINGE
	land.draw_colored_polygon(PackedVector2Array([
		Vector2(h.x - 24.0, h.y - 3.0), Vector2(h.x - 9.0, h.y - 11.0), Vector2(h.x + 7.0, h.y - 10.0),
		Vector2(h.x + 12.0, h.y - 1.0), Vector2(h.x + 5.0, h.y + 9.0), Vector2(h.x - 14.0, h.y + 9.0),
	]), INK)
	art._beam(land, Vector2(h.x - 14.0, h.y - 4.0), Vector2(h.x - 20.0, h.y - 30.0), 5.0, 1.0)

static func _ground(art, x: float) -> float:
	for profile in art.level.MARSH_LANDS:
		var p: PackedVector2Array = profile
		if x >= p[0].x and x <= p[p.size() - 1].x:
			return art._visual_y(p, x)
	return 400.0

static func _draw_dressing(art) -> void:
	var land: Node2D = art.land
	for spec in [Vector2(6486.0, 46.0), Vector2(6640.0, 58.0), Vector2(6738.0, 40.0), Vector2(6868.0, 34.0)]:
		var y: float = _ground(art, spec.x) + 2.0
		art._twig_fan(land, Vector2(spec.x, y), spec.y, int(spec.x))
	for stake in [Vector2(6528.0, 40.0), Vector2(6546.0, 28.0), Vector2(6950.0, 44.0)]:
		var base := Vector2(stake.x, _ground(art, stake.x) + 3.0)
		art._beam(land, base, base + Vector2(sin(stake.x) * 6.0, -stake.y), 4.4, stake.x)

# ------------------------------------------------------------------ dynamic ink

static func draw_dynamic(art) -> void:
	var cliff = art.level.cliff
	if cliff == null or not art._visible_x(6400.0, 1100.0):
		return
	_draw_bridge(art, cliff)
	_draw_lift(art, cliff)

static func _rope(canvas: Node2D, points: PackedVector2Array, width: float) -> void:
	canvas.draw_polyline(points, INK, width, true)

static func _sag(a: Vector2, b: Vector2, drop: float, wiggle: float = 0.0, phase: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var normal := (b - a).orthogonal().normalized()
	for i in range(13):
		var t := float(i) / 12.0
		pts.append(a.lerp(b, t) + Vector2(0.0, drop * sin(PI * t)) + normal * sin(t * 11.0 + phase) * wiggle * sin(PI * t))
	return pts

static func _draw_bridge(art, cliff) -> void:
	var dyn: Node2D = art.dyn
	var angle: float = cliff.bridge_angle
	var length := Cliff.BRIDGE_LENGTH
	dyn.draw_set_transform(Cliff.BRIDGE_HINGE + Vector2(0.0, -2.0), -angle)
	var thick := Cliff.BRIDGE_THICK
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	# While the deck takes weight it bows: every part of it follows the same dip curve.
	var dip: float = cliff.bridge_sag if cliff.bridge_state == Cliff.Bridge.DOWN else 0.0
	var stations := 18
	# Two stringers under the deck.
	for rail in [0.0, 1.0]:
		var ox := 8.0 if rail == 0.0 else 0.0
		var strip := PackedVector2Array()
		var x0 := ox + 8.0
		var x1 := length - 6.0 - ox * 0.5
		for n in range(stations + 1):
			var x := lerpf(x0, x1, float(n) / float(stations))
			strip.append(Vector2(x, thick - 1.0 + dip * sin(PI * x / length)))
		for n in range(stations, -1, -1):
			var x := lerpf(x0, x1, float(n) / float(stations))
			strip.append(Vector2(x, thick + 6.0 + rail * 2.0 + dip * sin(PI * x / length) - (4.0 if n == stations or n == 0 else 0.0)))
		dyn.draw_colored_polygon(strip, INK)
	# One continuous deck of planks laid edge to edge: a slightly notched top, no see-through rungs.
	var deck := PackedVector2Array()
	var count := 9
	var step := length / float(count)
	for i in range(count + 1):
		var x := minf(float(i) * step, length)
		deck.append(Vector2(x, rng.randf_range(-1.6, 0.2) + dip * sin(PI * x / length)))
		if i < count:
			var mx := x + step * 0.5
			deck.append(Vector2(mx, -0.4 + rng.randf_range(-0.8, 0.4) + dip * sin(PI * mx / length)))
	for n in range(stations, -1, -1):
		var x := length * float(n) / float(stations)
		deck.append(Vector2(x, thick + dip * sin(PI * x / length)))
	dyn.draw_colored_polygon(deck, INK)
	# Low rope railing on short posts, so it reads as a bridge and not a ladder.
	var post_x := [16.0, 96.0, 176.0, 246.0]
	var tops := PackedVector2Array()
	for px in post_x:
		var base_dip: float = dip * sin(PI * px / length)
		art._beam(dyn, Vector2(px, base_dip), Vector2(px + 0.5, -28.0 + base_dip), 4.0, px)
		tops.append(Vector2(px + 0.5, -27.0 + base_dip))
	dyn.draw_polyline(tops, INK, 2.0, true)
	# A heavy cross-beam at the tip, where the rope bites.
	dyn.draw_colored_polygon(PackedVector2Array([
		Vector2(length - 12.0, -5.0), Vector2(length + 5.0, -3.0), Vector2(length + 6.0, thick + 5.0), Vector2(length - 10.0, thick + 3.0),
	]), INK)
	# The loose end of the rope lies along the planks.
	if cliff.bridge_state != Cliff.Bridge.RAISED:
		var loose := PackedVector2Array()
		for k in range(10):
			var t := float(k) / 9.0
			var lx := length - 2.0 - t * 96.0
			loose.append(Vector2(lx, -3.0 - sin(t * 9.0) * 3.0 * t + dip * sin(PI * lx / length)))
		_rope(dyn, loose, 2.4)
	dyn.draw_set_transform(Vector2.ZERO)
	var tip: Vector2 = cliff.bridge_tip() + Vector2(0.0, -2.0)
	if cliff.bridge_state == Cliff.Bridge.RAISED:
		_rope(dyn, _sag(tip, Cliff.BRIDGE_ANCHOR, 4.0), 2.8)
	else:
		# The anchored half swings and settles.
		var hang := Cliff.BRIDGE_ANCHOR
		var swing: float = cliff.rope_swing
		var points := PackedVector2Array()
		for k in range(12):
			var t := float(k) / 11.0
			points.append(hang + Vector2(sin(swing * 0.9) * t * 112.0 + sin(t * 6.0 + swing * 4.0) * 3.0 * t, t * 112.0 * (1.0 - 0.06 * absf(swing))))
		_rope(dyn, points, 2.8)

static func _draw_lift(art, cliff) -> void:
	var dyn: Node2D = art.dyn
	var top: float = cliff.cage_top() + cliff.lift_shiver()
	var left := Cliff.LIFT_X
	var right := Cliff.LIFT_X + Cliff.LIFT_W
	var cx := (left + right) * 0.5
	var roof := top - 108.0
	# Deck: boards with a chipped front edge and iron straps hanging under it.
	dyn.draw_colored_polygon(PackedVector2Array([
		Vector2(left - 5.0, top + 1.0), Vector2(left + 24.0, top - 1.2), Vector2(left + 60.0, top - 0.6), Vector2(right - 6.0, top - 1.0), Vector2(right + 3.0, top + 2.0),
		Vector2(right + 2.0, top + 15.0), Vector2(right - 30.0, top + 17.0), Vector2(left + 28.0, top + 15.0), Vector2(left - 4.0, top + 14.0),
	]), INK)
	for strap in [left + 14.0, cx, right - 14.0]:
		art._beam(dyn, Vector2(strap, top + 12.0), Vector2(strap + 1.0, top + 30.0), 3.0, strap)
	# Rollers that ride the guide rail.
	dyn.draw_circle(Vector2(left - 3.0, top + 6.0), 5.0, INK, true, -1.0, true)
	dyn.draw_circle(Vector2(left - 3.0, roof + 10.0), 4.0, INK, true, -1.0, true)
	# Frame: two posts, a bowed roof beam and diagonal braces.
	art._beam(dyn, Vector2(left + 4.0, top), Vector2(left + 3.0, roof), 5.0, 1.0)
	art._beam(dyn, Vector2(right - 6.0, top), Vector2(right - 5.0, roof), 5.0, 2.0)
	art._beam(dyn, Vector2(left - 6.0, roof + 2.0), Vector2(right + 4.0, roof - 2.0), 5.4, 3.0)
	art._beam(dyn, Vector2(left + 4.0, top - 52.0), Vector2(left + 30.0, top - 8.0), 2.8, 4.0)
	art._beam(dyn, Vector2(right - 6.0, top - 48.0), Vector2(right - 34.0, top - 6.0), 2.8, 5.0)
	art._beam(dyn, Vector2(right - 6.0, top - 40.0), Vector2(right - 34.0, top - 40.0), 3.0, 6.0)
	# Hanger ropes meet above the roof and run up out of the picture.
	var join := Vector2(cx, roof - 34.0)
	_rope(dyn, PackedVector2Array([Vector2(left - 2.0, roof), join]), 2.2)
	_rope(dyn, PackedVector2Array([Vector2(right + 2.0, roof), join]), 2.2)
	_rope(dyn, PackedVector2Array([join, Vector2(cx + 1.0, join.y - 1800.0)]), 3.4)
	# The lever: a floor lever beside the right post. The stick is drawn through the player's hands
	# at the stand spot, so it is the thing their arms are closed on.
	var pivot := Vector2(Cliff.LIFT_X + Cliff.LIFT_W - 14.0, top - 2.0)
	var stand_x: float = Cliff.LIFT_X + Cliff.LIFT_W - 14.0 - 46.0
	var hand := Vector2(stand_x + 31.0 + 14.0 * float(cliff.lever_s), top - 16.0)
	if cliff.lever_hand_driven:
		hand = cliff.lever_hand_world  # the hooded boy: the stick goes through the point his hand is at
	var along: Vector2 = (hand - pivot).normalized()
	var tip: Vector2 = hand + along * 11.0 if cliff.lever_hand_driven else pivot + along * 54.0
	# The base plate is sunk into the deck boards, so the lever is bolted to the floor, not resting above it.
	dyn.draw_colored_polygon(PackedVector2Array([pivot + Vector2(-14.0, 6.0), pivot + Vector2(-10.0, -4.0), pivot + Vector2(-5.0, -7.0), pivot + Vector2(7.0, -7.0), pivot + Vector2(12.0, -4.0), pivot + Vector2(15.0, 6.0)]), INK)
	art._limb(dyn, [pivot, pivot.lerp(tip, 0.5), tip], [4.0, 3.3, 2.9])
	dyn.draw_circle(tip, 5.4, INK, true, -1.0, true)
	# The other end of the pulley rope runs down from the top of the picture to the ring on the slab.
	var ground: float = _ground(art, Cliff.STACK_X)
	var ring := Vector2(Cliff.STACK_X - 38.0, ground - Cliff.SLAB_H - 2.0)
	_rope(dyn, PackedVector2Array([Vector2(ring.x + 1.0, -1700.0), ring]), 3.2)
	# Rope that has slipped through the pin as the cage came down lies in a loose heap beside it.
	var piled: float = (Cliff.LIFT_TRAVEL - cliff.lift_s) / Cliff.LIFT_TRAVEL
	if piled > 0.02:
		var heap := PackedVector2Array()
		var span := 8.0 + 52.0 * piled
		for k in range(24):
			var t := float(k) / 23.0
			heap.append(Vector2(ring.x - t * span, ground - 2.0 - absf(sin(t * 11.0)) * (2.0 + 9.0 * piled) * (1.0 - t * 0.4)))
		_rope(dyn, heap, 3.0)

# ------------------------------------------------------------------ effects

static func draw_effects(art) -> void:
	var cliff = art.level.cliff
	if cliff == null:
		return
	var effects: Node2D = art.effects
	# Where the slope tops out it is lost in fog: the way on.
	if art._visible_x(Cliff.EXIT_X, 600.0):
		for k in range(6):
			var px := Cliff.EXIT_X - 70.0 + float(k) * 58.0 + sin(art.clock * 0.3 + float(k)) * 10.0
			var py := _ramp_y(px) - 40.0 - float(k % 3) * 24.0
			art._soft(effects, Vector2(px, py), Vector2(240.0 + float(k % 3) * 40.0, 120.0), Color(0.84, 0.84, 0.82, 0.12 + 0.05 * float(k)))
	if cliff.charging:
		_draw_preview(art, cliff)

static func _draw_preview(art, cliff) -> void:
	var effects: Node2D = art.effects
	var path: Dictionary = cliff.preview_path()
	var points: PackedVector2Array = path.points
	if points.size() < 2:
		return
	var ratio := clampf((cliff.hold - 0.18) / 0.82, 0.0, 1.0)
	if cliff.hold < 0.18:
		# Still a tap: nothing to aim yet.
		return
	# No line and no markers: a short trail of dark, soft motes that thin out with distance, like
	# grit shaken off the stone. It shows the way without looking like a drawn guide.
	var reach := mini(points.size() - 1, 4 + int(ratio * 34.0))
	var step := 3
	var shown := 0
	for dot in range(step, reach, step):
		var fade := 1.0 - float(dot) / float(reach + 4)
		var drift := Vector2(sin(art.clock * 2.1 + float(dot)) * 1.2, cos(art.clock * 1.7 + float(dot) * 1.3) * 1.2)
		var size := 6.0 + 3.0 * fade
		art._soft(effects, points[dot] + drift, Vector2(size * 1.6, size * 1.4), Color(0.05, 0.05, 0.05, (0.17 + 0.28 * ratio) * fade))
		shown += 1
	if bool(path.rope) and reach >= points.size() - 1:
		# Where it would hit the rope the air brightens a little.
		art._soft(effects, points[points.size() - 1], Vector2(34.0, 30.0), Color(0.9, 0.9, 0.88, 0.5))

# Impact dust and flying chips for the act's physical events.
static func react(art, delta: float) -> void:
	var cliff = art.level.cliff
	if cliff == null:
		return
	for event in cliff.take_events():
		var at: Vector2 = event.pos
		match String(event.kind):
			"bridge_thud":
				art._burst(at + Vector2(-90.0, 0.0), 22, 210.0, 70.0, 34.0, 0.5)
				art._burst(at + Vector2(-240.0, 0.0), 12, 150.0, 40.0, 28.0, 0.38)
				for n in range(12):
					art._chip(at + Vector2(-art.dust_rng.randf_range(0.0, 250.0), -2.0), Vector2(art.dust_rng.randf_range(-130.0, 130.0), -art.dust_rng.randf_range(60.0, 260.0)), art.dust_rng.randf_range(2.0, 4.6), art.dust_rng.randf_range(0.5, 1.0))
			"bridge_creak":
				var power := float(event.power)
				art._puff(at, Vector2(art.dust_rng.randf_range(-10.0, 10.0), art.dust_rng.randf_range(10.0, 40.0)), art.dust_rng.randf_range(8.0, 14.0) * (0.7 + power * 0.4), 0.8, 0.16 + 0.1 * power)
				for n in range(1 + int(power * 2.0)):
					art._chip(at + Vector2(art.dust_rng.randf_range(-14.0, 14.0), 0.0), Vector2(art.dust_rng.randf_range(-12.0, 12.0), art.dust_rng.randf_range(10.0, 50.0)), art.dust_rng.randf_range(1.2, 2.4), 0.9)
			"rope_snap":
				art._burst(at, 5, 40.0, 20.0, 10.0, 0.3)
				for n in range(6):
					art._chip(at, Vector2(art.dust_rng.randf_range(-120.0, 120.0), -art.dust_rng.randf_range(10.0, 120.0)), art.dust_rng.randf_range(1.2, 2.4), art.dust_rng.randf_range(0.4, 0.8))
			"twang":
				for n in range(3):
					art._chip(at, Vector2(art.dust_rng.randf_range(-60.0, 60.0), -art.dust_rng.randf_range(10.0, 60.0)), art.dust_rng.randf_range(1.0, 2.0), 0.5)
			"stone_hit":
				var power := float(event.power)
				art._burst(at, 3, 24.0, 14.0, 9.0 + power * 0.01, 0.22)
				for n in range(2):
					art._chip(at, Vector2(art.dust_rng.randf_range(-70.0, 70.0), -art.dust_rng.randf_range(20.0, 110.0)), art.dust_rng.randf_range(1.2, 2.4), 0.5)
			"stone_lost":
				art._burst(at, 6, 40.0, 16.0, 14.0, 0.25)
			"stack_pull":
				art._burst(at + Vector2(0.0, 18.0), 9, 50.0, 22.0, 15.0, 0.3)
				for n in range(7):
					art._chip(at + Vector2(art.dust_rng.randf_range(-18.0, 18.0), art.dust_rng.randf_range(-6.0, 12.0)), Vector2(art.dust_rng.randf_range(-70.0, 70.0), -art.dust_rng.randf_range(20.0, 130.0)), art.dust_rng.randf_range(1.4, 3.0), 0.7)
				# The rope groans through its pin: dust sifts off the cliff face beside the cage.
				for n in range(5):
					art._puff(Vector2(Cliff.CLIFF_X - 6.0, art.level.cliff.cage_top() + art.dust_rng.randf_range(-90.0, 10.0)), Vector2(art.dust_rng.randf_range(-20.0, 4.0), art.dust_rng.randf_range(30.0, 80.0)), art.dust_rng.randf_range(8.0, 14.0), 0.9, 0.2)
			"lever_pump":
				for n in range(5):
					art._chip(at + Vector2(art.dust_rng.randf_range(-12.0, 12.0), art.dust_rng.randf_range(-4.0, 8.0)), Vector2(art.dust_rng.randf_range(-40.0, 40.0), art.dust_rng.randf_range(10.0, 90.0)), art.dust_rng.randf_range(1.2, 2.4), 0.8)
			"lift_thud":
				var weight := float(event.power)
				art._burst(at, int(10 + 14 * weight), 140.0 * (0.5 + weight), 50.0, 28.0 * (0.6 + weight * 0.4), 0.42)
				for n in range(int(4 + 6 * weight)):
					art._chip(at + Vector2(art.dust_rng.randf_range(-40.0, 40.0), -4.0), Vector2(art.dust_rng.randf_range(-140.0, 140.0), -art.dust_rng.randf_range(50.0, 200.0)), art.dust_rng.randf_range(1.8, 4.0), art.dust_rng.randf_range(0.5, 1.0))
	# While the cage moves it scrapes the face: grit sifts down beside it.
	if absf(cliff.lift_speed) > 20.0:
		art.warn_dust_clock += delta
		if art.warn_dust_clock > 0.05:
			art.warn_dust_clock = 0.0
			var y: float = cliff.cage_top()
			art._puff(Vector2(Cliff.CLIFF_X - 4.0, y + art.dust_rng.randf_range(-70.0, 10.0)), Vector2(art.dust_rng.randf_range(-24.0, 6.0), art.dust_rng.randf_range(30.0, 90.0)), art.dust_rng.randf_range(8.0, 16.0), 0.9, 0.2)
			art._chip(Vector2(Cliff.CLIFF_X - 2.0, y + art.dust_rng.randf_range(-40.0, 10.0)), Vector2(art.dust_rng.randf_range(-40.0, -4.0), art.dust_rng.randf_range(20.0, 120.0)), art.dust_rng.randf_range(1.2, 2.6), 0.9)

# ------------------------------------------------------------------ the slope's front grass

# Like the slope that leads down into act one: a band of roots and dense, long blades planted along
# the ground and drawn in front of the player, so the climber's feet and shins are lost in it. The
# blades sway with the same shader as the rest of the grass.
static func draw_grass(art) -> void:
	var grass: Node2D = art.grass
	var rng := RandomNumberGenerator.new()
	rng.seed = 7312
	var x0 := Cliff.CLIFF_X + 16.0
	var x1 := Cliff.WORLD_END + 40.0
	var roots := PackedVector2Array()
	for sample in range(int(x0), int(x1) + 1, 4):
		var taper := smoothstep(0.0, 40.0, float(sample) - x0)
		roots.append(Vector2(sample, _ramp_y(sample) - 1.4 - 15.0 * taper - art.noise.get_noise_1d(float(sample) * 1.8) * 5.0 * taper))
	for sample in range(int(x1), int(x0) - 1, -4):
		roots.append(Vector2(sample, _ramp_y(sample) + 12.0))
	grass.draw_colored_polygon(roots, Color(0, 0, 0, 1))
	var x := x0
	while x < x1:
		var y := _ramp_y(x)
		var height := rng.randf_range(28.0, 40.0) * lerpf(0.15, 1.0, smoothstep(0.0, 40.0, x - x0))
		var lean := rng.randf_range(-10.0, 13.0)
		for offset in [-2.0, 2.0]:
			grass.draw_polygon(
				PackedVector2Array([Vector2(x + offset - 2.0, y + 5.0), Vector2(x + lean + offset * 2.0, y - height + absf(offset)), Vector2(x + offset + 2.0, y + 5.0)]),
				PackedColorArray([Color(0, 0, 0, 1), Color(1, 0, 0, 1), Color(0, 0, 0, 1)])
			)
		x += rng.randf_range(3.0, 6.0)
