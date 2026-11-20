extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var baseline_scripts:Array=[]
func _initialize()->void:
 # Load the exact rollback sources into the isolated review process only.
 # Production files are never overwritten to compare pre-existing outcomes.
 for name in ["mine_cart_relay.gd","mine_cart_pair_room.gd"]:
  var script:=GDScript.new()
  script.source_code=FileAccess.get_file_as_string("res://artifacts/mine-ramp-rollback-v16/before/scripts/chapters/"+name)
  if script.reload()!=OK:quit(2);return
  script.take_over_path("res://scripts/chapters/"+name);baseline_scripts.append(script)
 call_deferred("run")
