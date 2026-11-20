extends "res://scripts/demos/c_zone_debug/cliff_visibility_v36_review.gd"
func run()->void:
 phase="diagnostic"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(20)
 level.debug_enter_rope_ladder(false);await frames(5);Input.action_press("climb_down");await frames(580);Input.action_release("climb_down")
 level.set_physics_process(false);await shot("00-baseline")
 for item in [["14-no-mine-art",level.bridge_to_c.art],["15-no-mine-trial",level.bridge_to_c.mine_trial],["16-no-shaft",level.bridge_to_c.shaft],["17-no-first-tree",level.bridge_to_c.trees[0]],["18-no-second-tree",level.bridge_to_c.trees[1]],["19-no-third-tree",level.bridge_to_c.trees[2]],["20-no-rope",level.bridge_to_c.swing_rope]]:
  var node=item[1];var was:bool=node.visible;node.hide();await frames(3);await shot(item[0]);node.visible=was
 print("SHADOW ISOLATION COMPLETE");quit()
