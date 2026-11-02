extends RefCounted
## Fresh connected rooms, loops and branches on every entry; seeded for regression tests.
const WIDTH = 46
const HEIGHT = 30
const TILE = 64.0
const NAMES = ["SUBNET CRYPT","FRACTURE MINE","VOID PROTOCOL","DATA CATACOMBS",
 "PHANTOM ARCHIVE","OMEGA TUNNELS","GLASS CATACOMB","ZERO GRAVE","OBSIDIAN NEXUS"]
const THEMES = ["FLOODED ARCHIVE", "CIPHER FOUNDRY", "GHOST CATHEDRAL", "ROOT VAULT"]
var id: int = 0
var level: int = 1
var layout_seed: int = 0
var theme: int = 0
var walls: Dictionary = {}
var floors: Dictionary = {}
var rooms: Array[Rect2i] = []
var caches: Array = []
var enemies: Array = []
var exit_pos: Vector2
var boss_pos: Vector2
var spawn: Vector2

func setup(dungeon_id: int, _boss_cleared: bool = false, seed_value: int = -1) -> void:
 id = clampi(dungeon_id,0,NAMES.size()-1)
 level = mini(5,1+int(id/2))
 var rng = RandomNumberGenerator.new()
 if seed_value < 0:
  rng.randomize()
  var next_seed: int = int(rng.randi())
  layout_seed = next_seed if next_seed != layout_seed else next_seed+1
 else:
  layout_seed = seed_value
 rng.seed = layout_seed
 theme = rng.randi_range(0,THEMES.size()-1)
 walls.clear()
 floors.clear()
 rooms.clear()
 caches.clear()
 enemies.clear()
 for attempt in range(220):
  var rect = Rect2i(rng.randi_range(2,WIDTH-12),rng.randi_range(2,HEIGHT-10),
   rng.randi_range(5,10),rng.randi_range(4,7))
  var fits: bool = rect.end.x < WIDTH-2 and rect.end.y < HEIGHT-2
  for previous in rooms:
   if previous.grow(2).intersects(rect):
    fits = false
    break
  if not fits:
   continue
  rooms.append(rect)
  _room(rect)
  if rooms.size() >= 9+level:
   break
 if rooms.size() < 5:
  rooms.clear()
  floors.clear()
  for y in [3,18]:
   for x in [3,18,33]:
    var rect = Rect2i(x,y,8,6)
    rooms.append(rect)
    _room(rect)
 # Every accepted room joins the previous one; extra edges add loops.
 for i in range(1,rooms.size()):
  _connect(rooms[i-1].get_center(),rooms[i].get_center(),rng.randf()<0.5)
 for i in range(rooms.size()/3):
  _connect(rooms[i].get_center(),rooms[rooms.size()-1-i].get_center(),rng.randf()<0.5)
 spawn = _center(rooms[0].get_center())
 exit_pos = spawn
 var distances: Dictionary = reachable_cells(spawn)
 var ranked: Array[int] = []
 for i in range(1,rooms.size()):
  ranked.append(i)
 ranked.sort_custom(func(a: int,b: int) -> bool:
  return int(distances.get(rooms[a].get_center(),0)) < int(distances.get(rooms[b].get_center(),0)))
 boss_pos = _center(rooms[ranked.back()].get_center())
 # Cache IDs stay stable so randomizing a layout never duplicates saved rewards.
 for i in range(3):
  var room: Rect2i = rooms[ranked[i]]
  caches.append({"pos":_center(room.position+Vector2i(1,1)),"id":i})
 for i in range(3):
  var location: Vector2 = boss_pos if i==2 else _center(rooms[ranked[mini(ranked.size()-2,i*2)]].get_center())
  enemies.append({"pos":location,"name":"CORE OVERSEER" if i==2 else "CRYPT SENTINEL",
   "level":mini(5,level+i),"boss":i==2,"defeated":false})
 for y in range(HEIGHT):
  for x in range(WIDTH):
   if not floors.has(Vector2i(x,y)):
    walls[_key(x,y)] = true

func _center(cell: Vector2i) -> Vector2:
 return (Vector2(cell)+Vector2(0.5,0.5))*TILE

func _room(rect: Rect2i) -> void:
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   floors[Vector2i(x,y)] = true

func _connect(a: Vector2i,b: Vector2i,horizontal_first: bool) -> void:
 var elbow = Vector2i(b.x,a.y) if horizontal_first else Vector2i(a.x,b.y)
 _corridor(a,elbow)
 _corridor(elbow,b)

func _corridor(a: Vector2i,b: Vector2i) -> void:
 for y in range(mini(a.y,b.y),maxi(a.y,b.y)+2):
  for x in range(mini(a.x,b.x),maxi(a.x,b.x)+2):
   if x>0 and y>0 and x<WIDTH-1 and y<HEIGHT-1:
    floors[Vector2i(x,y)] = true

func reachable_cells(from: Vector2) -> Dictionary:
 var start = Vector2i(floor(from.x/TILE),floor(from.y/TILE))
 var found: Dictionary = {start:0}
 var queue: Array[Vector2i] = [start]
 var head: int = 0
 while head<queue.size():
  var at: Vector2i = queue[head]
  head+=1
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next: Vector2i = at+direction
   if floors.has(next) and not found.has(next):
    found[next] = int(found[at])+1
    queue.append(next)
 return found

func _key(x: int,y: int) -> String:
 return "%d:%d" % [x,y]

func is_blocked(pos: Vector2) -> bool:
 if pos.x<18.0 or pos.y<18.0 or pos.x>WIDTH*TILE-18.0 or pos.y>HEIGHT*TILE-18.0:
  return true
 for diff in [Vector2(-18,-18),Vector2(18,-18),Vector2(-18,18),Vector2(18,18)]:
  var at: Vector2 = pos+diff
  if not floors.has(Vector2i(floor(at.x/TILE),floor(at.y/TILE))):
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
 if index<0 or index>=enemies.size() or bool(enemies[index]["defeated"]):
  return false
 enemies[index]["defeated"] = true
 return true

func find_route(from: Vector2,to: Vector2) -> PackedVector2Array:
 var goal=Vector2i(floor(to.x/TILE),floor(to.y/TILE))
 var start=Vector2i(floor(from.x/TILE),floor(from.y/TILE))
 var distances: Dictionary=reachable_cells(to)
 var route=PackedVector2Array()
 if not distances.has(start):
  return route
 var at: Vector2i=start
 while at!=goal:
  var next: Vector2i=at
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   if int(distances.get(at+direction,99999))<int(distances[at]):
    next=at+direction
    break
  if next==at:
   break
  at=next
  route.append(_center(at))
 return route
