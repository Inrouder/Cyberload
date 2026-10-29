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
 if game.base_nodes.size() != 9 or game.nodes.size() != 10:
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
 # The outer Red Zone security wall must be breached before the inner gate.
 game.state.clearance_level = 0
 game.zone_access = false
 game._start_red_zone_breach()
 if not game.breach_open or game.breach_target != "ZONE":
  _fail("Red Zone entry must initiate outer breach")
  return
 game._choose_code(Vector2(216,216))
 game._choose_code(Vector2(216,285))
 game._choose_code(Vector2(354,285))
 if game.breach_open or not game.zone_access or game.ice_open:
  _fail("Red Zone breach did not unlock only the outer gate")
  return
 game.player = Vector2(1490,550)
 game._interact()
 if not game.breach_open and game.world_mode != 1:
  _fail("ICE gateway cannot be used")
  return
 game._enter_homebase()
 game.base_player = Vector2(955,285)
 game._interact()
 if not game.node_open or game.base_nodes[game.selected_node]["kind"] != "FAB":
  _fail("Fabricator terminal cannot be opened")
  return
 game._node_action(0)
 if game.overlay_mode != "CRAFT":
  _fail("Fabricator does not open crafting UI")
  return
 game.overlay_mode = ""
 game.base_player = Vector2(485,845)
 game._interact()
 if not game.node_open or game.base_nodes[game.selected_node]["kind"] != "ARMORY":
  _fail("Armory terminal cannot be opened")
  return
 game._node_action(1)
 if not game.duel_active or game.duel.result != "RUNNING":
  _fail("Armory training duel cannot start")
  return
 print("CYBERLOAD WORLD SMOKE PASS: base, uplink, security wall, independent ICE gate, crafting, armory battle")
 game.queue_free()
 quit(0)

func _fail(message: String) -> void:
 push_error("CYBERLOAD WORLD SMOKE FAIL: "+message)
 quit(1)
