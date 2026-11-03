extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func report(values: Array[int]) -> Dictionary:
 if values.is_empty():return {"count":0}
 values.sort()
 var sum: int=0
 for value in values:sum+=value
 return {"count":values.size(),"mean_us":float(sum)/values.size(),"p95_us":values[int(values.size()*0.95)],"max_us":values.back()}
func run() -> void:
 var game=load("res://tools/profile_open_world.gd").new()
 root.add_child(game)
 game._enter_withnet()
 game.player=game.open_world.find_clear(Vector2(2450,1150))
 game.zone_access=true
 game.guard_cooldown=10000
 game.signal_mines.clear()
 game.set_physics_process(false)
 for i in range(600):
  if i==200:game.player=game.open_world.find_clear(Vector2(6200,2200))
  if i==400:game.player=game.open_world.find_clear(Vector2(4900,1150))
  game._mesh_update(1.0/60.0)
  game.runner_mesh.set_motion(150,1.0/60.0)
  await process_frame
 print(JSON.stringify({"draw":report(game.draws),"ai_and_shots":report(game.meshes),"process":report(game.processes)}))
 game.queue_free()
 await process_frame
 quit()
