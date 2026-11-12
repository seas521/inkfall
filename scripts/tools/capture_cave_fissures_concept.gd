extends "res://scripts/tools/capture_long_cave_concept.gd"
# Static design only. Four actors denote four moments, not four players.
var moments:Array[Dictionary]=[
	{"feet":Vector2(436,739),"clip":&"low_enter","frame":22,"title":"01 / ENTRY"},
	{"feet":Vector2(775,704),"clip":&"low_walk","frame":6,"title":"02 / FIRST FISSURE"},
	{"feet":Vector2(1215,698),"clip":&"low_walk","frame":17,"title":"03 / SECOND FISSURE"},
	{"feet":Vector2(1760,718),"clip":&"low_walk","frame":10,"title":"04 / EXIT"}
]
func run()->void:
	background=ImageTexture.create_from_image(Image.load_from_file(OUT+"long-passage-v3-fissures-environment.png"))
	factor=2304.0/background.get_width()
	await new_canvas(Vector2i(2304,1024))
	plate(stage)
	for moment:Dictionary in moments:actor_at(stage,moment.feet,moment.clip,moment.frame)
	plate(stage,true)
	await save("long-passage-v3-fissures-actors")
	await new_canvas(Vector2i(1600,920))
	var backdrop:=ColorRect.new();backdrop.size=Vector2(1600,920);backdrop.color=Color(.035,.035,.035)
	stage.add_child(backdrop)
	for i in 4:
		var moment:Dictionary=moments[i]
		var view:=SubViewport.new();view.size=Vector2i(792,398)
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		canvas.add_child(view)
		var local:=Node2D.new();view.add_child(local)
		local.scale=Vector2.ONE*2.3
		local.position=Vector2(365,318)-Vector2(moment.feet)*2.3
		plate(local)
		actor_at(local,moment.feet,moment.clip,moment.frame)
		plate(local,true)
		var image:=Sprite2D.new();image.texture=view.get_texture();image.centered=false
		image.position=Vector2((i%2)*808,(i/2)*455);stage.add_child(image)
		label_at(moment.title+" / existing "+String(moment.clip),image.position+Vector2(20,405),20)
	await save("long-passage-v3-fissures-details")
	print("CONCEPT ONLY: actor visual_scale remains 0.90; main level untouched")
	quit()
