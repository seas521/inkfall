extends CanvasLayer

const COVER_TIME := 0.75
const REVEAL_TIME := 0.90
const DURATION := 2.40

var elapsed := 0.0
var veil: ColorRect
var top_bar: ColorRect
var bottom_bar: ColorRect

func _ready() -> void:
	layer = 100
	veil = _panel(Control.PRESET_FULL_RECT)
	top_bar = _panel(Control.PRESET_TOP_WIDE)
	bottom_bar = _panel(Control.PRESET_BOTTOM_WIDE)
	advance(0.0)

func _panel(preset: int) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = Color.BLACK
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(preset)
	add_child(panel)
	return panel

func advance(delta: float) -> void:
	elapsed += delta
	var cover := smoothstep(0.08, COVER_TIME, elapsed)
	var reveal := smoothstep(REVEAL_TIME, 1.75, elapsed)
	veil.color.a = cover * (1.0-reveal)
	var bars := 34.0*smoothstep(0.0,0.45,elapsed)*(1.0-smoothstep(1.65,DURATION,elapsed))
	top_bar.offset_bottom = bars
	bottom_bar.offset_top = -bars
