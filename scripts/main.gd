extends Node2D
## CYBERLOAD // NET.RUNNER v0.3 - offline 2D cyberworld, procedural graphics
## World rendering is separated from saved RPG state (game_state.gd).
const GameState = preload("res://scripts/game_state.gd")
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
const HACK_TARGETS = [
 ["E9", "BD", "55"],
 ["7A", "55", "E9"],
 ["BD", "55", "1C"]
]
const DARK_PACKETS = [
 Vector2(3.5 * TILE, 1.5 * TILE),
 Vector2(5.5 * TILE, 9.5 * TILE),
 Vector2(11.5 * TILE, 7.5 * TILE)
]
const EXIT_POS = Vector2(13.5 * TILE, 9.5 * TILE)
const WORLD_SIZE = Vector2(1920, 1200)
const GATE_POS = Vector2(1490, 550)
const HOME_PORTAL_POS = Vector2(175, 550)
const BASE_SIZE = Vector2(1440, 1000)
const BASE_SPAWN = Vector2(720, 625)

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

func _ready() -> void:
 font = ThemeDB.fallback_font
 state.load_game()
 _init_nodes()
 _init_base_nodes()
 _init_orbs()
 _init_matrix()
 if state.breaches > 0:
  ice_open = true
 _reset_darknet()
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
  {"pos":Vector2(1710,300), "kind":"VAULT", "name":"GHOST // 07", "details":"Hidden encrypted cache discovered by scan.", "color":LIME, "hidden":true}
 ]

func _init_base_nodes() -> void:
 # The homebase uses the same terminal panel and economy as the Withnet nodes.
 base_nodes = [
  {"pos":Vector2(1090,460), "kind":"UPLINK", "name":"UPLINK // 00", "details":"Enter the Withnet or review the network map.", "color":CYAN},
  {"pos":Vector2(720,285), "kind":"CORE", "name":"CORE // 01", "details":"Repair integrity and reduce tracing in this safe zone.", "color":LIME},
  {"pos":Vector2(395,460), "kind":"UPGRADE", "name":"WORKSHOP // 02", "details":"Upgrade your movement drive or code buffer.", "color":VIOLET},
  {"pos":Vector2(395,765), "kind":"ARCHIVE", "name":"ARCHIVE // 03", "details":"Review operator log and current contract.", "color":CYAN},
  {"pos":Vector2(1090,765), "kind":"MISSION", "name":"OPS // 04", "details":"Your mission console. Current network contracts.", "color":LIME}
 ]

func _active_nodes() -> Array:
 return base_nodes if world_mode == 2 else nodes

func _enter_withnet() -> void:
 world_mode = 0
 player = HOME_PORTAL_POS + Vector2(142,0)
 player_trail.clear()
 node_open = false
 _notify("WITHNET ONLINE  //  FOLLOW THE DATA HIGHWAY")

func _enter_homebase() -> void:
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
 matrix.clear()
 for y in range(5):
  var row = []
  for x in range(5):
   row.append(CODE_VALUES[(x * 7 + y * 11 + x * y) % CODE_VALUES.size()])
  matrix.append(row)
 # Guaranteed solvable path: (0,0)->(0,1)->(2,1).
 matrix[0][0] = "E9"
 matrix[1][0] = "BD"
 matrix[1][2] = "55"

func _reset_darknet() -> void:
 dark_player = Vector2(1.5 * TILE, 1.5 * TILE)
 dark_collected = 0
 dark_loot.clear()
 hunter = Vector2(12.5*TILE, 9.5*TILE)
 hunter_direction = -1.0
 hunter_cooldown = 0.0

func _process(delta: float) -> void:
 elapsed += delta
 notification_timer = maxf(0.0,notification_timer-delta)
 if breach_open:
  breach_timer -= delta
  if breach_timer <= 0:
   _breach_failed()
 elif not node_open and not journal_open:
  _update_player(delta)
  if world_mode == 1:
   _update_darknet(delta)
  elif state.trace > 0.0:
   state.trace = maxf(0.0,state.trace-delta*0.025)
  var world_player = _current_pos()
  player_trail.push_front(world_player)
  if player_trail.size() > 18:
   player_trail.resize(18)
 queue_redraw()

func _update_player(delta: float) -> void:
 var direction = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
 if joystick.length() > 0.08:
  direction = joystick
 if direction.length() > 1.0:
  direction = direction.normalized()
 if world_mode == 2:
  base_player += direction * delta * (240.0 + state.speed_level*30.0)
  base_player = base_player.clamp(Vector2(170,175),BASE_SIZE-Vector2(165,120))
 elif world_mode == 0:
  player += direction * delta * (240.0 + state.speed_level*30.0)
  player = player.clamp(Vector2(30,30),WORLD_SIZE-Vector2(30,30))
  _collect_world_packets()
 else:
  var next_pos = dark_player + direction * delta * (174.0 + state.speed_level*18.0)
  if not _maze_wall(Vector2(next_pos.x,dark_player.y)):
   dark_player.x = next_pos.x
  if not _maze_wall(Vector2(dark_player.x,next_pos.y)):
   dark_player.y = next_pos.y


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
 hunter.x += hunter_direction * delta * 58.0
 if hunter.x < 9.5*TILE:
  hunter_direction = 1.0
 if hunter.x > 12.5*TILE:
  hunter_direction = -1.0
 hunter_cooldown = maxf(0.0,hunter_cooldown-delta)
 if dark_player.distance_to(hunter) < 42.0 and hunter_cooldown == 0.0:
  state.integrity = maxf(0.0,state.integrity-17.0)
  state.trace = minf(100.0,state.trace+11.0)
  hunter_cooldown = 2.0
  _notify("BLACK ICE IMPACT  -17 INTEGRITY  +11 TRACE")
  if state.integrity <= 0.0:
   _emergency_disconnect()
  state.save_game()
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
    buffer.clear()
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
 match kind:
 match kind:
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
 for target in HACK_TARGETS:
  for offset in range(sequence.size()-target.size()+1):
   var valid = true
   for k in range(target.size()):
    if sequence[offset+k] != target[k]:
     valid = false
   if valid:
    breach_open = false
    ice_open = true
    state.breaches += 1
    state.credits += 30
    state.fragments += 4
    state.trace = minf(100.0,state.trace+4.0)
    _mission_event("breach")
    _notify("ICE BREACHED  +30 CR  +4 FR  //  ENTER GATE")
    state.save_game()
    return

func _input(event: InputEvent) -> void:
 var canvas = get_viewport_rect().size
 if event is InputEventScreenTouch:
  if event.pressed:
   if breach_open:
    _choose_code(event.position)
   elif node_open:
    _click_panel(event.position,canvas)
   elif journal_open:
    journal_open = false
   elif event.position.x < canvas.x*0.35 and event.position.y > canvas.y*0.46:
    joystick_touch = event.index
    joystick_origin = event.position
   elif event.position.x > canvas.x-260 and event.position.y > canvas.y-305:
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
  if breach_open:
   _choose_code(event.position)
  elif node_open:
   _click_panel(event.position,canvas)
  elif journal_open:
   journal_open = false
  elif event.position.x > canvas.x-260 and event.position.y > canvas.y-305:
   _interact()
  elif event.position.y < 84 and event.position.x < canvas.x*0.5:
   journal_open = true
  else:
   _touch_world(event.position,canvas)
 elif event is InputEventKey and event.pressed and not event.echo:
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
 if breach_open:
  _draw_breach(canvas)
  return
 var focus = _current_pos()
 camera_offset = focus-canvas/2.0
 draw_set_transform(-camera_offset)
 if world_mode == 0:
  _draw_withnet()
 elif world_mode == 1:
  _draw_darknet()
 else:
  _draw_homebase()
 for j in range(player_trail.size()):
  var alpha = (1.0-float(j)/float(player_trail.size()))*0.28
  draw_circle(player_trail[j],9.0,Color(CYAN.r,CYAN.g,CYAN.b,alpha))
 _glow(focus,CYAN,12.0+sin(elapsed*7)*2)
 draw_arc(focus,27+sin(elapsed*2)*2,0,TAU,42,Color(0.36,0.88,1.0,0.44),2)
 draw_set_transform(Vector2.ZERO)
 _draw_hud(canvas)
 if node_open:
  _draw_node_panel(canvas)
 if journal_open:
  _draw_journal(canvas)

func _draw_withnet() -> void:
 # A readable public network: one continuous east-west data highway and three
 # labelled districts instead of a tangled set of arbitrary node connections.
 for gx in range(0,2000,72):
  draw_line(Vector2(gx,0),Vector2(gx,1200),Color("#10283B"),1.0)
 for gy in range(0,1250,72):
  draw_line(Vector2(0,gy),Vector2(2000,gy),Color("#10283B"),1.0)
 var sectors = [
  {"bounds":Rect2(260,140,680,890),"title":"SECTOR A   //   PUBLIC DATA","tag":"ARCHIVES / SEARCH / TOOLS","accent":CYAN},
  {"bounds":Rect2(960,140,415,890),"title":"SECTOR B  //  SERVICES","tag":"MISSIONS / REPAIR","accent":LIME},
  {"bounds":Rect2(1395,140,450,890),"title":"SECTOR C  //  RED ZONE","tag":"BLACK ICE / ANOMALIES","accent":PINK}
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
 # An unbroken transit line makes the overall topology easy to understand.
 _beam(Vector2(175,550),Vector2(1770,550),CYAN)
 draw_line(Vector2(175,565),Vector2(1770,565),Color("#226781"),2)
 for i in range(7):
  var x = 330.0+i*230.0
  draw_line(Vector2(x,535),Vector2(x,575),Color("#2FA4B6"),2)
  _glow(Vector2(175,550).lerp(Vector2(1770,550),fposmod(elapsed*0.18+float(i)*0.143,1.0)),CYAN,4)
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
 # Central firewall portal divides the regular net from a protected system.
 draw_arc(GATE_POS,57+sin(elapsed*3.7)*4,0,TAU,64,PINK,4)
 draw_arc(GATE_POS,77,0.3,PI*1.5,52,Color(1,0.2,0.45,0.55),2)
 _glow(GATE_POS,LIME if ice_open else PINK,28)
 _text(GATE_POS+Vector2(-94,-98),"ICE // SECURITY",PINK,21)
 _text(GATE_POS+Vector2(-94,115),"ACCESS GRANTED" if ice_open else "BREACH REQUIRED",LIME,17)
 if player.distance_to(GATE_POS) < 109:
  _text(GATE_POS+Vector2(-94,145),"HACK TO CONNECT",CYAN,17)

func _draw_homebase() -> void:
 # The safe zone is a small futuristic operations room with five usable terminals.
 for gx in range(0,1500,60):
  draw_line(Vector2(gx,0),Vector2(gx,1000),Color("#112C3C"),1.0)
 for gy in range(0,1050,60):
  draw_line(Vector2(0,gy),Vector2(1500,gy),Color("#112C3C"),1.0)
 var room = Rect2(145,135,1150,755)
 draw_rect(room,Color("#091B29"))
 draw_rect(room,Color("#26627A"),false,5)
 draw_rect(Rect2(153,143,1134,76),Color("#112E3B"))
 _text(Vector2(185,196),"NET.RUNNER  /  PERSONAL NODE",LIME,33)
 _text(Vector2(925,195),"PRIVATE GRID : ONLINE",CYAN,18)
 for x in range(260,1280,92):
  draw_line(Vector2(x,227),Vector2(x,868),Color("#183A4B"),1)
 for y in range(270,862,94):
  draw_line(Vector2(170,y),Vector2(1278,y),Color("#183A4B"),1)
 # Architecture: raised central platform with a rotating data core.
 var hub = Vector2(720,528)
 draw_rect(Rect2(hub-Vector2(152,144),Vector2(304,300)),Color("#0C2838"))
 draw_rect(Rect2(hub-Vector2(152,144),Vector2(304,300)),Color("#2F8095"),false,3)
 draw_arc(hub,108,0,TAU,64,Color("#2B7F97"),3)
 draw_arc(hub,89,0.15+elapsed*0.12,PI*1.75+elapsed*0.12,55,CYAN,4)
 draw_arc(hub,64,0,TAU,64,LIME,3)
 _glow(hub,CYAN,33+sin(elapsed*2.5)*3)
 _text(hub+Vector2(-74,-135),"SYSTEM KERNEL",CYAN,20)
 _text(hub+Vector2(-64,125),"STATUS: STABLE",LIME,17)
 # Each console is functional. Branches show the route to the central core.
 for i in range(base_nodes.size()):
  var n = base_nodes[i]
  var at: Vector2 = n["pos"]
  var tint: Color = n["color"]
  var endpt = hub + (at-hub).normalized()*110
  _beam(endpt,at,Color(tint.r,tint.g,tint.b,0.70))
  draw_rect(Rect2(at-Vector2(52,44),Vector2(104,88)),Color("#101F34"))
  draw_rect(Rect2(at-Vector2(52,44),Vector2(104,88)),tint,false,2)
  draw_arc(at,33+sin(elapsed*2+i)*2,0,TAU,42,tint,3)
  _glow(at,tint,15)
  _text(at+Vector2(-76,-66),n["name"],tint,19)
  _text(at+Vector2(-65,70),n["kind"]+" / READY",Color("#8EAFC4"),15)
 # Starting mark and tactile area under the avatar.
 draw_arc(BASE_SPAWN,50,0,TAU,60,Color("#39788B"),2)
 _text(BASE_SPAWN+Vector2(-75,76),"SPAWN // SAFE",CYAN,17)
 _text(Vector2(205,859),"NO BLACK ICE IN THIS ZONE  /  APPROACH A TERMINAL AND TAP HACK",LIME,17)

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
 draw_rect(Rect2(18,99,minf(canvas.x-36.0,960.0),53),Color("#112638"))
 _text(Vector2(34,132),status,LIME,19)
 var resource_y = canvas.y-85
 draw_rect(Rect2(0,resource_y,canvas.x,85),Color("#0A1726"))
 draw_line(Vector2(0,resource_y),Vector2(canvas.x,resource_y),Color("#245873"),2)
 _text(Vector2(27,resource_y+28),"CR %d" % state.credits,LIME,18)
 _text(Vector2(160,resource_y+28),"DATA %d" % state.fragments,CYAN,18)
 _text(Vector2(315,resource_y+28),"TRACE %d%%" % int(state.trace),PINK,18)
 _text(Vector2(480,resource_y+28),"HP %d%%" % int(state.integrity),LIME,18)
 _text(Vector2(28,resource_y+65),state.mission_text(),Color("#85BAC8"),16)
 _text(Vector2(canvas.x-175,resource_y+66),"TAP TITLE: LOG",Color("#7199AB"),14)
 if world_mode == 1:
  _text(Vector2(canvas.x-390,132),"PACKETS %d / 3" % dark_collected,LIME,20)
 else:
  var nearby = _nearest_node()
  if nearby >= 0:
   _text(Vector2(canvas.x-360,132),"HACK  //  "+_active_nodes()[nearby]["kind"],CYAN,18)
 if world_mode == 0:
  _draw_minimap(canvas)
 elif world_mode == 2:
  _text(Vector2(canvas.x-320,190),"SAFE ZONE  //  NO ICE",LIME,19)
 _draw_controls(canvas)

func _draw_controls(canvas: Vector2) -> void:
 var center = Vector2(122,canvas.y-185)
 draw_circle(center,85,Color("#0B2739"))
 draw_arc(center,85,0,TAU,60,Color("#4B9BAF"),2)
 draw_arc(center,70,0,TAU,50,Color("#1C5D74"),1)
 _glow(center+joystick*50,CYAN,18)
 var action = Vector2(canvas.x-120,canvas.y-187)
 draw_circle(action,75,Color("#291524"))
 draw_arc(action,75,0,TAU,55,PINK,3)
 draw_arc(action,62,0,TAU,55,Color("#AB3B5A"),1)
 _text(action+Vector2(-32,7),"HACK",LIME,24)

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
  "UPLINK": return "PUBLIC MAP: A / DATA - B / SERVICES - C / ICE"
  "CORE": return "Your private core repairs and hides your signal"
  "ARCHIVE": return "Mission status, progress, and network information"
  "UPGRADE": return "OVERCLOCK increases speed; BUFFER adds a matrix slot"
  "MARKET": return "Purchased utilities are applied immediately"
  "ANOMALY": return "Danger: extraction increases network TRACE"
  "MISSION": return state.mission_text()
  "VAULT": return "One-time secret cache discovered through scan"
  _: return "Select an available terminal operation"

func _node_buttons(kind: String) -> Array:
 match kind:
  "UPLINK": return ["ENTER WITHNET","OPEN NETWORK LOG"]
  "CORE": return ["REPAIR HP / 20 CR","CLEAR TRACE / 25 CR"]
  "ARCHIVE": return ["OPEN OPERATOR LOG","VIEW CONTRACT"]
  "DATA": return ["EXTRACT ARCHIVE","CHECK CACHE"]
  "SCAN": return ["REVEAL HIDDEN NODE","CLEAN TRACE -8"]
  "UPGRADE": return ["SPEED UPGRADE","BUFFER UPGRADE"]
  "MARKET": return ["SCRUB TRACE / 35 CR","REPAIR HP / 45 CR"]
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
 _text(Vector2(x,550),"PROGRESS IS SAVED AUTOMATICALLY",LIME,18)
 _text(Vector2(x,600),"TAP TO RETURN",Color("#8BB3C2"),19)

func _draw_breach(canvas: Vector2) -> void:
 draw_rect(Rect2(30,44,canvas.x-60,canvas.y-88),Color("#101C28"))
 draw_rect(Rect2(30,44,canvas.x-60,canvas.y-88),LIME,false,1)
 _text(Vector2(70,98),"BREACH PROTOCOL // ICE MATRIX",LIME,29)
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
 var names = ["GHOST ACCESS","ICE OVERRIDE","DATA LEACH"]
 for i in range(HACK_TARGETS.size()):
  _text(Vector2(650,333+i*81),names[i],CYAN,21)
  _text(Vector2(650,365+i*81),"%s  %s  %s" % [HACK_TARGETS[i][0],HACK_TARGETS[i][1],HACK_TARGETS[i][2]],LIME,23)
 _text(Vector2(205,586),"FIRST ROW -> SAME COLUMN -> SAME ROW",CYAN,17)
 _text(Vector2(205,627),"TIMER EXPIRY = TRACE +12",PINK,16)
 _text(Vector2(1000,627),"RESET BUFFER",LIME,18)
