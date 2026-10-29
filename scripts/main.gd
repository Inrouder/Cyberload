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
    status = "DARKNET COMPLETE // RETURNED"
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
 var camera = current - canvas / 2
 draw_set_transform(-camera)
 if area == 0:
  _draw_withnet()
  _glow_point(pos,C,12 + sin(elapsed*6)*2)
 else:
  _draw_darknet()
  _glow_point(maze_pos,C,11)
 draw_set_transform(Vector2.ZERO)
 draw_rect(Rect2(0,0,canvas.x,62),Color("#101c2c"))
 _text(Vector2(25,40),"CYBERLOAD // NET//RUNNER",L,25)
 _text(Vector2(canvas.x-310,39),"WITHNET" if area == 0 else "DARKNET",C,20)
 _text(Vector2(30,97),status,L,18)
 _text(Vector2(25,canvas.y-28),"MOVE: WASD / ARROWS    HACK: E     TOUCH: LEFT JOYSTICK + RIGHT ACTION",C,15)
 # Touch controls
 draw_arc(Vector2(120,canvas.y-120),78,0,TAU,48,C*Color(1,1,1,0.45),2)
 _glow_point(Vector2(120,canvas.y-120)+movement*55,C,15)
 draw_arc(Vector2(canvas.x-108,canvas.y-118),52,0,TAU,48,R,3)
 _text(Vector2(canvas.x-145,canvas.y-112),"HACK",L,19)

func _draw_withnet() -> void:
 for x in range(0,1900,80):
  _line(Vector2(x,0),Vector2(x,1200),Color("#193448"),1)
 for y in range(0,1200,80):
  _line(Vector2(0,y),Vector2(1900,y),Color("#193448"),1)
 var hubs = [Vector2(300,220),Vector2(630,180),Vector2(820,520),Vector2(350,750),Vector2(1350,220),Vector2(1500,760),Vector2(1740,480)]
 for i in range(hubs.size()-1):
  _line(hubs[i],hubs[i+1],C,3)
 for i in range(hubs.size()):
  _glow_point(hubs[i],L if i%2==0 else C,16)
  _text(hubs[i]+Vector2(24,-18),"NODE-%02d" % i,L,16)
 _glow_point(gate,R,37 + sin(elapsed*3)*6)
 _text(gate+Vector2(-80,-70),"ICE // SECURITY",R,20)
 _text(gate+Vector2(-70,75),"E TO BREACH",L,16)

func _draw_darknet() -> void:
 for y in range(MAZE.size()):
  for x in range(MAZE[y].length()):
   var at = Vector2(x,y)*T
   if MAZE[y][x] == "#":
    draw_rect(Rect2(at,Vector2(T,T)),Color("#192338"))
    draw_rect(Rect2(at+Vector2(5,5),Vector2(T-10,T-10)),Color("#0c1423"))
    draw_rect(Rect2(at,Vector2(T,T)),R*Color(1,1,1,0.35),false,1)
   else:
    draw_circle(at+Vector2(T/2,T/2),2,C*Color(1,1,1,0.3))
 _glow_point(Vector2(13.5*T,9.5*T),L,22)
 _text(Vector2(13*T,9*T),"EXIT",L,19)

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
  _text(Vector2(650,376+i*85),"  ".join(TARGETS[i]),L,22)
 _text(Vector2(215,575),"START: FIRST ROW  //  ALTERNATE COLUMN AND ROW",C,16)
 _text(Vector2(965,631),"TAP HERE TO RESET",R,17)
 _text(Vector2(215,634),"ESC TO CANCEL",C,17)
