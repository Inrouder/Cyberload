extends RefCounted
## Playable room-and-corridor instanced subnetwork. Deterministic per gate.
const WIDTH = 30
const HEIGHT = 18
const TILE = 64.0
const NAMES = ["SUBNET CRYPT","FRACTURE MINE","VOID PROTOCOL","DATA CATACOMBS",
 "PHANTOM ARCHIVE","OMEGA TUNNELS","GLASS CATACOMB","ZERO GRAVE","OBSIDIAN NEXUS"]
var id: int = 0
var level: int = 1
var walls: Dictionary = {}
var caches: Array = []
var enemies: Array = []
var exit_pos: Vector2 = Vector2(2.5*TILE,8.5*TILE)
var boss_pos: Vector2 = Vector2(26.5*TILE,8.5*TILE)
var spawn: Vector2 = Vector2(2.5*TILE,8.5*TILE)

func setup(dungeon_id: int, boss_cleared: bool = false) -> void:
 id = clampi(dungeon_id,0,NAMES.size()-1)
 level = mini(5,1+int(id/2))
 walls.clear()
 caches.clear()
 enemies.clear()
 var rng = RandomNumberGenerator.new()
 rng.seed = 717901+id*491
 for y in range(HEIGHT):
  for x in range(WIDTH):
   if x==0 or y==0 or x==WIDTH-1 or y==HEIGHT-1:
    walls[_key(x,y)] = true
 # Walls split the grid into distinctive interconnected chambers.
 # Center corridor Y=8 and vertical links X=5/13/21/26 are always open.
 for y in range(2,HEIGHT-2):
  if y==8 or y==4 or y==13:
   continue
  for x in [9,17,24]:
   walls[_key(x,y)] = true
 for y in [5,12]:
  for x in range(4,WIDTH-3):
   if x in [5,13,21,26]:
    continue
   walls[_key(x,y)] = true
 for i in range(34):
  var x: int = rng.randi_range(3,WIDTH-4)
  var y: int = rng.randi_range(2,HEIGHT-3)
  if y==8 or x in [5,13,21,26] or y in [4,13]:
   continue
  if Vector2i(x,y) in [Vector2i(6,3),Vector2i(14,14),Vector2i(24,3)]:
   continue
  walls[_key(x,y)] = true
 # A 2-tile buffer around portals, caches and guards ensures reachability.
 for cell in [Vector2i(2,8),Vector2i(3,8),Vector2i(6,3),Vector2i(14,14),
              Vector2i(24,3),Vector2i(10,8),Vector2i(19,8),Vector2i(26,8)]:
  walls.erase(_key(cell.x,cell.y))
 caches = [
  {"pos":Vector2(6.5*TILE,3.5*TILE),"id":0},
  {"pos":Vector2(14.5*TILE,14.5*TILE),"id":1},
  {"pos":Vector2(24.5*TILE,3.5*TILE),"id":2}
 ]
 if not boss_cleared:
  for i in range(3):
   var location: Vector2 = [Vector2(10.5*TILE,8.5*TILE),Vector2(19.5*TILE,8.5*TILE),boss_pos][i]
   enemies.append({"pos":location,"name":("CORE OVERSEER" if i==2 else "CRYPT SENTINEL"),
    "level":mini(5,level+i),"boss":i==2,"defeated":false})

func _key(x: int,y: int) -> String:
 return "%d:%d" % [x,y]

func is_blocked(pos: Vector2) -> bool:
 var cx: int = int(floor(pos.x/TILE))
 var cy: int = int(floor(pos.y/TILE))
 if walls.has(_key(cx,cy)):
  return true
 # Collision radius: check 8 px around runner.
 for diff in [Vector2(-12,0),Vector2(12,0),Vector2(0,-12),Vector2(0,12)]:
  var v: Vector2 = pos+diff
  if walls.has(_key(int(floor(v.x/TILE)),int(floor(v.y/TILE)))):
   return true
 return false

func nearest_cache(pos: Vector2, distance: float = 80.0) -> int:
 var nearest: int = -1
 for i in range(caches.size()):
  if pos.distance_to(caches[i]["pos"]) < distance:
   distance = pos.distance_to(caches[i]["pos"])
   nearest = i
 return nearest

func enemy_near(pos: Vector2, distance: float = 62.0) -> int:
 for i in range(enemies.size()):
  if not bool(enemies[i]["defeated"]) and pos.distance_to(enemies[i]["pos"]) < distance:
   return i
 return -1

func defeat(index: int) -> bool:
 if index < 0 or index >= enemies.size() or bool(enemies[index]["defeated"]):
  return false
 enemies[index]["defeated"] = true
 return true
