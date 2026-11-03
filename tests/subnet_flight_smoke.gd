extends SceneTree
const Flight=preload("res://scripts/subnet_flight.gd")
func _initialize() -> void:call_deferred("_run")
func check(value: bool,message: String) -> bool:
 if not value:
  push_error("CYBERLOAD FLIGHT FAIL: "+message)
  quit(1)
 return value
func _run() -> void:
 var game=Flight.new()
 game.begin(0,31415)
 var initial: float=game.energy
 game.tick(0.1)
 if not check(game.energy==initial,"Energy regenerates without kills"):return
 game.spawn_enemy(Vector2(500,360))
 game.damage_enemy(0,1000)
 if not check(game.kills==1 and game.energy>initial,"Kill does not charge powers"):return
 game.energy=100
 if not check(game.activate_power(0) and game.energy==65,"Shield charge cost wrong"):return
 var hp: float=game.hp
 game.invulnerable=0
 game.take_hit(50)
 if not check(game.hp==hp,"Shield does not absorb damage"):return
 if not check(not game.activate_power(0),"Active power can consume charge twice"):return
 game.shield=0
 game.energy=0
 if not check(not game.activate_power(1),"Uncharged power activated"):return
 for weapon in range(3):
  game.weapon=weapon
  game.shot_delay=0
  game.shots.clear()
  if not check(game.fire() and game.shots.size()==(3 if weapon==1 else 1),"Weapon pattern wrong"):return
  if not check(not game.fire(),"Shot cooldown bypassed"):return
 for bomb in range(3):
  game.begin(0,2718)
  game.bomb_type=bomb
  game.spawn_enemy(Vector2(600,360),"TANK")
  game._shot(Vector2(550,200),Vector2(-200,0),true)
  if not check(game.use_bomb() and game.bombs==2 and game.shots.is_empty(),"Bomb charge/hostile clearing failed"):return
  if bomb==0 and not check(game.enemies.is_empty(),"Logic bomb has no damage"):return
  if bomb==1 and not check(game.emp>0,"EMP does not stun"):return
  if bomb==2:
   for tick in range(240):game.tick(1.0/60)
   if not check(game.kills>0,"Worm damage-over-time failed"):return
 # A shot and the player both collide with gate segments, while the gap stays open.
 game.begin(0,1)
 game.obstacles=[{"x":500.0,"gap":350.0,"size":220.0}]
 game._shot(Vector2(480,180),Vector2(920,0),false)
 game.tick(0.03)
 if not check(game.shots.is_empty(),"Projectile passed through a closed gate segment"):return
 game.ship=Vector2(500,350)
 game.invulnerable=0
 hp=game.hp
 game.tick(0.016)
 if not check(game.hp==hp,"Gate opening damages the player"):return
 # Distinct boss mechanics and their actual damage gates.
 game.begin(0,11)
 game._begin_boss()
 game.tick(0.016)
 hp=game.boss_hp
 game._hit_boss(game.boss_pos,100)
 if not check(game.boss_shield and game.boss_hp==hp,"Aegis shield fails to stop damage"):return
 game.boss_clock=5
 game.tick(0.016)
 game._hit_boss(game.boss_pos,100)
 if not check(game.boss_hp<hp,"Aegis has no vulnerable window"):return
 game.begin(1,12)
 game._begin_boss()
 for attack in range(3):
  game.boss_delay=0
  game.tick(0.016)
 var mirrors: int=0
 for enemy in game.enemies:
  if enemy["kind"]=="MIRROR":mirrors+=1
 if not check(mirrors>=2,"Mirror boss never creates double signatures"):return
 game.begin(2,13)
 game._begin_boss()
 game.tick(0.016)
 hp=game.boss_hp
 game._hit_boss(game.boss_pos,100)
 if not check(game.boss_hp==hp and game.boss_nodes.size()==3,"Hydra core is not protected by three nodes"):return
 for node in range(3):game._hit_boss(game.node_position(node),500)
 game.tick(0.016)
 game._hit_boss(game.boss_pos,100)
 if not check(not game.boss_shield and game.boss_hp<hp,"Hydra core stays locked after nodes die"):return
 # Each long run reaches its boss, keeps memory bounded, and checkpoints restore.
 for id in range(3):
  game.begin(id,500+id)
  for tick in range(13500):
   game.invulnerable=10
   game.tick(1.0/60,Vector2(0,sin(tick*0.014)),true)
   game.events.clear()
   if not check(game.enemies.size()<=Flight.MAX_ENEMIES and game.shots.size()<=Flight.MAX_SHOTS and game.particles.size()<=Flight.MAX_PARTICLES,"Combat arrays grew beyond budget"):return
   if game.phase=="BOSS":break
  if not check(game.phase=="BOSS" and game.checkpoint.get("boss",false),"Long subnet has no boss checkpoint"):return
  var checkpoint: Dictionary=game.checkpoint.duplicate(true)
  var restored=Flight.new()
  if not check(restored.restore(checkpoint) and restored.phase=="BOSS" and restored.id==id and restored.kills==game.kills,"Checkpoint loses run progress"):return
  # Drive actual weapon collisions through a full boss encounter (not a direct win flag).
  restored.invulnerable=10000
  restored.weapon=2
  for tick in range(15000):
   restored.invulnerable=10000
   var target: Vector2=restored.boss_pos
   if id==2:
    for node in range(restored.boss_nodes.size()):
     if float(restored.boss_nodes[node]["hp"])>0:
      target=restored.node_position(node)
      break
   restored.ship.y=clampf(target.y,110,restored.view.y-140)
   restored.tick(1.0/60,Vector2.ZERO,true)
   restored.events.clear()
   if restored.result!="RUNNING":break
  if not check(restored.result=="WIN","Boss cannot be defeated with actual shots: %d" % id):return
  var score: int=restored.score
  restored.tick(1)
  restored._win()
  if not check(restored.score==score,"Boss awards victory more than once"):return
 print("CYBERLOAD FLIGHT PASS: long subnets, three bosses, real weapon victories, bombs, kill charge, collision, checkpoints and bounded combat")
 quit(0)
