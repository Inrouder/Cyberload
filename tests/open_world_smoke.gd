extends SceneTree
const World = preload("res://scripts/open_world.gd")
const Dungeon = preload("res://scripts/dungeon_instance.gd")
const State = preload("res://scripts/game_state.gd")

func _initialize() -> void:
 call_deferred("_run")

func _fail(message: String) -> void:
 push_error("CYBERLOAD OPEN WORLD FAIL: "+message)
 quit(1)

func _run() -> void:
 var w = World.new()
 w.generate([Vector2(430,300),Vector2(850,1600)])
 if w.veins.size() < 150 or w.portals.size() != 9 or w.walls.size() < 90:
  _fail("Not enough veins / playable dungeons / architectural blocks")
  return
 if not w.is_blocked(Vector2(2,700)) or not w.is_blocked(Vector2(4500,2)) or not w.is_blocked(Vector2(9599,2500)) or not w.is_blocked(Vector2(5000,3399)):
  _fail("Outer border must be sealed on all four sides")
  return
 for pos in [Vector2(800,550),Vector2(5200,1750),Vector2(8800,2760)]:
  if w.is_blocked(pos):
   _fail("Major transit routes blocked at %s" % str(pos))
   return
 var model = State.new()
 model.credits = 2500
 model.fragments = 200
 var seed: Dictionary = w.veins[0]
 var timestamp: int = 1810000000
 if int(seed["tier"]) > 0:
  model.drill_level = int(seed["tier"])
 if not model.mine_vein(seed,timestamp) or model.mine_vein(seed,timestamp):
  _fail("Mining depletion / cooldown not enforced")
  return
 if model.ore_total() <= 0 or not model.mine_vein(seed,timestamp+500):
  _fail("Ore yield or timed vein respawn failed")
  return
 if model.sell_ore() <= 0 or model.ore_total() != 0:
  _fail("Mining trader did not credit extracted materials")
  return
 for id in range(9):
  var instance = Dungeon.new()
  instance.setup(id)
  if instance.is_blocked(instance.spawn) or instance.is_blocked(instance.boss_pos) or not instance.is_blocked(Vector2(5,5)):
   _fail("Dungeon spawn or boss/outer wall invalid: %d" % id)
   return
  for x in range(2,27):
   if instance.is_blocked(Vector2((float(x)+0.5)*Dungeon.TILE,8.5*Dungeon.TILE)):
    _fail("Guaranteed dungeon escape/boss corridor blocked")
    return
  if instance.enemy_near(instance.boss_pos) < 0 or instance.caches.size()!=3:
   _fail("Dungeon boss/loot missing for entrance %d" % id)
   return
  var last: int = instance.enemy_near(instance.boss_pos)
  if not instance.defeat(last) or instance.defeat(last):
   _fail("Dungeon boss can be looted twice")
   return
 model.drill_level = 0
 if not model.upgrade_drill() or model.drill_level != 1:
  _fail("Drill upgrade failed")
  return
 model.dungeon_clears["DUNGEON_0"] = true
 model.dungeon_caches["0:1"] = true
 model.save_game()
 var saved = State.new()
 saved.load_game()
 if saved.drill_level != 1 or not saved.dungeon_clears.has("DUNGEON_0") or not saved.dungeon_caches.has("0:1"):
  _fail("Mining / dungeon save data not restored")
  return
 print("CYBERLOAD OPEN WORLD PASS: walls, routes, 9 dungeons, mining economy and persistence")
 quit(0)
