extends RefCounted
## Bounded side-scrolling combat simulation. No rendering, audio or filesystem writes.
const NAMES = ["AEGIS TRANSIT", "MIRROR EXPANSE", "HYDRA ROOT"]
const BOSSES = ["AEGIS-9", "MIRROR WRAITH", "ROOT HYDRA"]
const DESCRIPTIONS = ["Schildfenster erkennen und den Lanzen ausweichen.","Doppelganger zerstoren und die echte Signatur finden.","Drei Waffenknoten ausschalten, dann den Kern brechen."]
const WEAPONS = ["PULSE", "SPLITTER", "ION"]
const BOMBS = ["LOGIC", "EMP", "WORM"]
const POWERS = ["SHIELD", "OVERCLOCK", "CHRONO"]
const COSTS = [35.0,50.0,65.0]
const MAX_ENEMIES = 28
const MAX_SHOTS = 220
const MAX_PARTICLES = 120
var view = Vector2(1280,720)
var id: int=0
var seed_value: int=0
var result: String="IDLE"
var phase: String="CRUISE"
var ship = Vector2(220,360)
var velocity = Vector2.ZERO
var hp: float=100.0
var energy: float=25.0
var bombs: int=3
var weapon: int=0
var bomb_type: int=0
var distance: float=0.0
var length: float=18000.0
var clock: float=0.0
var kills: int=0
var score: int=0
var wave: int=0
var next_wave: float=200.0
var next_obstacle: float=1200.0
var checkpoint_sector: int=0
var checkpoint: Dictionary={}
var enemies: Array=[]
var shots: Array=[]
var obstacles: Array=[]
var particles: Array=[]
var lasers: Array=[]
var events: Array=[]
var shot_delay: float=0.0
var invulnerable: float=0.0
var shield: float=0.0
var overclock: float=0.0
var chrono: float=0.0
var emp: float=0.0
var boss_infection: float=0.0
var boss_hp: float=0.0
var boss_max: float=0.0
var boss_clock: float=0.0
var boss_delay: float=1.5
var boss_pos = Vector2(1070,360)
var boss_nodes: Array=[]
var boss_shield: bool=false
var boss_attack: int=0
var notice: String="SPACE / FIRE: FEUERN  //  Q: BOMBE"
var notice_time: float=4.0
var rng = RandomNumberGenerator.new()
var serial: int=0

func begin(subnet_id: int,run_seed: int=-1) -> void:
 id=clampi(subnet_id,0,2)
 if run_seed<0:
  rng.randomize()
  seed_value=int(rng.randi())
 else:seed_value=run_seed
 rng.seed=seed_value
 result="RUNNING"
 phase="CRUISE"
 ship=Vector2(220,view.y*0.5)
 velocity=Vector2.ZERO
 hp=100
 energy=25
 bombs=3
 weapon=0
 bomb_type=0
 distance=0
 length=18000+id*3000
 clock=0
 kills=0
 score=0
 wave=0
 next_wave=200
 next_obstacle=1200
 checkpoint_sector=0
 serial=0
 for collection in [enemies,shots,obstacles,particles,lasers,events,boss_nodes]:collection.clear()
 shot_delay=0
 invulnerable=1.5
 shield=0
 overclock=0
 chrono=0
 emp=0
 boss_infection=0
 boss_hp=0
 boss_max=0
 boss_clock=0
 boss_delay=1.5
 boss_attack=0
 boss_shield=false
 _set_checkpoint()
 _message("SUBNET LINK // "+NAMES[id])

func _message(value: String) -> void:
 notice=value
 notice_time=3.5

func _set_checkpoint() -> void:
 checkpoint={"id":id,"seed":seed_value,"distance":distance,"hp":hp,"energy":energy,
  "bombs":bombs,"weapon":weapon,"bomb_type":bomb_type,"kills":kills,"score":score,
  "wave":wave,"rng_state":str(rng.state),"boss":phase=="BOSS"}
 events.append({"kind":"checkpoint"})

func restore(data: Dictionary) -> bool:
 if not data.has("id") or not data.has("seed"):return false
 begin(clampi(int(data["id"]),0,2),int(data["seed"]))
 distance=clampf(float(data.get("distance",0)),0,length)
 hp=clampf(float(data.get("hp",100)),1,100)
 energy=clampf(float(data.get("energy",25)),0,100)
 bombs=clampi(int(data.get("bombs",3)),0,5)
 weapon=clampi(int(data.get("weapon",0)),0,2)
 bomb_type=clampi(int(data.get("bomb_type",0)),0,2)
 kills=maxi(0,int(data.get("kills",0)))
 score=maxi(0,int(data.get("score",0)))
 wave=maxi(0,int(data.get("wave",0)))
 rng.state=int(str(data.get("rng_state",rng.state)))
 next_wave=distance+160
 next_obstacle=distance+850
 checkpoint_sector=int(distance/4500)
 if bool(data.get("boss",false)) or distance>=length:
  _begin_boss(false)
 _set_checkpoint()
 _message("CHECKPOINT GELADEN // "+NAMES[id])
 return true

func cycle_weapon() -> void:
 weapon=(weapon+1)%WEAPONS.size()
 _message("HACK SHOT // "+WEAPONS[weapon])

func cycle_bomb() -> void:
 bomb_type=(bomb_type+1)%BOMBS.size()
 _message("BOMB HACK // "+BOMBS[bomb_type])

func activate_power(index: int) -> bool:
 if result!="RUNNING" or index<0 or index>=3:return false
 if energy<COSTS[index]:
  _message("ZU WENIG LADUNG // GEGNER ABSCHIESSEN")
  return false
 if (index==0 and shield>0) or (index==1 and overclock>0) or (index==2 and chrono>0):return false
 energy-=COSTS[index]
 match index:
  0:shield=6.0
  1:overclock=6.0
  2:chrono=4.0
 events.append({"kind":"power"})
 _message(POWERS[index]+" // AKTIV")
 return true

func fire() -> bool:
 if result!="RUNNING" or shot_delay>0:return false
 var boost: float=0.52 if overclock>0 else 1.0
 shot_delay=[0.15,0.23,0.38][weapon]*boost
 var damage: float=[14.0,10.0,38.0][weapon]*(1.25 if overclock>0 else 1.0)
 for angle in ([-0.16,0.0,0.16] if weapon==1 else [0.0]):
  _shot(ship+Vector2(30,0),Vector2(920,0).rotated(angle),false,damage,2 if weapon==2 else 0)
 events.append({"kind":"fire"})
 return true

func use_bomb() -> bool:
 if result!="RUNNING" or bombs<=0:return false
 bombs-=1
 for i in range(shots.size()-1,-1,-1):
  if shots[i]["enemy"]:shots.remove_at(i)
 match bomb_type:
  0:
   for i in range(enemies.size()-1,-1,-1):damage_enemy(i,160)
   if phase=="BOSS":
    for node in boss_nodes:node["hp"]=maxf(0,float(node["hp"])-90)
    boss_hp=maxf(0,boss_hp-(55 if boss_shield else 150))
  1:
   emp=3.5
   lasers.clear()
   if phase=="BOSS":boss_hp=maxf(0,boss_hp-40)
  2:
   for enemy in enemies:enemy["infected"]=4.0
   boss_infection=4.0
 burst(ship,"bomb",50)
 events.append({"kind":"bomb"})
 _message(BOMBS[bomb_type]+" // DETONATION")
 return true

func _shot(at: Vector2,speed: Vector2,hostile: bool,damage: float=10,pierce: int=0) -> void:
 if shots.size()>=MAX_SHOTS:return
 shots.append({"pos":at,"vel":speed,"enemy":hostile,"damage":damage,"life":7.0,"pierce":pierce,"hit":{}})

func spawn_enemy(at: Vector2,kind: String="DRONE") -> void:
 if enemies.size()>=MAX_ENEMIES:return
 for obstacle in obstacles:
  if absf(at.x-(float(obstacle["x"])-distance))<100:
   at.y=clampf(at.y,float(obstacle["gap"])-float(obstacle["size"])*0.5+38,float(obstacle["gap"])+float(obstacle["size"])*0.5-38)
 serial+=1
 var health: float=100 if kind=="TANK" else (32 if kind=="MIRROR" else 38+id*9)
 enemies.append({"id":serial,"pos":at,"origin_y":at.y,"hp":health,"max":health,"kind":kind,
  "age":0.0,"fire":rng.randf_range(1.3,2.6),"infected":0.0})

func damage_enemy(index: int,damage: float) -> void:
 if index<0 or index>=enemies.size():return
 enemies[index]["hp"]=float(enemies[index]["hp"])-damage
 if float(enemies[index]["hp"])>0:return
 var dead: Dictionary=enemies[index]
 enemies.remove_at(index)
 kills+=1
 score+=180 if dead["kind"]=="TANK" else 80
 energy=minf(100,energy+(22 if dead["kind"]=="TANK" else 12))
 if kills%12==0:bombs=mini(5,bombs+1)
 if kills%8==0:hp=minf(100,hp+8)
 burst(dead["pos"],"enemy",12)
 events.append({"kind":"kill"})

func take_hit(damage: float) -> void:
 if result!="RUNNING" or invulnerable>0 or shield>0:return
 hp=maxf(0,hp-damage)
 invulnerable=0.9
 burst(ship,"hit",15)
 events.append({"kind":"hit"})
 if hp<=0:
  result="LOSE"
  _message("VERBINDUNG VERLOREN // CHECKPOINT BEREIT")

func tick(delta: float,direction: Vector2=Vector2.ZERO,shooting: bool=false) -> void:
 if result!="RUNNING":return
 var count: int=maxi(1,int(ceil(minf(maxf(delta,0),0.1)*60)))
 for i in range(count):
  if result!="RUNNING":break
  _step(minf(maxf(delta,0),0.1)/count,direction.limit_length(),shooting)

func _step(dt: float,direction: Vector2,shooting: bool) -> void:
 clock+=dt
 notice_time=maxf(0,notice_time-dt)
 shot_delay=maxf(0,shot_delay-dt)
 invulnerable=maxf(0,invulnerable-dt)
 shield=maxf(0,shield-dt)
 overclock=maxf(0,overclock-dt)
 chrono=maxf(0,chrono-dt)
 emp=maxf(0,emp-dt)
 boss_infection=maxf(0,boss_infection-dt)
 velocity=velocity.lerp(direction*330,1-exp(-dt*11))
 ship+=velocity*dt
 ship=ship.clamp(Vector2(48,110),Vector2(view.x*0.64,view.y-140))
 if shooting:fire()
 var hostile_dt: float=dt*(0.42 if chrono>0 else 1.0)
 if phase=="CRUISE":
  distance=minf(length,distance+dt*(132+id*9))
  if distance>=next_wave:
   _spawn_wave()
   next_wave+=rng.randf_range(620,850)
  if distance>=next_obstacle:
   _spawn_obstacle()
   next_obstacle+=rng.randf_range(1700,2300)
  var sector: int=int(distance/4500)
  if sector>checkpoint_sector and distance<length:
   checkpoint_sector=sector
   _set_checkpoint()
   _message("CHECKPOINT // SEKTOR %d" % (sector+1))
  if distance>=length:_begin_boss()
 else:
  _tick_boss(hostile_dt)
 for i in range(enemies.size()-1,-1,-1):
  if i>=enemies.size():continue
  var enemy: Dictionary=enemies[i]
  enemy["age"]=float(enemy["age"])+hostile_dt
  var at: Vector2=enemy["pos"]
  if emp<=0:
   at.x-=(82 if enemy["kind"]=="TANK" else 140+id*15)*hostile_dt
   var desired_y: float=float(enemy["origin_y"])
   if enemy["kind"]!="TANK":desired_y+=sin(float(enemy["age"])*2.5)*42
   for obstacle in obstacles:
    var wall_x: float=float(obstacle["x"])-distance
    if at.x>wall_x-55 and at.x<wall_x+290:
     desired_y=clampf(desired_y,float(obstacle["gap"])-float(obstacle["size"])*0.5+38,float(obstacle["gap"])+float(obstacle["size"])*0.5-38)
     if at.x<wall_x+65 and absf(at.y-float(obstacle["gap"]))>float(obstacle["size"])*0.5-32:
      at.x=wall_x+65
   at.y=move_toward(at.y,desired_y,hostile_dt*190)
  enemy["pos"]=at
  if float(enemy["infected"])>0:
   enemy["infected"]=maxf(0,float(enemy["infected"])-dt)
   damage_enemy(i,dt*28)
   if i>=enemies.size() or enemies[i]!=enemy:continue
  if at.x< -80:
   enemies.remove_at(i)
   continue
  enemy["fire"]=float(enemy["fire"])-hostile_dt
  if float(enemy["fire"])<=0 and at.x<view.x-30 and emp<=0:
   enemy["fire"]=2.4
   _shot(at,(ship-at).normalized()*(230+id*20),true,10)
  if at.distance_to(ship)<40:
   take_hit(18)
   enemies.remove_at(i)
 for i in range(obstacles.size()-1,-1,-1):
  var obstacle: Dictionary=obstacles[i]
  var x: float=float(obstacle["x"])-distance
  if x< -110:
   obstacles.remove_at(i)
   continue
  if absf(ship.x-x)<52 and absf(ship.y-float(obstacle["gap"]))>float(obstacle["size"])*0.5-22:
   take_hit(14)
   ship.x=maxf(48,ship.x-35)
 for i in range(lasers.size()-1,-1,-1):
  var laser: Dictionary=lasers[i]
  laser["age"]=float(laser["age"])+hostile_dt
  if float(laser["age"])>1.5:
   lasers.remove_at(i)
  elif float(laser["age"])>=1.05 and absf(ship.y-float(laser["y"]))<22:
   take_hit(20)
 for i in range(shots.size()-1,-1,-1):
  var shot: Dictionary=shots[i]
  var at: Vector2=shot["pos"]
  at+=Vector2(shot["vel"])*(hostile_dt if shot["enemy"] else dt)
  shot["pos"]=at
  shot["life"]=float(shot["life"])-dt
  var removed: bool=at.x< -90 or at.x>view.x+120 or at.y<60 or at.y>view.y-70 or float(shot["life"])<=0
  # The same blocks stop both hostile and friendly projectiles.
  if not removed:
   for obstacle in obstacles:
    if absf(at.x-(float(obstacle["x"])-distance))<44 and absf(at.y-float(obstacle["gap"]))>float(obstacle["size"])*0.5:
     removed=true
     break
  if not removed and shot["enemy"]:
   if at.distance_to(ship)<20:
    take_hit(float(shot["damage"]))
    removed=true
  elif not removed:
   for k in range(enemies.size()-1,-1,-1):
    var enemy: Dictionary=enemies[k]
    if shot["hit"].has(enemy["id"]) or Vector2(enemy["pos"]).distance_to(at)>29:continue
    shot["hit"][enemy["id"]]=true
    damage_enemy(k,float(shot["damage"]))
    shot["pierce"]=int(shot["pierce"])-1
    removed=int(shot["pierce"])<0
    break
   if not removed and phase=="BOSS" and _hit_boss(at,float(shot["damage"])):removed=true
  if removed:shots.remove_at(i)
 for i in range(particles.size()-1,-1,-1):
  var part: Dictionary=particles[i]
  part["age"]=float(part["age"])+dt
  part["pos"]=Vector2(part["pos"])+Vector2(part["vel"])*dt
  part["vel"]=Vector2(part["vel"])*exp(-dt*2)
  if float(part["age"])>0.7:particles.remove_at(i)
 if phase=="BOSS" and boss_hp<=0:_win()

func _spawn_wave() -> void:
 wave+=1
 var y: float=rng.randf_range(160,view.y-200)
 for i in range(3+wave%3):
  var at=Vector2(view.x+50+i*100,clampf(y+sin(i*1.7)*100,135,view.y-160))
  spawn_enemy(at,"TANK" if wave%5==0 and i==0 else "DRONE")
 if wave%4==0:_message("HOSTILE WAVE %02d // LADUNG DURCH ABSCHUSSE" % wave)

func _spawn_obstacle() -> void:
 var gap: float=rng.randf_range(215,view.y-235)
 obstacles.append({"x":distance+view.x+100,"gap":gap,"size":220.0})

func _begin_boss(heal: bool=true) -> void:
 phase="BOSS"
 distance=length
 enemies.clear()
 shots.clear()
 obstacles.clear()
 lasers.clear()
 boss_max=900+id*300
 boss_hp=boss_max
 boss_clock=0
 boss_delay=2.0
 boss_pos=Vector2(view.x-185,view.y*0.5)
 boss_nodes.clear()
 if id==2:
  for i in range(3):boss_nodes.append({"hp":140.0,"offset":Vector2(-55,(i-1)*112)})
 if heal:hp=minf(100,hp+25)
 invulnerable=1.5
 _tick_boss(0.0)
 _set_checkpoint()
 events.append({"kind":"boss"})
 _message("BOSS LINK // "+BOSSES[id])

func node_position(index: int) -> Vector2:
 return boss_pos+Vector2(boss_nodes[index]["offset"])

func _hit_boss(at: Vector2,damage: float) -> bool:
 if id==2:
  for i in range(boss_nodes.size()):
   if float(boss_nodes[i]["hp"])>0 and at.distance_to(node_position(i))<36:
    boss_nodes[i]["hp"]=maxf(0,float(boss_nodes[i]["hp"])-damage)
    if float(boss_nodes[i]["hp"])<=0:burst(node_position(i),"enemy",18)
    return true
 if at.distance_to(boss_pos)>68:return false
 if not boss_shield:boss_hp=maxf(0,boss_hp-damage)
 return true

func _tick_boss(dt: float) -> void:
 boss_clock+=dt
 var rage: bool=boss_hp<boss_max*0.35
 boss_pos.x=view.x-185
 boss_pos.y=view.y*0.5+sin(boss_clock*(0.65 if id!=1 else 1.3))*minf(125,view.y*0.18)
 boss_shield=id==0 and fmod(boss_clock,8.0)<4.2 and emp<=0
 if id==2:
  boss_shield=false
  for node in boss_nodes:
   if float(node["hp"])>0:boss_shield=true
 if boss_infection>0 and not boss_shield:boss_hp=maxf(0,boss_hp-dt*24)
 if emp>0:return
 boss_delay-=dt
 if boss_delay>0:return
 boss_delay=(1.45 if rage else 2.1)
 boss_attack+=1
 match id:
  0:
   if boss_attack%3==0:
    lasers.append({"y":ship.y,"age":0.0})
    _message("AEGIS: LANZE // WARNLINIE VERLASSEN")
   else:
    for i in range(7):_shot(boss_pos,Vector2.LEFT.rotated((i-3)*0.16)*250,true,12)
   if not boss_shield:_message("AEGIS: SCHILDFENSTER OFFEN")
  1:
   for i in range(5):_shot(boss_pos,(ship-boss_pos).normalized().rotated((i-2)*0.13)*260,true,11)
   if boss_attack%3==0:
    for y in [165.0,view.y-185]:spawn_enemy(Vector2(view.x-265,y),"MIRROR")
    _message("MIRROR: DOPPELGANGER // DIE HELLE SIGNATUR IST ECHT")
  2:
   for i in range(boss_nodes.size()):
    if float(boss_nodes[i]["hp"])>0:
     var at: Vector2=node_position(i)
     _shot(at,(ship-at).normalized()*240,true,12)
   if boss_attack%3==0:
    lasers.append({"y":view.y*0.32,"age":0.0})
    lasers.append({"y":view.y*0.71,"age":0.0})
    _message("HYDRA: KNOTEN BRECHEN // MITTLERE GASSE FREIHALTEN")
   if not boss_shield:
    for i in range(9):_shot(boss_pos,Vector2.LEFT.rotated((i-4)*0.13)*255,true,12)
 if rage and boss_attack%3==1:spawn_enemy(Vector2(view.x-230,160))

func burst(at: Vector2,kind: String,count: int=16) -> void:
 for i in range(mini(count,MAX_PARTICLES)):
  if particles.size()>=MAX_PARTICLES:particles.pop_front()
  particles.append({"pos":at,"vel":Vector2.RIGHT.rotated(rng.randf_range(-PI,PI))*rng.randf_range(60,270),"age":0.0,"kind":kind})

func _win() -> void:
 if result!="RUNNING":return
 result="WIN"
 score+=2000+id*1000
 burst(boss_pos,"bomb",70)
 shots.clear()
 enemies.clear()
 lasers.clear()
 events.append({"kind":"victory"})
 _message("SUBNET GESICHERT // "+BOSSES[id]+" OFFLINE")
