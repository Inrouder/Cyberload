extends SceneTree
const World = preload("res://scripts/open_world.gd")
const Dungeon = preload("res://scripts/dungeon_instance.gd")
const Brain = preload("res://scripts/ambush_ai.gd")
const Game = preload("res://scripts/main.gd")

func _initialize() -> void:
 call_deferred("_run")

func _check(condition: bool,message: String) -> bool:
 if not condition:
  push_error("CYBERLOAD DATAVERSE FAIL: "+message)
  quit(1)
 return condition

func _cell(pos: Vector2) -> Vector2i:
 return Vector2i(floor(pos.x/Dungeon.TILE),floor(pos.y/Dungeon.TILE))

func _run() -> void:
 var fingerprints: Dictionary={}
 # Every floor and objective must connect, not merely have one clear tile around it.
 for seed_value in range(200):
  var dungeon=Dungeon.new()
  dungeon.setup(seed_value%9,false,seed_value*719+31)
  var connected: Dictionary=dungeon.reachable_cells(dungeon.spawn)
  if not _check(connected.size()==dungeon.floors.size(),"Disconnected dungeon, seed %d" % dungeon.layout_seed): return
  if not _check(connected.has(_cell(dungeon.boss_pos)) and not dungeon.is_blocked(dungeon.boss_pos),"Boss unreachable"): return
  var cache_positions: Dictionary={}
  for cache in dungeon.caches:
   var at: Vector2=cache["pos"]
   if not _check(connected.has(_cell(at)) and not dungeon.is_blocked(at),"Cache unreachable"): return
   cache_positions[at]=true
  if not _check(cache_positions.size()==3,"Caches overlap"): return
  if not _check(not dungeon.find_route(dungeon.spawn,dungeon.boss_pos).is_empty(),"Boss route missing"): return
  fingerprints[str(dungeon.floors)]=true
  var same=Dungeon.new()
  same.setup(seed_value%9,false,seed_value*719+31)
  if not _check(str(same.floors)==str(dungeon.floors),"Explicit seed is not reproducible"): return
 if not _check(fingerprints.size()==200,"Layout variation is insufficient"): return
 var fresh=Dungeon.new()
 fresh.setup(0)
 var previous: int=fresh.layout_seed
 fresh.setup(0)
 if not _check(previous!=fresh.layout_seed,"Re-entry reused its random seed"): return
 var game=Game.new()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game._enter_withnet()
 var world: RefCounted=game.open_world
 for objective in game.nodes+world.portals:
  var at: Vector2=objective["pos"]
  if not _check(not world.is_blocked(at),"Objective inside architecture"): return
  var route: PackedVector2Array=world.find_route(Vector2(325,550),at)
  if not _check(not route.is_empty(),"World objective disconnected: "+str(at)): return
  var previous_waypoint=Vector2(325,550)
  for waypoint in route:
   if not _check(world.segment_clear(previous_waypoint,waypoint),"Navigation crosses architecture at "+str(waypoint)): return
   previous_waypoint=waypoint
 # All ore and enemies must spawn on collision-free ground.
 for vein in world.veins:
  if not _check(not world.is_blocked(vein["pos"]),"Ore is inside a building"): return
 for enemy in game.mesh_enemies:
  if not _check(not world.is_blocked(enemy["pos"]),"Mesh spawned in a wall"): return
 # The same mapped liquid area powers both drawing and movement rules.
 if not _check(world.is_liquid(world.canals[0].get_center()) and not world.is_liquid(Vector2(325,550)),"Liquid surface mismatch"): return
 # Warning cannot immediately damage a player; a trap can fire only once and expires.
 var brain=Brain.new()
 var enemy={"pos":Vector2(800,550),"rank":1,"boss":false,"timer":0.0}
 brain.prepare(enemy,0,world)
 enemy["pos"]=Vector2(800,550)
 enemy["origin"]=enemy["pos"]
 if not _check(not brain.update_enemy(enemy,Vector2(850,550),0.016,world) and enemy["ai"]=="WARNING","Ambush has no readable warning"): return
 brain.update_enemy(enemy,Vector2(850,550),1.0,world)
 if not _check(brain.traps.size()==1 and not brain.update_traps(0.1,enemy["pos"]),"Trap armed without delay"): return
 if not _check(brain.update_traps(1.0,enemy["pos"]) and not brain.update_traps(0.01,enemy["pos"]),"Snare is not one-shot"): return
 brain.update_traps(8.0,enemy["pos"])
 if not _check(brain.traps.is_empty(),"Expired trap remains active"): return
 # A projectile cannot reach an enemy or player through any building.
 var wall: Rect2=world.walls[0]["rect"]
 var left=Vector2(wall.position.x-30,wall.get_center().y)
 var right=Vector2(wall.end.x+30,wall.get_center().y)
 if not _check(not world.segment_clear(left,right),"Shot tunneled through architecture"): return
 # Deterministic short integration: 30Hz and 120Hz must agree closely.
 game.player=Vector2(400,550)
 game.mesh_velocity=Vector2.ZERO
 game.zone_access=true
 for i in range(30): game._mesh_physics_move(Vector2.RIGHT,1.0/30)
 var slow_position: Vector2=game.player
 game.player=Vector2(400,550)
 game.mesh_velocity=Vector2.ZERO
 for i in range(120): game._mesh_physics_move(Vector2.RIGHT,1.0/120)
 if not _check(game.player.distance_to(slow_position)<1.0,"Frame rate changes travel distance"): return
 # Locomotion must animate in the base and random dungeon as well as Withnet.
 game._enter_dungeon(0)
 var position: Vector2=game.dungeon_player
 var desired=Vector2.RIGHT
 if game.dungeon.is_blocked(position+desired*40): desired=Vector2.DOWN
 game._mesh_physics_move(desired,0.1)
 game.runner_mesh.set_motion(game.dungeon_player.distance_to(position)/0.1,0.1)
 if not _check(game.runner_mesh.movement_blend>0,"Dungeon locomotion frozen"): return
 # The old protected Darknet gate also creates a fresh map, with three reachable packets.
 var dark_seed: int=game.dark_dungeon.layout_seed
 game._reset_darknet()
 if not _check(dark_seed!=game.dark_dungeon.layout_seed and game.dark_packets.size()==3,"Darknet still uses a static labyrinth"): return
 var dark_connected: Dictionary=game.dark_dungeon.reachable_cells(game.dark_player)
 for packet in game.dark_packets:
  if not _check(dark_connected.has(_cell(packet)),"Darknet packet unreachable"): return
 # Previously earned dungeon slots stay consumed across layout regeneration.
 game.state.dungeon_caches["0:0"]=true
 var credits_before: int=game.state.credits
 game.dungeon_id=0
 game.dungeon_player=game.dungeon.caches[0]["pos"]
 game._dungeon_interact()
 if not _check(game.state.credits==credits_before,"Randomization duplicated a claimed cache reward"): return
 game.queue_free()
 await process_frame
 call_deferred("_finish")

func _finish() -> void:
 print("CYBERLOAD DATAVERSE PASS: 200 connected layouts, objectives, random re-entry, cover, warnings, traps, 30/120Hz physics, Darknet and saved rewards")
 quit(0)
