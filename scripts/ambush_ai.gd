extends RefCounted
## Cover-aware mesh AI. Traps always telegraph before arming and expire.
const MAX_TRAPS = 18
var traps: Array = []
var events: Array = []

func prepare(enemy: Dictionary,index: int,world: RefCounted) -> void:
 var ambusher: bool = index%3==0 and not bool(enemy["boss"])
 var region: Dictionary=world.region_at(enemy["pos"])
 var sites: Array=[]
 for site in world.ambush_sites:
  var pos: Vector2=site["pos"]
  if pos.x>=float(region["from"])+45 and pos.x<float(region["to"])-45:
   sites.append(site)
 if ambusher and not sites.is_empty():
  enemy["pos"]=sites[index%sites.size()]["pos"]
 else:
  enemy["pos"]=world.find_clear(enemy["pos"])
 enemy["role"] = "LURKER" if ambusher else "PATROL"
 enemy["ai"] = "HIDDEN" if ambusher else "PATROL"
 enemy["origin"] = enemy["pos"]
 enemy["warn"] = 0.0
 enemy["memory"] = 0.0
 enemy["repath"] = 0.0
 enemy["path"] = PackedVector2Array()
 enemy["trap_used"] = false
 enemy["velocity"] = Vector2.ZERO

func update_enemy(enemy: Dictionary,player: Vector2,delta: float,world: RefCounted) -> bool:
 var at: Vector2 = enemy["pos"]
 var distance: float = at.distance_to(player)
 enemy["motion_speed"] = 0.0
 if distance>900:
  return false
 var visible: bool = distance<520 and world.segment_clear(at,player)
 var mode: String = str(enemy["ai"])
 if mode=="HIDDEN":
  # Close-range footsteps can wake an ambusher around a blind corner.
  if distance<175:
   enemy["ai"]="WARNING"
   enemy["warn"]=0.95
   events.append({"kind":"warning","pos":at})
  return false
 if mode=="WARNING":
  enemy["warn"]=maxf(0.0,float(enemy["warn"])-delta)
  if float(enemy["warn"])<=0:
   enemy["ai"]="HUNT"
   enemy["memory"]=7.0
   if traps.size()<MAX_TRAPS:
    # Spawn on the pursuer's walkable tile, never on the player's current tile.
    traps.append({"pos":at,"age":0.0,"armed":false,"spent":false,"life":7.0})
    enemy["trap_used"]=true
  return false
 if visible:
  enemy["memory"]=7.0
  enemy["target"]=player
  enemy["ai"]="HUNT"
 else:
  enemy["memory"]=maxf(0.0,float(enemy["memory"])-delta)
  if float(enemy["memory"])<=0:
   enemy["ai"]="RETURN"
 var target: Vector2 = enemy.get("target",enemy["origin"]) if float(enemy["memory"])>0 else enemy["origin"]
 if at.distance_to(target)>72.0:
  enemy["repath"]=float(enemy["repath"])-delta
  var path: PackedVector2Array=enemy["path"]
  if float(enemy["repath"])<=0:
   path=world.find_route(at,target)
   enemy["repath"]=0.65
  while not path.is_empty() and at.distance_to(path[0])<18.0:
   path.remove_at(0)
  if not path.is_empty():
   var direction: Vector2=(path[0]-at).normalized()
   var speed: float=48.0+float(enemy["rank"])*12.0
   var velocity: Vector2=Vector2(enemy["velocity"]).move_toward(direction*speed,delta*speed*5)
   var next: Vector2=at+velocity*delta
   # Axis separation slides along cover rather than pushing through it.
   if not world.is_blocked(Vector2(next.x,at.y)):
    at.x=next.x
   else:
    velocity.x=0
   if not world.is_blocked(Vector2(at.x,next.y)):
    at.y=next.y
   else:
    velocity.y=0
   enemy["velocity"]=velocity
  enemy["path"]=path
 enemy["motion_speed"]=Vector2(enemy["pos"]).distance_to(at)/maxf(delta,0.001)
 enemy["anim_clock"]=float(enemy.get("anim_clock",0.0))+delta*clampf(float(enemy["motion_speed"])/65.0,0,1)
 enemy["pos"]=at
 enemy["timer"]=float(enemy["timer"])-delta
 if visible and distance<430 and float(enemy["timer"])<=0:
  enemy["timer"]=2.25
  return true
 return false

func update_traps(delta: float,player: Vector2) -> bool:
 var caught: bool = false
 for i in range(traps.size()-1,-1,-1):
  var trap: Dictionary=traps[i]
  trap["age"]=float(trap["age"])+delta
  trap["life"]=float(trap["life"])-delta
  trap["armed"]=float(trap["age"])>=1.0
  if float(trap["life"])<=0:
   traps.remove_at(i)
   continue
  if bool(trap["armed"]) and not bool(trap["spent"]) and Vector2(trap["pos"]).distance_to(player)<37:
   trap["spent"]=true
   trap["life"]=0.35
   caught=true
   events.append({"kind":"snare","pos":trap["pos"]})
 return caught
