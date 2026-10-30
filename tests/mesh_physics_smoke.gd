extends SceneTree
const Game = preload("res://scripts/main.gd")

func _initialize() -> void:
 call_deferred("_test")

func fail(message: String) -> void:
 push_error("CYBERLOAD MESH PHYSICS FAIL: "+message)
 quit(1)

func _test() -> void:
 var game=Game.new()
 get_root().add_child(game)
 game._enter_withnet()
 var start: Vector2=Vector2(940.0,1750.0)
 game.player=start
 game.mesh_velocity=Vector2.ZERO
 game._mesh_physics_move(Vector2.RIGHT,0.016)
 if game.player.x<=start.x or game.mesh_velocity.length()<=0.0:
  fail("Acceleration did not move runner")
  return
 var initial_speed: float=game.mesh_velocity.length()
 game._mesh_physics_move(Vector2.RIGHT,0.016)
 if game.mesh_velocity.length()<=initial_speed:
  fail("Acceleration did not ramp up")
  return
 var heading_before: float=game.mesh_heading
 for i in range(30):
  game._mesh_physics_move(Vector2.DOWN,0.016)
 if absf(wrapf(game.mesh_heading-PI/2.0,-PI,PI)) >= absf(wrapf(heading_before-PI/2.0,-PI,PI)):
  fail("Mesh heading does not follow actual travel")
  return
 for i in range(80):
  game._mesh_physics_move(Vector2.ZERO,0.016)
 if game.mesh_velocity.length()>1.5:
  fail("Runner drifts indefinitely with no joystick input")
  return
 game.player=Vector2(81.0,1850.0)
 game.mesh_velocity=Vector2(-330.0,0.0)
 for i in range(12):
  game._mesh_physics_move(Vector2.LEFT,0.016)
 if game.player.x<64.0:
  fail("Physical world perimeter was penetrated")
  return
 game.runner_mesh.mode="SWIM"
 var water_speed: float=game.runner_mesh.travel_multiplier(true)
 game.runner_mesh.mode="CRAWL"
 if water_speed<=game.runner_mesh.travel_multiplier(true):
  fail("Swimmer has no movement advantage in liquid data")
  return
 print("CYBERLOAD MESH PHYSICS PASS: acceleration, heading, drag, walls and swim")
 quit(0)
