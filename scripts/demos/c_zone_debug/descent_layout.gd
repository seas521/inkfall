extends RefCounted

# Art layout in the SAME world as scene 1 and C. No puzzle/hazard simulation yet.
# Camera origins, not separate rooms: intermediate space is rendered continuously.
const SHOTS := [
	{"name": "崩塌后的栈道", "camera": Vector2(-3850, -4670), "feet": Vector2(-3255, -4170)},
	{"name": "风雨中的崖腹", "camera": Vector2(-3720, -3570), "feet": Vector2(-3170, -3030)},
	{"name": "废弃吊运站", "camera": Vector2(-3740, -2640), "feet": Vector2(-3220, -2120)},
	{"name": "落石斜廊", "camera": Vector2(-3410, -1360), "feet": Vector2(-2910, -810)},
	{"name": "崖脚蝙蝠洞", "camera": Vector2(-2260, -130), "feet": Vector2(-1680, 434)},
	{"name": "洞口 · C区雾岸", "camera": Vector2(-590, -100), "feet": Vector2(-190, 328)},
	{"name": "C区 · 原有河岸", "camera": Vector2(0, 0), "feet": Vector2(420, 550)},
]

# Camera rail for art review only; traversal collisions will be authored after art approval.
static func path(t: float) -> Vector2:
	var i := mini(int(t), SHOTS.size() - 2)
	var u := smoothstep(0.0, 1.0, clampf(t - float(i), 0.0, 1.0))
	return Vector2(SHOTS[i].camera).lerp(SHOTS[i + 1].camera, u)
