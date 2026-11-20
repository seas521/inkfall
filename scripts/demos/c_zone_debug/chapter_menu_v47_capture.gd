extends SceneTree
var main
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func press(action:String)->void:
 Input.action_press(action);await frames(2);Input.action_release(action);await frames(2)
func snap(label:String)->void:
 await frames(24);await RenderingServer.frame_post_draw
 var folder="res://artifacts/chapter-entry-menu-v47/native";DirAccess.make_dir_recursive_absolute(folder)
 var im=root.get_texture().get_image()
 var f=FileAccess.open(folder+"/"+label+".linear",FileAccess.WRITE);f.store_buffer(im.get_data());f.close()
 f=FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));f.close()
func run()->void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 main=load("res://scenes/main.tscn").instantiate();main.debug_start_level=0;root.add_child(main);await frames(10)
 DisplayServer.window_set_title("Inkfall · 第一章与测试入口")
 if OS.get_environment("INKFALL_MENU_PREVIEW")=="play":print("CHAPTER MENU V47 PLAY READY");return
 await snap("01-menu-chapter")
 await press("ui_accept");await snap("02-full-chapter")
 await press("ui_cancel");await press("ui_down");await snap("03-menu-ladder")
 await press("ui_accept");await snap("04-ladder-test")
 await press("ui_cancel");await press("ui_down");await snap("05-menu-valley")
 await press("ui_accept");await snap("06-valley-entry")
 await press("ui_cancel");await snap("07-return-selected-valley")
 print("CHAPTER MENU V47 NATIVE CAPTURE COMPLETE");quit()
