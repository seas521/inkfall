extends "res://scripts/demos/c_zone_debug/route_softness_v35_capture.gd"
# Native visual/coverage review: no public debug-menu entry is added.
var failed:=false
var checks:=0
var output:="res://artifacts/chapter-player-plane-v54/review"
var timings:Array[float]=[]
const FOCUS=preload("res://scripts/art/valley_player_focus.gd")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failed=true;push_error(label)
 print("PASS " if ok else "FAIL ",label)
func capture(label:String)->void:
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var raw:=FileAccess.open(output+"/"+label+".linear",FileAccess.WRITE)
 raw.store_buffer(image.get_data());raw.close()
 var meta:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE)
 meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
 var mask_image:Image=level.art.valley_player_focus.mask_view.get_texture().get_image()
 mask_image.save_png(output+"/"+label+"-coverage.png")
func present(root_pose:bool=false)->void:
 if root_pose:route._present(0.)
 else:level._present(0.)
func settle(at:Vector2)->void:
 place(at)
 level.set_physics_process(true)
 await frames(28)
 level.set_physics_process(false)
 for i in 6:present(route.active);await frames(1)
func verify(label:String,region:StringName,root_pose:bool=false)->void:
 for i in 6:present(root_pose);await frames(1)
 var focus=level.art.valley_player_focus
 check(focus.enabled and focus.discovery_region==region,label+" uses the correct playing-plane region")
 check(is_equal_approx(float(level.actor.sprite.material.get_shader_parameter("gameplay_focus")),1.),label+" actor uses restrained source diffusion")
 check((level.actor.sprite.visibility_layer&FOCUS.MASK)!=0,label+" actor belongs to the coverage view")
 var bounds:Transform2D=level.get_canvas_transform()
 var actor_at:Vector2=bounds*level.actor.global_position
 var pixel:Vector2=actor_at/level.get_viewport_rect().size*Vector2(focus.mask_view.size)
 await RenderingServer.frame_post_draw
 var mask_image:Image=focus.mask_view.get_texture().get_image()
 var silhouette:=0.0
 for y in range(maxi(0,int(pixel.y)-24),mini(mask_image.get_height(),int(pixel.y)-6)):
  for x in range(maxi(0,int(pixel.x)-12),mini(mask_image.get_width(),int(pixel.x)+12)):
   silhouette=maxf(silhouette,mask_image.get_pixel(x,y).a)
 check(silhouette>.25,label+" mask contains the visible body above the floor")
 check(level.camera.zoom.x>=.899 and level.camera.zoom.x<=1.001,label+" keeps camera pullback within the authored optical range")
 await capture(label)
func walk(label:String,expected_region:StringName)->void:
 var start:Vector2=level.player.position
 level.set_physics_process(true);Input.action_press("move_right")
 for i in 45:
  await physics_frame
  timings.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.)
 Input.action_release("move_right")
 await frames(18);level.set_physics_process(false)
 check(level.player.position.x>start.x+15.,label+" remains responsive while focus is active")
 check(level.art.valley_player_focus.discovery_region==expected_region,label+" focus stays stable during traversal")
func run()->void:
 var high:=OS.get_environment("INKFALL_FOCUS_1080")=="1"
 if high:output+="-1080p"
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1920,1080) if high else Vector2i(1280,720)
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 await settle(Vector2(-6450,S.ground_top(-6450)))
 await verify("01-forest-clearing",&"forest")
 check(level.art.grass_art.get_parent()==level.art,"walkable grass uses the real world camera transform")
 check((level.art.grass_art.visibility_layer&FOCUS.MASK)!=0,"ground grass shares the playing-plane depth coverage")
 check((level.art.plates_mid.visibility_layer&FOCUS.MASK)==0,"distant upper forest stays outside gameplay coverage")
 var focal=level.art.valley_player_focus
 var original_position:Vector2=level.player.position
 var anchor_before:Vector2=focal.focus_anchor
 level.player.position.y-=55.
 for i in 4:focal.sync(true);await frames(1)
 check(absf(focal.focus_anchor.y-anchor_before.y)<1.,"ordinary jumps do not pump the activity focus vertically")
 level.player.position=original_position+Vector2(150,0)
 for i in 12:focal.sync(true);await frames(1)
 var focal_shift:float=focal.focus_anchor.x-anchor_before.x
 check(focal_shift>1. and focal_shift<149.,"the activity region follows horizontal movement gradually")
 level.player.position=original_position;focal._update_focus(&"forest",true)
 await walk("upper forest",&"forest")
 level.enter_root_cliff_test();level.set_physics_process(false)
 await verify("02-gorge",&"gorge",true)
 level.enter_mine_cart_pair_test()
 await settle(Vector2(70.,-3050.))
 await verify("03-mine-hoist",&"mine",true)
 var room=route.mine_trial.gap.art.pair_room
 check((room.scenery.far.visibility_layer&FOCUS.MASK)==0,"opaque mine background is excluded")
 check((route.art.mountain.visibility_layer&FOCUS.MASK)==0,"hidden exterior rock cannot focus the cave background")
 check((room.carts[0].front.visibility_layer&FOCUS.MASK)!=0 and (room.carts[1].front.visibility_layer&FOCUS.MASK)!=0,"both mine carts stay in focus away from the player")
 check((room.scenery.mechanisms.crown_wheel.visibility_layer&FOCUS.MASK)!=0,"hoist wheel and handles belong to the interaction plane")
 var mask:Image=level.art.valley_player_focus.mask_view.get_texture().get_image()
 # World point in the open air between the player and ceiling. No main-plane
 # object occupies it; a hidden opaque mountain used to fill this area.
 var air:Vector2=level.get_canvas_transform()*Vector2(100.,-3315.)/level.get_viewport_rect().size*Vector2(mask.get_size())
 check(mask.get_pixelv(Vector2i(air)).a<.05,"mine air is not mistaken for playing geometry")
 await walk("mine platform",&"mine")
 place(Vector2(1180.,room.TRACK_Y));route._present(0.)
 await verify("04-mine-relay",&"mine",true)
 level.enter_valley_test()
 await settle(Vector2(950.,level.ground_y(950.)))
 await verify("05-valley-light",&"valley")
 check((level.art.valley_depth.visibility_layer&FOCUS.MASK)==0,"distant valley forest retains authored defocus")
 await walk("valley bank",&"valley")
 await settle(Vector2(1600.,575.))
 await verify("06-water-and-boat",&"valley")
 await settle(Vector2(4200.,level.marsh_rock_surface_y(4200.)))
 await verify("07-valley-hill",&"valley")
 var saved_flags:int=level.actor.sprite.visibility_layer&~FOCUS.MASK
 level.hide();await frames(4)
 var film=get_nodes_in_group("film_look")[0]
 check(not level.art.valley_player_focus.enabled and level.art.valley_player_focus.mask_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden chapters stop rendering coverage")
 check(float(film.lens_material.get_shader_parameter("player_plane_focus"))==0.,"hiding the chapter releases film focus")
 check(float(level.actor.sprite.material.get_shader_parameter("gameplay_focus"))==0.,"hiding the chapter restores actor source settings")
 level.show();present();await frames(4)
 check(level.art.valley_player_focus.enabled,"re-entering the chapter restores coverage")
 var key:=InputEventKey.new();key.keycode=KEY_F10;key.pressed=true
 Input.parse_input_event(key);await frames(2)
 key=InputEventKey.new();key.keycode=KEY_F10;key.pressed=false
 Input.parse_input_event(key);await frames(2)
 check(film.visible,"F10 cannot bypass the final artwork")
 var helper=level.art.valley_player_focus
 helper._release_tags()
 check(level.actor.sprite.visibility_layer==saved_flags,"coverage cleanup preserves original visibility layers")
 timings.sort()
 var performance={"samples":timings.size(),"cpu_process_median_ms":timings[timings.size()/2],"cpu_process_p95_ms":timings[int(timings.size()*.95)],"resolution":str(root.size),"checks":checks,"failed":failed}
 var report_file:=FileAccess.open(output+"/result.json",FileAccess.WRITE);report_file.store_string(JSON.stringify(performance,"  "));report_file.close()
 print("CHAPTER PLAYER PLANE V54 ","FAIL" if failed else "PASS"," ",performance)
 level.queue_free();await frames(3);quit(1 if failed else 0)
