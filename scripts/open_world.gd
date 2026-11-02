extends RefCounted
## Persistent, deterministic 9600 x 3400 Withnet districts, mining and portals.
const SIZE = Vector2(9600,3400)
const WALL_THICKNESS = 64.0
const ORE_NAMES = ["COPPER","COBALT","QUANTUM","PHANTOM","PLASMA","VOID"]
const ORE_COLORS = [
 Color("#CF955D"),Color("#47D8FB"),Color("#CCEB68"),
 Color("#B887FF"),Color("#FF6B8C"),Color("#68E3D4")
]
const REGIONS = [
 {"name":"PUBLIC GRID","from":70.0,"to":1395.0,"color":Color("#49B9D3"),"tier":0},
 {"name":"RED SECURITY","from":1395.0,"to":2050.0,"color":Color("#FF497B"),"tier":1},
 {"name":"NEON BAZAAR","from":2050.0,"to":3100.0,"color":Color("#B887FF"),"tier":2},
 {"name":"GHOST PORT","from":3100.0,"to":4300.0,"color":Color("#50E8FF"),"tier":3},
 {"name":"CIPHER CITADEL","from":4300.0,"to":5550.0,"color":Color("#FA4E80"),"tier":4},
 {"name":"GLASS WASTES","from":5550.0,"to":6890.0,"color":Color("#C9E56E"),"tier":4},
 {"name":"ZERO GRAVE","from":6890.0,"to":8240.0,"color":Color("#A48BFF"),"tier":5},
 {"name":"OBSIDIAN CORE","from":8240.0,"to":9530.0,"color":Color("#F85B9B"),"tier":5}
]
const NAV_CELL = 48.0
var walls: Array = []
var veins: Array = []
var portals: Array = []
var pylons: Array = []
var roads: Array = []
var canals: Array[Rect2] = []
var ambush_sites: Array = []
var wall_buckets: Dictionary = {}
var navigation = AStarGrid2D.new()

func generate(terminal_positions: Array) -> void:
 var rng = RandomNumberGenerator.new()
 rng.seed = 840351
 walls.clear()
 veins.clear()
 pylons.clear()
 portals.clear()
 roads.clear()
 canals.clear()
 ambush_sites.clear()
 var locations = [Vector2(860,1720),Vector2(1290,2760),Vector2(1930,1690),
  Vector2(2840,2790),Vector2(3950,1650),Vector2(5180,2830),
  Vector2(6290,1700),Vector2(7570,2820),Vector2(8960,1740)]
 var names = ["SUBNET CRYPT","FRACTURE MINE","VOID PROTOCOL","DATA CATACOMBS",
  "PHANTOM ARCHIVE","OMEGA TUNNELS","GLASS CATACOMB","ZERO GRAVE","OBSIDIAN NEXUS"]
 for i in range(locations.size()):
  portals.append({"id":i,"name":names[i],"pos":locations[i],"level":mini(5,1+int(i/2))})
 # Broad arteries, connected block boundaries and recursively split back streets.
 for y in [550.0,1750.0,2760.0]:
  _road(Rect2(90,y-72,SIZE.x-180,144),true)
 for region in REGIONS:
  var left: float = float(region["from"])+65.0
  var right: float = float(region["to"])-65.0
  _road(Rect2(left-52,130,104,SIZE.y-260),false)
  for band in [Vector2(145,450),Vector2(660,1638),Vector2(1860,2650),Vector2(2870,3250)]:
   _subdivide(Rect2(left,band.x,right-left,band.y-band.x),region,rng,0)
 for lane_x in [1050.0,1790.0,3100.0,4450.0,5810.0,7160.0,8500.0]:
  _carve(Rect2(lane_x-58,110,116,SIZE.y-220),false)
 # Each console and portal gets a plaza and a physical spur to its nearest artery.
 var reserved: Array = terminal_positions.duplicate()
 reserved.append(Vector2(175,550))
 reserved.append(Vector2(1490,550))
 for portal in portals:
  reserved.append(portal["pos"])
 for point in reserved:
  var at: Vector2 = point
  var road_y: float = 550.0
  for y in [1750.0,2760.0]:
   if absf(at.y-y)<absf(at.y-road_y):
    road_y=y
  _carve(Rect2(at-Vector2(108,108),Vector2(216,216)),false)
  _carve(Rect2(at.x-56,minf(at.y,road_y)-56,112,absf(at.y-road_y)+112),false)
 # Liquid channels are actual mapped surfaces: physics and rendering use this list.
 for i in [1,3,5,7]:
  var channel = Rect2(1100.0*i,2030,900,130)
  canals.append(channel)
  _carve(channel.grow(12),false)
 _index_walls()
 _build_navigation()
 for i in range(walls.size()):
  var wall: Dictionary = walls[i]
  var rect: Rect2 = wall["rect"]
  if i%4==0:
   var corner: Vector2 = find_clear(rect.end+Vector2(42,42))
   if corner.x>540 and corner.distance_to(rect.end)<130.0:
    ambush_sites.append({"pos":corner,"trigger":corner,"tier":wall["tier"]})
  if i%3==0:
   var at: Vector2 = rect.position+Vector2(24,20)
   pylons.append({"pos":at,"color":wall["tint"]})
 # Mining deposits live on navigable ground, never inside a building.
 var index: int = 0
 for region in REGIONS:
  for i in range(36):
   var at: Vector2
   var clear: bool=false
   for attempt in range(24):
    at=find_clear(Vector2(rng.randf_range(float(region["from"])+105,float(region["to"])-95),rng.randf_range(800,3190)))
    if not _clear_of_reserved(at,reserved,132):
     continue
    clear=true
    for previous in veins:
     if at.distance_to(previous["pos"])<55:
      clear=false
      break
    if clear:
     break
   if not clear:
    continue
   var tier: int = mini(5,maxi(0,int(region["tier"])-1)+int(i%4==0))
   veins.append({"id":"VEIN_%03d" % index,"pos":at,"type":ORE_NAMES[tier],"tier":tier,
    "color":ORE_COLORS[tier],"amount":2+int(i%3)})
   index+=1

func _subdivide(rect: Rect2,region: Dictionary,rng: RandomNumberGenerator,depth: int) -> void:
 var vertical: bool = rect.size.x>rect.size.y*0.9
 var length: float = rect.size.x if vertical else rect.size.y
 if length>390 and depth<5:
  var cut: float = length*rng.randf_range(0.40,0.60)
  var gap: float = rng.randf_range(108,146)
  var first: Rect2 = rect
  var second: Rect2 = rect
  var alley: Rect2 = rect
  if vertical:
   first.size.x=cut-gap*0.5
   second.position.x+=cut+gap*0.5
   second.size.x-=cut+gap*0.5
   alley.position.x+=cut-gap*0.5
   alley.size.x=gap
  else:
   first.size.y=cut-gap*0.5
   second.position.y+=cut+gap*0.5
   second.size.y-=cut+gap*0.5
   alley.position.y+=cut-gap*0.5
   alley.size.y=gap
  _road(alley,false)
  _subdivide(first,region,rng,depth+1)
  _subdivide(second,region,rng,depth+1)
 else:
  var footprint: Rect2 = rect.grow(-17)
  if footprint.size.x<35 or footprint.size.y<35:
   return
  walls.append({"rect":footprint,"tint":region["color"],"tier":region["tier"],
   "height":rng.randf_range(16,35),"style":rng.randi_range(0,3)})

func _road(rect: Rect2,major: bool) -> void:
 roads.append({"rect":rect,"major":major})

func _carve(corridor: Rect2,major: bool) -> void:
 _road(corridor,major)
 var pieces: Array = []
 for building in walls:
  var rect: Rect2 = building["rect"]
  var overlap: Rect2 = rect.intersection(corridor)
  if not rect.intersects(corridor):
   pieces.append(building)
   continue
  for part in [Rect2(rect.position,Vector2(rect.size.x,overlap.position.y-rect.position.y)),
   Rect2(Vector2(rect.position.x,overlap.end.y),Vector2(rect.size.x,rect.end.y-overlap.end.y)),
   Rect2(Vector2(rect.position.x,overlap.position.y),Vector2(overlap.position.x-rect.position.x,overlap.size.y)),
   Rect2(Vector2(overlap.end.x,overlap.position.y),Vector2(rect.end.x-overlap.end.x,overlap.size.y))]:
   if part.size.x>=18 and part.size.y>=18:
    var copy: Dictionary = building.duplicate()
    copy["rect"]=part
    pieces.append(copy)
 walls=pieces

func _index_walls() -> void:
 wall_buckets.clear()
 for i in range(walls.size()):
  var rect: Rect2 = walls[i]["rect"].grow(20)
  for y in range(int(rect.position.y/256),int(rect.end.y/256)+1):
   for x in range(int(rect.position.x/256),int(rect.end.x/256)+1):
    var key = Vector2i(x,y)
    if not wall_buckets.has(key):
     wall_buckets[key]=[]
    wall_buckets[key].append(i)

func _build_navigation() -> void:
 navigation.region=Rect2i(0,0,int(ceil(SIZE.x/NAV_CELL)),int(ceil(SIZE.y/NAV_CELL)))
 navigation.cell_size=Vector2(NAV_CELL,NAV_CELL)
 navigation.offset=Vector2(NAV_CELL*0.5,NAV_CELL*0.5)
 navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
 navigation.update()
 for y in range(navigation.region.size.y):
  for x in range(navigation.region.size.x):
   navigation.set_point_solid(Vector2i(x,y),is_blocked((Vector2(x,y)+Vector2(0.5,0.5))*NAV_CELL))

func is_blocked(pos: Vector2) -> bool:
 if pos.x<82 or pos.y<82 or pos.x>SIZE.x-82 or pos.y>SIZE.y-82:
  return true
 for index in wall_buckets.get(Vector2i(floor(pos.x/256),floor(pos.y/256)),[]):
  var rect: Rect2 = walls[index]["rect"]
  if rect.grow(18).has_point(pos):
   return true
 return false

func segment_clear(a: Vector2,b: Vector2) -> bool:
 var steps: int = maxi(1,int(ceil(a.distance_to(b)/10.0)))
 for i in range(steps+1):
  if is_blocked(a.lerp(b,float(i)/steps)):
   return false
 return true

func find_clear(at: Vector2) -> Vector2:
 if not is_blocked(at):
  return at
 for radius in range(1,32):
  for i in range(16):
   var point: Vector2 = at+Vector2.RIGHT.rotated(i*TAU/16.0)*float(radius)*24
   if not is_blocked(point):
    return point
 return Vector2(325,550)

func _nav_id(at: Vector2) -> Vector2i:
 var cell = Vector2i(floor(at.x/NAV_CELL),floor(at.y/NAV_CELL))
 if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):
  return cell
 for r in range(1,12):
  for y in range(-r,r+1):
   for x in range(-r,r+1):
    var test: Vector2i=cell+Vector2i(x,y)
    if navigation.is_in_boundsv(test) and not navigation.is_point_solid(test) and segment_clear(at,(Vector2(test)+Vector2(0.5,0.5))*NAV_CELL):
     return test
 return Vector2i(6,11)

func find_route(from: Vector2,to: Vector2) -> PackedVector2Array:
 if segment_clear(from,to):
  return PackedVector2Array([to])
 var path: PackedVector2Array=navigation.get_point_path(_nav_id(from),_nav_id(to))
 if not path.is_empty() and segment_clear(path[path.size()-1],to):
  path.append(to)
 return path

func is_liquid(at: Vector2) -> bool:
 for canal in canals:
  if canal.has_point(at):
   return true
 return false

func _clear_of_reserved(pos: Vector2,reserved: Array,clearance: float) -> bool:
 for point in reserved:
  if pos.distance_to(point)<clearance:
   return false
 return true

func nearest_vein(pos: Vector2,distance: float = 86.0) -> int:
 var nearest: int = -1
 for i in range(veins.size()):
  if pos.distance_to(veins[i]["pos"])<distance:
   distance=pos.distance_to(veins[i]["pos"])
   nearest=i
 return nearest

func nearest_portal(pos: Vector2,distance: float = 105.0) -> int:
 var nearest: int = -1
 for i in range(portals.size()):
  if pos.distance_to(portals[i]["pos"])<distance:
   distance=pos.distance_to(portals[i]["pos"])
   nearest=i
 return nearest

func region_at(pos: Vector2) -> Dictionary:
 for region in REGIONS:
  if pos.x>=float(region["from"]) and pos.x<float(region["to"]):
   return region
 return REGIONS.back()
