extends RefCounted

const SCREEN := Vector2(1280.0, 720.0)
const PLAYER_SIZE := Vector2(26.0, 54.0)

const GRAVITY := 1550.0
const RUN_SPEED := 285.0
const JUMP_SPEED := -590.0
const THROW_HOLD_THRESHOLD := 0.18
const THROW_MIN_SPEED := 620.0
const THROW_MAX_SPEED := 1240.0
const SHAFT_FATAL_FALL_SPEED := 920.0

const INK := Color("17191b")
const PAPER := Color("f4f3ed")
const PALE := Color("d8d8d2")
const MID := Color("8a8c89")
const WATER := Color("22b8cb")
const WATER_PALE := Color("8ce6eb")
const GAS := Color("73d13d")
const FIRE := Color("ff7a2f")
const HEMP := Color("b88955")
const HEMP_LIGHT := Color("dfbd86")
const GOLD := Color("f2c94c")
const GOLD_LIGHT := Color("ffe59a")

const CELLAR_KEY_COLOR := Color("f2c94c")
const CELLAR_STONE_COLOR := Color("c9cbc6")
const CELLAR_BG := Color("080b0c")
const CELLAR_WALL := Color("222729")
const CELLAR_LINE := Color("bfc5c0")
