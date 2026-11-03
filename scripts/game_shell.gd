extends RefCounted
const CYAN=Color("#50E8FF")
const LIME=Color("#D0F96C")
const PINK=Color("#FF507C")
const VIOLET=Color("#B887FF")
const Flight=preload("res://scripts/subnet_flight.gd")

func text(c: CanvasItem,at: Vector2,value: String,tint: Color=CYAN,size: int=20) -> void:
 c.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,tint)

func button(c: CanvasItem,rect: Rect2,label: String,tint: Color=CYAN,enabled: bool=true) -> void:
 var tone: Color=tint if enabled else Color("#42596A")
 var hover: bool=rect.has_point(c.get_viewport().get_mouse_position()) and enabled
 c.draw_style_box(_box(Color("#18344A") if hover else Color("#101F32"),tone),rect)
 text(c,rect.position+Vector2(22,rect.size.y*0.5+8),label,tone,21)

func _box(fill: Color,edge: Color) -> StyleBoxFlat:
 var box=StyleBoxFlat.new()
 box.bg_color=fill
 box.border_color=Color(edge,0.75)
 box.set_border_width_all(1)
 box.set_corner_radius_all(9)
 return box

func menu_rect(index: int,canvas: Vector2) -> Rect2:
 return Rect2(canvas.x*0.5-235,canvas.y*0.36+index*83,470,65)

func music_rect(canvas: Vector2) -> Rect2:
 return Rect2(28,canvas.y-68,225,44)
func sound_rect(canvas: Vector2) -> Rect2:
 return Rect2(266,canvas.y-68,225,44)
func volume_rect(index: int,canvas: Vector2) -> Rect2:
 return Rect2(canvas.x-267+index*125,canvas.y-68,113,44)
func pause_rect(canvas: Vector2) -> Rect2:
 return Rect2(canvas.x-495,22,105,40)
func subnet_rect(index: int,canvas: Vector2) -> Rect2:
 var width: float=(canvas.x-116)/3
 return Rect2(40+index*(width+18),166,width,canvas.y-250)

func background(c: CanvasItem,canvas: Vector2,time: float) -> void:
 c.draw_rect(Rect2(Vector2.ZERO,canvas),Color("#050B17"))
 var center=Vector2(canvas.x*0.5,canvas.y*0.43)
 for i in range(9):
  var radius: float=160+i*75+sin(time*0.3+i)*9
  c.draw_arc(center,radius,time*0.025+i*0.2,time*0.025+i*0.2+PI*1.6,64,Color(CYAN,0.035),1,true)
 for i in range(42):
  var at=Vector2(fposmod(i*179.0-time*(5+i%4),canvas.x),90+fposmod(i*71.0,canvas.y-180))
  c.draw_line(at,at+Vector2(10,0),Color(VIOLET,0.17),1)
 c.draw_line(Vector2(30,83),Vector2(canvas.x-30,83),Color(CYAN,0.3),1)
 text(c,Vector2(34,54),"CYBERLOAD",LIME,30)
 text(c,Vector2(canvas.x-300,51),"NET//RUNNER   v0.8.0",CYAN,18)

func draw_title(c: CanvasItem,canvas: Vector2,time: float,has_save: bool,confirm: bool,message: String) -> void:
 background(c,canvas,time)
 text(c,Vector2(canvas.x*0.5-234,canvas.y*0.23),"DEINE SIGNATUR. DEIN NETZ.",CYAN,25)
 text(c,Vector2(canvas.x*0.5-234,canvas.y*0.23+35),"WITHNET  /  SUBNETS  /  BLACK ICE",Color("#7A9DB2"),16)
 button(c,menu_rect(0,canvas),"NEU STARTEN BESTÄTIGEN" if confirm else "NEUES SPIEL",PINK if confirm else LIME)
 button(c,menu_rect(1,canvas),"ABBRECHEN" if confirm else "SPIEL LADEN",CYAN,has_save or confirm)
 text(c,menu_rect(1,canvas).position+Vector2(4,104),"Vorheriger Stand wird als Backup gesichert." if confirm else ("Fortsetzen ab Basis, Weltposition oder Shooter-Checkpoint." if has_save else "Noch kein gültiger Spielstand vorhanden."),Color("#7A9DB2"),15)
 if message!="":text(c,Vector2(canvas.x*0.5-235,canvas.y-142),message,PINK,16)

func draw_audio(c: CanvasItem,canvas: Vector2,music: bool,sound: bool,volume: float) -> void:
 button(c,music_rect(canvas),"MUSIK: AN" if music else "MUSIK: AUS",VIOLET)
 button(c,sound_rect(canvas),"EFFEKTE: AN" if sound else "EFFEKTE: AUS",CYAN)
 text(c,Vector2(canvas.x-268,canvas.y-88),"MUSIKLAUTSTÄRKE %d%%" % int(volume*100),Color("#7A9DB2"),14)
 button(c,volume_rect(0,canvas),"−",VIOLET)
 button(c,volume_rect(1,canvas),"+",VIOLET)

func draw_pause(c: CanvasItem,canvas: Vector2,flight: bool) -> void:
 c.draw_rect(Rect2(Vector2.ZERO,canvas),Color(0.01,0.03,0.07,0.94))
 text(c,Vector2(canvas.x*0.5-235,canvas.y*0.24),"VERBINDUNG PAUSIERT",LIME,30)
 button(c,menu_rect(0,canvas),"WEITERSPIELEN",CYAN)
 button(c,menu_rect(1,canvas),"SPEICHERN & HAUPTMENÜ",VIOLET)
 if flight:button(c,menu_rect(2,canvas),"CHECKPOINT NEUSTART",PINK)
 else:text(c,menu_rect(2,canvas).position+Vector2(0,27),"N: SHOOTER-SUBNETS IN DER BASIS",Color("#7A9DB2"),17)

func draw_subnets(c: CanvasItem,canvas: Vector2,time: float,state: RefCounted) -> void:
 background(c,canvas,time)
 text(c,Vector2(42,129),"SUBNET UPLINK // SIDE-SCROLLING COMBAT",CYAN,25)
 var tags: Array=["SCHILDFENSTER / WARNLANZEN","DOPPELGÄNGER / ZIELSALVEN","DREI KNOTEN / LASERKANÄLE"]
 for i in range(3):
  var rect: Rect2=subnet_rect(i,canvas)
  var tone: Color=[CYAN,VIOLET,PINK][i]
  c.draw_style_box(_box(Color("#101D31"),tone),rect)
  text(c,rect.position+Vector2(20,41),"0%d // %s" % [i+1,Flight.NAMES[i]],tone,23)
  var center: Vector2=rect.position+Vector2(rect.size.x*0.5,147)
  for ring in range(3):c.draw_arc(center,38+ring*17,time*(0.1+ring*0.05),time*(0.1+ring*0.05)+PI*1.7,36,Color(tone,0.25+ring*0.15),2,true)
  c.draw_colored_polygon(PackedVector2Array([center+Vector2(-22,-18),center+Vector2(33,0),center+Vector2(-22,18)]),tone)
  text(c,rect.position+Vector2(20,238),Flight.BOSSES[i],LIME,24)
  text(c,rect.position+Vector2(20,270),tags[i],Color("#85A6BA"),13)
  text(c,rect.position+Vector2(20,303),"%d KM // 4+ SEKTOREN // CHECKPOINTS" % (18+i*3),Color("#85A6BA"),14)
  var best: int=int(state.flight_best.get(str(i),0))
  text(c,rect.position+Vector2(20,335),"BEST %06d  //  %s" % [best,"GESICHERT" if state.flight_clears.has(str(i)) else "UNERFORSCHT"],tone,15)
  button(c,Rect2(rect.position+Vector2(16,rect.size.y-74),Vector2(rect.size.x-32,55)),"SUBNET STARTEN",tone)
 text(c,Vector2(42,canvas.y-35),"ESC / ZURÜCK: BASIS   //   WAFFE: E   BOMBE: Q   BOMBENTYP: R   POWER-UPS: 1 / 2 / 3",Color("#7A9DB2"),15)
