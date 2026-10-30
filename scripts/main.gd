extends Node2D
## CYBERLOAD // NET.RUNNER v0.3 - offline 2D cyberworld, procedural graphics
## World rendering is separated from saved RPG state (game_state.gd).
const GameState = preload("res://scripts/game_state.gd")
const RhythmCombat = preload("res://scripts/rhythm_combat.gd")
const FxSystem = preload("res://scripts/fx_system.gd")
const RedZone = preload("res://scripts/red_zone.gd")
const OpenWorld = preload("res://scripts/open_world.gd")
const DungeonInstance = preload("res://scripts/dungeon_instance.gd")
const MeshCreature = preload("res://scripts/mesh_creature.gd")
const CYAN = Color("#50E8FF")
const LIME = Color("#D0F96C")
const PINK = Color("#FF3F73")
const VIOLET = Color("#B887FF")
const BG = Color("#050C17")
const TILE = 64.0
const MAZE = [
 "###############",
 "#.....#.......#",
 "#.###.#.#####.#",
 "#.#...#...#...#",
 "#.#.#####.#.###",
 "#...#.....#...#",
 "###.#.#######.#",
 "#...#.........#",
 "#.###########.#",
 "#.............#",
 "###############"
]
const CODE_VALUES = ["1C", "55", "7A", "BD", "E9"]
const HACK_NAMES = ["GHOST ACCESS","ICE OVERRIDE","DATA LEACH"]
const DARK_PACKETS = [
 Vector2(3.5 * TILE, 1.5 * TILE),
 Vector2(5.5 * TILE, 9.5 * TILE),
 Vector2(11.5 * TILE, 7.5 * TILE)
]
const EXIT_POS = Vector2(13.5 * TILE, 9.5 * TILE)
const WORLD_SIZE = OpenWorld.SIZE
const GATE_POS = Vector2(1490, 550)
const HOME_PORTAL_POS = Vector2(175, 550)
const BASE_SIZE = Vector2(1440, 1000)
const BASE_SPAWN = Vector2(720, 690)
const ICE_DUEL_POS = Vector2(1660, 990)

var state = GameState.new()
var player = HOME_PORTAL_POS + Vector2(150, 0)
var base_player = BASE_SPAWN
var dark_player = Vector2(1.5 * TILE, 1.5 * TILE)
var world_mode: int = 2 # 0 Withnet, 1 Darknet, 2 Homebase, 3 Dungeon
var nodes: Array = []
var base_nodes: Array = []
var orbs: Array = []
var dark_loot: Dictionary = {}
var dark_collected: int = 0
var hunter = Vector2(12.5 * TILE, 9.5 * TILE)
var hunter_direction: float = -1.0
var hunter_cooldown: float = 0.0
var breach_open: bool = false
var node_open: bool = false
var selected_node: int = -1
var journal_open: bool = false
var matrix: Array = []
var hack_targets: Array = []
var hack_rng = RandomNumberGenerator.new()
var last_hack_signature: String = ""
var buffer: Array = []
var breach_timer: float = 0.0
var ice_open: bool = false
var joystick: Vector2 = Vector2.ZERO
var joystick_touch: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var status: String = "WELCOME TO THE WITHNET"
var notification_timer: float = 5.0
var elapsed: float = 0.0
var player_trail: Array = []
var camera_offset = Vector2.ZERO
var font: Font
var duel = RhythmCombat.new()
var duel_active: bool = false
var duel_training: bool = false
var duel_from_darknet: bool = false
var hunter_disabled: bool = false
var overlay_mode: String = ""
var selected_program: int = 0
var selected_module: int = 0
var last_combat_message: String = ""
var red_zone = RedZone.new()
var zone_access: bool = false
var breach_target: String = "GATE"
var red_guard_index: int = -1
var guard_cooldown: float = 0.0
var signal_mines: Array = []
var jam_remaining: float = 0.0
var mine_duel: bool = false
var fx = FxSystem.new()
var net_walls: Array = []
var open_world = OpenWorld.new()
var dungeon = DungeonInstance.new()
var dungeon_player: Vector2 = Vector2.ZERO
var dungeon_return: Vector2 = Vector2.ZERO
var dungeon_id: int = -1
var dungeon_guard_index: int = -1
var dungeon_duel: bool = false
var dungeon_guard_cooldown: float = 0.0
var runner_mesh = MeshCreature.new()
var mesh_enemies: Array = []
var mesh_shots: Array = []
var mesh_wrecks: Array = []
var mesh_fire_delay: float = 0.0
var mesh_direction: Vector2 = Vector2.RIGHT
var mesh_velocity: Vector2 = Vector2.ZERO
var mesh_observed_pos: Vector2 = Vector2.ZERO
var mesh_heading: float = 0.0
var mesh_angular_velocity: float = 0.0
var mesh_lean: float = 0.0
var mesh_step_phase: float = 0.0
var mesh_last_mode: int = -1
var mesh_hit_impulse: Vector2 = Vector2.ZERO
var mesh_selected: int = 0
var mesh_loot_index: int = -1
var mesh_loot_active: bool = false
var duel_burst_done: bool = false
var trail_spark_clock: float = 0.0
var dev_overkill: bool = false
var dev_key_buffer: String = ""
var dev_taps: int = 0
var dev_tap_deadline: float = 0.0
const DEV_CODE = "OVERKILL"

func _ready() -> void:
 font = ThemeDB.fallback_font
 state.load_game()
 runner_mesh.setup_saved(state.mesh_cells,state.mesh_mode,state.mesh_level)
 mesh_observed_pos = player
 _init_nodes()
 var landmarks: Array = []
 for n in nodes:
  landmarks.append(n["pos"])
 open_world.generate(landmarks)
 _mesh_spawn()
 _init_net_architecture()
 _init_base_nodes()
 _init_orbs()
 _init_matrix()
 if state.breaches > 0:
  ice_open = true
 _reset_darknet()
 red_zone.reset_guards()
 _notify("HOMEBASE ONLINE  //  CONNECT TO UPLINK")

func _init_nodes() -> void:
 # Three recognizable districts. The public map remains free-roaming.
 nodes = [
  {"pos":Vector2(430,300), "kind":"DATA", "name":"NODE // 00", "details":"Archive cache. Extract encrypted data packets.", "color":LIME},
  {"pos":Vector2(430,820), "kind":"SCAN", "name":"NODE // 01", "details":"Pulse scanner. Reveal hidden network traffic.", "color":CYAN},
  {"pos":Vector2(780,300), "kind":"UPGRADE", "name":"NODE // 02", "details":"Improve buffer size or movement speed.", "color":LIME},
  {"pos":Vector2(780,820), "kind":"MARKET", "name":"NODE // 03", "details":"Black-market utilities and trace removal.", "color":VIOLET},
  {"pos":Vector2(1140,300), "kind":"MISSION", "name":"NODE // 04", "details":"Encrypted contracts and mission rewards.", "color":LIME},
  {"pos":Vector2(1140,820), "kind":"RELAY", "name":"NODE // 05", "details":"Restore integrity or jump back to base.", "color":CYAN},
  {"pos":Vector2(1710,820), "kind":"ANOMALY", "name":"NODE // 06", "details":"Unstable data rift. High risk, high reward.", "color":PINK},
  {"pos":Vector2(1710,300), "kind":"VAULT", "name":"GHOST // 07", "details":"Hidden encrypted cache discovered by scan.", "color":LIME, "hidden":true},
  {"pos":ICE_DUEL_POS, "kind":"COMBAT", "name":"ICE // ARENA", "details":"Initiate a rhythm upload battle against defensive ICE.", "color":PINK}
 ]
 var cities = ["NEON BAZAAR","GHOST PORT","CIPHER CITADEL"]
 for i in range(cities.size()):
  var cx: float = 2450.0+float(i)*1200.0
  nodes.append({"pos":Vector2(cx,340),"kind":"DATACITY","name":cities[i],"details":"Discover a new data city.", "color":VIOLET,"city":i})
  nodes.append({"pos":Vector2(cx,820),"kind":"DATAMARKET","name":"DATA MARKET %02d" % i,"details":"Buy field repairs and trace scrubbers.", "color":LIME,"city":i})
 signal_mines.clear()
 for i in range(9):
  signal_mines.append({"pos":Vector2(2140.0+float(i)*370.0,[480.0,690.0,400.0][i%3]),"active":true})
 var frontier = ["GLASS WASTES","ZERO GRAVE","OBSIDIAN CORE"]
 for i in range(3):
  var x: float = 6270.0+float(i)*1250.0
  nodes.append({"pos":Vector2(x,1360),"kind":"DATACITY","name":frontier[i],"details":"Frontier data city.","color":LIME,"city":i+3})
  nodes.append({"pos":Vector2(x,2420),"kind":"DATAMARKET","name":"FRONTIER MARKET %02d" % (i+3),"details":"Trade in the outer zones.","color":VIOLET,"city":i+3})
 for i in range(3):
  nodes.append({"pos":Vector2([840.0,3610.0,7390.0][i],[1320.0,2670.0,1480.0][i]),
   "kind":"MINING_RIG","name":"EXTRACTOR %02d" % i,"details":"Drill upgrades and ore selling.","color":CYAN})

func _update_signal_mines(delta: float) -> void:
 jam_remaining = maxf(0.0,jam_remaining-delta)
 if not _has_red_zone_access() or duel_active:
  return
 for i in range(signal_mines.size()):
  var mine: Dictionary = signal_mines[i]
  if bool(mine["active"]) and player.distance_to(mine["pos"]) < 62.0:
   mine["active"] = false
   signal_mines[i] = mine
   mine_duel = true
   fx.burst(mine["pos"],"damage",false,28)
   fx.impact(9.0,0.27)
   red_guard_index = -1
   _start_duel(false,false)
   duel.level = mini(5,2+int(i/3))
   _notify("SIGNAL MINE // DEFEND TO KEEP VISION")
   return

func _draw_signal_jam(canvas: Vector2) -> void:
 if world_mode != 0 or jam_remaining <= 0.0:
  return
 var center: Vector2 = canvas*0.5
 var radius: float = 135.0
 var shade = Color(0.0,0.02,0.06,0.97)
 draw_rect(Rect2(0,0,canvas.x,maxf(0.0,center.y-radius)),shade)
 draw_rect(Rect2(0,center.y+radius,canvas.x,canvas.y),shade)
 draw_rect(Rect2(0,center.y-radius,maxf(0.0,center.x-radius),radius*2.0),shade)
 draw_rect(Rect2(center.x+radius,center.y-radius,canvas.x,radius*2.0),shade)
 draw_arc(center,radius,0,TAU,80,PINK,3)

func _init_net_architecture() -> void:
 # Solid pixel walls; never obstruct the data highway or terminals.
 net_walls.clear()
 var bands: Array = [Vector2(285,925),Vector2(965,1360),Vector2(1410,1835),Vector2(2050,2970),Vector2(3050,3970),Vector2(4050,5415)]
 var colors: Array = [CYAN,LIME,PINK,VIOLET,CYAN,PINK]
 for sector in range(bands.size()):
  var band: Vector2 = bands[sector]
  for i in range(9):
   var wx: float = band.x+60.0+float(i)*(band.y-band.x-180.0)/9.0
   var wy: float = 183.0 if i%2 == 0 else (978.0 if i%3 == 0 else 715.0)
   var rect = Rect2(wx,wy,88.0,36.0)
   if _wall_clear_of_nodes(rect):
    net_walls.append({"rect":rect,"color":colors[sector]})

func _wall_clear_of_nodes(rect: Rect2) -> bool:
 for node in nodes:
  if rect.grow(120.0).has_point(node["pos"]):
   return false
 return not rect.grow(105.0).has_point(GATE_POS) and not rect.grow(105.0).has_point(HOME_PORTAL_POS)

func _world_wall_collision(pos: Vector2) -> bool:
 for wall in net_walls:
  var rect: Rect2 = wall["rect"]
  if rect.grow(13.0).has_point(pos):
   return true
 return open_world.is_blocked(pos)

func _power_tier() -> int:
 var power: int = state.speed_level+state.scan_level+state.clearance_level+state.installed_modules.size()+int(state.ice_wins/3.0)
 return 3 if power >= 13 else (2 if power >= 8 else (1 if power >= 3 else 0))

func _draw_runner_trail(focus: Vector2) -> void:
 var tier: int = _power_tier()
 for i in range(player_trail.size()-1,-1,-1):
  var fraction: float = 1.0-float(i)/maxf(1.0,float(player_trail.size()))
  var tint: Color = CYAN
  if tier == 1:
   tint = CYAN.lerp(LIME,float(i)/maxf(1.0,float(player_trail.size())))
  elif tier == 2:
   tint = CYAN.lerp(VIOLET,float(i)/maxf(1.0,float(player_trail.size())))
  elif tier == 3:
   tint = VIOLET.lerp(PINK,0.5+sin(elapsed*7.0+float(i))*0.35)
  var radius: float = 3.0+fraction*(4.0+float(tier)*3.0)
  draw_circle(player_trail[i],radius,Color(tint.r,tint.g,tint.b,fraction*(0.25+tier*0.15)))
  if tier >= 2 and i%4 == 0:
   draw_rect(Rect2(player_trail[i]-Vector2(radius*0.5,radius*0.5),Vector2(radius,radius)),Color(tint.r,tint.g,tint.b,fraction*0.6))
 var core: Color = PINK if dev_overkill else (VIOLET if tier >= 3 else CYAN)
 _glow(focus,core,12.0+tier*3.0+sin(elapsed*7.0)*2.0)
 draw_arc(focus,27.0+tier*3.0,0,TAU,42,core,2.0+tier*0.5)
 if tier >= 3:
  draw_arc(focus,38.0+sin(elapsed*5.0)*4.0,elapsed,elapsed+PI*1.6,42,LIME,2.0)

func _draw_pixel_architecture() -> void:
 for wall in net_walls:
  var rect: Rect2 = wall["rect"]
  if absf(rect.get_center().x-player.x)>920.0:
   continue
  var tint: Color = wall["color"]
  draw_rect(rect,Color("#081827"))
  draw_rect(rect,Color(tint.r,tint.g,tint.b,0.75),false,2.0)
  for i in range(0,int(rect.size.x)-12,18):
   var by: float = 5.0+float(int(i/18)%2)*11.0
   draw_rect(Rect2(rect.position+Vector2(i+3,by),Vector2(14,9)),Color(tint.r,tint.g,tint.b,0.28))
 # Flickering circuitry at the edge of every district.
 var starts: Array = [300.0,980.0,1420.0,2070.0,3070.0,4070.0]
 for s in starts:
  if absf(float(s)-player.x)>1700.0:
   continue
  for i in range(11):
   var px: float = float(s)+float(i)*96.0
   var py: float = 164.0 if i%2 == 0 else 1041.0
   draw_rect(Rect2(px,py,30,10),Color(0.18,0.77,0.96,0.25+0.18*sin(elapsed*2.0+i)))

func _draw_fx(screen_space: bool) -> void:
 for pulse in fx.pulses:
  if bool(pulse["screen"]) != screen_space:
   continue
  var t: float = float(pulse["age"])/float(pulse["duration"])
  var tint: Color = fx.tint(str(pulse["kind"]),t)
  draw_arc(pulse["pos"],12.0+t*84.0,0,TAU,52,Color(tint.r,tint.g,tint.b,(1.0-t)*0.70),2.0)
 for part in fx.particles:
  if bool(part["screen"]) != screen_space:
   continue
  var t: float = clampf(1.0-float(part["life"])/float(part["max_life"]),0.0,1.0)
  var tint: Color = fx.tint(str(part["kind"]),t)
  var size: float = maxf(1.0,float(part["size"])*(1.0-t*0.75))
  draw_rect(Rect2(Vector2(part["pos"])-Vector2(size*0.5,size*0.5),Vector2(size,size)),Color(tint.r,tint.g,tint.b,(1.0-t)*0.96))

func _draw_fx_flash(canvas: Vector2) -> void:
 if fx.flash_time > 0.0 and fx.flash_max > 0.0:
  var opacity: float = 0.18*fx.flash_time/fx.flash_max
  draw_rect(Rect2(Vector2.ZERO,canvas),Color(fx.flash_color.r,fx.flash_color.g,fx.flash_color.b,opacity))

func _mesh_spawn() -> void:
 mesh_enemies.clear()
 for i in range(56):
  var region: Dictionary=OpenWorld.REGIONS[mini(7,int(i/7))]
  var at=Vector2(float(region["from"])+160.0+float(i%7)*115.0,1050.0+float(i%4)*405.0)
  var rank: int=mini(5,1+int(i/12))
  var form=MeshCreature.new()
  form.setup_saved(MeshCreature.enemy_blueprint(i,rank),"CRAWL",15)
  var boss: bool=i%7==6
  var hp: float=(85.0+rank*38.0)*(3.0 if boss else 1.0)
  mesh_enemies.append({"pos":at,"hp":hp,"max":hp,"rank":rank,"cells":form.cells.duplicate(true),"alive":true,"timer":2.0,"boss":boss})

func _mesh_fire() -> void:
 if world_mode!=0 or mesh_fire_delay>0.0 or overlay_mode!="" or duel_active:
  return
 mesh_fire_delay=0.3
 var direction: Vector2=mesh_direction
 var closest: float=500.0
 for enemy in mesh_enemies:
  if bool(enemy["alive"]):
   var offset: Vector2=Vector2(enemy["pos"])-player
   if offset.length()<closest:
    closest=offset.length()
    direction=offset.normalized()
 mesh_shots.append({"pos":player,"vel":direction*700.0,"damage":float(runner_mesh.stats()["damage"]),"life":1.1,"enemy":false})
 fx.burst(player,"upgrade",false,6)

func _mesh_update(delta: float) -> void:
 mesh_fire_delay=maxf(0.0,mesh_fire_delay-delta)
 # Drive the motion from actual player displacement, not only desired velocity.
 # Also animate in the homebase and dungeons when the player physically moves.
 var observed: float = player.distance_to(mesh_observed_pos)/maxf(delta,0.001)
 runner_mesh.set_motion(observed if world_mode==0 else 0.0,delta)
 mesh_observed_pos=player
 for k in range(mesh_enemies.size()):
  var e: Dictionary=mesh_enemies[k]
  if not bool(e["alive"]):
   continue
  var p: Vector2=e["pos"]
  var distance: float=p.distance_to(player)
  e["motion_speed"]=0.0
  e["anim_clock"]=float(e.get("anim_clock",0.0))
  if distance>900.0:
   continue
  if distance<500.0 and distance>95.0:
   var next: Vector2=p+(player-p).normalized()*delta*(48.0+float(e["rank"])*11.0)
   if not _world_wall_collision(next):
    e["pos"]=next
    e["motion_speed"]=(next-p).length()/maxf(delta,0.001)
    e["anim_clock"]=float(e["anim_clock"])+delta
  e["timer"]=float(e["timer"])-delta
  if distance<430.0 and float(e["timer"])<=0.0:
   e["timer"]=2.2
   mesh_shots.append({"pos":e["pos"],"vel":(player-Vector2(e["pos"])).normalized()*280.0,
    "damage":8.0+float(e["rank"]),"life":2.0,"enemy":true})
  mesh_enemies[k]=e
 for i in range(mesh_shots.size()-1,-1,-1):
  var shot: Dictionary=mesh_shots[i]
  shot["pos"]=Vector2(shot["pos"])+Vector2(shot["vel"])*delta
  shot["life"]=float(shot["life"])-delta
  var p: Vector2=shot["pos"]
  var hit: bool=float(shot["life"])<=0.0 or _world_wall_collision(p)
  if not hit and bool(shot["enemy"]) and p.distance_to(player)<25.0:
   state.integrity=maxf(1.0,state.integrity-float(shot["damage"]))
   mesh_hit_impulse+=Vector2(shot["vel"]).normalized()*105.0
   fx.impact(4.5,0.12)
   fx.burst(p,"damage",false,9)
   hit=true
  elif not hit and not bool(shot["enemy"]):
   for k in range(mesh_enemies.size()):
    var e: Dictionary=mesh_enemies[k]
    if not bool(e["alive"]) or Vector2(e["pos"]).distance_to(p)>38.0:
     continue
    e["hp"]=float(e["hp"])-float(shot["damage"])
    fx.burst(p,"damage",false,8)
    if float(e["hp"])<=0.0:
     e["alive"]=false
     mesh_wrecks.append({"pos":e["pos"],"rank":e["rank"]})
     fx.burst(p,"ice",false,28)
     _notify("ICE DISABLED // HACK CORE TO CLAIM LOOT")
    mesh_enemies[k]=e
    hit=true
    break
  if hit:
   if not bool(shot["enemy"]):
    fx.burst(p,"upgrade",false,3)
   mesh_shots.remove_at(i)
  else:
   mesh_shots[i]=shot

func _mesh_nearest_wreck() -> int:
 for i in range(mesh_wrecks.size()):
  if player.distance_to(mesh_wrecks[i]["pos"])<90.0:
   return i
 return -1

func _mesh_finish_loot(won: bool) -> void:
 var index: int=mesh_loot_index
 mesh_loot_index=-1
 mesh_loot_active=false
 if index<0 or index>=mesh_wrecks.size():
  return
 if won:
  var rank: int=int(mesh_wrecks[index]["rank"])
  state.credits+=50+rank*30
  state.fragments+=3+rank*3
  state.mesh_kills+=1
  if state.award_mesh_xp(50+rank*42):
   runner_mesh.level=state.mesh_level
   _notify("MESH LEVEL UP // ADD MORE BLOCKS")
  else:
   _notify("CORE HACKED // CREDITS + DATA + XP")
  mesh_wrecks.remove_at(index)
 else:
  _notify("CORE HACK FAILED // TRY AGAIN")
 state.save_game()

func _mesh_edit(point: Vector2,canvas: Vector2) -> void:
 var box=Rect2(canvas*0.5-Vector2(390,245),Vector2(780,490))
 if not box.has_point(point):
  overlay_mode=""
  return
 var local: Vector2=point-box.position
 if local.y>425.0:
  if local.x<250.0:
   var old_mode: String=runner_mesh.mode
   var next_mode: String=MeshCreature.MODES[(MeshCreature.MODES.find(old_mode)+1)%MeshCreature.MODES.size()]
   runner_mesh.mode=next_mode
   # A new basic chassis is offered only if the runner still uses the initial starter.
   if runner_mesh.cells.size()==3 and runner_mesh.parts_count("CORE")==1:
    var default_parts: int=runner_mesh.parts_count("LEG")+runner_mesh.parts_count("FIN")+runner_mesh.parts_count("THRUSTER")
    if default_parts==2:
     runner_mesh.setup_saved([],next_mode,runner_mesh.level)
   mesh_velocity=Vector2.ZERO
   mesh_hit_impulse=Vector2.ZERO
  elif local.x<505.0:
   mesh_selected=(mesh_selected+1)%(MeshCreature.TYPES.size()-1)
  else:
   overlay_mode=""
 elif local.y<65.0 and local.x>650.0:
  overlay_mode=""
 else:
  var cell=Vector2i(roundi((local.x-390.0)/36.0),roundi((local.y-245.0)/36.0))
  if cell!=Vector2i.ZERO:
   if runner_mesh.occupied(cell):
    runner_mesh.remove_block(cell)
   else:
    runner_mesh.add_block(cell,MeshCreature.TYPES[mesh_selected+1])
 state.mesh_cells=runner_mesh.cells.duplicate(true)
 state.mesh_mode=runner_mesh.mode
 state.save_game()

func _mesh_draw_editor(canvas: Vector2) -> void:
 draw_rect(Rect2(Vector2.ZERO,canvas),Color(0,0,0,0.88))
 var box=Rect2(canvas*0.5-Vector2(390,245),Vector2(780,490))
 draw_rect(box,Color("#091C2B"))
 draw_rect(box,CYAN,false,2)
 _text(box.position+Vector2(24,42),"MESH LAB // BUILD YOUR RUNNER",LIME,27)
 _text(box.position+Vector2(660,41),"CLOSE",PINK,18)
 _text(box.position+Vector2(22,96),"LEVEL %d  //  %d / %d BLOCKS" % [runner_mesh.level,runner_mesh.cells.size(),runner_mesh.capacity()],CYAN,20)
 var center: Vector2=box.position+Vector2(390,245)
 for x in range(-7,8):
  for y in range(-3,5):
   var p: Vector2=center+Vector2(x,y)*36.0
   draw_rect(Rect2(p-Vector2(17,17),Vector2(34,34)),Color("#234456"),false,1)
 for c in runner_mesh.cells:
  var at: Vector2=center+Vector2(float(c["x"]),float(c["y"]))*36.0
  var color: Color=runner_mesh._cell_color(str(c["type"]),false)
  draw_rect(Rect2(at-Vector2(14,14),Vector2(28,28)),color)
  draw_rect(Rect2(at-Vector2(10,10),Vector2(20,20)),Color("#0A1D2B"))
  draw_rect(Rect2(at-Vector2(6,6),Vector2(12,12)),color)
 var slots: Dictionary=runner_mesh.locomotion_slots()
 _text(box.position+Vector2(22,119),"LEGS %d/%d   FINS %d/%d   THRUST %d/%d" % [runner_mesh.parts_count("LEG"),int(slots["legs"]),runner_mesh.parts_count("FIN"),int(slots["fins"]),runner_mesh.parts_count("THRUSTER"),int(slots["thrusters"])],CYAN,15)
 var names: Array=["MODE "+runner_mesh.mode,"BLOCK "+MeshCreature.TYPES[mesh_selected+1],"SAVE / EXIT"]
 for k in range(3):
  var button=Rect2(box.position+Vector2(16+k*250,430),Vector2(236,53))
  draw_rect(button,Color("#153244"))
  draw_rect(button,CYAN,false,2)
  _text(button.position+Vector2(11,34),names[k],LIME,18)

func _mesh_draw() -> void:
 if world_mode!=0:
  return
 for enemy in mesh_enemies:
  if not bool(enemy["alive"]) or Vector2(enemy["pos"]).distance_to(player)>930.0:
   continue
  var form=MeshCreature.new()
  form.setup_saved(enemy["cells"],"CRAWL",15)
  form.movement_blend=MeshCreature.locomotion_blend(float(enemy.get("motion_speed",0.0)))
  form.travel_clock=float(enemy.get("anim_clock",0.0))
  var at: Vector2=enemy["pos"]
  var boss: bool=bool(enemy.get("boss",false))
  var heading: float=(player-at).angle()
  form.draw_mesh(self,at,heading,elapsed,true,1.6 if boss else 1.0)
  if boss:
   draw_arc(at,64.0+sin(elapsed*4.0)*4.0,0,TAU,55,PINK,3)
   _text(at+Vector2(-75,-88),"MESH ALPHA / BOSS",PINK,17)
  draw_rect(Rect2(at+Vector2(-33,-51),Vector2(66,6)),Color("#283C4E"))
  draw_rect(Rect2(at+Vector2(-33,-51),Vector2(66*clampf(float(enemy["hp"])/float(enemy["max"]),0.0,1.0),6)),PINK)
 for corpse in mesh_wrecks:
  var at: Vector2=corpse["pos"]
  if at.distance_to(player)<900.0:
   draw_arc(at,30.0+sin(elapsed*4.0)*4.0,0,TAU,40,LIME,3)
   draw_rect(Rect2(at-Vector2(12,12),Vector2(24,24)),PINK)
   _text(at+Vector2(-50,-40),"HACK CORE",LIME,15)
 for shot in mesh_shots:
  var at: Vector2=shot["pos"]
  var tint: Color=PINK if bool(shot["enemy"]) else LIME
  draw_circle(at,6.0,tint)

func _init_base_nodes() -> void:
 # Eight compact consoles in four bays, plus one central repair core.
 # Positions are shared with movement, touch targeting and interaction logic.
 base_nodes = [
  {"pos":Vector2(885,500), "kind":"UPLINK", "name":"UPLINK // 00", "details":"Enter the Withnet or review the network map.", "color":CYAN},
  {"pos":Vector2(720,610), "kind":"CORE", "name":"CORE // 01", "details":"Repair integrity and reduce tracing in this safe zone.", "color":LIME},
  {"pos":Vector2(325,500), "kind":"UPGRADE", "name":"WORKSHOP // 02", "details":"Upgrade your movement drive or code buffer.", "color":VIOLET},
  {"pos":Vector2(885,760), "kind":"ARCHIVE", "name":"ARCHIVE // 03", "details":"Review operator log and current contract.", "color":CYAN},
  {"pos":Vector2(1120,500), "kind":"MISSION", "name":"OPS // 04", "details":"Your mission console. Current network contracts.", "color":LIME},
  {"pos":Vector2(325,760), "kind":"MODULE", "name":"MODULE // 05", "details":"Install permanent base defense, amplifier and sync systems.", "color":VIOLET},
  {"pos":Vector2(560,500), "kind":"FAB", "name":"FABRICATOR // 06", "details":"Craft hacking programs and assemble an equipped loadout.", "color":CYAN},
  {"pos":Vector2(560,760), "kind":"ARMORY", "name":"ARMORY // 07", "details":"Inspect your programs or train rhythm countermeasures.", "color":PINK},
  {"pos":Vector2(1120,760), "kind":"ACCESS", "name":"CLEARANCE // 08", "details":"Upgrade your Red Zone clearance level.", "color":LIME}
 ]

func _active_nodes() -> Array:
 return base_nodes if world_mode == 2 else nodes

func _enter_withnet() -> void:
 zone_access = state.can_bypass_red_zone()
 red_zone.reset_guards()
 guard_cooldown = 0.0
 breach_open = false
 overlay_mode = ""
 journal_open = false
 world_mode = 0
 player = HOME_PORTAL_POS + Vector2(142,0)
 player_trail.clear()
 mesh_velocity=Vector2.ZERO
 mesh_hit_impulse=Vector2.ZERO
 node_open = false
 _notify("WITHNET ONLINE  //  FOLLOW THE DATA HIGHWAY")

func _enter_homebase() -> void:
 zone_access = false
 red_guard_index = -1
 breach_open = false
 overlay_mode = ""
 journal_open = false
 world_mode = 2
 base_player = BASE_SPAWN
 player_trail.clear()
 mesh_velocity=Vector2.ZERO
 mesh_hit_impulse=Vector2.ZERO
 node_open = false
 _notify("HOMEBASE ONLINE  //  SYSTEMS STABLE")

func _current_pos() -> Vector2:
 if world_mode == 2:
  return base_player
 if world_mode == 1:
  return dark_player
 if world_mode == 3:
  return dungeon_player
 return player


func _init_orbs() -> void:
 orbs = [
  Vector2(540,550),Vector2(620,695),Vector2(965,550),
  Vector2(1340,410),Vector2(1630,650),Vector2(960,930),
  Vector2(545,925),Vector2(1810,920)
 ]


func _init_matrix() -> void:
 # New randomized solvable codes for each firewall/ICE breach.
 hack_rng.randomize()
 var signature: String = ""
 for attempt in range(12):
  matrix.clear()
  hack_targets.clear()
  for y in range(5):
   var row: Array = []
   for x in range(5):
    row.append(CODE_VALUES[hack_rng.randi_range(0,CODE_VALUES.size()-1)])
   matrix.append(row)
  var col: int = hack_rng.randi_range(0,4)
  var row_index: int = hack_rng.randi_range(1,4)
  var other_col: int = hack_rng.randi_range(0,4)
  while other_col == col:
   other_col = hack_rng.randi_range(0,4)
  var path: Array = [Vector2i(col,0),Vector2i(col,row_index),Vector2i(other_col,row_index)]
  var first: Array = []
  for cell in path:
   var code: String = CODE_VALUES[hack_rng.randi_range(0,CODE_VALUES.size()-1)]
   matrix[cell.y][cell.x] = code
   first.append(code)
  hack_targets.append(first)
  for i in range(2):
   var target: Array = []
   for k in range(3):
    target.append(CODE_VALUES[hack_rng.randi_range(0,CODE_VALUES.size()-1)])
   while hack_targets.has(target):
    target[2] = CODE_VALUES[(CODE_VALUES.find(target[2])+1)%CODE_VALUES.size()]
   hack_targets.append(target)
  signature = str(matrix)+str(hack_targets)
  if signature != last_hack_signature:
   break
 last_hack_signature = signature

func _reset_darknet() -> void:
 dark_player = Vector2(1.5 * TILE, 1.5 * TILE)
 dark_collected = 0
 dark_loot.clear()
 hunter = Vector2(12.5*TILE, 9.5*TILE)
 hunter_direction = -1.0
 hunter_cooldown = 0.0
 hunter_disabled = false

func _process(delta: float) -> void:
 # Every frame refresh animation even when the player is inside a menu/base.
 if world_mode!=0:
  runner_mesh.set_motion(0.0,delta)
  mesh_observed_pos=player
 elapsed += delta
 fx.update(delta)
 notification_timer = maxf(0.0,notification_timer-delta)
 if duel_active:
  duel.tick(delta)
  if duel.result != "RUNNING" and not duel_burst_done:
   duel_burst_done = true
   var winner: bool = duel.result == "WIN"
   fx.burst(get_viewport_rect().size*0.5,"ice" if winner else "damage",true,72 if winner else 28)
   fx.impact(14.0 if winner else 8.0,0.36)
   fx.flash(CYAN if winner else PINK,0.20)
 elif breach_open:
  breach_timer -= delta
  if breach_timer <= 0:
   _breach_failed()
 elif not node_open and not journal_open and overlay_mode == "":
  guard_cooldown = maxf(0.0,guard_cooldown-delta)
  _update_player(delta)
  if world_mode == 0:
   _update_red_zone(delta)
   _update_signal_mines(delta)
   _mesh_update(delta)
  if world_mode == 1:
   _update_darknet(delta)
  elif world_mode == 3:
   _update_dungeon(delta)
  elif state.trace > 0.0:
   state.trace = maxf(0.0,state.trace-delta*0.025)
  var world_player = _current_pos()
  player_trail.push_front(world_player)
  var trail_limit: int = 18+_power_tier()*8
  if player_trail.size() > trail_limit:
   player_trail.resize(trail_limit)
  if _power_tier() >= 2 and (joystick.length() > 0.1 or Input.get_vector("ui_left","ui_right","ui_up","ui_down").length() > 0.1):
   trail_spark_clock += delta
   if trail_spark_clock >= 0.23:
    trail_spark_clock = 0.0
    fx.burst(world_player,"upgrade",false,2)
 queue_redraw()

func _update_player(delta: float) -> void:
 var direction = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
 if joystick.length() > 0.08:
  direction = joystick
 if direction.length() > 1.0:
  direction = direction.normalized()
 if world_mode!=0 and direction.length()>0.15:
  mesh_direction=direction.normalized()
  var desired: float=direction.angle()
  mesh_heading=lerp_angle(mesh_heading,desired,clampf(delta*11.0,0.0,1.0))
 if world_mode == 2:
  base_player += direction * delta * (240.0 + state.speed_level*30.0)
  base_player = base_player.clamp(Vector2(190,432),Vector2(1250,824))
 elif world_mode == 0:
  _mesh_physics_move(direction,delta)
  _collect_world_packets()
 elif world_mode == 3:
  var speed: float = 215.0+state.speed_level*22.0
  var target: Vector2 = dungeon_player+direction*delta*speed
  if not dungeon.is_blocked(Vector2(target.x,dungeon_player.y)):
   dungeon_player.x = target.x
  if not dungeon.is_blocked(Vector2(dungeon_player.x,target.y)):
   dungeon_player.y = target.y
 else:
  var next_pos = dark_player + direction * delta * (174.0 + state.speed_level*18.0)
  if not _maze_wall(Vector2(next_pos.x,dark_player.y)):
   dark_player.x = next_pos.x
  if not _maze_wall(Vector2(dark_player.x,next_pos.y)):
   dark_player.y = next_pos.y


func _mesh_physics_move(direction: Vector2,delta: float) -> void:
 # Steering inertia, surface drag, acceleration, wall sliding and damped rotation.
 var step: float = minf(delta,0.05)
 var wet: bool = player.y>1900.0 and player.y<2480.0
 var max_speed: float=(240.0+state.speed_level*30.0)*float(runner_mesh.stats()["speed"])*runner_mesh.travel_multiplier(wet)
 var response: float = 7.7 if runner_mesh.mode=="FLY" else (5.0 if wet else 10.5)
 if runner_mesh.mode=="SWIM" and wet:
  response=4.8
 if runner_mesh.mode=="FLY":
  response=7.2
 var target_velocity: Vector2=direction*max_speed
 var before: Vector2=mesh_velocity
 mesh_velocity=mesh_velocity.move_toward(target_velocity,max_speed*response*step)
 mesh_hit_impulse=mesh_hit_impulse.move_toward(Vector2.ZERO,360.0*step)
 var delta_motion: Vector2=(mesh_velocity+mesh_hit_impulse)*step
 var old: Vector2=player
 var destination: Vector2=(player+delta_motion).clamp(Vector2(70,70),WORLD_SIZE-Vector2(70,70))
 if red_zone.is_crossing_border(player,destination) and not _has_red_zone_access():
  player.x=minf(player.x,RedZone.SAFE_RETURN_X)
  mesh_velocity=Vector2.ZERO
  _start_red_zone_breach()
  return
 if not _world_wall_collision(Vector2(destination.x,player.y)):
  player.x=destination.x
 else:
  mesh_velocity.x=0.0
 if not _world_wall_collision(Vector2(player.x,destination.y)):
  player.y=destination.y
 else:
  mesh_velocity.y=0.0
 if direction.length()>0.12:
  mesh_direction=direction.normalized()
 # Model faces the ACTUAL movement vector, never the last fired projectile.
 var motion: Vector2=player-old
 if motion.length()>0.18:
  var requested: float=motion.angle()
  var rotation_diff: float=wrapf(requested-mesh_heading,-PI,PI)
  mesh_angular_velocity=lerpf(mesh_angular_velocity,rotation_diff*(10.0 if runner_mesh.mode=="CRAWL" else (7.5 if runner_mesh.mode=="FLY" else 6.0)),minf(1.0,step*12.0))
  mesh_heading=wrapf(mesh_heading+clampf(mesh_angular_velocity*step,-0.34,0.34),-PI,PI)
  mesh_step_phase+=motion.length()*0.075
 mesh_lean=lerpf(mesh_lean,clampf((mesh_velocity-before).cross(mesh_direction)*0.00014,-0.20,0.20),minf(1.0,step*7.0))

func _enter_dungeon(portal: int) -> void:
 if portal < 0 or portal >= open_world.portals.size() or duel_active:
  return
 dungeon_return = player
 dungeon_id = portal
 dungeon.setup(portal,bool(state.dungeon_clears.get("DUNGEON_%d" % portal,false)))
 dungeon_player = dungeon.spawn
 world_mode = 3
 mesh_velocity=Vector2.ZERO
 mesh_hit_impulse=Vector2.ZERO
 dungeon_guard_index = -1
 dungeon_guard_cooldown = 1.4
 node_open = false
 joystick = Vector2.ZERO
 player_trail.clear()
 fx.burst(dungeon_player,"upgrade",false,35)
 fx.impact(6.0,0.22)
 _notify("DUNGEON LINK // "+str(open_world.portals[portal]["name"]))

func _exit_dungeon() -> void:
 if world_mode != 3:
  return
 world_mode = 0
 mesh_velocity=Vector2.ZERO
 mesh_hit_impulse=Vector2.ZERO
 player = dungeon_return+Vector2(0,120)
 if _world_wall_collision(player):
  player = dungeon_return
 dungeon_id = -1
 dungeon_guard_index = -1
 dungeon_guard_cooldown = 1.2
 joystick = Vector2.ZERO
 player_trail.clear()
 fx.burst(player,"upgrade",false,24)
 _notify("DUNGEON EXIT // WITHNET LINK RESTORED")

func _update_dungeon(delta: float) -> void:
 dungeon_guard_cooldown = maxf(0.0,dungeon_guard_cooldown-delta)
 if dungeon_guard_cooldown > 0.0:
  return
 var idx: int = dungeon.enemy_near(dungeon_player)
 if idx >= 0:
  dungeon_guard_index = idx
  dungeon_duel = true
  _start_duel(false,false)
  _notify("DUNGEON ICE // "+str(dungeon.enemies[idx]["name"]))

func _dungeon_interact() -> void:
 if dungeon_player.distance_to(dungeon.exit_pos) < 110.0:
  _exit_dungeon()
  return
 var cache: int = dungeon.nearest_cache(dungeon_player)
 if cache < 0:
  _notify("SEEK THE DATA CACHES OR RETURN TO THE EXIT")
  return
 var key: String = "%d:%d" % [dungeon_id,cache]
 if state.dungeon_caches.has(key):
  _notify("CACHE EMPTY // ALREADY EXTRACTED")
  return
 state.dungeon_caches[key] = true
 var gain: int = 65+dungeon.level*35
 state.credits += gain
 state.fragments += 4+dungeon.level*2
 var ore: String = OpenWorld.ORE_NAMES[mini(5,dungeon.level)]
 state.ore_inventory[ore] = int(state.ore_inventory.get(ore,0))+3
 fx.burst(dungeon.caches[cache]["pos"],"data",false,45)
 fx.impact(5.0,0.15)
 _notify("CACHE OPEN // +%d CR +DATA +RARE ORE" % gain)
 state.save_game()

func _mine_world_vein(index: int) -> void:
 if index < 0 or index >= open_world.veins.size():
  return
 var vein: Dictionary = open_world.veins[index]
 var now: int = int(Time.get_unix_time_from_system())
 if int(vein["tier"]) > state.drill_level:
  _notify("DRILL LEVEL %d REQUIRED // EXTRACTOR UPGRADE" % int(vein["tier"]))
 elif now < int(state.mined_veins.get(str(vein["id"]),0)):
  _notify("ORE VEIN DEPLETED // REGENERATING")
 elif state.mine_vein(vein,now):
  fx.burst(vein["pos"],"data",false,36)
  fx.impact(5.5,0.18)
  _notify("%s MINED // +%d ORE // CARGO %d" % [str(vein["type"]),int(vein["amount"])+int(state.drill_level/2),state.ore_total()])

func _has_red_zone_access() -> bool:
 return zone_access or state.can_bypass_red_zone()

func _start_red_zone_breach() -> void:
 if breach_open or duel_active:
  return
 breach_open = true
 breach_target = "ZONE"
 buffer.clear()
 _init_matrix()
 breach_timer = 60.0 + state.clearance_level*18.0
 _notify("RESTRICTED SECTOR  //  BREACH RED FIREWALL")

func _update_red_zone(delta: float) -> void:
 if guard_cooldown > 0.0:
  return
 var index = red_zone.tick(delta,player,_has_red_zone_access())
 if index >= 0:
  red_guard_index = index
  fx.burst(red_zone.guards[index]["pos"],"damage",false,20)
  fx.impact(5.0,0.17)
  _start_duel(false,false)
  _notify("HOSTILE "+str(red_zone.guards[index]["name"])+"  //  NETDUEL")

func _collect_world_packets() -> void:
 for i in range(orbs.size()):
  if state.collected_orbs.has(str(i)):
   continue
  if player.distance_to(orbs[i]) < 25.0:
   state.collected_orbs[str(i)] = true
   state.fragments += 2
   state.credits += 10
   fx.burst(orbs[i],"data",false,16)
   fx.impact(2.5,0.09)
   _notify("FREE PACKET  +10 CR  +2 DATA")
   state.save_game()

func _update_darknet(delta: float) -> void:
 for idx in range(DARK_PACKETS.size()):
  if not dark_loot.has(str(idx)) and dark_player.distance_to(DARK_PACKETS[idx]) < 27.0:
   dark_loot[str(idx)] = true
   dark_collected += 1
   state.credits += 25
   state.fragments += 3
   state.trace = minf(100.0,state.trace+2.0)
   _notify("DATA EXTRACTED  +25 CR  +3 FR")
   if dark_collected == 3:
    _mission_event("darkloot")
   state.save_game()
 if not hunter_disabled:
  hunter.x += hunter_direction * delta * 58.0
  if hunter.x < 9.5*TILE:
   hunter_direction = 1.0
  if hunter.x > 12.5*TILE:
   hunter_direction = -1.0
  hunter_cooldown = maxf(0.0,hunter_cooldown-delta)
  if dark_player.distance_to(hunter) < 42.0 and hunter_cooldown == 0.0:
   hunter_cooldown = 2.0
   _start_duel(true,false)
 if dark_player.distance_to(EXIT_POS) < 35.0:
  if dark_collected >= DARK_PACKETS.size():
   _finish_darknet()
  elif notification_timer <= 0.0:
   _notify("EXIT LOCKED  //  COLLECT ALL 3 PACKETS")

func _maze_wall(p: Vector2) -> bool:
 var x = int(floor(p.x / TILE))
 var y = int(floor(p.y / TILE))
 return y < 0 or y >= MAZE.size() or x < 0 or x >= MAZE[0].length() or MAZE[y][x] == "#"

func _finish_darknet() -> void:
 world_mode = 0
 zone_access = true
 player = GATE_POS + Vector2(-130,90)
 state.darknet_runs += 1
 state.credits += 80
 state.fragments += 6
 state.trace = maxf(0.0,state.trace-15.0)
 player_trail.clear()
 _mission_event("escape")
 _notify("DARKNET COMPLETE  +80 CREDITS  +6 DATA")
 state.save_game()

func _emergency_disconnect() -> void:
 world_mode = 0
 _enter_homebase()
 player_trail.clear()
 state.integrity = 50.0
 state.trace = maxf(0.0,state.trace-20.0)
 _notify("EMERGENCY DISCONNECT  //  INTEGRITY RECOVERING")

func _nearest_node() -> int:
 var result = -1
 var best = 108.0
 var active = _active_nodes()
 var current = _current_pos()
 for i in range(active.size()):
  if active[i].get("hidden",false) and not state.hidden_revealed:
   continue
  var distance = current.distance_to(active[i]["pos"])
  if distance < best:
   best = distance
   result = i
 return result

func _interact() -> void:
 if node_open or journal_open:
  node_open = false
  journal_open = false
  return
 if world_mode == 1 or breach_open:
  return
 if world_mode == 3:
  _dungeon_interact()
  return
 if world_mode == 0:
  var corpse: int = _mesh_nearest_wreck()
  if corpse>=0:
   mesh_loot_index=corpse
   mesh_loot_active=true
   _start_duel(false,false)
   return
  var portal: int = open_world.nearest_portal(player)
  if portal >= 0:
   _enter_dungeon(portal)
   return
  var vein: int = open_world.nearest_vein(player)
  if vein >= 0:
   _mine_world_vein(vein)
   return
  if not _has_red_zone_access() and player.x >= RedZone.BORDER_X:
   player.x = RedZone.SAFE_RETURN_X
   _start_red_zone_breach()
   return
  if not _has_red_zone_access() and player.x < RedZone.BORDER_X and player.x > RedZone.BORDER_X-110.0:
   _start_red_zone_breach()
   return
  if player.distance_to(HOME_PORTAL_POS) < 100.0:
   _enter_homebase()
   return
  if player.distance_to(GATE_POS) < 106.0:
   if ice_open:
    world_mode = 1
    _reset_darknet()
    player_trail.clear()
    _notify("DARKNET CONNECTED  //  COLLECT 3 PACKETS")
   else:
    breach_open = true
    breach_target = "GATE"
    buffer.clear()
    _init_matrix()
    breach_timer = 63.0-state.trace*0.14
   return
 var n = _nearest_node()
 if n >= 0:
  selected_node = n
  node_open = true
 else:
  _notify("NO TERMINAL IN RANGE  //  MOVE CLOSER")


func _mission_event(tag: String) -> void:
 var msg = state.on_event(tag)
 if msg != "":
  _notify(msg)

func _notify(message: String) -> void:
 status = message
 notification_timer = 5.5

func _node_action(option: int) -> void:
 var active = _active_nodes()
 if selected_node < 0 or selected_node >= active.size():
  node_open = false
  return
 var kind: String = active[selected_node]["kind"]
 var id = str(selected_node)
 var times = int(state.node_claims.get(id,0))
 match kind:
  "UPLINK":
   if option == 0:
    _enter_withnet()
   else:
    journal_open = true
    _notify("NETWORK ATLAS  //  PUBLIC GRID, SERVICE GRID, RED ZONE")
  "CORE":
   if option == 0 and state.buy(20,0):
    state.integrity = minf(100.0,state.integrity+35.0)
    _notify("SYSTEM CORE  //  INTEGRITY +35")
   elif option == 1 and state.buy(25,0):
    state.trace = maxf(0.0,state.trace-30.0)
    _notify("FIREWALL PURGED  //  TRACE -30")
   else:
    _notify("NOT ENOUGH CREDITS")
  "ARCHIVE":
   journal_open = true
   _notify("OPERATOR ARCHIVE LOADED")
  "DATA":
   if option == 0 and times == 0:
    state.credits += 55
    state.fragments += 7
    state.node_claims[id] = 1
    _mission_event("data")
    _notify("ARCHIVE EXTRACTED  +55 CR  +7 FR")
   else:
    _notify("ARCHIVE EMPTY  //  NO DATA LEFT")
  "SCAN":
   if option == 0:
    state.hidden_revealed = true
    state.scan_level = maxi(state.scan_level,1)
    state.node_claims[id] = 1
    _mission_event("scan")
    _notify("SCAN COMPLETE  //  GHOST NODE REVEALED")
   else:
    state.trace = maxf(0.0,state.trace-8.0)
    _notify("NETWORK SIGNATURE CLEANED  -8 TRACE")
  "UPGRADE":
   if option == 0:
    if state.speed_level >= 5:
     _notify("SPEED ALREADY MAXED")
    elif state.buy(30+state.speed_level*25,4+state.speed_level*2):
     state.speed_level += 1
     fx.burst(_current_pos(),"upgrade",false,26)
     fx.impact(4.0,0.13)
     _notify("OVERCLOCK INSTALLED  //  SPEED UP")
    else:
     _notify("INSUFFICIENT CREDITS OR FRAGMENTS")
   else:
    if state.buffer_level >= 2:
     _notify("BUFFER AT MAX CAPACITY")
    elif state.buy(65+state.buffer_level*50,7+state.buffer_level*4):
     state.buffer_level += 1
     fx.burst(_current_pos(),"upgrade",false,21)
     _notify("BUFFER EXPANDED  +1 CODE SLOT")
    else:
     _notify("INSUFFICIENT CREDITS OR FRAGMENTS")
  "MINING_RIG":
   if option == 0:
    if state.upgrade_drill():
     fx.burst(_current_pos(),"upgrade",false,32)
     _notify("DRILL UPGRADE // LEVEL %d" % state.drill_level)
    else:
     _notify("DRILL MAXED OR NOT ENOUGH RESOURCES")
   else:
    var earned: int = state.sell_ore()
    if earned > 0:
     fx.burst(_current_pos(),"data",false,24)
     _notify("ORE SOLD // +%d CR" % earned)
    else:
     _notify("NO ORE TO SELL // MINE IN OPEN WORLD")
  "DATACITY":
   var city_id: int = int(active[selected_node]["city"])
   var city_key: String = "CITY_%d" % city_id
   if option == 0 and not state.node_claims.has(city_key):
    state.node_claims[city_key] = 1
    state.credits += 120+city_id*75
    state.fragments += 12+city_id*4
    _notify("NEW DATA CITY DISCOVERED // REWARD UNLOCKED")
   else:
    _notify("CITY INTEL // FIND THE MARKET AND BOSS")
  "DATAMARKET":
   if option == 0 and state.buy(65,5):
    state.integrity = minf(100.0,state.integrity+65.0)
    jam_remaining = 0.0
    fx.burst(_current_pos(),"shield",false,25)
    fx.flash(LIME,0.10)
    _notify("DATA MARKET // FIELD REPAIR AND JAM CLEAR")
   elif option == 1 and state.buy(90,7):
    state.trace = maxf(0.0,state.trace-50.0)
    _notify("DATA MARKET // TRACE CLEANED")
   else:
    _notify("NOT ENOUGH DATA / CREDITS")
  "MARKET":
   if option == 0 and state.buy(35,0):
    state.trace = maxf(0.0,state.trace-32.0)
    _notify("TRACE SCRUBBER APPLIED  -32 TRACE")
   elif option == 1 and state.buy(45,0):
    state.integrity = minf(100.0,state.integrity+50.0)
    _notify("INTEGRITY REPAIRED  +50")
   else:
    _notify("NOT ENOUGH CREDITS")
  "MISSION":
   _notify(state.mission_text())
  "RELAY":
   if option == 0 and state.buy(15,0):
    state.integrity = minf(100.0,state.integrity+30.0)
    _notify("SIGNAL PATCHED  +30 INTEGRITY")
   elif option == 1:
    _enter_homebase()
   else:
    _notify("NOT ENOUGH CREDITS")
  "ANOMALY":
   if option == 0:
    if times == 0:
     state.node_claims[id] = 1
     state.trace = minf(100.0,state.trace+25.0)
     state.credits += 160
     state.fragments += 10
     _notify("RIFT LOOTED  +160 CR  +10 FR  +25 TRACE")
    else:
     _notify("RIFT DEPLETED")
   else:
    _notify("RIFT BYPASSED  //  SAFE")
  "ACCESS":
   if option == 0:
    if state.upgrade_clearance():
     _notify("SECURITY CLEARANCE UPDATED  //  LEVEL %d" % state.clearance_level)
     if state.can_bypass_red_zone():
      zone_access = true
    else:
     _notify("CLEARANCE %d/2  //  NEXT %d CR  %d DATA" % [state.clearance_level,int(state.clearance_price()["credits"]),int(state.clearance_price()["fragments"])])
   else:
    _notify("INSUFFICIENT RESOURCES OR MAX CLEARANCE")
  "FAB":
   overlay_mode = "CRAFT" if option == 0 else "MESH"
   node_open = false
  "ARMORY":
   if option == 0:
    overlay_mode = "INVENTORY"
   else:
    _start_duel(false,true)
  "MODULE":
   overlay_mode = "MODULES"
  "COMBAT":
   if option == 0:
    _start_duel(false,false)
   else:
    _notify("ICE ARENA: HACK AGAIN TO START A DUEL")
  "VAULT":
   if times == 0:
    state.node_claims[id] = 1
    state.credits += 120
    state.fragments += 15
    _notify("GHOST CACHE RECOVERED  +120 CR  +15 FR")
   else:
    _notify("VAULT EMPTY")
 node_open = false
 state.save_game()

func _breach_failed() -> void:
 breach_open = false
 if breach_target == "ZONE":
  player.x = minf(player.x,RedZone.SAFE_RETURN_X)
 buffer.clear()
 state.trace = minf(100.0,state.trace+12.0)
 fx.burst(_current_pos(),"damage",false,30)
 fx.impact(7.0,0.24)
 fx.flash(PINK,0.14)
 _notify("BREACH FAILED  //  TRACE +12")
 state.save_game()

func _choose_code(p: Vector2) -> void:
 if p.x > 1000.0 and p.y > 594.0:
  buffer.clear()
  return
 var col = int(floor((p.x-205.0)/69.0))
 var row = int(floor((p.y-205.0)/69.0))
 if col < 0 or col > 4 or row < 0 or row > 4:
  return
 if buffer.size() >= 6+state.buffer_level:
  _notify("BUFFER FULL  //  RESET TO RETRY")
  return
 var cell = Vector2i(col,row)
 if buffer.has(cell):
  return
 if buffer.is_empty() and row != 0:
  return
 if not buffer.is_empty():
  var prev: Vector2i = buffer.back()
  if buffer.size()%2 == 1 and col != prev.x:
   return
  if buffer.size()%2 == 0 and row != prev.y:
   return
 buffer.append(cell)
 var sequence = []
 for location in buffer:
  sequence.append(matrix[location.y][location.x])
 for target in hack_targets:
  for offset in range(sequence.size()-target.size()+1):
   var valid = true
   for k in range(target.size()):
    if sequence[offset+k] != target[k]:
     valid = false
   if valid:
    breach_open = false
    fx.burst(Vector2(RedZone.BORDER_X,player.y) if breach_target == "ZONE" else GATE_POS,"ice",false,74)
    fx.impact(13.0,0.42)
    fx.flash(CYAN,0.23)
    if breach_target == "ZONE":
     zone_access = true
     player.x = RedZone.ZONE_ENTRY_X
     state.red_zone_hacks += 1
     state.trace = minf(100.0,state.trace+3.0)
     _notify("RED FIREWALL BREACHED  //  SECTOR C OPEN")
     state.save_game()
     return
    ice_open = true
    state.breaches += 1
    state.credits += 30
    state.fragments += 4
    state.trace = minf(100.0,state.trace+4.0)
    _mission_event("breach")
    _notify("ICE BREACHED  +30 CR  +4 FR  //  ENTER GATE")
    state.save_game()
    return

func _dev_mobile_hit(point: Vector2, canvas: Vector2) -> bool:
 return world_mode == 2 and not node_open and not journal_open and overlay_mode == "" and point.y < 84.0 and point.x > canvas.x-300.0

func _dev_title_tap() -> void:
 if elapsed > dev_tap_deadline:
  dev_taps = 0
 dev_taps += 1
 dev_tap_deadline = elapsed+3.0
 if dev_taps >= 7:
  dev_taps = 0
  _toggle_dev_overkill()

func _dev_key(key: int) -> bool:
 var letter: String = OS.get_keycode_string(key).to_upper()
 if letter.length() != 1 or letter < "A" or letter > "Z":
  return false
 dev_key_buffer += letter
 if dev_key_buffer.length() > DEV_CODE.length():
  dev_key_buffer = dev_key_buffer.right(DEV_CODE.length())
 if dev_key_buffer == DEV_CODE:
  dev_key_buffer = ""
  _toggle_dev_overkill()
  return true
 return false

func _toggle_dev_overkill() -> void:
 dev_overkill = not dev_overkill
 if duel_active:
  duel.dev_overkill = dev_overkill
 fx.burst(_current_pos(),"dev",false,32)
 fx.impact(10.0,0.30)
 fx.flash(PINK,0.16)
 _notify("DEVELOPER OVERKILL // "+("ACTIVE" if dev_overkill else "OFF"))

func _input(event: InputEvent) -> void:
 var canvas = get_viewport_rect().size
 if event is InputEventScreenTouch:
  if event.pressed:
   if overlay_mode == "MESH":
    _mesh_edit(event.position,canvas)
    return
   if _dev_mobile_hit(event.position,canvas):
    _dev_title_tap()
    return
   if duel_active:
    _duel_touch(event.position,canvas)
   elif overlay_mode != "":
    _overlay_touch(event.position,canvas)
   elif breach_open:
    _choose_code(event.position)
   elif node_open:
    _click_panel(event.position,canvas)
   elif journal_open:
    journal_open = false
   elif event.position.distance_to(_joystick_center(canvas)) < _joystick_radius()+22.0:
    joystick_touch = event.index
    joystick_origin = event.position
   elif _mesh_fire_hit(event.position,canvas):
    _mesh_fire()
   elif _action_hit(event.position,canvas):
    _interact()
   elif event.position.y < 84 and event.position.x < canvas.x*0.5:
    journal_open = true
   else:
    _touch_world(event.position,canvas)
  elif event.index == joystick_touch:
   joystick_touch = -1
   joystick = Vector2.ZERO
 elif event is InputEventScreenDrag and event.index == joystick_touch:
  joystick = (event.position-joystick_origin).limit_length(85.0)/85.0
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  if overlay_mode == "MESH":
   _mesh_edit(event.position,canvas)
   return
  if _dev_mobile_hit(event.position,canvas):
   _dev_title_tap()
   return
  if duel_active:
   _duel_touch(event.position,canvas)
  elif overlay_mode != "":
   _overlay_touch(event.position,canvas)
  elif breach_open:
   _choose_code(event.position)
  elif node_open:
   _click_panel(event.position,canvas)
  elif journal_open:
   journal_open = false
  elif _mesh_fire_hit(event.position,canvas):
   _mesh_fire()
  elif _action_hit(event.position,canvas):
   _interact()
  elif event.position.y < 84 and event.position.x < canvas.x*0.5:
   journal_open = true
  else:
   _touch_world(event.position,canvas)
 elif event is InputEventKey and event.pressed and not event.echo:
  if _dev_key(event.keycode):
   return
  if duel_active:
   if duel.result != "RUNNING":
    _finish_duel()
   elif event.keycode == KEY_SPACE:
    duel.activate_slowmo()
   elif event.keycode == KEY_Q:
    _duel_bomb()
   else:
    _duel_key(event.keycode)
   return
  if overlay_mode != "":
   if overlay_mode=="MESH":
    if event.keycode==KEY_ESCAPE:
     overlay_mode=""
    return
   if event.keycode == KEY_ESCAPE:
    overlay_mode = ""
   elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
    _overlay_action(event.keycode-KEY_1)
   return
  if event.keycode == KEY_ESCAPE:
   breach_open = false
   node_open = false
   journal_open = false
  elif event.keycode == KEY_E or event.keycode == KEY_SPACE:
   if node_open:
    _node_action(0)
   elif not breach_open:
    _interact()
  elif event.keycode == KEY_F:
   _mesh_fire()
  elif event.keycode == KEY_B:
   overlay_mode = "MESH"
  elif event.keycode == KEY_M or event.keycode == KEY_TAB:
   journal_open = not journal_open
  elif event.keycode == KEY_1 and node_open:
   _node_action(0)
  elif event.keycode == KEY_2 and node_open:
   _node_action(1)

func _touch_world(point: Vector2,canvas: Vector2) -> void:
 if world_mode == 1:
  return
 var relative = point + camera_offset
 if world_mode == 3:
  if dungeon_player.distance_to(dungeon.exit_pos) < 110.0 and relative.distance_to(dungeon.exit_pos) < 85.0:
   _exit_dungeon()
  elif dungeon.nearest_cache(dungeon_player) >= 0 and relative.distance_to(dungeon.caches[dungeon.nearest_cache(dungeon_player)]["pos"]) < 90.0:
   _dungeon_interact()
  return
 if world_mode == 0:
  var portal: int = open_world.nearest_portal(relative,75.0)
  if portal >= 0 and player.distance_to(open_world.portals[portal]["pos"]) < 110.0:
   _enter_dungeon(portal)
   return
  var vein: int = open_world.nearest_vein(relative,65.0)
  if vein >= 0 and player.distance_to(open_world.veins[vein]["pos"]) < 100.0:
   _mine_world_vein(vein)
   return
  if not _has_red_zone_access() and relative.x >= RedZone.BORDER_X-30.0 and relative.x < RedZone.BORDER_X+70.0 and player.x >= RedZone.BORDER_X-150.0:
   _start_red_zone_breach()
   return
  if relative.distance_to(HOME_PORTAL_POS) < 70 and player.distance_to(HOME_PORTAL_POS) < 108:
   _enter_homebase()
   return
  if relative.distance_to(GATE_POS) < 70 and player.distance_to(GATE_POS) < 110:
   _interact()
   return
 var active = _active_nodes()
 var current = _current_pos()
 for i in range(active.size()):
  if active[i].get("hidden",false) and not state.hidden_revealed:
   continue
  if relative.distance_to(active[i]["pos"]) < 64 and current.distance_to(active[i]["pos"]) < 117:
   selected_node = i
   node_open = true
   return


func _panel_rect(canvas: Vector2) -> Rect2:
 return Rect2((canvas.x-720)/2.0,(canvas.y-478)/2.0,720,478)

func _click_panel(p: Vector2,canvas: Vector2) -> void:
 var rect = _panel_rect(canvas)
 if not rect.has_point(p):
  node_open = false
  return
 if p.y > rect.position.y+280 and p.y < rect.position.y+359:
  if p.x > rect.position.x+28 and p.x < rect.position.x+347:
   _node_action(0)
  elif p.x > rect.position.x+372 and p.x < rect.position.x+691:
   _node_action(1)
 elif p.y > rect.position.y+390 or p.y < rect.position.y+55:
  node_open = false

func _text(p: Vector2,value: String,color: Color=CYAN,size: int=20) -> void:
 draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _glow(p: Vector2,color: Color,radius: float) -> void:
 for i in range(4,0,-1):
  draw_circle(p,radius+i*7.0,Color(color.r,color.g,color.b,0.028))
 draw_circle(p,radius,color)

func _beam(a: Vector2,b: Vector2,color: Color) -> void:
 draw_line(a,b,Color(color.r,color.g,color.b,0.10),14.0)
 draw_line(a,b,Color(color.r,color.g,color.b,0.42),5.0)
 draw_line(a,b,color,1.5)

func _draw() -> void:
 var canvas = get_viewport_rect().size
 draw_rect(Rect2(Vector2.ZERO,canvas),BG)
 if duel_active:
  draw_set_transform(fx.shake_offset)
  _draw_duel(canvas)
  _draw_fx(true)
  draw_set_transform(Vector2.ZERO)
  _draw_fx_flash(canvas)
  return
 if breach_open:
  draw_set_transform(fx.shake_offset)
  _draw_breach(canvas)
  draw_set_transform(Vector2.ZERO)
  _draw_fx_flash(canvas)
  return
 var focus = _current_pos()
 camera_offset = _base_camera_offset(canvas) if world_mode == 2 else focus-canvas/2.0
 draw_set_transform(-camera_offset+fx.shake_offset)
 if world_mode == 0:
  _draw_withnet()
 elif world_mode == 1:
  _draw_darknet()
 elif world_mode == 3:
  _draw_dungeon()
 else:
  _draw_homebase()
 _draw_runner_trail(focus)
 runner_mesh.draw_mesh(self,focus,mesh_heading+mesh_lean,elapsed,false,1.0)
 if world_mode==0 and mesh_velocity.length()>75.0:
  var wake: Vector2=Vector2.LEFT.rotated(mesh_heading)
  draw_line(focus+wake*22.0,focus+wake*(26.0+mesh_velocity.length()*0.13),CYAN.darkened(0.43),2.0)
 _mesh_draw()
 _draw_fx(false)
 draw_set_transform(Vector2.ZERO)
 _draw_signal_jam(canvas)
 _draw_hud(canvas)
 if node_open:
  _draw_node_panel(canvas)
 if journal_open:
  _draw_journal(canvas)
 if overlay_mode == "MESH":
  _mesh_draw_editor(canvas)
 elif overlay_mode != "":
  _draw_overlay(canvas)
 _draw_fx_flash(canvas)

func _draw_large_world() -> void:
 # Full 9600 x 3400 pixel biome territories and a solid four-sided perimeter.
 for region in OpenWorld.REGIONS:
  var left: float = float(region["from"])
  var right: float = float(region["to"])
  var tint: Color = region["color"]
  var area = Rect2(left,95.0,right-left,WORLD_SIZE.y-190.0)
  draw_rect(area,Color(tint.r,tint.g,tint.b,0.018))
  draw_rect(area,Color(tint.r,tint.g,tint.b,0.19),false,2)
  for label_y in [1380.0,2420.0,3100.0]:
   _text(Vector2(left+26,label_y),str(region["name"])+" // LV %d" % int(region["tier"]),tint,22)
   draw_line(Vector2(left+30,label_y+19),Vector2(right-35,label_y+19),Color(tint.r,tint.g,tint.b,0.34),2)
 # Liquid-data biome: visible canals determine swimming creature mobility.
 for segment in range(9):
  if segment%2==0:
   continue
  var left: float=float(segment)*1100.0
  if absf(left-player.x)>1750.0:
   continue
  var canal: Rect2=Rect2(left,1880.0,1100.0,570.0)
  draw_rect(canal,Color("#124F6D",0.15))
  draw_rect(canal,Color("#3EBCDE",0.47),false,3)
  for row in range(8):
   for col in range(11):
    var px: float=left+float(col)*101.0+fposmod(elapsed*35.0+float(row)*47.0,75.0)
    var py: float=1932.0+float(row)*60.0
    draw_line(Vector2(px,py),Vector2(px+36.0,py),Color("#55DEFA",0.25+0.15*sin(elapsed*3.0+col)),2)
  _text(Vector2(left+40,1940),"LIQUID DATA // SWIM ROUTE",CYAN,18)
 # Physical outer border also appears as a neon-pixel fortress wall.
 for rect in [Rect2(0,0,WORLD_SIZE.x,64),Rect2(0,WORLD_SIZE.y-64,WORLD_SIZE.x,64),
              Rect2(0,0,64,WORLD_SIZE.y),Rect2(WORLD_SIZE.x-64,0,64,WORLD_SIZE.y)]:
  draw_rect(rect,Color("#0D1526"))
  draw_rect(rect,PINK.darkened(0.3),false,4)
 for i in range(maxi(0,int((player.x-800.0)/44.0)),mini(int(WORLD_SIZE.x/44.0),int((player.x+800.0)/44.0)+1)):
  var px: float = float(i)*44.0
  for wall_y in [10.0,WORLD_SIZE.y-22.0]:
   draw_rect(Rect2(px,wall_y,30,13),Color(PINK.r,PINK.g,PINK.b,0.51 if i%3==0 else 0.20))
 for i in range(maxi(0,int((player.y-600.0)/44.0)),mini(int(WORLD_SIZE.y/44.0),int((player.y+600.0)/44.0)+1)):
  var py: float = float(i)*44.0
  for wall_x in [10.0,WORLD_SIZE.x-22.0]:
   draw_rect(Rect2(wall_x,py,13,30),Color(VIOLET.r,VIOLET.g,VIOLET.b,0.52))
 for block in open_world.walls:
  var rect: Rect2 = block["rect"]
  if absf(rect.get_center().x-player.x)>850.0 or absf(rect.get_center().y-player.y)>720.0:
   continue
  var tint: Color = block["tint"]
  draw_rect(rect,Color("#0B1B2F"))
  draw_rect(rect,Color(tint.r,tint.g,tint.b,0.70),false,3)
  for k in range(0,int(rect.size.x)-12,19):
   var brick_y: float = 6.0+float(int(k/19)%2)*13.0
   draw_rect(Rect2(rect.position+Vector2(k+5,brick_y),Vector2(13,9)),Color(tint.r,tint.g,tint.b,0.32))
 for pylon in open_world.pylons:
  var at: Vector2 = pylon["pos"]
  if at.distance_to(player)>850.0:
   continue
  var tint: Color = pylon["color"]
  draw_rect(Rect2(at-Vector2(13,23),Vector2(26,46)),Color("#13293C"))
  draw_rect(Rect2(at-Vector2(13,23),Vector2(26,46)),tint,false,2)
  draw_circle(at+Vector2(0,-10),4+sin(elapsed*3.0+at.x)*1.2,tint)
 var now: int = int(Time.get_unix_time_from_system())
 for vein in open_world.veins:
  var at: Vector2 = vein["pos"]
  if at.distance_to(player)>950.0:
   continue
  var ready: bool = now>=int(state.mined_veins.get(str(vein["id"]),0))
  var tint: Color = vein["color"] if ready else Color("#405366")
  draw_rect(Rect2(at-Vector2(22,15),Vector2(44,30)),Color("#0C1829"))
  draw_colored_polygon(PackedVector2Array([at+Vector2(-17,4),at+Vector2(-9,-18),
   at+Vector2(3,-14),at+Vector2(17,-21),at+Vector2(18,13),at+Vector2(0,20)]),tint)
  draw_arc(at,26+sin(elapsed*3.0+at.x)*2.0,0,TAU,32,Color(tint.r,tint.g,tint.b,0.43),2)
  if at.distance_to(player)<105.0:
   _text(at+Vector2(-45,-38),str(vein["type"])+" // "+("MINE" if ready else "EMPTY"),tint,14)
 for portal in open_world.portals:
  var at: Vector2 = portal["pos"]
  if at.distance_to(player)>1100.0:
   continue
  var clear: bool = bool(state.dungeon_clears.get("DUNGEON_%d" % int(portal["id"]),false))
  var tint: Color = LIME if clear else VIOLET
  draw_rect(Rect2(at-Vector2(54,44),Vector2(108,88)),Color("#151B33"))
  draw_rect(Rect2(at-Vector2(54,44),Vector2(108,88)),tint,false,3)
  draw_arc(at,35.0+sin(elapsed*4.0+at.x)*5.0,0,TAU,48,tint,4)
  draw_arc(at,21.0,elapsed*0.85,elapsed*0.85+PI*1.55,34,CYAN,3)
  draw_circle(at,9.0,PINK)
  _text(at+Vector2(-80,-65),str(portal["name"]),tint,17)
  _text(at+Vector2(-58,70),"LV %d // %s" % [int(portal["level"]),"CLEARED" if clear else "ENTER"],LIME if clear else CYAN,15)

func _draw_dungeon() -> void:
 var tint: Color = [CYAN,VIOLET,PINK,LIME][dungeon.id%4]
 for y in range(DungeonInstance.HEIGHT):
  for x in range(DungeonInstance.WIDTH):
   var at: Vector2 = Vector2(float(x),float(y))*DungeonInstance.TILE
   var tile = Rect2(at,Vector2(DungeonInstance.TILE,DungeonInstance.TILE))
   if dungeon.walls.has(dungeon._key(x,y)):
    draw_rect(tile,Color("#101827"))
    draw_rect(Rect2(at+Vector2(5,5),tile.size-Vector2(10,10)),Color("#213145"))
    draw_rect(tile,Color(tint.r,tint.g,tint.b,0.34),false,2)
    if (x+y)%3==0:
     draw_line(at+Vector2(12,14),at+Vector2(50,14),Color(tint.r,tint.g,tint.b,0.28),3)
   else:
    draw_rect(tile,Color("#0B1B2C") if (x+y)%2==0 else Color("#102333"))
    draw_rect(tile,Color("#19415A"),false,1)
    if (x*17+y*11)%7==0:
     draw_rect(Rect2(at+Vector2(26,28),Vector2(9,5)),Color(tint.r,tint.g,tint.b,0.35))
 draw_arc(dungeon.exit_pos,42+sin(elapsed*3.0)*3.0,0,TAU,44,LIME,3)
 _glow(dungeon.exit_pos,CYAN,18)
 _text(dungeon.exit_pos+Vector2(-45,-61),"EXIT",LIME,18)
 for cache in dungeon.caches:
  var at: Vector2 = cache["pos"]
  var key: String = "%d:%d" % [dungeon_id,int(cache["id"])]
  var collected: bool = state.dungeon_caches.has(key)
  var c: Color = Color("#496274") if collected else CYAN
  draw_rect(Rect2(at-Vector2(23,23),Vector2(46,46)),Color("#15273C"))
  draw_rect(Rect2(at-Vector2(23,23),Vector2(46,46)),c,false,3)
  _glow(at,c,8.0 if collected else 13.0)
  _text(at+Vector2(-28,-37),"EMPTY" if collected else "CACHE",c,15)
 for enemy in dungeon.enemies:
  var at: Vector2 = enemy["pos"]
  var defeated: bool = bool(enemy["defeated"])
  var c: Color = Color("#43586A") if defeated else (PINK if bool(enemy["boss"]) else VIOLET)
  draw_arc(at,54.0 if bool(enemy["boss"]) else 34.0,0,TAU,46,c,4)
  draw_rect(Rect2(at-Vector2(17,17),Vector2(34,34)),c)
  _text(at+Vector2(-54,-60),str(enemy["name"]),c,16)

func _draw_withnet() -> void:
 # A readable public network: one continuous east-west data highway and three
 # labelled districts instead of a tangled set of arbitrary node connections.
 for gx in range(maxi(0,int((player.x-950.0)/72.0)*72),mini(int(WORLD_SIZE.x),int(player.x+950.0)),72):
  draw_line(Vector2(gx,maxf(0.0,player.y-900.0)),Vector2(gx,minf(WORLD_SIZE.y,player.y+900.0)),Color("#10283B"),1.0)
 for gy in range(maxi(0,int((player.y-750.0)/72.0)*72),mini(int(WORLD_SIZE.y),int(player.y+750.0)),72):
  draw_line(Vector2(maxf(0.0,player.x-1050.0),gy),Vector2(minf(WORLD_SIZE.x,player.x+1050.0),gy),Color("#10283B"),1.0)
 var sectors = [
  {"bounds":Rect2(260,140,680,890),"title":"SECTOR A   //   PUBLIC DATA","tag":"ARCHIVES / SEARCH / TOOLS","accent":CYAN},
  {"bounds":Rect2(960,140,415,890),"title":"SECTOR B  //  SERVICES","tag":"MISSIONS / REPAIR","accent":LIME},
  {"bounds":Rect2(1395,140,450,890),"title":"SECTOR C  //  RED ZONE","tag":"BLACK ICE / ANOMALIES","accent":PINK},
   {"bounds":Rect2(2040,140,950,890),"title":"SECTOR D // NEON BAZAAR","tag":"DATA CITY / MINES","accent":VIOLET},
   {"bounds":Rect2(3040,140,950,890),"title":"SECTOR E // GHOST PORT","tag":"DATA CITY / ELITE ICE","accent":CYAN},
   {"bounds":Rect2(4040,140,1420,890),"title":"SECTOR F // CIPHER CITADEL","tag":"BOSS CITY / BLACK MARKET","accent":PINK}
 ]
 for sector in sectors:
  var region: Rect2 = sector["bounds"]
  var tint: Color = sector["accent"]
  draw_rect(region,Color(tint.r,tint.g,tint.b,0.025))
  draw_rect(region,Color(tint.r,tint.g,tint.b,0.26),false,2.0)
  draw_rect(Rect2(region.position,Vector2(region.size.x,56)),Color(tint.r,tint.g,tint.b,0.10))
  _text(region.position+Vector2(21,35),sector["title"],tint,21)
  _text(region.position+Vector2(21,72),sector["tag"],Color("#6F98AA"),14)
  for k in range(1,5):
   var y = region.position.y+100+k*142
   draw_line(Vector2(region.position.x+15,y),Vector2(region.end.x-15,y),Color("#1B4052"),1)
 _draw_pixel_architecture()
 _draw_large_world()
 # An unbroken transit line makes the overall topology easy to understand.
 _beam(Vector2(175,550),Vector2(WORLD_SIZE.x-180.0,550),CYAN)
 draw_line(Vector2(175,565),Vector2(WORLD_SIZE.x-180.0,565),Color("#226781"),2)
 for route_y in [1750.0,2760.0]:
  draw_line(Vector2(140,route_y),Vector2(WORLD_SIZE.x-155.0,route_y),Color("#17506A"),10)
  draw_line(Vector2(140,route_y),Vector2(WORLD_SIZE.x-155.0,route_y),CYAN.darkened(0.57),2)
 for lane_x in [1050.0,1790.0,3100.0,4450.0,5810.0,7160.0,8500.0]:
  draw_line(Vector2(lane_x,550),Vector2(lane_x,2760),Color("#17506A"),7)
  draw_line(Vector2(lane_x,550),Vector2(lane_x,2760),VIOLET.darkened(0.55),2)
 for i in range(39):
  var x = 330.0+i*230.0
  draw_line(Vector2(x,535),Vector2(x,575),Color("#2FA4B6"),2)
  _glow(Vector2(175,550).lerp(Vector2(WORLD_SIZE.x-180.0,550),fposmod(elapsed*0.18+float(i)*0.026,1.0)),CYAN,4)
 # Vertical service lanes and glowing branch connections.
 for idx in range(nodes.size()):
  var n = nodes[idx]
  if n.get("hidden",false) and not state.hidden_revealed:
   continue
  var at: Vector2 = n["pos"]
  var tint: Color = n["color"]
  var junction = Vector2(at.x,550)
  _beam(junction,at,tint)
  draw_arc(junction,12,0,TAU,30,tint,2)
  _glow(junction.lerp(at,fposmod(elapsed*0.25+float(idx)*0.13,1.0)),tint,4)
  var frame = Rect2(at+Vector2(-36,-36),Vector2(72,72))
  draw_rect(frame,Color(tint.r,tint.g,tint.b,0.08))
  draw_rect(frame,Color(tint.r,tint.g,tint.b,0.52),false,2)
  draw_arc(at,30+sin(elapsed*2+idx)*3,0,TAU,40,tint,2)
  _glow(at,tint,14)
  var offset = Vector2(-62,-69) if at.x > 1560 else Vector2(36,-46)
  _text(at+offset,n["name"],tint,18)
  _text(at+offset+Vector2(0,23),n["kind"]+" / ONLINE",Color("#80AEBE"),14)
 # Small collectable data packets between the route branches.
 for i in range(orbs.size()):
  if state.collected_orbs.has(str(i)):
   continue
  var orb: Vector2 = orbs[i]
  draw_arc(orb,12+sin(elapsed*3+i)*3,0,TAU,28,LIME,2)
  _glow(orb,LIME,5)
 # Homebase entry is easy to identify from the western transit line.
 draw_arc(HOME_PORTAL_POS,60+sin(elapsed*3)*4,0,TAU,60,LIME,3)
 _glow(HOME_PORTAL_POS,CYAN,29)
 _text(HOME_PORTAL_POS+Vector2(-64,-92),"HOMEBASE",LIME,21)
 _text(HOME_PORTAL_POS+Vector2(-67,100),"SAFE UPLINK",CYAN,16)
 if player.distance_to(HOME_PORTAL_POS) < 108:
  _text(HOME_PORTAL_POS+Vector2(-65,129),"HACK TO RETURN",LIME,17)
 # The outer firewall covers the entire height of Sector C (not just the ICE gate).
 var powered = not _has_red_zone_access()
 var wall_color = PINK if powered else Color("#42DCB9")
 draw_rect(Rect2(RedZone.BORDER_X-18,0,36,WORLD_SIZE.y),Color(wall_color.r,wall_color.g,wall_color.b,0.09))
 for k in range(72):
  var y = float(k)*48.0
  var flash = 0.4+0.35*sin(elapsed*3.2+float(k)*0.64)
  var width = 13.0 if powered else 5.0
  draw_line(Vector2(RedZone.BORDER_X,y),Vector2(RedZone.BORDER_X,y+42.0),
    Color(wall_color.r,wall_color.g,wall_color.b,flash),width)
  draw_circle(Vector2(RedZone.BORDER_X+sin(elapsed*1.5+float(k))*9.0,y+21.0),3,wall_color)
 draw_line(Vector2(RedZone.BORDER_X-31,0),Vector2(RedZone.BORDER_X-31,WORLD_SIZE.y),Color(PINK.r,PINK.g,PINK.b,0.28),2)
 _text(Vector2(RedZone.BORDER_X-195,102),"RED SECURITY WALL",PINK,20)
 _text(Vector2(RedZone.BORDER_X-181,126),"CLEARANCE %d/2" % state.clearance_level,LIME,17)
 _text(Vector2(RedZone.BORDER_X-174,595),"HACK REQUIRED" if powered else "ACCESS VERIFIED",wall_color,19)
 # Moving hostile ICE guards have detection circles and combat-type labels.
 for guard in red_zone.guards:
  var p: Vector2 = guard["pos"]
  var is_down: bool = guard["defeated"]
  var tint = Color("#45636A") if is_down else PINK
  var radius = float(guard["radius"])
  draw_arc(p,radius,0,TAU,64,Color(tint.r,tint.g,tint.b,0.27),2)
  draw_arc(p,31.0+sin(elapsed*3.0)*3.0,0,TAU,48,tint,3)
  if not is_down:
   _glow(p,tint,15)
  else:
   draw_line(p+Vector2(-13,-13),p+Vector2(13,13),tint,3)
   draw_line(p+Vector2(13,-13),p+Vector2(-13,13),tint,3)
  _text(p+Vector2(-43,-48),str(guard["name"]),tint,16)
  _text(p+Vector2(-30,53),"OFFLINE" if is_down else "LV %d  //  HOSTILE" % int(guard["level"]),tint,13)
 for mine in signal_mines:
  if bool(mine["active"]):
   var mp: Vector2 = mine["pos"]
   draw_arc(mp,27,0,TAU,40,PINK,3)
   draw_line(mp+Vector2(-12,-12),mp+Vector2(12,12),PINK,3)
   _text(mp+Vector2(-42,-40),"SIGNAL MINE",PINK,14)
 # Central firewall portal divides the regular net from a protected system.
 draw_arc(GATE_POS,57+sin(elapsed*3.7)*4,0,TAU,64,PINK,4)
 draw_arc(GATE_POS,77,0.3,PI*1.5,52,Color(1,0.2,0.45,0.55),2)
 _glow(GATE_POS,LIME if ice_open else PINK,28)
 _text(GATE_POS+Vector2(-94,-98),"ICE // SECURITY",PINK,21)
 _text(GATE_POS+Vector2(-94,115),"ACCESS GRANTED" if ice_open else "BREACH REQUIRED",LIME,17)
 if player.distance_to(GATE_POS) < 109:
  _text(GATE_POS+Vector2(-94,145),"HACK TO CONNECT",CYAN,17)

func _base_camera_offset(canvas: Vector2) -> Vector2:
 # A fixed landscape camera keeps the room visible without clipping consoles.
 return Vector2(720,600)-canvas*0.5

func _draw_base_terminal(node: Dictionary) -> void:
 var at: Vector2 = node["pos"]
 var tint: Color = node["color"]
 var kind: String = str(node["kind"])
 var label: String = str(node["name"]).split(" // ")[0]
 var caption: String = ""
 match kind:
  "UPLINK": caption = "ENTER WITHNET"
  "UPGRADE": caption = "SPEED / BUFFER"
  "FAB": caption = "CRAFT PROGRAMS"
  "MISSION": caption = "CONTRACTS"
  "MODULE": caption = "BASE DEFENSE"
  "ARMORY": caption = "ICE TRAINING"
  "ARCHIVE": caption = "OPERATOR LOG"
  "ACCESS": caption = "RED ZONE PASS"
 var card = Rect2(at-Vector2(110,51),Vector2(220,102))
 var nearby: bool = base_player.distance_to(at) < 108.0
 draw_rect(card,Color("#101F30"))
 draw_rect(Rect2(card.position,Vector2(card.size.x,4)),tint)
 draw_rect(card,Color(tint.r,tint.g,tint.b,0.95 if nearby else 0.45),false,3 if nearby else 1)
 var indicator = at+Vector2(-68,3)
 draw_arc(indicator,27,0,TAU,40,tint,3)
 draw_circle(indicator,11.0+sin(elapsed*2.8+at.x)*2.0,tint)
 _text(at+Vector2(-24,-3),label,tint,18)
 _text(at+Vector2(-24,23),caption,Color("#A1BDCC"),13)
 if nearby:
  draw_rect(Rect2(card.position+Vector2(5,card.size.y-8),Vector2(card.size.x-10,3)),LIME)

func _draw_homebase() -> void:
 # Calm functional room: four distinct bays and a central safe corridor.
 var room = Rect2(145,355,1150,495)
 draw_rect(room,Color("#071B29"))
 draw_rect(room,Color("#2E7186"),false,4)
 for gx in range(195,1290,64):
  draw_line(Vector2(gx,410),Vector2(gx,841),Color("#173244"),1)
 for gy in range(415,850,64):
  draw_line(Vector2(155,gy),Vector2(1286,gy),Color("#173244"),1)
 draw_rect(Rect2(152,363,1136,48),Color("#112D3A"))
 draw_rect(Rect2(161,375,5,27),LIME)
 _text(Vector2(183,395),"HOMEBASE  //  OPERATOR HUB",LIME,26)
 _text(Vector2(975,393),"PRIVATE GRID / ONLINE",CYAN,16)
 for i in range(9):
  var x: float = 235.0+float(i)*110.0
  draw_rect(Rect2(x,406,24,3),Color(CYAN.r,CYAN.g,CYAN.b,0.25+0.55*absf(sin(elapsed*1.7+float(i)*0.85))))
 draw_rect(Rect2(204,417,472,412),Color("#0B2230"))
 draw_rect(Rect2(764,417,472,412),Color("#0B2230"))
 draw_line(Vector2(204,676),Vector2(676,676),Color("#2B5164"),2)
 draw_line(Vector2(764,676),Vector2(1236,676),Color("#2B5164"),2)
 _text(Vector2(220,438),"01  //  ENGINEERING",VIOLET,15)
 _text(Vector2(780,438),"02  //  NETWORK",CYAN,15)
 _text(Vector2(220,699),"03  //  DEFENSE",PINK,15)
 _text(Vector2(780,699),"04  //  INTEL & ACCESS",LIME,15)
 for n in base_nodes:
  if n["kind"] != "CORE":
   _draw_base_terminal(n)
 var hub = Vector2(720,610)
 draw_circle(hub,65,Color("#0C2B39"))
 draw_arc(hub,62,0,TAU,60,Color("#27677D"),2)
 draw_arc(hub,51,elapsed*0.2,elapsed*0.2+PI*1.7,46,CYAN,3)
 draw_arc(hub,35,0,TAU,45,LIME,2)
 _glow(hub,CYAN,18.0+sin(elapsed*2.0)*2.0)
 _text(hub+Vector2(-37,-78),"CORE",LIME,17)
 _text(Vector2(670,658),"SAFE / NO ICE",LIME,13)
 draw_line(Vector2(720,676),Vector2(720,681),CYAN,3)
 draw_arc(BASE_SPAWN,25,0,TAU,40,Color("#39788B"),2)

func _draw_minimap(canvas: Vector2) -> void:
 var origin = Vector2(canvas.x-252,96)
 var rect = Rect2(origin,Vector2(233,150))
 draw_rect(rect,Color("#0A1E2C"))
 draw_rect(rect,Color("#3B91A4"),false,1)
 _text(origin+Vector2(12,23),"NETWORK OVERVIEW",LIME,15)
 var map_base = origin+Vector2(10,35)
 var sx = 213.0/WORLD_SIZE.x
 var sy = 105.0/WORLD_SIZE.y
 for line_x in [260.0,960.0,1395.0,2050.0,3100.0,4300.0,5550.0,6890.0,8240.0]:
  draw_line(map_base+Vector2(line_x*sx,0),map_base+Vector2(line_x*sx,104),Color("#2E586B"),1)
 draw_line(map_base+Vector2(0,550.0*sy),map_base+Vector2(213,550.0*sy),CYAN,2)
 for i in range(nodes.size()):
  if nodes[i].get("hidden",false) and not state.hidden_revealed:
   continue
  var pos: Vector2 = nodes[i]["pos"]
  draw_circle(map_base+Vector2(pos.x*sx,pos.y*sy),3,nodes[i]["color"])
 draw_line(map_base+Vector2(RedZone.BORDER_X*sx,0),map_base+Vector2(RedZone.BORDER_X*sx,104),LIME if _has_red_zone_access() else PINK,2)
 for guard in red_zone.guards:
  if not bool(guard["defeated"]):
   var p: Vector2 = guard["pos"]
   draw_circle(map_base+Vector2(p.x*sx,p.y*sy),3,PINK)
 draw_circle(map_base+Vector2(GATE_POS.x*sx,GATE_POS.y*sy),4,PINK)
 draw_circle(map_base+Vector2(HOME_PORTAL_POS.x*sx,HOME_PORTAL_POS.y*sy),4,LIME)
 for entry in open_world.portals:
  var gate: Vector2 = entry["pos"]
  draw_circle(map_base+Vector2(gate.x*sx,gate.y*sy),3,VIOLET)
 for road_y in [1750.0,2760.0]:
  draw_line(map_base+Vector2(0,road_y*sy),map_base+Vector2(213,road_y*sy),CYAN.darkened(0.40),1)
 draw_circle(map_base+Vector2(player.x*sx,player.y*sy),5,CYAN)

func _draw_darknet() -> void:
 for y in range(MAZE.size()):
  for x in range(MAZE[y].length()):
   var at = Vector2(x,y)*TILE
   if MAZE[y][x] == "#":
    draw_rect(Rect2(at,Vector2(TILE,TILE)),Color("#171A2A"))
    draw_rect(Rect2(at+Vector2(5,5),Vector2(TILE-10,TILE-10)),Color("#0B1522"))
    draw_rect(Rect2(at,Vector2(TILE,TILE)),Color(1.0,0.24,0.40,0.48),false,2)
   else:
    draw_circle(at+Vector2(TILE/2,TILE/2),2,Color("#28556D"))
 for i in range(DARK_PACKETS.size()):
  if dark_loot.has(str(i)):
   continue
  var at: Vector2 = DARK_PACKETS[i]
  draw_arc(at,22+sin(elapsed*3+i)*3,0,TAU,40,LIME,3)
  _glow(at,LIME,9)
  _text(at+Vector2(-33,-30),"DATA",LIME,14)
 var exit_color = LIME if dark_collected >= DARK_PACKETS.size() else PINK
 draw_arc(EXIT_POS,31+sin(elapsed*5)*3,0,TAU,40,exit_color,3)
 _glow(EXIT_POS,exit_color,17)
 _text(EXIT_POS+Vector2(-30,-45),"EXIT",exit_color,18)
 if not hunter_disabled:
  _glow(hunter,PINK,13)
  draw_arc(hunter,28,0,TAU,42,PINK,3)
  _text(hunter+Vector2(-30,-43),"ICE",PINK,16)

func _draw_hud(canvas: Vector2) -> void:
 draw_rect(Rect2(0,0,canvas.x,82),Color("#0D1B2A"))
 draw_rect(Rect2(20,17,5,45),LIME)
 _text(Vector2(39,47),"CYBERLOAD",LIME,29)
 _text(Vector2(260,46),"// NET.RUNNER",CYAN,23)
 var zone_name = "00 / HOMEBASE" if world_mode == 2 else ("01 / WITHNET" if world_mode == 0 else ("02 / DARKNET" if world_mode == 1 else "03 / DUNGEON"))
 _text(Vector2(canvas.x-255,46),zone_name,PINK if world_mode==1 else CYAN,20)
 draw_rect(Rect2(0,82,canvas.x,2),Color("#2388A1"))
 if world_mode != 2:
  draw_rect(Rect2(18,99,minf(canvas.x-36.0,960.0),53),Color("#112638"))
  _text(Vector2(34,132),status,LIME,19)
 var resource_y = canvas.y-85
 draw_rect(Rect2(0,resource_y,canvas.x,85),Color("#0A1726"))
 draw_line(Vector2(0,resource_y),Vector2(canvas.x,resource_y),Color("#245873"),2)
 _text(Vector2(27,resource_y+28),"CR %d" % state.credits,LIME,18)
 _text(Vector2(160,resource_y+28),"DATA %d" % state.fragments,CYAN,18)
 _text(Vector2(315,resource_y+28),"TRACE %d%%" % int(state.trace),PINK,18)
 _text(Vector2(480,resource_y+28),"HP %d%%" % int(state.integrity),LIME,18)
 _text(Vector2(615,resource_y+28),"CLEARANCE %d/2" % state.clearance_level,CYAN,17)
 if world_mode == 0:
  _text(Vector2(820,resource_y+28),"DRILL %d  ORE %d" % [state.drill_level,state.ore_total()],CYAN,17)
 _text(Vector2(28,resource_y+65),("DUNGEON // "+DungeonInstance.NAMES[dungeon_id]+" | FIND BOSS / CACHE / EXIT" if world_mode==3 else state.mission_text()),Color("#85BAC8"),16)
 _text(Vector2(canvas.x-175,resource_y+66),"TAP TITLE: LOG",Color("#7199AB"),14)
 if world_mode == 1:
  _text(Vector2(canvas.x-390,132),"PACKETS %d / 3" % dark_collected,LIME,20)
 elif world_mode == 3:
  var cleared: bool = bool(state.dungeon_clears.get("DUNGEON_%d" % dungeon_id,false))
  _text(Vector2(canvas.x-445,132),"BOSS DEFEATED // EXIT" if cleared else "FIND THE BOSS // LV %d" % dungeon.level,LIME if cleared else PINK,18)
 elif world_mode == 0:
  var nearby = _nearest_node()
  if nearby >= 0:
   _text(Vector2(canvas.x-360,132),"HACK  //  "+_active_nodes()[nearby]["kind"],CYAN,18)
  elif open_world.nearest_portal(player) >= 0:
   _text(Vector2(canvas.x-435,132),"HACK // ENTER DUNGEON",VIOLET,18)
  elif open_world.nearest_vein(player) >= 0:
   _text(Vector2(canvas.x-435,132),"HACK // MINE DATA ORE",LIME,18)
 if dev_overkill:
  _text(Vector2(canvas.x*0.5-20,47),"DEV // OVERKILL",PINK,18)
 if world_mode == 0 and jam_remaining <= 0.0:
  _draw_minimap(canvas)
 elif world_mode == 0 and jam_remaining > 0.0:
  _text(Vector2(canvas.x-330,132),"RADAR OFFLINE / JAMMED",PINK,18)
 elif world_mode == 2 and notification_timer > 0.0:
  var toast = Rect2(canvas.x*0.5-285,resource_y-36,570,30)
  draw_rect(toast,Color("#132B39"))
  draw_rect(toast,CYAN,false,1)
  _text(toast.position+Vector2(12,21),status,LIME,15)
 _draw_controls(canvas)

func _joystick_center(canvas: Vector2) -> Vector2:
 return Vector2(94,canvas.y-167) if world_mode == 2 else Vector2(122,canvas.y-185)

func _joystick_radius() -> float:
 return 59.0 if world_mode == 2 else 85.0

func _action_center(canvas: Vector2) -> Vector2:
 return Vector2(canvas.x-77,canvas.y-167) if world_mode == 2 else Vector2(canvas.x-120,canvas.y-187)

func _action_hit(point: Vector2,canvas: Vector2) -> bool:
 return point.distance_to(_action_center(canvas)) <= (60.0 if world_mode == 2 else 80.0)

func _mesh_fire_hit(point: Vector2,canvas: Vector2) -> bool:
 return world_mode==0 and point.distance_to(Vector2(canvas.x-260.0,canvas.y-325.0))<63.0

func _draw_controls(canvas: Vector2) -> void:
 var center = _joystick_center(canvas)
 var radius = _joystick_radius()
 draw_circle(center,radius,Color("#0B2739"))
 draw_arc(center,radius,0,TAU,60,Color("#4B9BAF"),2)
 draw_arc(center,radius*0.78,0,TAU,50,Color("#1C5D74"),1)
 _glow(center+joystick*(radius*0.6),CYAN,13.0 if world_mode == 2 else 18.0)
 var action = _action_center(canvas)
 var action_radius = 55.0 if world_mode == 2 else 75.0
 draw_circle(action,action_radius,Color("#291524"))
 draw_arc(action,action_radius,0,TAU,55,PINK,3)
 draw_arc(action,action_radius*0.83,0,TAU,55,Color("#AB3B5A"),1)
 _text(action+Vector2(-26,7),"HACK",LIME,19 if world_mode == 2 else 24)
 if world_mode==0:
  var fire=Vector2(canvas.x-260.0,canvas.y-325.0)
  draw_circle(fire,58.0,Color("#221D38"))
  draw_arc(fire,58.0,0,TAU,50,LIME,3)
  _text(fire+Vector2(-29,8),"FIRE",LIME,21)

func _draw_node_panel(canvas: Vector2) -> void:
 var rect = _panel_rect(canvas)
 draw_rect(Rect2(Vector2.ZERO,canvas),Color(0,0,0,0.67))
 draw_rect(rect,Color("#0C1C2D"))
 draw_rect(rect,CYAN,false,2)
 var p = rect.position
 var n = _active_nodes()[selected_node]
 _text(p+Vector2(30,55),"NODE INTERFACE  //  "+n["name"],LIME,26)
 _text(p+Vector2(31,100),n["kind"]+" SYSTEM",CYAN,23)
 _text(p+Vector2(31,143),n["details"],Color("#A3C9D5"),18)
 _text(p+Vector2(31,187),"CREDITS: %d    DATA: %d    TRACE: %d%%" % [state.credits,state.fragments,int(state.trace)],LIME,18)
 _text(p+Vector2(31,230),_node_hint(n["kind"]),Color("#93B7C9"),16)
 var labels = _node_buttons(n["kind"])
 for i in range(2):
  var button_rect = Rect2(p+Vector2(28+i*344,280),Vector2(319,79))
  draw_rect(button_rect,Color("#12374A") if i==0 else Color("#26314A"))
  draw_rect(button_rect,CYAN if i==0 else VIOLET,false,2)
  _text(button_rect.position+Vector2(14,46),labels[i],LIME,18)
 _text(p+Vector2(32,420),"TAP AN ACTION  //  E: OPTION 1  //  ESC: CLOSE",Color("#8DB3C1"),17)

func _node_hint(kind: String) -> String:
 match kind:
  "ACCESS": return "LEVEL 1: EXTRA TIME  /  LEVEL 2: AUTO-ACCESS"
  "FAB": return "Craft new hacking daemons from data fragments"
  "MODULE": return "Permanent base defense and signal upgrades"
  "ARMORY": return "Train rhythm attacks or change active program"
  "COMBAT": return "Four inputs per attack or counter-ICE defense"
  "UPLINK": return "PUBLIC MAP: A / DATA - B / SERVICES - C / ICE"
  "CORE": return "Your private core repairs and hides your signal"
  "ARCHIVE": return "Mission status, progress, and network information"
  "UPGRADE": return "OVERCLOCK increases speed; BUFFER adds a matrix slot"
  "MARKET": return "Purchased utilities are applied immediately"
  "DATACITY": return "Discover distant Red Zone city for credits and data"
  "DATAMARKET": return "Advanced local trade and signal-jam recovery"
  "MINING_RIG": return "Upgrade your drill to mine rare ores // Sell cargo"
  "ANOMALY": return "Danger: extraction increases network TRACE"
  "MISSION": return state.mission_text()
  "VAULT": return "One-time secret cache discovered through scan"
  _: return "Select an available terminal operation"

func _node_buttons(kind: String) -> Array:
 match kind:
  "ACCESS": return ["UPGRADE CLEARANCE","CHECK CURRENT LEVEL"]
  "FAB": return ["CRAFT PROGRAMS","MESH BUILDER"]
  "ARMORY": return ["OPEN LOADOUT","TRAIN AGAINST ICE"]
  "MODULE": return ["INSTALL MODULES","VIEW MODULES"]
  "COMBAT": return ["INITIATE ICE DUEL","SCAN SECURITY"]
  "UPLINK": return ["ENTER WITHNET","OPEN NETWORK LOG"]
  "CORE": return ["REPAIR HP / 20 CR","CLEAR TRACE / 25 CR"]
  "ARCHIVE": return ["OPEN OPERATOR LOG","VIEW CONTRACT"]
  "DATA": return ["EXTRACT ARCHIVE","CHECK CACHE"]
  "SCAN": return ["REVEAL HIDDEN NODE","CLEAN TRACE -8"]
  "UPGRADE": return ["SPEED UPGRADE","BUFFER UPGRADE"]
  "MARKET": return ["SCRUB TRACE / 35 CR","REPAIR HP / 45 CR"]
  "DATACITY": return ["DISCOVER DATA CITY","CITY INTELLIGENCE"]
  "DATAMARKET": return ["REPAIR / 65 CR 5 DATA","SCRUB / 90 CR 7 DATA"]
  "MINING_RIG": return ["UPGRADE DRILL","SELL ALL ORE"]
  "MISSION": return ["VIEW CONTRACT","CHECK PROGRESS"]
  "RELAY": return ["REPAIR HP / 15 CR","RETURN TO UPLINK"]
  "ANOMALY": return ["EXTRACT RIFT / RISK","ABORT EXTRACTION"]
  "VAULT": return ["OPEN SECRET CACHE","LEAVE UNTOUCHED"]
 return ["CONNECT","CANCEL"]

func _draw_journal(canvas: Vector2) -> void:
 draw_rect(Rect2(Vector2.ZERO,canvas),Color(0,0,0,0.8))
 var x = canvas.x*0.5-350
 _text(Vector2(x,150),"NET.RUNNER  //  OPERATOR LOG",LIME,31)
 _text(Vector2(x,218),"CURRENT CONTRACT",CYAN,23)
 _text(Vector2(x,255),state.mission_text(),LIME,21)
 _text(Vector2(x,327),"CREDITS  %d       FRAGMENTS  %d" % [state.credits,state.fragments],CYAN,20)
 _text(Vector2(x,369),"INTEGRITY %d%%       TRACE %d%%" % [int(state.integrity),int(state.trace)],PINK,20)
 _text(Vector2(x,411),"SPEED LVL %d      BUFFER +%d      SCAN LVL %d" % [state.speed_level,state.buffer_level,state.scan_level],CYAN,20)
 _text(Vector2(x,463),"BREACHES  %d        DARKNET RUNS  %d" % [state.breaches,state.darknet_runs],CYAN,20)
 _text(Vector2(x,490),"EQUIPPED: "+state.active_program+"   ICE WINS: %d" % state.ice_wins,CYAN,19)
 _text(Vector2(x,520),"CLEARANCE %d/2    RED HACKS %d    GUARDS DEFEATED %d" % [state.clearance_level,state.red_zone_hacks,state.defeated_guards_total],LIME,17)
 _text(Vector2(x,550),"PROGRESS IS SAVED AUTOMATICALLY",LIME,18)
 _text(Vector2(x,600),"TAP TO RETURN",Color("#8BB3C2"),19)

func _draw_breach(canvas: Vector2) -> void:
 draw_rect(Rect2(30,44,canvas.x-60,canvas.y-88),Color("#101C28"))
 draw_rect(Rect2(30,44,canvas.x-60,canvas.y-88),LIME,false,1)
 _text(Vector2(70,98),"BREACH // RED ZONE FIREWALL" if breach_target == "ZONE" else "BREACH // DARKNET ICE MATRIX",LIME,29)
 _text(Vector2(74,145),"BREACH TIMER   %04.1f" % breach_timer,PINK,24)
 _text(Vector2(650,144),"BUFFER  %d / %d" % [buffer.size(),6+state.buffer_level],LIME,21)
 for i in range(6+state.buffer_level):
  var p = Vector2(650+i*68,165)
  draw_rect(Rect2(p,Vector2(61,51)),Color("#173041"))
  var value = "--"
  if i < buffer.size():
   var cell: Vector2i = buffer[i]
   value = matrix[cell.y][cell.x]
  _text(p+Vector2(10,34),value,CYAN,21)
 _text(Vector2(205,188),"CODE MATRIX",LIME,18)
 for y in range(5):
  for x in range(5):
   var p = Vector2(205+x*69,205+y*69)
   var chosen = buffer.has(Vector2i(x,y))
   draw_rect(Rect2(p,Vector2(63,63)),Color("#1D4051") if chosen else Color("#182637"))
   draw_rect(Rect2(p,Vector2(63,63)),CYAN if chosen else Color("#385569"),false,2)
   _text(p+Vector2(10,40),matrix[y][x],LIME,23)
 _text(Vector2(650,275),"AVAILABLE DAEMONS",LIME,21)
 for i in range(hack_targets.size()):
  var target: Array = hack_targets[i]
  _text(Vector2(650,333+i*81),HACK_NAMES[i],CYAN,21)
  _text(Vector2(650,365+i*81),"%s  %s  %s" % [target[0],target[1],target[2]],LIME,23)
 _text(Vector2(205,586),"FIRST ROW -> SAME COLUMN -> SAME ROW",CYAN,17)
 _text(Vector2(205,627),"TIMER EXPIRY = TRACE +12",PINK,16)
 _text(Vector2(1000,627),"RESET BUFFER",LIME,18)


# --------------------------------------------------------------------------
# GAME SYSTEMS v0.5: crafting, base building and rhythm-based ICE encounters
# --------------------------------------------------------------------------
func _start_duel(from_darknet: bool, training: bool) -> void:
 duel_from_darknet = from_darknet
 duel_training = training
 duel_active = true
 node_open = false
 overlay_mode = ""
 joystick = Vector2.ZERO
 # Experienced players encounter faster elite ICE in repeated arenas/runs.
 var difficulty = 1 if training else (clampi(3+int(state.darknet_runs/2.0),3,5) if from_darknet else clampi(2+int(state.ice_wins/3.0),2,5))
 if red_guard_index >= 0:
  difficulty = int(red_zone.guards[red_guard_index]["level"])
 if dungeon_duel and dungeon_guard_index >= 0:
  difficulty = int(dungeon.enemies[dungeon_guard_index]["level"])
 var hp = 100.0 if training else state.integrity
 if mesh_loot_active:
  difficulty = 1
 duel.begin(state.active_program, state.installed_modules, hp, difficulty, state.chrono_unlocked,mesh_loot_active)
 duel.dev_overkill = dev_overkill
 duel_burst_done = false
 fx.clear_screen()
 _notify("NETDUEL ACTIVE  //  "+duel.phase)

func _finish_duel() -> void:
 if not duel_active or duel.result == "RUNNING":
  return
 var won: bool = duel.result == "WIN"
 duel_active = false
 if duel_training:
  _notify("TRAINING COMPLETE  //  "+duel.result)
  return
 state.integrity = maxf(1.0,duel.player_hp)
 if dungeon_duel:
  dungeon_duel = false
  var guardian: int = dungeon_guard_index
  dungeon_guard_index = -1
  dungeon_guard_cooldown = 1.8
  if won and dungeon.defeat(guardian):
   var boss: bool = bool(dungeon.enemies[guardian]["boss"])
   var reward: int = (230 if boss else 75)+dungeon.level*35
   state.credits += reward
   state.fragments += (18 if boss else 4)+dungeon.level*3
   state.ice_wins += 1
   fx.burst(dungeon.enemies[guardian]["pos"],"ice",false,70 if boss else 38)
   if boss:
    state.dungeon_clears["DUNGEON_%d" % dungeon_id] = true
    state.ore_inventory["VOID"] = int(state.ore_inventory.get("VOID",0))+2+dungeon.level
    _notify("DUNGEON BOSS DESTROYED // +RARE ORE")
   else:
    _notify("DUNGEON ICE DEFEATED // +%d CR" % reward)
  elif not won:
   state.ice_losses += 1
   state.trace = minf(100.0,state.trace+12.0)
   dungeon_player = dungeon.spawn
   _notify("DUNGEON ICE HIT // RESPAWN AT ENTRY")
  state.save_game()
  return
 if mesh_loot_active:
  _mesh_finish_loot(won)
  return
 if mine_duel:
  mine_duel = false
  if won:
   fx.burst(_current_pos(),"ice",false,44)
   state.credits += 45
   _notify("SIGNAL MINE DEFUSED // +45 CR")
  else:
   fx.impact(12.0,0.28)
   fx.flash(PINK,0.19)
   jam_remaining = 25.0
   _notify("SIGNAL JAM // VISION REDUCED 25 SEC")
  state.save_game()
  return
 if won:
  var victory_position: Vector2 = GATE_POS if duel_from_darknet else player
  if red_guard_index >= 0:
   victory_position = red_zone.guards[red_guard_index]["pos"]
  fx.burst(victory_position,"ice",false,65)
  fx.impact(10.0,0.25)
  state.ice_wins += 1
  state.credits += 90 if duel_from_darknet else 60
  state.fragments += 9 if duel_from_darknet else 6
  state.trace = maxf(0.0,state.trace-6.0)
  if duel_from_darknet:
   hunter_disabled = true
  elif red_guard_index >= 0:
   if red_zone.defeat(red_guard_index):
    state.defeated_guards_total += 1
    var is_boss: bool = str(red_zone.guards[red_guard_index]["kind"]) == "BOSS"
    state.credits += (300 if is_boss else 35) + 15 * int(red_zone.guards[red_guard_index]["level"])
    state.fragments += (25 if is_boss else 0) + int(red_zone.guards[red_guard_index]["level"])*2
   guard_cooldown = 1.4
  _notify("ICE DEFEATED  //  REWARD UPLOADED")
 else:
  fx.impact(9.0,0.28)
  fx.flash(PINK,0.2)
  state.ice_losses += 1
  state.trace = minf(100.0,state.trace+16.0)
  if duel_from_darknet:
   _emergency_disconnect()
  elif red_guard_index >= 0:
   player = Vector2(RedZone.SAFE_RETURN_X-30.0,player.y)
   zone_access = false
   guard_cooldown = 2.0
  _notify("ICE DUEL LOST  //  TRACE INCREASED")
 red_guard_index = -1
 state.save_game()

func _duel_press(direction: int) -> void:
 var old_index: int = duel.index
 var old_phase: String = duel.phase
 var correct: bool = duel.press(direction)
 if correct:
  fx.burst(get_viewport_rect().size*0.5,"shield" if old_phase == "DEFEND" else "upgrade",true,9)
  fx.impact(2.0,0.07)
 elif duel.index != old_index or duel.phase != old_phase:
  fx.burst(get_viewport_rect().size*0.5,"damage",true,11)
  fx.impact(4.0,0.11)

func _duel_key(key: int) -> void:
 var direction = -1
 match key:
  KEY_UP, KEY_W: direction = 0
  KEY_RIGHT, KEY_D: direction = 1
  KEY_DOWN, KEY_S: direction = 2
  KEY_LEFT, KEY_A: direction = 3
 if direction >= 0:
  _duel_press(direction)

func _duel_bomb_rect(canvas: Vector2) -> Rect2:
 return Rect2(Vector2(canvas.x-477,401),Vector2(205,63))

func _duel_bomb() -> void:
 if duel.activate_bomb():
  fx.burst(get_viewport_rect().size*0.5,"ice",true,54)
  fx.impact(11.0,0.23)
  fx.flash(PINK,0.18)

func _duel_slowmo_rect(canvas: Vector2) -> Rect2:
 return Rect2(Vector2(canvas.x-255,401),Vector2(207,63))

func _duel_button_rect(index: int,canvas: Vector2) -> Rect2:
 var slot_width = (canvas.x-208.0)/4.0
 return Rect2(Vector2(84.0+index*(slot_width+12.0),canvas.y-211.0),Vector2(slot_width,104))

func _duel_touch(point: Vector2,canvas: Vector2) -> void:
 if duel.result != "RUNNING":
  _finish_duel()
  return
 if _duel_bomb_rect(canvas).has_point(point):
  _duel_bomb()
  return
 if _duel_slowmo_rect(canvas).has_point(point):
  duel.activate_slowmo()
  return
 for i in range(4):
  if _duel_button_rect(i,canvas).has_point(point):
   _duel_press(i)
   return

func _duel_arrow_direction(direction: int) -> Vector2:
 # Must match RhythmCombat.KEYS and the existing touch/keyboard indices.
 match direction:
  0: return Vector2.UP
  1: return Vector2.RIGHT
  2: return Vector2.DOWN
  3: return Vector2.LEFT
 return Vector2.ZERO

func _draw_duel_arrow(center: Vector2,direction: int,tint: Color,length: float) -> void:
 # True vector arrows work with every mobile font and DPI.
 var heading = _duel_arrow_direction(direction)
 if heading == Vector2.ZERO:
  return
 var side = Vector2(-heading.y,heading.x)
 var tip = center+heading*length*0.53
 var tail = center-heading*length*0.49
 draw_line(tail,tip-heading*length*0.20,tint,maxf(3.0,length*0.11),true)
 draw_colored_polygon(PackedVector2Array([
  tip,
  tip-heading*length*0.38+side*length*0.25,
  tip-heading*length*0.38-side*length*0.25
 ]),tint)

func _draw_duel(canvas: Vector2) -> void:
 draw_rect(Rect2(Vector2.ZERO,canvas),Color("#070C19"))
 for x in range(0,int(canvas.x),54):
  draw_line(Vector2(x,0),Vector2(x,canvas.y),Color("#12293C"),1)
 for y in range(0,int(canvas.y),54):
  draw_line(Vector2(0,y),Vector2(canvas.x,y),Color("#12293C"),1)
 _text(Vector2(65,65),"NETDUEL // ICE ENCOUNTER",LIME,31)
 if dev_overkill:
  _text(Vector2(canvas.x*0.5-90,63),"DEV OVERKILL",PINK,20)
 _text(Vector2(canvas.x-350,63),"ROUND %02d" % duel.turn,PINK,24)
 draw_rect(Rect2(63,104,canvas.x-126,67),Color("#13273A"))
 _text(Vector2(83,144),"RUNNER    %d HP" % int(duel.player_hp),CYAN,20)
 _text(Vector2(canvas.x-350,144),"BLACK ICE    %d HP" % int(duel.ice_hp),PINK,20)
 var hpbar: float = canvas.x-160.0
 draw_rect(Rect2(80,184,hpbar*0.5,11),Color("#293B4E"))
 draw_rect(Rect2(80,184,hpbar*0.5*clampf(duel.player_hp/100.0,0.0,1.0),11),CYAN)
 draw_rect(Rect2(canvas.x*0.5+10,184,hpbar*0.5,11),Color("#293B4E"))
 draw_rect(Rect2(canvas.x*0.5+10,184,hpbar*0.5*clampf(duel.ice_hp/duel.ice_max,0.0,1.0),11),PINK)
 if duel.result != "RUNNING":
  var result_color: Color = LIME if duel.result == "WIN" else PINK
  _text(Vector2(canvas.x*0.5-230,293),"ICE NEUTRALIZED" if duel.result=="WIN" else "CONNECTION LOST",result_color,39)
  _text(Vector2(canvas.x*0.5-210,350),"TAP SCREEN TO RETURN TO NETWORK",CYAN,22)
  _text(Vector2(canvas.x*0.5-180,424),"PROGRAM // "+duel.program,LIME,20)
  return

 var attacking: bool = duel.phase == "ATTACK"
 var lane_tint: Color = CYAN if attacking else PINK
 var target = Vector2(canvas.x*0.5,350)
 var start_x: float = 118.0 if attacking else canvas.x-118.0
 _text(Vector2(87,250),"ATTACK // SEND CODE" if attacking else "DEFEND // BLOCK BLACK ICE",LIME if attacking else PINK,25)
 _text(Vector2(canvas.x-423,248),"PROGRAM  "+duel.program,CYAN,17)
 _text(Vector2(91,294),"YOUR UPLOAD  >>>" if attacking else "<<<  INCOMING ICE",lane_tint,17)
 _text(Vector2(canvas.x-330,294),"LEVEL %d // %d BPM" % [duel.level,duel.bpm()],LIME,17)

 # Persistent neon lane and its single visible target ring.
 draw_line(Vector2(start_x,target.y),target,Color(lane_tint.r,lane_tint.g,lane_tint.b,0.25),17.0,true)
 draw_line(Vector2(start_x,target.y),target,Color(lane_tint.r,lane_tint.g,lane_tint.b,0.50),3.0,true)
 var on_target: bool = absf(duel.time_until_hit(duel.index)) <= duel.hit_window()
 var ring_color: Color = LIME if on_target else lane_tint
 draw_circle(target,46.0,Color("#0D2334"))
 for i in range(duel.index,duel.sequence.size()):
  var until: float = duel.time_until_hit(i)
  if until > duel.travel_time() or until < -duel.hit_window():
   continue
  var x: float = target.x+(start_x-target.x)*until/duel.travel_time()
  var arrow_tint: Color = LIME if attacking else PINK
  if i > duel.index:
   arrow_tint = CYAN if attacking else Color("#EBA0B6")
  _draw_duel_arrow(Vector2(x,target.y),int(duel.sequence[i]),arrow_tint,49.0)
 draw_arc(target,50.0,0,TAU,80,ring_color,5.0 if on_target else 3.0)
 draw_arc(target,37.0,0,TAU,64,Color(ring_color.r,ring_color.g,ring_color.b,0.55),2.0)
 _text(target+Vector2(-43,80),"HIT ZONE",ring_color,16)
 _text(Vector2(88,439),"FOLLOW ARROWS TO THE CIRCLE  //  TAP IN THE RING",LIME,18)
 var prog = Rect2(Vector2(canvas.x*0.5-310,463),Vector2(420,11))
 draw_rect(prog,Color("#193249"))
 draw_rect(Rect2(prog.position,Vector2(prog.size.x*duel.progress(),11)),lane_tint)
 draw_rect(prog,Color("#45687A"),false,2)
 _text(Vector2(90,496),duel.feedback,PINK if duel.feedback.find("MISS")>=0 or duel.feedback.find("WRONG")>=0 else CYAN,16)
 
 var bomb = _duel_bomb_rect(canvas)
 var bomb_ready: bool = duel.phase=="ATTACK" and duel.bomb_charges>0
 draw_rect(bomb,Color("#3C1B32") if bomb_ready else Color("#18212E"))
 draw_rect(bomb,PINK if bomb_ready else Color("#657080"),false,2)
 _text(bomb.position+Vector2(12,29),"BOMB %d" % duel.bomb_charges,PINK if bomb_ready else Color("#798695"),19)
 _text(bomb.position+Vector2(12,53),"BLAST ICE / Q",CYAN,14)
 var slow = _duel_slowmo_rect(canvas)
 var available: bool = duel.chrono_unlocked and duel.slowmo_charges > 0
 draw_rect(slow,Color("#142F42") if available else Color("#17212B"))
 draw_rect(slow,VIOLET if available else Color("#4B5A6C"),false,2)
 var slow_label: String = "SLOWMO %d/2" % duel.slowmo_charges if duel.chrono_unlocked else "SLOWMO LOCKED"
 if duel.slowmo_remaining > 0.0:
  slow_label = "TIME DILATED"
 _text(slow.position+Vector2(14,29),slow_label,VIOLET if available or duel.slowmo_remaining > 0.0 else Color("#8291A1"),18)
 _text(slow.position+Vector2(15,54),"SPACE / TAP" if duel.chrono_unlocked else "CRAFT AT BASE",CYAN if duel.chrono_unlocked else Color("#8291A1"),14)
 for i in range(4):
  var rect = _duel_button_rect(i,canvas)
  draw_rect(rect,Color("#173043"))
  draw_rect(rect,CYAN,false,2)
  _draw_duel_arrow(rect.get_center(),i,LIME,52.0)
 _text(Vector2(83,canvas.y-53),"ATTACK: LEFT TO RIGHT    //    DEFEND: RIGHT TO LEFT",Color("#8BB1BF"),18)

func _overlay_rect(canvas: Vector2) -> Rect2:
 return Rect2(canvas.x*0.5-505,89,1010,535)

func _overlay_entries() -> Array:
 if overlay_mode == "CRAFT":
  return ["LOGIC_BOMB","MIRROR_SHIELD","OVERDRIVE","CHRONO_HACK"]
 if overlay_mode == "INVENTORY":
  return state.PROGRAMS
 return ["FIREWALL","AMPLIFIER","SYNC"]

func _overlay_action(index: int) -> void:
 var entries = _overlay_entries()
 if index < 0 or index >= entries.size():
  return
 var selection: String = entries[index]
 match overlay_mode:
  "CRAFT":
   if selection == "CHRONO_HACK":
    if state.craft_chrono_hack():
     _notify("CHRONO UNLOCKED // SLOWMO IN ICE DUELS")
    else:
     _notify("CHRONO OWNED OR INSUFFICIENT RESOURCES")
   elif state.owned_programs.has(selection):
    _notify("PROGRAM ALREADY CRAFTED")
   elif state.craft_program(selection):
    _notify("NEW PROGRAM CRAFTED  //  "+selection)
   else:
    _notify("NOT ENOUGH CREDITS OR DATA")
  "INVENTORY":
   if state.equip_program(selection):
    _notify("PROGRAM EQUIPPED  //  "+selection)
   else:
    _notify("PROGRAM LOCKED  //  FABRICATE FIRST")
  "MODULES":
   if state.has_module(selection):
    _notify("MODULE ALREADY INSTALLED")
   elif state.install_module(selection):
    _notify("BASE MODULE INSTALLED  //  "+selection)
   else:
    _notify("INSUFFICIENT FUNDS FOR MODULE")
 state.save_game()

func _overlay_touch(point: Vector2,canvas: Vector2) -> void:
 var rect = _overlay_rect(canvas)
 if not rect.has_point(point) or point.y > rect.end.y-55:
  overlay_mode = ""
  return
 var entries = _overlay_entries()
 for i in range(entries.size()):
  var row = Rect2(rect.position+Vector2(19,131+i*87),Vector2(rect.size.x-39,77))
  if row.has_point(point):
   _overlay_action(i)
   return

func _draw_overlay(canvas: Vector2) -> void:
 draw_rect(Rect2(Vector2.ZERO,canvas),Color(0,0,0,0.81))
 var rect = _overlay_rect(canvas)
 draw_rect(rect,Color("#091B2D"))
 draw_rect(rect,CYAN,false,2)
 var origin = rect.position
 var title = {"CRAFT":"DAEMON FABRICATOR","INVENTORY":"HACK LOADOUT","MODULES":"BASE MODULE ENGINEERING"}.get(overlay_mode,"SYSTEM")
 _text(origin+Vector2(26,47),"CYBERLOAD // "+title,LIME,28)
 _text(origin+Vector2(28,97),"CREDITS  %d      DATA  %d      EQUIPPED: %s" % [state.credits,state.fragments,state.active_program],CYAN,18)
 var entries = _overlay_entries()
 for i in range(entries.size()):
  var id: String = entries[i]
  var r = Rect2(origin+Vector2(20,131+i*87),Vector2(rect.size.x-40,77))
  draw_rect(r,Color("#112C3F"))
  draw_rect(r,Color("#2A7E91"),false,1)
  var desc = ""
  var action = ""
  match overlay_mode:
   "CRAFT":
    var recipe: Dictionary = state.RECIPES[id]
    desc = "%d CR  /  %d DATA" % [recipe["credits"],recipe["fragments"]]
    action = "OWNED" if (state.chrono_unlocked if id == "CHRONO_HACK" else state.owned_programs.has(id)) else "CRAFT"
   "INVENTORY":
    desc = "ATTACK / COUNTER-ICE PROGRAM"
    action = "ACTIVE" if state.active_program == id else ("EQUIP" if state.owned_programs.has(id) else "LOCKED")
   "MODULES":
    var cost: Dictionary = state.MODULE_PRICES[id]
    desc = "%d CR  /  %d DATA" % [cost["credits"],cost["fragments"]]
    action = "INSTALLED" if state.has_module(id) else "INSTALL"
  _text(r.position+Vector2(19,31),id,LIME,23)
  _text(r.position+Vector2(19,60),desc,Color("#90BDCC"),17)
  draw_rect(Rect2(r.position+Vector2(r.size.x-191,18),Vector2(169,48)),Color("#17465A"))
  _text(r.position+Vector2(r.size.x-177,50),action,CYAN,19)
 _text(origin+Vector2(28,509),"TAP AN ITEM TO CRAFT, EQUIP OR INSTALL  //  TAP BOTTOM TO CLOSE",Color("#8DB9C9"),17)
