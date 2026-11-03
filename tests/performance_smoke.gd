extends SceneTree
const Game = preload("res://scripts/main.gd")
const Brain = preload("res://scripts/ambush_ai.gd")

func _initialize() -> void:
 call_deferred("_run")

func check(condition: bool,message: String) -> bool:
 if not condition:
  push_error("CYBERLOAD PERFORMANCE FAIL: "+message)
  quit(1)
 return condition

func _run() -> void:
 var game=Game.new()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game._enter_withnet()
 game.player=game.open_world.find_clear(Vector2(2450,1150))
 game.camera_follow=game.player
 game.camera_mode=0
 for i in range(4):
  game.queue_redraw()
  await process_frame
 var backdrop=game.world_backdrop
 var initial: int=backdrop.rebuilds()
 if not check(initial>0 and backdrop.chunks.size()<=150,"Static chunks were not built with a bounded spatial grid"):return
 var covered: int=0
 for layers in backdrop.chunks.values():
  for layer in layers:
   if layer.layer==2:covered+=layer.buildings.size()
 if not check(covered==game.open_world.walls.size(),"Chunking lost or duplicated buildings"):return
 var minimap_id: int=game.minimap_texture.get_instance_id()
 if not check(game.minimap_texture.get_width()==213 and game.minimap_texture.get_height()==105,"Radar cache is not a small fixed texture"):return
 for i in range(25):
  game.elapsed+=1.0/60
  game.queue_redraw()
  await process_frame
 if not check(backdrop.rebuilds()==initial,"Stationary world rebuilt static architecture every frame"):return
 if not check(game.minimap_texture.get_instance_id()==minimap_id,"Radar geometry was re-uploaded every frame"):return
 game.camera_follow+=Vector2(1536,0)
 for i in range(3):
  game.queue_redraw()
  await process_frame
 if not check(backdrop.rebuilds()>initial and backdrop.active.size()<backdrop.chunks.size()/2,"Camera did not load local chunks and cull distant chunks"):return
 game._enter_homebase()
 game.queue_redraw()
 await process_frame
 if not check(not backdrop.visible,"World cache covers the homebase"):return
 game._enter_withnet()
 game.breach_open=true
 game.queue_redraw()
 await process_frame
 if not check(not backdrop.visible,"World cache covers the breach UI"):return
 game.breach_open=false
 # Repath requests must remain bounded when many enemies wake together.
 var world: RefCounted=game.open_world
 var brain=Brain.new()
 var target=Vector2(2450,1750)
 var actors: Array=[]
 for i in range(24):
  var actor={"pos":Vector2(2750,1750),"rank":1,"boss":false,"timer":20.0}
  brain.prepare(actor,i,world)
  actor["pos"]=Vector2(2750,1750)
  actor["origin"]=actor["pos"]
  actor["ai"]="HUNT"
  actor["target"]=target
  actor["memory"]=7.0
  actor["visible"]=true
  actor["sight_delay"]=2.0
  actor["repath"]=0.0
  actors.append(actor)
 for tick in range(24):
  brain.begin_frame()
  for actor in actors:brain.update_enemy(actor,target,1.0/60,world)
  if not check(brain.path_queries<=1,"Simultaneous path searches exceeded the frame budget"):return
 for actor in actors:
  if not check(float(actor["repath"])>0,"Path-search budget starved an enemy"):return
 # Perception can be cached; a shot must still check the current cover immediately.
 var wall_found: bool=false
 for wall in world.walls:
  var rect: Rect2=wall["rect"]
  var left=Vector2(rect.position.x-25,rect.get_center().y)
  var right=Vector2(rect.end.x+25,rect.get_center().y)
  if left.distance_to(right)>420 or world.is_blocked(left) or world.is_blocked(right):continue
  var actor={"pos":left,"rank":1,"boss":false,"timer":0.0}
  brain.prepare(actor,1,world)
  actor["pos"]=left
  actor["origin"]=left
  actor["visible"]=true
  actor["sight_delay"]=2.0
  actor["ai"]="HUNT"
  actor["memory"]=7.0
  actor["repath"]=2.0
  if not check(not brain.update_enemy(actor,right,0.016,world),"Cached sight allowed a shot through a wall"):return
  wall_found=true
  break
 if not check(wall_found,"Cover scenario could not be constructed"):return
 # Rebuilding a body after editing must refresh its cached structural links.
 var form=game.runner_mesh
 form.setup_saved([],"CRAWL",5)
 form.cache_draw_links()
 var links: int=form.draw_links.size()
 if not check(form.add_block(Vector2i(0,1),"HULL") and form.draw_topology_dirty,"Mesh editor did not invalidate topology"):return
 form.cache_draw_links()
 if not check(form.draw_links.size()>links,"New mesh block has no structural link"):return
 game.queue_free()
 await process_frame
 call_deferred("_finish")

func _finish() -> void:
 print("CYBERLOAD PERFORMANCE PASS: retained chunks, stable radar, camera/mode transitions, bounded fair pathfinding and immediate firing cover")
 quit(0)
