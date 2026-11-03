extends RefCounted
const Flight=preload("res://scripts/subnet_flight.gd")
const Shell=preload("res://scripts/game_shell.gd")
const CYAN=Color("#50E8FF")
const PINK=Color("#FF507C")
const LIME=Color("#D0F96C")
const VIOLET=Color("#B887FF")
var shell=Shell.new()

func power_rect(index: int,canvas: Vector2) -> Rect2:
 return Rect2(26+index*188,canvas.y-68,176,46)
func weapon_rect(canvas: Vector2) -> Rect2:
 return Rect2(canvas.x-472,canvas.y-68,205,46)
func bomb_rect(canvas: Vector2) -> Rect2:
 return Rect2(canvas.x-252,canvas.y-68,226,46)
func pause_rect(canvas: Vector2) -> Rect2:
 return Rect2(canvas.x-126,18,106,40)
func result_rect(index: int,canvas: Vector2) -> Rect2:
 return Rect2(canvas.x*0.5-285+index*298,canvas.y*0.64,272,58)
func stick_center(canvas: Vector2) -> Vector2:
 return Vector2(108,canvas.y-183)
func fire_center(canvas: Vector2) -> Vector2:
 return Vector2(canvas.x-95,canvas.y-180)
func bomb_center(canvas: Vector2) -> Vector2:
 return Vector2(canvas.x-222,canvas.y-175)

func draw(c: CanvasItem,m: RefCounted,canvas: Vector2,time: float,form: RefCounted,touch: bool,stick: Vector2) -> void:
 var tone: Color=[CYAN,VIOLET,LIME][m.id]
 c.draw_rect(Rect2(Vector2.ZERO,canvas),Color("#040A16"))
 # Multiple parallax speeds provide lateral depth without rebuilding a world map.
 for i in range(70):
  var x: float=fposmod(i*193-m.distance*(0.1+(i%3)*0.07),canvas.x+40)-20
  var y: float=100+fposmod(i*73,canvas.y-220)
  c.draw_line(Vector2(x,y),Vector2(x+3+i%5,y),Color(tone,0.13+(i%4)*0.06),1.5)
 for i in range(10):
  var x: float=fposmod(i*231-m.distance*0.27,canvas.x+420)-210
  var height: float=55+(i*37)%135
  var rect=Rect2(x,canvas.y-100-height,115,height)
  c.draw_rect(rect,Color("#111B31"))
  c.draw_rect(rect,Color(tone,0.14),false,1)
  for k in range(3):c.draw_line(rect.position+Vector2(16,16+k*15),rect.position+Vector2(65,16+k*15),Color(tone,0.15),2)
 for y in [90,canvas.y-98]:
  c.draw_line(Vector2(0,y),Vector2(canvas.x,y),Color(tone,0.2),2)
  for i in range(24):
   var x: float=fposmod(i*93-m.distance*0.65,canvas.x+90)-45
   c.draw_line(Vector2(x,y+7),Vector2(x+26,y+7),Color(tone,0.28),2)
 for obstacle in m.obstacles:
  var x: float=float(obstacle["x"])-m.distance
  var gap: float=obstacle["gap"]
  var size: float=obstacle["size"]
  for rect in [Rect2(x-38,92,76,maxf(0,gap-size*0.5-92)),Rect2(x-38,gap+size*0.5,76,maxf(0,canvas.y-98-gap-size*0.5))]:
   c.draw_rect(rect,Color("#17283D"))
   c.draw_rect(rect,Color(tone,0.8),false,2)
   for y in range(int(rect.position.y)+12,int(rect.end.y)-8,24):c.draw_line(Vector2(x-24,y),Vector2(x+24,y),Color(tone,0.23),2)
  if x>canvas.x-250 and x<canvas.x:shell.text(c,Vector2(x-58,gap),"DURCHGANG",tone,13)
 for enemy in m.enemies:
  var at: Vector2=enemy["pos"]
  var tint: Color=VIOLET if enemy["kind"]=="MIRROR" else PINK
  var radius: float=27 if enemy["kind"]=="TANK" else 19
  var points=PackedVector2Array([at+Vector2(-radius-7,0),at+Vector2(8,-radius),at+Vector2(radius,0),at+Vector2(8,radius),at+Vector2(-radius-7,0)])
  c.draw_colored_polygon(points,Color("#2A1933"))
  c.draw_polyline(points,tint,2,true)
  c.draw_circle(at-Vector2(5,0),6,LIME if float(enemy["infected"])>0 else tint)
  c.draw_rect(Rect2(at+Vector2(-23,-37),Vector2(46,4)),Color("#27354A"))
  c.draw_rect(Rect2(at+Vector2(-23,-37),Vector2(46*maxf(0,float(enemy["hp"])/float(enemy["max"])),4)),tint)
 if m.phase=="BOSS":_boss(c,m,time)
 for laser in m.lasers:
  var y: float=laser["y"]
  var active: bool=float(laser["age"])>=1.05
  c.draw_line(Vector2(0,y),Vector2(canvas.x-180,y),Color(PINK,0.7 if active else 0.20+0.12*sin(time*18)),16 if active else 2,true)
  if not active:shell.text(c,Vector2(55,y-16),"! LASER LOCK !",PINK,14)
 for shot in m.shots:
  var at: Vector2=shot["pos"]
  var tint: Color=PINK if shot["enemy"] else (LIME if m.weapon==2 else CYAN)
  var trail: Vector2=Vector2(shot["vel"]).normalized()*18
  c.draw_line(at-trail,at,tint,4 if not shot["enemy"] and m.weapon==2 else 2.8,true)
  c.draw_circle(at,3.5,tint)
 # The player's built mesh is carried into a shuttle chassis in this perspective.
 var at: Vector2=m.ship
 var wing=PackedVector2Array([at+Vector2(36,0),at+Vector2(-22,-28),at+Vector2(-12,0),at+Vector2(-22,28)])
 c.draw_colored_polygon(wing,Color("#15354B"))
 c.draw_polyline(PackedVector2Array([wing[0],wing[1],wing[2],wing[3],wing[0]]),Color(CYAN,0.6),1.5,true)
 c.draw_line(at-Vector2(28,0),at-Vector2(65+sin(time*21)*9,0),Color(CYAN,0.6),5,true)
 if m.invulnerable<=0 or int(time*18)%2==0:form.draw_mesh(c,at,m.velocity.y*0.0004,time,false,0.94)
 if m.shield>0:c.draw_arc(at,51,0,TAU,48,CYAN,3,true)
 if m.overclock>0:c.draw_arc(at,43,-time*3,-time*3+PI*1.6,36,LIME,2,true)
 if m.chrono>0:
  c.draw_rect(Rect2(Vector2.ZERO,canvas),Color(VIOLET,0.025))
  c.draw_arc(at,64,time,time+PI*1.8,40,VIOLET,2,true)
 for part in m.particles:
  var p: Vector2=part["pos"]
  var tint: Color=PINK if part["kind"]=="hit" else (LIME if part["kind"]=="bomb" else VIOLET)
  c.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color(tint,clampf(1-float(part["age"])/0.7,0,1)))
 _hud(c,m,canvas)
 if touch and m.result=="RUNNING":
  var center: Vector2=stick_center(canvas)
  c.draw_circle(center,64,Color("#10273A",0.75))
  c.draw_arc(center,64,0,TAU,40,Color(CYAN,0.55),2,true)
  c.draw_circle(center+stick*34,17,Color(CYAN,0.75))
  for point in [fire_center(canvas),bomb_center(canvas)]:
   c.draw_circle(point,45,Color("#20213B",0.9))
   c.draw_arc(point,45,0,TAU,40,CYAN if point==fire_center(canvas) else PINK,2,true)
  shell.text(c,fire_center(canvas)+Vector2(-26,7),"FIRE",LIME,20)
  shell.text(c,bomb_center(canvas)+Vector2(-32,7),"BOMB",PINK,18)
 if m.result!="RUNNING":
  c.draw_rect(Rect2(Vector2.ZERO,canvas),Color(0.01,0.02,0.06,0.88))
  shell.text(c,Vector2(canvas.x*0.5-285,canvas.y*0.28),"SUBNET GESICHERT" if m.result=="WIN" else "VERBINDUNG VERLOREN",LIME if m.result=="WIN" else PINK,35)
  shell.text(c,Vector2(canvas.x*0.5-285,canvas.y*0.28+55),"%s  //  SCORE %06d" % [Flight.NAMES[m.id],m.score],CYAN,22)
  shell.text(c,Vector2(canvas.x*0.5-285,canvas.y*0.28+95),"%d ABSCHÜSSE // %s" % [m.kills,"BELOHNUNG GESPEICHERT" if m.result=="WIN" else "CHECKPOINT KANN WIEDERHOLT WERDEN"],Color("#9BB6C9"),16)
  shell.button(c,result_rect(0,canvas),"NEUER RUN" if m.result=="WIN" else "CHECKPOINT LADEN",CYAN)
  shell.button(c,result_rect(1,canvas),"ZUR BASIS",VIOLET)

func _boss(c: CanvasItem,m: RefCounted,time: float) -> void:
 var at: Vector2=m.boss_pos
 var tint: Color=[CYAN,VIOLET,PINK][m.id]
 var points=PackedVector2Array()
 for i in range(7):points.append(at+Vector2.RIGHT.rotated(i*TAU/6+PI/6)*71)
 c.draw_colored_polygon(points,Color("#2A203A"))
 c.draw_polyline(points,tint,3,true)
 c.draw_arc(at,54,time*0.2,time*0.2+PI*1.7,48,Color(tint,0.7),3,true)
 c.draw_circle(at,24,PINK if m.boss_shield else LIME)
 if m.boss_shield:c.draw_arc(at,91,0,TAU,64,Color(tint,0.8),3,true)
 if m.id==1:
  for side in [-1,1]:
   var ghost: Vector2=at+Vector2(-35,side*118)
   c.draw_arc(ghost,36,0,TAU,32,Color(VIOLET,0.25),2,true)
  shell.text(c,at+Vector2(-72,-113),"ECHTE SIGNATUR",LIME,14)
 if m.id==2:
  for i in range(m.boss_nodes.size()):
   var node: Vector2=m.node_position(i)
   var alive: bool=float(m.boss_nodes[i]["hp"])>0
   c.draw_line(at,node,Color(tint,0.5 if alive else 0.15),5,true)
   c.draw_circle(node,29,Color("#173248") if alive else Color("#18202A"))
   c.draw_arc(node,29,0,TAU,32,LIME if alive else Color("#455366"),3,true)
   c.draw_rect(Rect2(node-Vector2(28,44),Vector2(56*maxf(0,float(m.boss_nodes[i]["hp"])/140),4)),LIME)

func _hud(c: CanvasItem,m: RefCounted,canvas: Vector2) -> void:
 c.draw_rect(Rect2(0,0,canvas.x,82),Color("#0C1829"))
 shell.text(c,Vector2(25,32),Flight.NAMES[m.id],LIME,24)
 shell.text(c,Vector2(26,63),"HP %03d" % int(m.hp),CYAN,15)
 c.draw_rect(Rect2(100,51,180,10),Color("#2A3145"))
 c.draw_rect(Rect2(100,51,180*m.hp/100,10),CYAN if m.hp>30 else PINK)
 shell.text(c,Vector2(325,32),"SCORE %06d  //  KILLS %03d" % [m.score,m.kills],CYAN,18)
 shell.text(c,Vector2(325,63),"LADUNG %d%%  //  BOMBEN %d" % [int(m.energy),m.bombs],VIOLET,16)
 c.draw_rect(Rect2(650,51,150,10),Color("#2A3145"))
 c.draw_rect(Rect2(650,51,150*m.energy/100,10),VIOLET)
 shell.text(c,Vector2(canvas.x-410,46),"BOSS ARENA" if m.phase=="BOSS" else "SEKTOR %d / %d" % [int(m.distance/4500)+1,int(ceil(m.length/4500))],LIME,18)
 shell.button(c,pause_rect(canvas),"PAUSE",CYAN)
 c.draw_rect(Rect2(0,79,canvas.x*minf(1,m.distance/m.length),3),VIOLET)
 if m.phase=="BOSS":
  shell.text(c,Vector2(250,116),Flight.BOSSES[m.id]+(" // GESCHÜTZT" if m.boss_shield else " // VERWUNDBAR"),PINK if m.boss_shield else LIME,20)
  c.draw_rect(Rect2(250,127,canvas.x-500,9),Color("#283147"))
  c.draw_rect(Rect2(250,127,(canvas.x-500)*maxf(0,m.boss_hp/m.boss_max),9),PINK)
 if m.notice_time>0:
  shell.text(c,Vector2(28,162 if m.phase=="BOSS" else 118),m.notice,CYAN,16)
 c.draw_rect(Rect2(0,canvas.y-84,canvas.x,84),Color("#0A1525"))
 for i in range(3):
  var active: bool=[m.shield,m.overclock,m.chrono][i]>0
  var rect: Rect2=power_rect(i,canvas)
  c.draw_rect(rect,Color("#153A46") if active else Color("#142239"))
  c.draw_rect(rect,LIME if active else (VIOLET if m.energy>=Flight.COSTS[i] else Color("#3E4B61")),false,1)
  shell.text(c,rect.position+Vector2(9,28),"%d %s %d" % [i+1,Flight.POWERS[i],int(Flight.COSTS[i])],LIME if active else CYAN,15)
 for rect in [weapon_rect(canvas),bomb_rect(canvas)]:c.draw_rect(rect,Color("#1B233D"))
 shell.text(c,weapon_rect(canvas).position+Vector2(12,28),"E: "+Flight.WEAPONS[m.weapon],CYAN,17)
 shell.text(c,bomb_rect(canvas).position+Vector2(12,28),"R: "+Flight.BOMBS[m.bomb_type]+" / Q",PINK,17)
 shell.text(c,Vector2(26,canvas.y-5),"WASD / PFEILE: STEUERN  //  SPACE / F / MAUS: FEUERN  //  Q: BOMBE  //  E / R: HACK WECHSELN",Color("#6C90A8"),12)
