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
var walls: Array = []
var veins: Array = []
var portals: Array = []
var pylons: Array = []

func generate(terminal_positions: Array) -> void:
 var rng = RandomNumberGenerator.new()
 rng.seed = 840351
 walls.clear()
 veins.clear()
 pylons.clear()
 portals.clear()
 var dungeon_names = ["SUBNET CRYPT","FRACTURE MINE","VOID PROTOCOL","DATA CATACOMBS",
  "PHANTOM ARCHIVE","OMEGA TUNNELS","GLASS CATACOMB","ZERO GRAVE","OBSIDIAN NEXUS"]
 var locations = [
  Vector2(860,1720),Vector2(1290,2760),Vector2(1930,1690),
  Vector2(2840,2790),Vector2(3950,1650),Vector2(5180,2830),
  Vector2(6290,1700),Vector2(7570,2820),Vector2(8960,1740)
 ]
 for i in range(locations.size()):
  portals.append({"id":i,"name":dungeon_names[i],"pos":locations[i],"level":mini(5,1+int(i/2))})
 var reserved: Array = terminal_positions.duplicate()
 reserved.append(Vector2(175,550))
 reserved.append(Vector2(1490,550))
 for p in portals:
  reserved.append(p["pos"])
 # Route network: continuous horizontal arteries at Y=550/1750/2760,
 # vertical connectors every ~1400 pixels, leaving room for lateral travel.
 for region in REGIONS:
  var left: float = float(region["from"])
  var right: float = float(region["to"])
  for i in range(42):
   var x: float = rng.randf_range(left+105.0,right-125.0)
   var y: float = [290.0,955.0,1170.0,2120.0,3170.0][i%5]+rng.randf_range(-72.0,72.0)
   var w: float = rng.randf_range(72.0,165.0)
   var block = Rect2(Vector2(x,y),Vector2(w,rng.randf_range(34.0,77.0)))
   if _safe_structure(block,reserved):
    walls.append({"rect":block,"tint":region["color"],"tier":region["tier"]})
  for i in range(12):
   var px: float = rng.randf_range(left+86.0,right-90.0)
   var py: float = [260.0,995.0,1410.0,2240.0,3120.0][i%5]
   var p = Vector2(px,py)
   if _clear_of_reserved(p,reserved,130.0):
    pylons.append({"pos":p,"color":region["color"]})
 # Dense but repeatably placed mining field with guaranteed access near spawn.
 var index: int = 0
 for region in REGIONS:
  for i in range(34):
   var x: float = rng.randf_range(float(region["from"])+95.0,float(region["to"])-95.0)
   var y: float = [875.0,1340.0,2120.0,3040.0][i%4]+rng.randf_range(-100.0,100.0)
   var pos = Vector2(x,y)
   if not _clear_of_reserved(pos,reserved,110.0) or is_blocked(pos):
    continue
   var tier: int = mini(5,maxi(0,int(region["tier"])-1)+int(i%4==0))
   veins.append({"id":"VEIN_%03d" % index,"pos":pos,"type":ORE_NAMES[tier],"tier":tier,
    "color":ORE_COLORS[tier],"amount":2+int(i%3)})
   index += 1

func _safe_structure(rect: Rect2, reserved: Array) -> bool:
 if rect.position.x <= WALL_THICKNESS+22.0 or rect.end.x >= SIZE.x-WALL_THICKNESS-22.0:
  return false
 if rect.position.y <= WALL_THICKNESS+22.0 or rect.end.y >= SIZE.y-WALL_THICKNESS-22.0:
  return false
 # Never obstruct the three great roads or transverse connectors.
 for road_y in [550.0,1750.0,2760.0]:
  if rect.grow(105.0).has_point(Vector2(rect.get_center().x,road_y)):
   return false
 for lane_x in [1050.0,1790.0,3100.0,4450.0,5810.0,7160.0,8500.0]:
  if rect.grow(65.0).has_point(Vector2(lane_x,rect.get_center().y)):
   return false
 for point in reserved:
  if rect.grow(145.0).has_point(point):
   return false
 return true

func _clear_of_reserved(pos: Vector2, reserved: Array, clearance: float) -> bool:
 if pos.x < 115.0 or pos.x > SIZE.x-115.0 or pos.y < 115.0 or pos.y > SIZE.y-115.0:
  return false
 for point in reserved:
  if pos.distance_to(point) < clearance:
   return false
 return true

func is_blocked(pos: Vector2) -> bool:
 # Full four-sided world perimeter acts as a solid physical wall.
 if pos.x < WALL_THICKNESS or pos.y < WALL_THICKNESS or pos.x > SIZE.x-WALL_THICKNESS or pos.y > SIZE.y-WALL_THICKNESS:
  return true
 for wall in walls:
  var rect: Rect2 = wall["rect"]
  if rect.grow(14.0).has_point(pos):
   return true
 return false

func nearest_vein(pos: Vector2, distance: float = 86.0) -> int:
 var nearest: int = -1
 for i in range(veins.size()):
  var dist: float = pos.distance_to(veins[i]["pos"])
  if dist < distance:
   distance = dist
   nearest = i
 return nearest

func nearest_portal(pos: Vector2, distance: float = 105.0) -> int:
 var nearest: int = -1
 for i in range(portals.size()):
  var dist: float = pos.distance_to(portals[i]["pos"])
  if dist < distance:
   distance = dist
   nearest = i
 return nearest

func region_at(pos: Vector2) -> Dictionary:
 for region in REGIONS:
  if pos.x >= float(region["from"]) and pos.x < float(region["to"]):
   return region
 return REGIONS[REGIONS.size()-1]
