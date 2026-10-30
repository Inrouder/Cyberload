extends RefCounted
## Connected modular crawler data-creatures. All builds share the same rules.
const MODES = ["CRAWL","SWIM","FLY"]
const TYPES = ["CORE","HULL","GUN","HACK","FIN","LEG","SHIELD","SENSOR","THRUSTER"]
const PALETTE = [Color("#E9FC86"),Color("#49E4FB"),Color("#FF507C"),Color("#B587FF")]
const MAX_CELLS = 65
var cells: Array = []
var mode: String = "CRAWL"
var level: int = 1

func setup_saved(saved: Array, movement: String, rank: int) -> void:
 level = maxi(1,rank)
 # Older CHAIN save slots migrate to the spider-style crawler.
 mode = ("CRAWL" if movement=="CHAIN" else movement) if MODES.has(movement) or movement=="CHAIN" else "CRAWL"
 cells.clear()
 for item in saved:
  if typeof(item) != TYPE_DICTIONARY:
   continue
  var p = Vector2i(int(item.get("x",0)),int(item.get("y",0)))
  var kind: String = str(item.get("type","HULL"))
  if TYPES.has(kind) and not occupied(p) and abs(p.x)<=9 and abs(p.y)<=9:
   cells.append({"x":p.x,"y":p.y,"type":kind})
 if cells.is_empty() or not _valid():
  cells = _starter_body(mode)

static func _starter_body(movement: String) -> Array:
 match movement:
  "SWIM":
   return [{"x":0,"y":0,"type":"CORE"},{"x":-1,"y":0,"type":"FIN"},{"x":1,"y":0,"type":"FIN"}]
  "FLY":
   return [{"x":0,"y":0,"type":"CORE"},{"x":-1,"y":0,"type":"THRUSTER"},{"x":1,"y":0,"type":"THRUSTER"}]
 return [{"x":0,"y":0,"type":"CORE"},{"x":-1,"y":0,"type":"LEG"},{"x":1,"y":0,"type":"LEG"}]

func locomotion_slots() -> Dictionary:
 var supported: int = 2+int(level/2)
 return {"legs":supported if mode=="CRAWL" else 0,
 "fins":supported if mode=="SWIM" else 0,
 "thrusters":supported if mode=="FLY" else 0}

func parts_count(kind: String) -> int:
 var total: int = 0
 for c in cells:
  if str(c["type"])==kind:
   total+=1
 return total

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
 var slots: Dictionary=locomotion_slots()
 if kind=="LEG" and mode=="CRAWL" and parts_count(kind)>=int(slots["legs"]):
  return false
 if kind=="FIN" and mode=="SWIM" and parts_count(kind)>=int(slots["fins"]):
  return false
 if kind=="THRUSTER" and mode=="FLY" and parts_count(kind)>=int(slots["thrusters"]):
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
   "FIN","LEG","THRUSTER": mobility+=1
 return {"damage":18.0+weapon*11.0+float(level)*2.0,
  "hp":90.0+armor*22.0+level*9.0,
  "hack":hacking,"speed":1.0+mobility*0.06}

func travel_multiplier(liquid: bool) -> float:
 if mode=="SWIM":
  return 1.45 if liquid else 0.72
 if mode=="FLY":
  return 1.18
 return 0.60 if liquid else 1.05

func _cell_color(kind: String, enemy: bool) -> Color:
 if enemy:
  return Color("#FF507C") if kind=="CORE" else Color("#D16A93")
 match kind:
  "CORE": return Color("#D0F96C")
  "GUN": return Color("#FF507C")
  "HACK","SENSOR": return Color("#B887FF")
  "FIN": return Color("#4ABEF9")
  "THRUSTER": return Color("#FCA867")
  "SHIELD": return Color("#F7D885")
  _: return Color("#50E8FF")

func _animated_pos(cell: Dictionary,at: Vector2,rotation: float,time: float,unit: float) -> Vector2:
 var base: Vector2=Vector2(float(cell["x"]),float(cell["y"]))*unit
 var distance: float=absf(float(cell["x"]))+absf(float(cell["y"]))
 match mode:
  "SWIM":
   # Traveling undulation grows towards the back; fin blocks delay their strokes.
   var phase: float=time*4.8-distance*0.72
   base.y+=sin(phase)*unit*(0.05+minf(distance,7.0)*0.095)
   base.x-=maxf(0.0,-float(cell["x"]))*unit*(0.06+0.04*sin(time*3.7-distance))
  "CRAWL":
   base.y+=sin(time*8.2)*unit*0.035
  "FLY":
   base.y+=sin(time*3.5+distance*0.30)*unit*0.06
 return at+base.rotated(rotation)

func _draw_ground_contact(canvas: CanvasItem,foot: Vector2,tone: Color,time: float,phase: float,scale: float) -> void:
 # A ring is emitted for a few frames around the moment the foot lands.
 var contact: float=fposmod(phase,TAU)
 if contact<0.65:
  var t: float=contact/0.65
  canvas.draw_arc(foot,3.0+11.0*t,0.0,TAU,24,Color(tone.r,tone.g,tone.b,(1.0-t)*0.55),1.7*scale)

func draw_mesh(canvas: CanvasItem,at: Vector2,rotation: float,time: float,enemy: bool=false,scale: float=1.0) -> void:
 var unit: float=18.0*scale
 var forward: Vector2=Vector2.RIGHT.rotated(rotation)
 var back: Vector2=-forward
 var sideways: Vector2=Vector2.DOWN.rotated(rotation)
 # Every mode has a distinct central chassis even when custom parts are sparse.
 var body_tint: Color=Color("#ED688F") if enemy else Color("#53DFFF")
 if mode=="FLY":
  var hull=PackedVector2Array([at+forward*unit*1.65,at+sideways*unit*0.77,
   at-back*unit*0.35,at-sideways*unit*0.77])
  canvas.draw_colored_polygon(hull,Color("#132A3C"))
  canvas.draw_polyline(PackedVector2Array([hull[0],hull[1],hull[2],hull[3],hull[0]]),body_tint,2.2*scale)
 elif mode=="SWIM":
  canvas.draw_arc(at,unit*1.06,rotation+0.6,rotation+TAU-0.6,32,body_tint,2.4*scale)
 else:
  canvas.draw_arc(at,unit*1.05,0.0,TAU,36,body_tint,2.0*scale)
 # Connected glowing structural struts preserve a readable custom-built mesh.
 for cell in cells:
  var origin: Vector2=_animated_pos(cell,at,rotation,time,unit)
  for offset in [Vector2i.RIGHT,Vector2i.DOWN]:
   var neighbor: Vector2i=Vector2i(int(cell["x"]),int(cell["y"]))+offset
   if not occupied(neighbor):
    continue
   for other in cells:
    if int(other["x"])==neighbor.x and int(other["y"])==neighbor.y:
     var endpoint: Vector2=_animated_pos(other,at,rotation,time,unit)
     canvas.draw_line(origin,endpoint,Color("#0C1829"),unit*0.46)
     canvas.draw_line(origin,endpoint,body_tint,2.0*scale)
     break
 var limb_id: int=0
 for cell in cells:
  var pivot: Vector2=_animated_pos(cell,at,rotation,time,unit)
  var kind: String=str(cell["type"])
  var tone: Color=_cell_color(kind,enemy)
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.45,unit*0.45),Vector2(unit*0.9,unit*0.9)),Color("#0A1527"))
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.39,unit*0.39),Vector2(unit*0.78,unit*0.78)),tone,false,2.0*scale)
  canvas.draw_rect(Rect2(pivot-Vector2(unit*0.16,unit*0.16),Vector2(unit*0.32,unit*0.32)),tone)
  if mode=="CRAWL" and (kind=="LEG" or kind=="CORE"):
   # Contralateral legs use offset phases like a spider or beetle gait.
   for side in [-1.0,1.0]:
    var phase: float=time*10.0+float(limb_id)*PI*0.68+(0.0 if side<0 else PI)
    var lift: float=maxf(0.0,sin(phase))
    var stride: float=cos(phase)*unit*0.56
    var knee: Vector2=pivot+sideways*side*unit*0.72+forward*(stride*0.5)-sideways*lift*unit*0.34
    var foot: Vector2=pivot+sideways*side*unit*1.24+forward*stride-sideways*lift*unit*0.50
    canvas.draw_line(pivot,knee,tone,2.5*scale)
    canvas.draw_line(knee,foot,tone,2.0*scale)
    canvas.draw_circle(foot,2.3*scale,tone)
    _draw_ground_contact(canvas,foot,tone,time,phase,scale)
   limb_id+=1
  if mode=="SWIM" and (kind=="FIN" or kind=="CORE"):
   var flap: float=sin(time*6.3-float(limb_id)*0.9)
   var tip: Vector2=pivot+back*unit*0.62+sideways*unit*(0.85+flap*0.24)
   var fin=PackedVector2Array([pivot+sideways*unit*0.10,tip,pivot+back*unit*0.65-sideways*unit*0.28])
   canvas.draw_colored_polygon(fin,Color(tone.r,tone.g,tone.b,0.30))
   canvas.draw_polyline(PackedVector2Array([fin[0],fin[1],fin[2]]),tone,1.8*scale)
   limb_id+=1
  if mode=="FLY" and (kind=="THRUSTER" or kind=="CORE"):
   var pulse: float=0.5+0.5*sin(time*12.0+float(limb_id))
   var jet: float=unit*(0.95+pulse*0.90)
   canvas.draw_line(pivot+back*unit*0.32,pivot+back*jet,Color("#80EEFF"),2.8*scale)
   for wave in range(3):
    var progress: float=fposmod(time*2.4+float(wave)/3.0,1.0)
    var center: Vector2=pivot+back*(jet+progress*unit*2.8)
    canvas.draw_line(center-sideways*unit*(0.18+progress*0.50),center+sideways*unit*(0.18+progress*0.50),
     Color(0.30,0.90,1.0,(1.0-progress)*0.55),1.8*scale)
   limb_id+=1
  if kind=="GUN":
   canvas.draw_line(pivot,pivot+forward*unit*0.95,tone,3.0*scale)
  if kind=="CORE":
   canvas.draw_arc(pivot,unit*0.58+sin(time*5.0)*2.0,0.0,TAU,30,tone,2.0*scale)

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
  result.append({"x":p.x,"y":p.y,"type":["HULL","GUN","LEG","FIN","THRUSTER","HACK"][rng.randi_range(0,5)]})
 return result
