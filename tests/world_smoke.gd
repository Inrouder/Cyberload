extends SceneTree
## Deterministic integration checks for Homebase -> Withnet -> Homebase.
## Run using: godot --headless --path . --script res://tests/world_smoke.gd

func _initialize() -> void:
 call_deferred("_run_checks")

func _run_checks() -> void:
 var scene: PackedScene = load("res://scenes/main.tscn")
 if scene == null:
  _fail("Main scene could not be loaded")
  return
 var game: Variant = scene.instantiate()
 root.add_child(game)
 await process_frame
 if game.world_mode != 2:
  _fail("Player must start in the private Homebase")
  return
 if game.base_nodes.size() != 5 or game.nodes.size() != 8:
  _fail("Homebase/Withnet terminal counts are incorrect")
  return
 game.base_player = Vector2(1090,460)
 game._interact()
 if not game.node_open or game.selected_node != 0:
  _fail("Uplink console cannot be opened")
  return
 game._node_action(0)
 if game.world_mode != 0:
  _fail("Uplink console does not enter Withnet")
  return
 game.player = Vector2(175,550)
 game._interact()
 if game.world_mode != 2:
  _fail("Withnet Homebase portal does not return home")
  return
 game._enter_withnet()
 game.player = Vector2(1490,550)
 game._interact()
 if not game.breach_open and game.world_mode != 1:
  _fail("ICE gateway cannot be used")
  return
 print("CYBERLOAD WORLD SMOKE PASS: base spawn, uplink, public map, return portal, ICE entry")
 game.queue_free()
 quit(0)

func _fail(message: String) -> void:
 push_error("CYBERLOAD WORLD SMOKE FAIL: "+message)
 quit(1)
