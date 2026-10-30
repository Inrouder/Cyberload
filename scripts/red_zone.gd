extends RefCounted
## Enemy AI and boundaries, independent from rendering and offline save data.
const BORDER_X = 1395.0
const SAFE_RETURN_X = 1351.0
const ZONE_ENTRY_X = 1437.0
const MAX_X = 1890.0

var guards: Array = []
var alert_level: float = 0.0
var elapsed: float = 0.0

func reset_guards() -> void:
 guards = [
  {"id":0,"name":"PATROL ICE","kind":"PATROL","pos":Vector2(1530,328),
   "origin":Vector2(1530,328),"axis":Vector2(0,1),"range":108.0,
   "speed":52.0,"sign":1.0,"radius":74.0,"level":1,"defeated":false},
  {"id":1,"name":"SHIELD SENTINEL","kind":"SENTINEL","pos":Vector2(1780,600),
   "origin":Vector2(1780,600),"axis":Vector2(0,1),"range":70.0,
   "speed":30.0,"sign":-1.0,"radius":79.0,"level":2,"defeated":false},
  {"id":2,"name":"RED HUNTER","kind":"HUNTER","pos":Vector2(1730,875),
   "origin":Vector2(1730,875),"axis":Vector2(1,0),"range":98.0,
   "speed":78.0,"sign":1.0,"radius":88.0,"level":3,"defeated":false}
 ]
 var boss_names = ["BAZAAR WARDEN","GHOST LEVIATHAN","CIPHER OVERLORD"]
 for sector in range(3):
  var x: float = 2250.0+float(sector)*1200.0
  for k in range(2):
   var p = Vector2(x+float(k)*230.0,420.0+float(k)*350.0)
   guards.append({"id":guards.size(),"name":"CITY PATROL","kind":"PATROL","pos":p,"origin":p,
    "axis":Vector2(0,1),"range":110.0,"speed":60.0+sector*15.0,"sign":1.0,
    "radius":78.0,"level":mini(5,2+sector+k),"defeated":false})
  var bp = Vector2(x+300.0,960.0)
  guards.append({"id":guards.size(),"name":boss_names[sector],"kind":"BOSS","pos":bp,
   "origin":bp,"axis":Vector2(1,0),"range":100.0,"speed":30.0,"sign":1.0,
   "radius":110.0,"level":3+sector,"defeated":false})

 # Nine extra frontier ICE guards cover the distant mining regions.
 for sector in range(3):
  var gx: float = 6200.0+float(sector)*1320.0
  for k in range(3):
   var loc = Vector2(gx+float(k%2)*310.0,1510.0+float(k)*610.0)
   guards.append({"id":guards.size(),"name":"FRONTIER ICE %d" % (sector+1),
    "kind":"HUNTER" if k==2 else "PATROL","pos":loc,"origin":loc,
    "axis":Vector2(1,0) if k==2 else Vector2(0,1),"range":100.0,
    "speed":65.0+float(sector)*15.0,"sign":1.0,"radius":76.0+float(k)*7.0,
    "level":mini(5,4+sector),"defeated":false})
 alert_level = 0.0
 elapsed = 0.0

func is_crossing_border(start: Vector2, destination: Vector2) -> bool:
 return start.x < BORDER_X and destination.x >= BORDER_X

func is_inside_zone(position: Vector2) -> bool:
 return position.x >= BORDER_X

func tick(delta: float, player: Vector2, has_access: bool) -> int:
 elapsed += delta
 if not has_access:
  return -1
 alert_level = maxf(0.0,alert_level-delta*0.85)
 for i in range(guards.size()):
  var guard: Dictionary = guards[i]
  if bool(guard["defeated"]):
   continue
  var origin: Vector2 = guard["origin"]
  var axis: Vector2 = guard["axis"]
  var position: Vector2 = guard["pos"]
  var offset = (position-origin).dot(axis)
  var sign: float = float(guard["sign"])
  if absf(offset) >= float(guard["range"]):
   sign *= -1.0
  position += axis * sign * float(guard["speed"]) * delta
  if guard["kind"] == "HUNTER" and player.x >= BORDER_X:
   var follow_direction = (player-position).normalized()
   position += follow_direction * minf(35.0*delta,player.distance_to(position))
  position.x = clampf(position.x,BORDER_X+35.0,9500.0)
  guard["pos"] = position
  guard["sign"] = sign
  guards[i] = guard
  if is_inside_zone(player) and position.distance_to(player) < float(guard["radius"]):
   alert_level = minf(100.0,alert_level+18.0)
   return i
 return -1

func defeat(index: int) -> bool:
 if index < 0 or index >= guards.size():
  return false
 if bool(guards[index]["defeated"]):
  return false
 guards[index]["defeated"] = true
 return true

func active_count() -> int:
 var count = 0
 for guard in guards:
  if not bool(guard["defeated"]):
   count += 1
 return count
