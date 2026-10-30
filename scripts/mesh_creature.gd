extends RefCounted
## Connected modular crawler data-creatures. All builds share the same rules.
const MODES = ["CRAWL","SWIM","CHAIN"]
const TYPES = ["CORE","HULL","GUN","HACK","FIN","LEG","SHIELD","SENSOR"]
const PALETTE = [Color("#E9FC86"),Color("#49E4FB"),Color("#FF507C"),Color("#B587FF")]
const MAX_CELLS = 65
var cells: Array = []
var mode: String = "CRAWL"
var level: int = 1

func setup_saved(saved: Array, movement: String, rank: int) -> void:
 level = maxi(1,rank)
 mode = movement if MODES.has(movement) else "CRAWL"
 cells.clear()
 for item in saved:
  if typeof(item) != TYPE_DICTIONARY:
   continue
  var p = Vector2i(int(item.get("x",0)),int(item.get("y",0)))
  var kind: String = str(item.get("type","HULL"))
  if TYPES.has(kind) and not occupied(p) and abs(p.x)<=9 and abs(p.y)<=9:
   cells.append({"x":p.x,"y":p.y,"type":kind})
 if cells.is_empty() or not _valid():
  cells = [{"x":0,"y":0,"type":"CORE"},{"x":-1,"y":0,"type":"LEG"},{"x":1,"y":0,"type":"LEG"}]

func occupied(p: Vector2i) -> bool:
 for cell in cells:
  if int(cell["x"])==p.x and int(cell["y"])==p.y:
   return true
 return false

func capacity() -> int:
 return mini(MAX_CELLS,3+level*2)

func _valid() -> bool:
 if cells.size()>capacity():
  return false
 var cores: int = 0
 for c in cells:
  if c["type"]=="CORE":
   cores+=1
 if cores!=1:
  return false
 var visited: Array = [Vector2i(int(cells[0]["x"]),int(cells[0]["y"]))]
 var cursor: int = 0
 while cursor<visited.size():
  var at: Vector2i = visited[cursor]
  cursor+=1
  for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next: Vector2i = at+delta
   if occupied(next) and not visited.has(next):
    visited.append(next)
 return visited.size()==cells.size()

func add_block(p: Vector2i, kind: String) -> bool:
 if not TYPES.has(kind) or kind=="CORE" or cells.size()>=capacity() or occupied(p) or abs(p.x)>9 or abs(p.y)>9:
  return false
 cells.append({"x":p.x,"y":p.y,"type":kind})
 if not _valid():
  cells.pop_back()
  return false
 return true

func remove_block(p: Vector2i) -> bool:
 for i in range(cells.size()):
  var c: Dictionary = cells[i]
  if int(c["x"])==p.x and int(c["y"])==p.y and c["type"]!="CORE":
   var previous: Dictionary = cells[i]
   cells.remove_at(i)
   if not _valid():
    cells.insert(i,previous)
    return false
   return true
 return false

func stats() -> Dictionary:
 var weapon: int = 0
 var armor: int = 0
 var hacking: int = 0
 var mobility: int = 0
 for c in cells:
  match str(c["type"]):
   "GUN": weapon+=1
   "HULL","SHIELD": armor+=1
   "HACK","SENSOR": hacking+=1
   "FIN","LEG": mobility+=1
 return {"damage":18.0+weapon*11.0+float(level)*2.0,
  "hp":90.0+armor*22.0+level*9.0,
  "hack":hacking,"speed":1.0+mobility*0.06}

func travel_multiplier(liquid: bool) -> float:
 if mode=="SWIM":
  return 1.45 if liquid else 0.72
 if mode=="CHAIN":
  return 1.15 if not liquid else 0.95
 return 0.60 if liquid else 1.05

func _cell_color(kind: String, enemy: bool) -> Color:
 if enemy:
  return Color("#FF507C") if kind=="CORE" else Color("#D16A93")
 match kind:
  "CORE": return Color("#D0F96C")
  "GUN": return Color("#FF507C")
  "HACK","SENSOR": return Color("#B887FF")
  "FIN": return Color("#4ABEF9")
  "SHIELD": return Color("#F7D885")
  _: return Color("#50E8FF")

func _animated_pos(cell: Dictionary,at: Vector2,rotation: float,time: float,unit: float) -> Vector2:
 var p=Vector2(float(cell["x"]),float(cell["y"]))*unit
 if mode=="CHAIN":
  # Phase-shifted spine links give long serpent builds an unmistakable ripple.
  p.y+=sin(time*5.0+float(cell["x"])*0.85)*unit*0.22*absf(float(cell["x"]))
 elif mode=="SWIM":
  p.y+=sin(time*4.0+float(cell["x"])*1.25)*unit*0.13
 return at+p.rotated(rotation)

func draw_mesh(canvas: CanvasItem,at: Vector2,rotation: float,time: float,enemy: bool=false,scale: float=1.0) -> void:
 # Wireframe digital arthropod built from physically connected pixel-cubes.
 var unit: float=18.0*scale
 for cell in cells:
  var origin: Vector2=_animated_pos(cell,at,rotation,time,unit)
  for neighbor in [Vector2i.RIGHT,Vector2i.DOWN]:
   var p=Vector2i(int(cell["x"]),int(cell["y"]))+neighbor
   if occupied(p):
    var next: Dictionary={}
    for other in cells:
     if int(other["x"])==p.x and int(other["y"])==p.y:
      next=other
      break
    if not next.is_empty():
     var destination: Vector2=_animated_pos(next,at,rotation,time,unit)
     canvas.draw_line(origin,destination,Color("#0B1830"),unit*0.42)
     canvas.draw_line(origin,destination,Color("#42D6DA") if not enemy else Color("#EF5C90"),2.0*scale)
 for cell in cells:
  var pivot: Vector2=_animated_pos(cell,at,rotation,time,unit)
  var kind: String=str(cell["type"])
  var tone: Color=_cell_color(kind,enemy)
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.47,unit*0.47),Vector2(unit*0.94,unit*0.94)),Color("#071123"))
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.40,unit*0.40),Vector2(unit*0.80,unit*0.80)),tone,false,maxf(1.0,1.9*scale))
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.19,unit*0.19),Vector2(unit*0.38,unit*0.38)),tone)
  var wobble: float=sin(time*8.0+float(cell["x"])*2.0)*unit*0.23
  if kind=="LEG" or mode=="CRAWL" and int(cell["y"])!=0:
   canvas.draw_line(pivot+Vector2(-unit*0.36,0),pivot+Vector2(-unit*0.92,wobble),tone,2.2)
   canvas.draw_line(pivot+Vector2(unit*0.36,0),pivot+Vector2(unit*0.92,-wobble),tone,2.2)
   canvas.draw_circle(pivot+Vector2(-unit*0.92,wobble),2.3,tone)
   canvas.draw_circle(pivot+Vector2(unit*0.92,-wobble),2.3,tone)
  if kind=="FIN" or mode=="SWIM" and int(cell["x"])!=0:
   var fin: PackedVector2Array=PackedVector2Array([
    pivot+Vector2(-unit*0.4,0),pivot+Vector2(0,-unit*(0.7+0.16*sin(time*6.0))),
    pivot+Vector2(unit*0.4,0)])
   canvas.draw_polyline(fin,tone,2.0)
  if kind=="GUN":
   canvas.draw_line(pivot,pivot+Vector2(unit,0).rotated(rotation),tone,3.0)
   canvas.draw_circle(pivot+Vector2(unit,0).rotated(rotation),3.0,Color("#FAEC73"))
  if kind=="CORE":
   var pulse: float=3.0+sin(time*5.0)*1.5
   canvas.draw_arc(pivot,unit*0.58+pulse,0.0,TAU,30,tone,2.0)

static func enemy_blueprint(seed: int,rank: int) -> Array:
 var rng = RandomNumberGenerator.new()
 rng.seed = 51031+seed*503
 var result: Array = [{"x":0,"y":0,"type":"CORE"}]
 var target: int = mini(24,3+rank*2+seed%3)
 while result.size()<target:
  var chosen: Dictionary = result[rng.randi_range(0,result.size()-1)]
  var offset: Vector2i = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT][rng.randi_range(0,3)]
  var p: Vector2i = Vector2i(int(chosen["x"]),int(chosen["y"]))+offset
  var taken: bool = false
  for c in result:
   if int(c["x"])==p.x and int(c["y"])==p.y:
    taken = true
  if taken or abs(p.x)>7 or abs(p.y)>7:
   continue
  result.append({"x":p.x,"y":p.y,"type":["HULL","GUN","LEG","FIN","SHIELD","HACK"][rng.randi_range(0,5)]})
 return result
