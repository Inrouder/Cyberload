extends Node2D
## CYBERLOAD // NET.RUNNER v0.3 - offline 2D cyberworld, procedural graphics
## World rendering is separated from saved RPG state (game_state.gd).
const GameState = preload("res://scripts/game_state.gd")
const RhythmCombat = preload("res://scripts/rhythm_combat.gd")
const FxSystem = preload("res://scripts/fx_system.gd")
const RedZone = preload("res://scripts/red_zone.gd")
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
const WORLD_SIZE = Vector2(5600, 1200)
const GATE_POS = Vector2(1490, 550)
const HOME_PORTAL_POS = Vector2(175, 550)
const BASE_SIZE = Vector2(1440, 1000)
const BASE_SPAWN = Vector2(720, 690)
const ICE_DUEL_POS = Vector2(1660, 990)

var state = GameState.new()
var player = HOME_PORTAL_POS + Vector2(150, 0)
var base_player = BASE_SPAWN
var dark_player = Vector2(1.5 * TILE, 1.5 * TILE)
var world_mode: int = 2 # 0 Withnet, 1 Darknet, 2 Homebase
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
 _init_nodes()
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
 return false

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
 node_open = false
 _notify("HOMEBASE ONLINE  //  SYSTEMS STABLE")

func _current_pos() -> Vector2:
 if world_mode == 2:
  return base_player
 if world_mode == 1:
  return dark_player
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
  if world_mode == 1:
   _update_darknet(delta)
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
 if world_mode == 2:
  base_player += direction * delta * (240.0 + state.speed_level*30.0)
  base_player = base_player.clamp(Vector2(190,432),Vector2(1250,824))
 elif world_mode == 0:
  var destination = player + direction * delta * (240.0 + state.speed_level*30.0)
  destination = destination.clamp(Vector2(30,30),WORLD_SIZE-Vector2(30,30))
  if red_zone.is_crossing_border(player,destination) and not _has_red_zone_access():
   player.x = minf(player.x,RedZone.SAFE_RETURN_X)
   _start_red_zone_breach()
  else:
   if not _world_wall_collision(Vector2(destination.x,player.y)):
    player.x = destination.x
   if not _world_wall_collision(Vector2(player.x,destination.y)):
    player.y = destination.y
  _collect_world_packets()
 else:
  var next_pos = dark_player + direction * delta * (174.0 + state.speed_level*18.0)
  if not _maze_wall(Vector2(next_pos.x,dark_player.y)):
   dark_player.x = next_pos.x
  if not _maze_wall(Vector2(dark_player.x,next_pos.y)):
   dark_player.y = next_pos.y


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
 if world_mode == 0:
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
     _notify("OVERCLOCK INSTALLED  //  SPEED UP")
    else:
     _notify("INSUFFICIENT CREDITS OR FRAGMENTS")
   else:
    if state.buffer_level >= 2:
     _notify("BUFFER AT MAX CAPACITY")
    elif state.buy(65+state.buffer_level*50,7+state.buffer_level*4):
     state.buffer_level += 1
     _notify("BUFFER EXPANDED  +1 CODE SLOT")
    else:
     _notify("INSUFFICIENT CREDITS OR FRAGMENTS")
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
   overlay_mode = "CRAFT" if option == 0 else "INVENTORY"
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
   else:
    _duel_key(event.keycode)
   return
  if overlay_mode != "":
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
 if world_mode == 0:
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
 else:
  _draw_homebase()
 _draw_runner_trail(focus)
 _draw_fx(false)
 draw_set_transform(Vector2.ZERO)
 _draw_signal_jam(canvas)
 _draw_hud(canvas)
 if node_open:
  _draw_node_panel(canvas)
 if journal_open:
  _draw_journal(canvas)
 if overlay_mode != "":
  _draw_overlay(canvas)
 _draw_fx_flash(canvas)

func _draw_withnet() -> void:
 # A readable public network: one continuous east-west data highway and three
 # labelled districts instead of a tangled set of arbitrary node connections.
 for gx in range(0,int(WORLD_SIZE.x),72):
  draw_line(Vector2(gx,0),Vector2(gx,1200),Color("#10283B"),1.0)
 for gy in range(0,1250,72):
  draw_line(Vector2(0,gy),Vector2(2000,gy),Color("#10283B"),1.0)
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
 # An unbroken transit line makes the overall topology easy to understand.
 _beam(Vector2(175,550),Vector2(5400,550),CYAN)
 draw_line(Vector2(175,565),Vector2(5400,565),Color("#226781"),2)
 for i in range(21):
  var x = 330.0+i*230.0
  draw_line(Vector2(x,535),Vector2(x,575),Color("#2FA4B6"),2)
  _glow(Vector2(175,550).lerp(Vector2(5400,550),fposmod(elapsed*0.18+float(i)*0.049,1.0)),CYAN,4)
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
 for k in range(26):
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
  draw_rect(Rect2(x,406,24,3),Color(CYAN.r,CYAN.g,CYAN.b,0.25+0.55*absf(sin(elapsed*1.7+float(i)*0.85)))
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
 for line_x in [260.0,960.0,1395.0]:
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
 var zone_name = "00 / HOMEBASE" if world_mode == 2 else ("01 / WITHNET" if world_mode == 0 else "02 / DARKNET")
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
  _text(Vector2(820,resource_y+28),"ICE GUARDS %d" % red_zone.active_count(),PINK,17)
 _text(Vector2(28,resource_y+65),state.mission_text(),Color("#85BAC8"),16)
 _text(Vector2(canvas.x-175,resource_y+66),"TAP TITLE: LOG",Color("#7199AB"),14)
 if world_mode == 1:
  _text(Vector2(canvas.x-390,132),"PACKETS %d / 3" % dark_collected,LIME,20)
 elif world_mode == 0:
  var nearby = _nearest_node()
  if nearby >= 0:
   _text(Vector2(canvas.x-360,132),"HACK  //  "+_active_nodes()[nearby]["kind"],CYAN,18)
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
  "ANOMALY": return "Danger: extraction increases network TRACE"
  "MISSION": return state.mission_text()
  "VAULT": return "One-time secret cache discovered through scan"
  _: return "Select an available terminal operation"

func _node_buttons(kind: String) -> Array:
 match kind:
  "ACCESS": return ["UPGRADE CLEARANCE","CHECK CURRENT LEVEL"]
  "FAB": return ["CRAFT PROGRAMS","OPEN LOADOUT"]
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
 var hp = 100.0 if training else state.integrity
 duel.begin(state.active_program, state.installed_modules, hp, difficulty, state.chrono_unlocked)
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
 if mine_duel:
  mine_duel = false
  if won:
   state.credits += 45
   _notify("SIGNAL MINE DEFUSED // +45 CR")
  else:
   jam_remaining = 25.0
   _notify("SIGNAL JAM // VISION REDUCED 25 SEC")
  state.save_game()
  return
 if won:
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

func _duel_slowmo_rect(canvas: Vector2) -> Rect2:
 return Rect2(Vector2(canvas.x-255,401),Vector2(207,63))

func _duel_button_rect(index: int,canvas: Vector2) -> Rect2:
 var slot_width = (canvas.x-208.0)/4.0
 return Rect2(Vector2(84.0+index*(slot_width+12.0),canvas.y-211.0),Vector2(slot_width,104))

func _duel_touch(point: Vector2,canvas: Vector2) -> void:
 if duel.result != "RUNNING":
  _finish_duel()
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
