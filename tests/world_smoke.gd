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
 if game.base_nodes.size() != 9 or game.nodes.size() != 24:
  _fail("Homebase/Withnet terminal counts are incorrect")
  return
 if game.signal_mines.size() != 9 or game.red_zone.guards.size() != 21:
  _fail("New data cities / signal mines / bosses missing")
  return
 if game.net_walls.is_empty():
  _fail("Pixel architecture was not initialized")
  return
 var wall: Rect2 = game.net_walls[0]["rect"]
 if not game._world_wall_collision(wall.get_center()) or game._world_wall_collision(Vector2(800,550)):
  _fail("World wall collision or free central highway invalid")
  return
 game._toggle_dev_overkill()
 if not game.dev_overkill:
  _fail("Developer overkill cannot turn on")
  return
 game._toggle_dev_overkill()
 if game.dev_overkill:
  _fail("Developer overkill cannot turn off")
  return
 if game.open_world.veins.size() < 150 or game.open_world.portals.size()!=9:
  _fail("Open world resource and dungeon generation not initialized")
  return
 if not game._world_wall_collision(Vector2(2,1900)) or game._world_wall_collision(Vector2(5200,1750)):
  _fail("Outer perimeter wall or mining highway collision broken")
  return
 # The slow-motion button must never overlap the rhythm direction buttons
 # on either 720px or shorter wide-screen Android viewports.
 for height in [720,687]:
  var combat_view = Vector2(1280,height)
  if game._duel_slowmo_rect(combat_view).end.y >= game._duel_button_rect(3,combat_view).position.y:
   _fail("Slowmo control overlaps the right-direction button")
   return
 # Consoles must stay visible above the footer and below the top HUD.
 var view = Vector2(1280,720)
 var offset = game._base_camera_offset(view)
 for node in game.base_nodes:
  var screen_pos: Vector2 = node["pos"]-offset
  if screen_pos.x < 160 or screen_pos.x > view.x-160 or screen_pos.y < 195 or screen_pos.y > view.y-150:
   _fail("Homebase terminal is clipped: "+str(node["kind"]))
   return
 if game._duel_arrow_direction(0) != Vector2.UP or game._duel_arrow_direction(1) != Vector2.RIGHT or game._duel_arrow_direction(2) != Vector2.DOWN or game._duel_arrow_direction(3) != Vector2.LEFT:
  _fail("Netduel arrows do not match controls")
  return
 game.base_player = Vector2(885,500)
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
 # Playable dungeon entrance -> combat -> loot -> exit, independent of the
 # existing Darknet and firewall matrix sequence.
 game.player = game.open_world.portals[0]["pos"]
 game._interact()
 if game.world_mode != 3 or game.dungeon_id != 0 or game.dungeon.enemies.size() != 3:
  _fail("HACK cannot enter generated dungeon from world portal")
  return
 game.dungeon_player = game.dungeon.enemies[0]["pos"]
 game._update_dungeon(2.0)
 if not game.duel_active or not game.dungeon_duel:
  _fail("Dungeon sentinel does not trigger netduel")
  return
 game.duel.dev_overkill = true
 game.duel.tick(game.duel.time_until_hit(0))
 game.duel.press(game.duel.current_key())
 game._finish_duel()
 if game.duel_active or not game.dungeon.enemies[0]["defeated"]:
  _fail("Dungeon ICE victory was not processed")
  return
 game.dungeon_player = game.dungeon.exit_pos
 game._interact()
 if game.world_mode != 0 or game.dungeon_id != -1:
  _fail("Dungeon exit failed to return player to Withnet")
  return
 # Extract a nearby surface deposit and sell it at the first extractor.
 var vein: Dictionary = game.open_world.veins[0]
 game.player = vein["pos"]
 game.state.drill_level = int(vein["tier"])
 game.state.mined_veins.erase(str(vein["id"]))
 var before_ore: int = game.state.ore_total()
 game._interact()
 if game.state.ore_total() <= before_ore:
  _fail("World HACK did not extract mined ore")
  return
 game.player = Vector2(840,1320)
 game._interact()
 if not game.node_open or game.nodes[game.selected_node]["kind"] != "MINING_RIG":
  _fail("Mining extractor terminal cannot be opened")
  return
 var before_cr: int = game.state.credits
 game._node_action(1)
 if game.state.credits <= before_cr or game.state.ore_total() != 0:
  _fail("Mining station sale did not pay for ore cargo")
  return
 game.node_open = false
 game._enter_withnet()
 # The outer Red Zone security wall must be breached before the inner gate.
 game.state.clearance_level = 0
 game.zone_access = false
 game._start_red_zone_breach()
 if game.hack_targets.size() != 3 or _find_solution(game).size() != 3:
  _fail("Random breach missing valid code target")
  return
 var previous_signature: String = game.last_hack_signature
 game._init_matrix()
 if previous_signature == game.last_hack_signature or _find_solution(game).size() != 3:
  _fail("Repeat hacking puzzle was identical or unsolvable")
  return
 if not game.breach_open or game.breach_target != "ZONE":
  _fail("Red Zone entry must initiate outer breach")
  return
 var solution = _find_solution(game)
 if solution.size() != 3:
  _fail("Random firewall unsolvable")
  return
 for cell in solution:
  game._choose_code(Vector2(216+cell.x*69,216+cell.y*69))
 if game.breach_open or not game.zone_access or game.ice_open:
  _fail("Red Zone breach did not unlock only the outer gate")
  return
 game.player = Vector2(1490,550)
 game._interact()
 if not game.breach_open and game.world_mode != 1:
  _fail("ICE gateway cannot be used")
  return
 game._enter_homebase()
 game.base_player = Vector2(560,500)
 game._interact()
 if not game.node_open or game.base_nodes[game.selected_node]["kind"] != "FAB":
  _fail("Fabricator terminal cannot be opened")
  return
 game._node_action(0)
 if game.overlay_mode != "CRAFT":
  _fail("Fabricator does not open crafting UI")
  return
 game.overlay_mode = ""
 game.base_player = Vector2(560,760)
 game._interact()
 if not game.node_open or game.base_nodes[game.selected_node]["kind"] != "ARMORY":
  _fail("Armory terminal cannot be opened")
  return
 game._node_action(1)
 if not game.duel_active or game.duel.result != "RUNNING":
  _fail("Armory training duel cannot start")
  return
 print("CYBERLOAD WORLD SMOKE PASS: base, mega-world mining, dungeon combat and exit, security wall, crafting, armory")
 game.queue_free()
 quit(0)

func _fail(message: String) -> void:
 push_error("CYBERLOAD WORLD SMOKE FAIL: "+message)
 quit(1)

func _find_solution(game) -> Array:
 var target: Array = game.hack_targets[0]
 for x in range(5):
  if game.matrix[0][x] != target[0]:
   continue
  for y in range(1,5):
   if game.matrix[y][x] != target[1]:
    continue
   for z in range(5):
    if z != x and game.matrix[y][z] == target[2]:
     return [Vector2i(x,0),Vector2i(x,y),Vector2i(z,y)]
 return []
