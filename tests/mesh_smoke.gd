extends SceneTree
const MeshBlueprint = preload("res://scripts/mesh_creature.gd")
func _initialize() -> void:
 call_deferred("_check")
func _fail(message: String) -> void:
 push_error("CYBERLOAD MESH TEST FAIL: "+message)
 quit(1)
func _check() -> void:
 var crawler=MeshBlueprint.new()
 crawler.setup_saved([],"CRAWL",1)
 if crawler.cells.size()!=3 or crawler.capacity()!=5:
  _fail("Starter or block capacity invalid")
  return
 if crawler.add_block(Vector2i(5,5),"GUN") or crawler.add_block(Vector2i(0,0),"HULL"):
  _fail("Detached or occupied block was accepted")
  return
 if not crawler.add_block(Vector2i(2,0),"GUN"):
  _fail("Adjacent weapon cannot be attached")
  return
 if crawler.remove_block(Vector2i(0,0)) or not crawler.remove_block(Vector2i(2,0)):
  _fail("Core protection or segment removal broken")
  return
 if not crawler.stats().has("damage") or crawler.stats()["hp"]<=0.0:
  _fail("Modular stats missing")
  return
 crawler.level=10
 if crawler.capacity()<=5:
  _fail("Mesh level did not increase capacity")
  return
 var enemy=MeshBlueprint.new()
 enemy.setup_saved(MeshBlueprint.enemy_blueprint(15,4),"SWIM",15)
 if enemy.cells.size()<5 or not enemy._valid():
  _fail("Procedural enemy violates connectivity")
  return
 var flyer=MeshBlueprint.new()
 flyer.setup_saved([],"FLY",4)
 if flyer.parts_count("THRUSTER")!=2 or flyer.locomotion_slots()["thrusters"]<2:
  _fail("Fly chassis missing thrusters and upgradeable attachment slots")
  return
 var legacy=MeshBlueprint.new()
 legacy.setup_saved([],"CHAIN",3)
 if legacy.mode!="CRAWL" or not legacy._valid():
  _fail("Old CHAIN saved build not migrated")
  return
 if flyer.travel_multiplier(false)<=crawler.travel_multiplier(false):
  _fail("Flyers should move faster over solid terrain")
  return
 if crawler.travel_multiplier(true)>=enemy.travel_multiplier(true):
  _fail("Swimming must improve liquid terrain mobility")
  return
 var idle=MeshBlueprint.new()
 idle.setup_saved([],"SWIM",3)
 idle.set_motion(0.0,0.1)
 if idle.movement_blend!=0.0 or idle.travel_clock!=0.0:
  _fail("Idle mesh incorrectly plays swimming locomotion")
  return
 idle.set_motion(260.0,0.1)
 if idle.movement_blend<=0.0 or idle.travel_clock<=0.0:
  _fail("Actual movement did not activate swim animation")
  return
 var moving_clock: float=idle.travel_clock
 for n in range(10):
  idle.set_motion(0.0,0.1)
 if idle.movement_blend!=0.0:
  _fail("Animation must fade to idle after stopping")
  return
 var stopped_clock: float=idle.travel_clock
 idle.set_motion(0.0,0.1)
 if idle.travel_clock!=stopped_clock:
  # Clock advances only while blending out, then freezes.
  _fail("Idle locomotion clock should remain frozen")
  return
 print("CYBERLOAD MESH TEST PASS: connected block editor, levels, enemies, modes and stats")
 quit(0)
