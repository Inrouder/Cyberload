extends SceneTree
const Mesh = preload("res://scripts/mesh_creature.gd")
func _initialize() -> void:
 call_deferred("_check")
func _fail(message: String) -> void:
 push_error("CYBERLOAD MESH TEST FAIL: "+message)
 quit(1)
func _check() -> void:
 var crawler=Mesh.new()
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
 var enemy=Mesh.new()
 enemy.setup_saved(Mesh.enemy_blueprint(15,4),"SWIM",15)
 if enemy.cells.size()<5 or not enemy._valid():
  _fail("Procedural enemy violates connectivity")
  return
 if crawler.travel_multiplier(true)>=enemy.travel_multiplier(true):
  _fail("Swimming must improve liquid terrain mobility")
  return
 print("CYBERLOAD MESH TEST PASS: connected block editor, levels, enemies, modes and stats")
 quit(0)
