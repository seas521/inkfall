extends SceneTree

const Manifest = preload("res://scripts/actors/crooked_tower_vector_manifest.gd")

const OUTPUT_DIR := "res://assets/art/actors/crooked_tower_vector/review"
const CELL_SCALE := 0.68
const CELL_WIDTH := 142
const ROW_HEIGHT := 148
const LABEL_WIDTH := 168
const HEADER_HEIGHT := 54

const SHEETS: Array[Dictionary] = [
	{
		"name": "01-locomotion",
		"title": "Locomotion",
		"clips": [&"idle", &"start", &"walk", &"stop", &"turn", &"takeoff", &"rise", &"apex", &"fall", &"land"],
	},
	{
		"name": "02-throwing",
		"title": "Pickup / Carry / Throw",
		"clips": [&"pickup", &"carry", &"carry_walk", &"put_down", &"throw_charge", &"throw_release"],
	},
	{
		"name": "03-shield",
		"title": "Shield",
		"clips": [&"shield_equip", &"shield_ready", &"shield_walk", &"shield_raise", &"shield_guard", &"shield_lower", &"shield_parry", &"shield_block"],
	},
	{
		"name": "04-blade",
		"title": "Blade",
		"clips": [&"blade_equip", &"blade_ready", &"blade_walk", &"blade_swing"],
	},
	{
		"name": "05-push",
		"title": "Heavy Push",
		"clips": [&"push_engage", &"push", &"push_release"],
	},
	{
		"name": "06-hit-failure",
		"title": "Hit / Failure",
		"clips": [&"hit", &"failure"],
	},
]

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for sheet in SHEETS:
		_build_sheet(sheet)
	quit(0)

func _build_sheet(sheet: Dictionary) -> void:
	var clips: Array = sheet["clips"]
	var max_frames := 1
	for clip in clips:
		max_frames = maxi(max_frames, int(Manifest.CLIPS[clip]["frames"]))
	var width := LABEL_WIDTH + max_frames * CELL_WIDTH + 20
	var height := HEADER_HEIGHT + clips.size() * ROW_HEIGHT + 18
	var content := """<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">
<rect width="%d" height="%d" fill="#606466"/>
<text x="24" y="34" fill="#f0a64a" font-family="sans-serif" font-size="22" font-weight="600">%s</text>
<text x="%d" y="34" fill="#d9dcdb" font-family="sans-serif" font-size="13">192x192 per frame · root (96,174) · untrimmed SVG</text>
""" % [width, height, width, height, width, height, String(sheet["title"]), width - 430]
	for row_index in range(clips.size()):
		var clip: StringName = clips[row_index]
		var metadata: Dictionary = Manifest.CLIPS[clip]
		var frame_count := int(metadata["frames"])
		var row_y := HEADER_HEIGHT + row_index * ROW_HEIGHT
		content += "<text x=\"18\" y=\"%d\" fill=\"#f2f3f2\" font-family=\"monospace\" font-size=\"15\">%s</text>\n" % [
			row_y + 70,
			String(clip),
		]
		content += "<text x=\"18\" y=\"%d\" fill=\"#c1c5c3\" font-family=\"sans-serif\" font-size=\"11\">%d frames · %.0f fps</text>\n" % [
			row_y + 90,
			frame_count,
			float(metadata["fps"]),
		]
		for frame_index in range(frame_count):
			var cell_x := LABEL_WIDTH + frame_index * CELL_WIDTH
			content += "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"#707577\" stroke=\"#858a8b\" stroke-width=\"1\"/>\n" % [
				cell_x,
				row_y,
				CELL_WIDTH - 4,
				ROW_HEIGHT - 6,
			]
			content += "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"#9a7a4e\" stroke-width=\"1\" opacity=\"0.55\"/>\n" % [
				cell_x + 4,
				row_y + int(Manifest.ROOT.y * CELL_SCALE),
				cell_x + CELL_WIDTH - 8,
				row_y + int(Manifest.ROOT.y * CELL_SCALE),
			]
			content += "<text x=\"%d\" y=\"%d\" fill=\"#d1d4d2\" font-family=\"monospace\" font-size=\"10\">%02d</text>\n" % [
				cell_x + 5,
				row_y + 13,
				frame_index,
			]
			var frame_content := _frame_inner_svg(Manifest.frame_path(clip, frame_index))
			content += "<g transform=\"translate(%d %d) scale(%.3f)\">%s</g>\n" % [
				cell_x + 4,
				row_y + 4,
				CELL_SCALE,
				frame_content,
			]
	content += "</svg>\n"
	var output_path := "%s/%s.svg" % [OUTPUT_DIR, String(sheet["name"])]
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(content)
	print("Built review sheet ", output_path)

func _frame_inner_svg(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var source := file.get_as_text()
	var opening_end := source.find(">")
	var closing_start := source.rfind("</svg>")
	if opening_end < 0 or closing_start < 0:
		return ""
	return source.substr(opening_end + 1, closing_start - opening_end - 1)
