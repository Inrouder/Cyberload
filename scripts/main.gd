extends Node2D
## Cyberload prototype - procedurally drawn 2D network.
const C = Color("#54eaff")
const L = Color("#cffa64")
const R = Color("#ff446a")
const BG = Color("#070d17")
const T = 64.0
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
const VALUES = ["1C", "55", "7A", "BD", "E9"]
const TARGETS = [["E9","BD","55"],["7A","55","E9"],["BD","55","1C"]]
var pos = Vector2(380,360)
var maze_pos = Vector2(96,96)
var gate = Vector2(930,360)
var area = 0
var breach = false
var timer = 60.0
var codes = []
var selected = []
var unlocked = false
var scanned = 0
var movement = Vector2.ZERO
var touch_id = -1
var touch_origin = Vector2.ZERO
var status = "FIND THE RED ICE GATE"
var elapsed = 0.0
var trail = []
var font: Font

func _ready() -> void:
 font = ThemeDB.fallback_font
 for y in range(5):
  var row = []
  for x in range(5):
   row.append(VALUES[(x * 7 + y * 11 + x * y) % 5])
  codes.append(row)
 # Ensure at least one solvable demonstration sequence.
 codes[0][0] = "E9"
 codes[1][0] = "BD"
 codes[1][2] = "55"

func _process(delta: float) -> void:
 elapsed += delta
 if breach:
  timer -= delta
  if timer <= 0:
   breach = false
   selected.clear()
   status = "BREACH FAILED // TRY AGAIN"
 else:
  var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
  if movement.length() > 0.05:
   direction = movement
  if area == 0:
   pos += direction * delta * 230
   pos = pos.clamp(Vector2(50,50), Vector2(1850,1100))
   if pos.distance_to(gate) < 95 and (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE)):
    _interact()
  else:
   var nxt = maze_pos + direction * delta * 170
   if not _wall(Vector2(nxt.x,maze_pos.y)):
    maze_pos.x = nxt.x
   if not _wall(Vector2(maze_pos.x,nxt.y)):
    maze_pos.y = nxt.y
   if maze_pos.distance_to(Vector2(13.5*T,9.5*T)) < 40:
    area = 0
    trail.clear()
    status = "DARKNET COMPLETE // RETURNED"
 if not breach:
  trail.push_front(pos if area == 0 else maze_pos)
  if trail.size() > 18:
   trail.resize(18)
 queue_redraw()

func _wall(p: Vector2) -> bool:
 var x = int(floor(p.x / T))
 var y = int(floor(p.y / T))
 return y < 0 or y >= MAZE.size() or x < 0 or x >= MAZE[0].length() or MAZE[y][x] == "#"

func _interact() -> void:
 if area != 0 or pos.distance_to(gate) >= 115:
  return
 if unlocked:
  area = 1
  trail.clear()
  status = "DARKNET // REACH GREEN EXIT"
 else:
  breach = true
  selected.clear()
  timer = 60.0
  status = "BREACH PROTOCOL"

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   if breach:
    _click(event.position)
   elif event.position.x < 380:
    touch_id = event.index
    touch_origin = event.position
   else:
    _interact()
  elif event.index == touch_id:
   touch_id = -1
   movement = Vector2.ZERO
 elif event is InputEventScreenDrag and event.index == touch_id:
  movement = (event.position - touch_origin).limit_length(85) / 85.0
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  if breach:
   _click(event.position)
  elif event.position.x > 950:
   _interact()
 elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  breach = false

func _click(p: Vector2) -> void:
 var origin = Vector2(215,185)
 var size = 68.0
 var col = int(floor((p.x-origin.x)/size))
 var row = int(floor((p.y-origin.y)/size))
 if row < 0 or row > 4 or col < 0 or col > 4 or selected.size() >= 6:
  if p.x > 1000 and p.y > 590:
   selected.clear()
  return
 var cell = Vector2i(col,row)
 if selected.has(cell):
  return
 if selected.is_empty() and row != 0:
  return
 if not selected.is_empty():
  var previous: Vector2i = selected.back()
  if selected.size() % 2 == 1 and col != previous.x:
   return
  if selected.size() % 2 == 0 and row != previous.y:
   return
 selected.append(cell)
 var buffer = []
 for v in selected:
  buffer.append(codes[v.y][v.x])
 for target in TARGETS:
  for offset in range(buffer.size() - target.size() + 1):
   var found = true
   for k in range(target.size()):
    if buffer[offset+k] != target[k]:
     found = false
   if found:
    unlocked = true
    breach = false
    status = "ICE DEFEATED // ENTER THE GATE"
    return

func _text(at: Vector2, value: String, color: Color = C, size: int = 19) -> void:
 draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _glow_point(at: Vector2, color: Color, radius: float) -> void:
 for scale in range(5,0,-1):
  draw_circle(at,radius + scale*5,color * Color(1,1,1,0.04))
 draw_circle(at,radius,color)

func _line(a: Vector2,b: Vector2,color: Color,width: float = 2.0) -> void:
 draw_line(a,b,color*Color(1,1,1,0.13),width+8)
 draw_line(a,b,color,width)

func _draw() -> void:
 var canvas = get_viewport_rect().size
 draw_rect(Rect2(Vector2.ZERO,canvas),BG)
 if breach:
  _draw_breach(canvas)
  return
 var current = pos if area == 0 else maze_pos
 var camera = current - canvas/2.0
 draw_set_transform(-camera)
 if area == 0:
  _draw_withnet()
 else:
  _draw_darknet()
 for i in range(trail.size()):
  var strength = 0.23*(1.0 - float(i)/float(trail.size()))
  draw_circle(trail[i], 9.0-float(i)*0.25, Color(C.r,C.g,C.b,strength))
 _glow_point(current,C,12.0+sin(elapsed*7.0)*2.0)
 draw_arc(current,27.0+sin(elapsed*2.0)*2.0,0,TAU,40,Color(0.3,0.9,1.0,0.4),2)
 draw_set_transform(Vector2.ZERO)
 _draw_hud(canvas)

func _draw_hud(canvas: Vector2) -> void:
 draw_rect(Rect2(0,0,canvas.x,83),Color("#0B192A"))
 draw_line(Vector2(0,83),Vector2(canvas.x,83),Color("#33A8C0"),2)
 draw_rect(Rect2(22,19,6,45),L)
 _text(Vector2(43,50),"CYBERLOAD",L,31)
 _text(Vector2(272,46),"// NET.RUNNER",C,24)
 _text(Vector2(canvas.x-285,48),"01  /  WITHNET" if area==0 else "02  /  DARKNET",C if area==0 else R,22)
 draw_rect(Rect2(18,99,minf(canvas.x-36,860),51),Color("#10273A"))
 draw_rect(Rect2(18,99,5,51),C if area==0 else R)
 _text(Vector2(38,134),status,L,21)
 draw_line(Vector2(0,canvas.y-78),Vector2(canvas.x,canvas.y-78),Color("#244255"),2)
 _text(Vector2(30,canvas.y-35),"SYS ONLINE  //  DATAFLOW ACTIVE",Color("#7FB8C7"),17)
 _text(Vector2(canvas.x*0.46,canvas.y-35),"ICE ACCESS: %s" % ("OPEN" if unlocked else "LOCKED"),L if unlocked else R,17)
 var joystick_center = Vector2(123,canvas.y-166)
 draw_circle(joystick_center,87,Color("#0A2637"))
 draw_arc(joystick_center,87,0,TAU,64,Color("#53A7BC"),2)
 draw_arc(joystick_center,70,0,TAU,48,Color("#1C5D74"),1)
 _glow_point(joystick_center+movement*50.0,C,18)
 var action_center = Vector2(canvas.x-133,canvas.y-166)
 draw_circle(action_center,76,Color("#291525"))
 draw_arc(action_center,76,0,TAU,64,R,3)
 draw_arc(action_center,61,0,TAU,48,Color("#9B3154"),1)
 _text(action_center+Vector2(-32,8),"HACK",L,25)

func _draw_withnet() -> void:
 for x in range(0,1900,80):
  _line(Vector2(x,0),Vector2(x,1200),Color("#143248"),1)
 for y in range(0,1200,80):
  _line(Vector2(0,y),Vector2(1900,y),Color("#143248"),1)
 for x in range(0,1900,160):
  for y in range(0,1200,160):
   draw_circle(Vector2(x,y),2,Color("#39758C"))
 var hubs = [Vector2(300,220),Vector2(630,180),Vector2(820,520),Vector2(350,750),Vector2(1350,220),Vector2(1500,760),Vector2(1740,480)]
 for i in range(hubs.size()-1):
  var a = hubs[i]
  var b = hubs[i+1]
  _line(a,b,Color("#165D78"),10)
  _line(a,b,C,2)
  var travel = fposmod(elapsed*0.32+float(i)*0.29,1.0)
  _glow_point(a.lerp(b,travel),C,5)
 for i in range(hubs.size()):
  var n = hubs[i]
  draw_arc(n,25.0+sin(elapsed*2.0+i)*3.0,0,TAU,40,Color(0.3,0.9,1.0,0.48),2)
  _glow_point(n,L if i%2==0 else C,12)
  _text(n+Vector2(32,-18),"NODE // %02d" % i,L,17)
  _text(n+Vector2(32,4),"UPLINK ACTIVE",Color("#7AABBA"),12)
 var ring = 55.0+sin(elapsed*4.0)*5.0
 draw_arc(gate,ring,0,TAU,64,R,4)
 draw_arc(gate,ring+16,0.25,PI*1.5,48,Color(1.0,0.2,0.45,0.45),2)
 _glow_point(gate,L if unlocked else R,28)
 _text(gate+Vector2(-105,-95),"ICE // SECURITY",R,22)
 _text(gate+Vector2(-95,102),"ACCESS GRANTED" if unlocked else "BREACH REQUIRED",L,17)

func _draw_darknet() -> void:
 for y in range(MAZE.size()):
  for x in range(MAZE[y].length()):
   var at = Vector2(x,y)*T
   if MAZE[y][x] == "#":
    draw_rect(Rect2(at,Vector2(T,T)),Color("#181B2C"))
    draw_rect(Rect2(at+Vector2(5,5),Vector2(T-10,T-10)),Color("#0C1422"))
    draw_rect(Rect2(at,Vector2(T,T)),Color(1,0.25,0.42,0.45),false,2)
    draw_line(at+Vector2(6,6),at+Vector2(T-6,6),Color(1,0.23,0.40,0.30),2)
   else:
    draw_circle(at+Vector2(T/2,T/2),2,Color(0.3,0.8,1.0,0.35))
 var exit_point = Vector2(13.5*T,9.5*T)
 draw_arc(exit_point,33+sin(elapsed*4)*4,0,TAU,48,L,3)
 _glow_point(exit_point,L,20)
 _text(exit_point+Vector2(-30,-43),"EXIT",L,21)

func _draw_breach(canvas: Vector2) -> void:
 draw_rect(Rect2(48,58,canvas.x-96,canvas.y-116),Color("#101b27"))
 _text(Vector2(72,104),"BREACH PROTOCOL // ICE MATRIX",L,28)
 _text(Vector2(73,143),"TIME LEFT: %04.1f" % timer,R,21)
 _text(Vector2(650,151),"BUFFER  %d / 6" % selected.size(),L,22)
 for i in range(6):
  var dest = Vector2(650+i*76,175)
  draw_rect(Rect2(dest,Vector2(65,57)),Color("#192a38"))
  var v = "--"
  if i < selected.size():
   var cell: Vector2i = selected[i]
   v = codes[cell.y][cell.x]
  _text(dest+Vector2(15,37),v,C,23)
 _text(Vector2(215,168),"CODE MATRIX",L,19)
 for y in range(5):
  for x in range(5):
   var at = Vector2(215+x*68,185+y*68)
   var chosen = selected.has(Vector2i(x,y))
   draw_rect(Rect2(at,Vector2(62,62)),Color("#21485a") if chosen else Color("#172637"))
   draw_rect(Rect2(at,Vector2(62,62)),C if chosen else Color("#365166"),false,2)
   _text(at+Vector2(11,40),codes[y][x],L,23)
 _text(Vector2(650,290),"AVAILABLE HACKS",L,23)
 for i in range(TARGETS.size()):
  _text(Vector2(650,345+i*85),["GHOST ACCESS","ICE OVERRIDE","DATA LEACH"][i],C,21)
  _text(Vector2(650,376+i*85),"%s  %s  %s" % [TARGETS[i][0], TARGETS[i][1], TARGETS[i][2]],L,22)
 _text(Vector2(215,575),"START: FIRST ROW  //  ALTERNATE COLUMN AND ROW",C,16)
 _text(Vector2(965,631),"TAP HERE TO RESET",R,17)
 _text(Vector2(215,634),"ESC TO CANCEL",C,17)
