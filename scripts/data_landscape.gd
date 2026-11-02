extends RefCounted
## Code-native 2.5D data architecture; shared geometry keeps the picture truthful.
const CYAN = Color("#50E8FF")
const PINK = Color("#FF507C")
const LIME = Color("#D0F96C")
const VIOLET = Color("#B887FF")

func _text(c: CanvasItem,at: Vector2,value: String,tint: Color,size: int=16) -> void:
 c.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,tint)

func _near(rect: Rect2,focus: Vector2) -> bool:
 return rect.grow(1050).has_point(focus)

func draw_world(c: CanvasItem,world: RefCounted,focus: Vector2,time: float,state: RefCounted) -> void:
 var region: Dictionary=world.region_at(focus)
 var accent: Color=region["color"]
 c.draw_rect(Rect2(Vector2.ZERO,world.SIZE),Color("#070E1B"))
 # Sparse circuitry, dim enough to separate walkable ground from the roofs.
 var start_x: int=maxi(80,int((focus.x-1000)/96)*96)
 var start_y: int=maxi(80,int((focus.y-650)/96)*96)
 for y in range(start_y,mini(3320,int(focus.y+680)),96):
  for x in range(start_x,mini(9520,int(focus.x+1050)),96):
   var at=Vector2(x,y)
   c.draw_line(at,at+Vector2(24,0),Color(accent,0.08),1)
   c.draw_circle(at,1.2,Color(accent,0.18))
 for road in world.roads:
  var rect: Rect2=road["rect"]
  if not _near(rect,focus):
   continue
  var major: bool=road["major"]
  c.draw_rect(rect,Color("#102335") if major else Color("#0C1B2C"))
  c.draw_rect(rect,Color(accent,0.12),false,1)
  if major:
   var y: float=rect.get_center().y
   var left: int=maxi(int(rect.position.x+20),int(focus.x-1000))
   left=int(left/90)*90
   for x in range(left,mini(int(rect.end.x-15),int(focus.x+1050)),90):
    c.draw_line(Vector2(x,y-29),Vector2(x+32,y-29),Color(CYAN,0.35),2,true)
    c.draw_line(Vector2(x,y+29),Vector2(x+32,y+29),Color(CYAN,0.20),2,true)
   for i in range(8):
    var px: float=fposmod(time*83+float(i)*169,1400)+focus.x-700
    c.draw_line(Vector2(px,y),Vector2(px+13,y),Color(CYAN,0.65),2,true)
 for canal in world.canals:
  if not _near(canal,focus):
   continue
  c.draw_rect(canal,Color("#0D4059"))
  c.draw_rect(canal,Color(CYAN,0.6),false,2)
  for row in range(4):
   for i in range(17):
    var x: float=canal.position.x+fposmod(i*56+time*35+row*23,canal.size.x-35)
    var y: float=canal.position.y+18+row*29
    c.draw_line(Vector2(x,y),Vector2(x+21,y),Color(CYAN,0.2+0.1*sin(time*3+i)),2,true)
  _text(c,canal.position+Vector2(16,23),"LIQUID DATA  >>>",Color(CYAN,0.7),13)
 # Cast shadows first, then draw slabs, side faces and luminous roof details.
 for wall in world.walls:
  var rect: Rect2=wall["rect"]
  if _near(rect,focus):
   c.draw_rect(Rect2(rect.position+Vector2(12,17),rect.size+Vector2(8,8)),Color(0.01,0.02,0.05,0.7))
 for wall in world.walls:
  var rect: Rect2=wall["rect"]
  if not _near(rect,focus):
   continue
  _building(c,rect,wall["tint"],float(wall["height"]),int(wall["style"]),time)
 for boundary in [Rect2(0,0,world.SIZE.x,64),Rect2(0,world.SIZE.y-64,world.SIZE.x,64),
  Rect2(0,0,64,world.SIZE.y),Rect2(world.SIZE.x-64,0,64,world.SIZE.y)]:
  c.draw_rect(boundary,Color("#182B41"))
  c.draw_rect(boundary,Color(VIOLET,0.7),false,3)
 for vein in world.veins:
  var at: Vector2=vein["pos"]
  if at.distance_to(focus)>950:
   continue
  var ready: bool=int(Time.get_unix_time_from_system())>=int(state.mined_veins.get(str(vein["id"]),0))
  var tint: Color=vein["color"] if ready else Color("#334356")
  c.draw_arc(at,25,0,TAU,24,Color(tint,0.25),1,true)
  c.draw_colored_polygon(PackedVector2Array([at+Vector2(-13,7),at+Vector2(-8,-12),at+Vector2(3,-18),at+Vector2(17,6),at+Vector2(2,15)]),tint.darkened(0.35))
  c.draw_line(at+Vector2(-8,-12),at+Vector2(3,-18),tint,2,true)
  c.draw_line(at+Vector2(3,-18),at+Vector2(2,15),tint,2,true)
  if at.distance_to(focus)<95:
   _text(c,at+Vector2(-42,-34),str(vein["type"])+(" / E" if ready else " / EMPTY"),tint,13)
 for portal in world.portals:
  var at: Vector2=portal["pos"]
  if at.distance_to(focus)>1050:
   continue
  var cleared: bool=bool(state.dungeon_clears.get("DUNGEON_%d" % int(portal["id"]),false))
  var tint: Color=LIME if cleared else VIOLET
  c.draw_circle(at,62,Color(tint,0.05))
  c.draw_arc(at,51,0,TAU,56,Color(tint,0.5),3,true)
  var center: Vector2=at+Vector2(0,-9+sin(time*2.4)*4)
  var diamond=PackedVector2Array([center+Vector2(0,-39),center+Vector2(28,0),center+Vector2(0,39),center+Vector2(-28,0),center+Vector2(0,-39)])
  c.draw_colored_polygon(diamond,Color("#172D47"))
  c.draw_polyline(diamond,tint,3,true)
  c.draw_arc(center,17,time,time+PI*1.6,30,CYAN,2,true)
  _text(c,at+Vector2(-80,-73),str(portal["name"]),tint,16)
  _text(c,at+Vector2(-70,80),"NEW SUBNET / HACK [E]",Color(CYAN,0.8),13)
 # District sign sits at the main road, away from the route itself.
 for district in world.REGIONS:
  var x: float=float(district["from"])+85
  if absf(x-focus.x)<1050:
   _text(c,Vector2(x,462),str(district["name"]),district["color"],19)
   _text(c,Vector2(x,486),"DATASCAPE / TIER %d" % int(district["tier"]),Color("#6F93A6"),12)

func _building(c: CanvasItem,rect: Rect2,tint: Color,height: float,style: int,time: float) -> void:
 var roof=Rect2(rect.position-Vector2(0,height*0.45),rect.size)
 c.draw_rect(rect,Color("#101B2A"))
 c.draw_rect(Rect2(Vector2(rect.position.x,roof.end.y),Vector2(rect.size.x,height*0.45)),Color(tint.darkened(0.78),1))
 c.draw_rect(roof,Color("#14243A") if style%2==0 else Color("#1B243B"))
 c.draw_rect(roof,Color(tint,0.45),false,1.5)
 c.draw_line(roof.position,roof.position+Vector2(roof.size.x,0),Color(tint,0.85),2,true)
 c.draw_line(roof.position,roof.position+Vector2(0,roof.size.y),Color(tint,0.5),2,true)
 if rect.size.x>68 and rect.size.y>65:
  var inset: Rect2=roof.grow(-14)
  c.draw_rect(inset,Color(tint,0.06))
  c.draw_rect(inset,Color(tint,0.17),false,1)
  for x in range(0,int(inset.size.x)-12,33):
   var at: Vector2=inset.position+Vector2(x+7,12)
   c.draw_line(at,at+Vector2(17,0),Color(tint,0.2+0.15*sin(time*0.8+rect.position.x+x)),3)
  if style==1:
   var center: Vector2=roof.get_center()
   c.draw_arc(center,minf(roof.size.x,roof.size.y)*0.22,0,TAU,32,Color(tint,0.2),2,true)
   c.draw_circle(center,4,Color(tint,0.65))
  elif style==2:
   for i in range(3):
    var at: Vector2=roof.get_center()+Vector2(-24+i*20,0)
    c.draw_rect(Rect2(at-Vector2(5,14),Vector2(10,28)),Color(tint,0.18))
 # Roof-mounted server cassettes and fine buses distinguish data infrastructure.
 if rect.size.x>145 and rect.size.y>100:
  var cassette: Vector2=roof.position+Vector2(25,roof.size.y*0.55)
  for slot in range(mini(4,int((roof.size.x-48)/42))):
   var chip=Rect2(cassette+Vector2(slot*42,0),Vector2(27,37))
   c.draw_rect(chip,Color("#0A1728"))
   c.draw_rect(chip,Color(tint,0.22),false,1)
   for bar in range(4):
    var y: float=chip.position.y+7+bar*7
    c.draw_line(Vector2(chip.position.x+5,y),Vector2(chip.end.x-5,y),Color(tint,0.15),1)
   c.draw_circle(chip.position+Vector2(21,5),1.6,Color(tint,0.65))
  var bus_y: float=roof.position.y+roof.size.y*0.55-11
  c.draw_line(Vector2(roof.position.x+18,bus_y),Vector2(roof.end.x-18,bus_y),Color(tint,0.17),1)
  for part in range(2):
   var offset=Vector2(roof.end.x-48,roof.position.y+23+part*13)
   c.draw_line(offset,offset+Vector2(18,0),Color(tint,0.3),2)
 # Small windows along the front convey depth without texture assets.
 for x in range(12,int(rect.size.x)-9,26):
  c.draw_line(Vector2(rect.position.x+x,rect.end.y-2),Vector2(rect.position.x+x+9,rect.end.y-2),Color(tint,0.65),2)

func draw_traps(c: CanvasItem,traps: Array,focus: Vector2,time: float) -> void:
 for trap in traps:
  var at: Vector2=trap["pos"]
  if at.distance_to(focus)>950:
   continue
  var armed: bool=trap["armed"]
  var tint: Color=PINK if armed else LIME
  var radius: float=37 if armed else 37*clampf(float(trap["age"]),0,1)
  c.draw_circle(at,radius,Color(tint,0.05+0.04*sin(time*12)))
  c.draw_arc(at,radius,0,TAU,36,tint,2,true)
  for i in range(4):
   var offset: Vector2=Vector2.RIGHT.rotated(i*PI*0.5+PI*0.25)*25
   c.draw_line(at+offset,at-offset,Color(tint,0.5),1,true)
  _text(c,at+Vector2(-28,-47),"SNARE" if armed else "ARMING",tint,13)

func draw_dungeon(c: CanvasItem,dungeon: RefCounted,focus: Vector2,time: float,state: RefCounted,dungeon_id: int,objectives: bool=true) -> void:
 var tint: Color=[CYAN,PINK,VIOLET,LIME][dungeon.theme]
 c.draw_rect(Rect2(Vector2.ZERO,Vector2(dungeon.WIDTH,dungeon.HEIGHT)*dungeon.TILE),Color("#040A14"))
 for y in range(dungeon.HEIGHT):
  for x in range(dungeon.WIDTH):
   var at=Vector2(x,y)*dungeon.TILE
   if absf(at.x-focus.x)>1050 or absf(at.y-focus.y)>730:
    continue
   var tile=Rect2(at,Vector2(dungeon.TILE,dungeon.TILE))
   if dungeon.floors.has(Vector2i(x,y)):
    c.draw_rect(tile,Color("#10283A") if dungeon.theme==0 else Color("#101D2F"))
    c.draw_rect(tile,Color(tint,0.06),false,1)
    if (x*7+y*11)%9==0:
     var point: Vector2=at+Vector2(30,30)
     c.draw_line(point-Vector2(8,0),point+Vector2(8,0),Color(tint,0.28),2)
    for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if not dungeon.floors.has(Vector2i(x,y)+d):
      var edge: Vector2=tile.get_center()+Vector2(d)*29
      var side: Vector2=Vector2(-d.y,d.x)*27
      c.draw_line(edge-side,edge+side,Color(tint,0.55),2,true)
   else:
    var exposed: bool=false
    for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if dungeon.floors.has(Vector2i(x,y)+d):
      exposed=true
    if exposed:
     _building(c,tile.grow(-2),tint,18,(x+y)%4,time)
 for i in range(dungeon.rooms.size()):
  var room: Rect2i=dungeon.rooms[i]
  var origin: Vector2=Vector2(room.position)*dungeon.TILE
  if origin.distance_to(focus)<1100:
   _text(c,origin+Vector2(18,27),"%s / %02d" % [dungeon.THEMES[dungeon.theme],i+1],Color(tint,0.4),14)
 if not objectives:
  return
 var exit: Vector2=dungeon.exit_pos
 c.draw_arc(exit,41,0,TAU,42,LIME,3,true)
 c.draw_arc(exit,27,time,time+PI*1.7,32,CYAN,2,true)
 _text(c,exit+Vector2(-45,-56),"EXIT [E]",LIME,17)
 for cache in dungeon.caches:
  var at: Vector2=cache["pos"]
  var taken: bool=state.dungeon_caches.has("%d:%d" % [dungeon_id,int(cache["id"])])
  var tone: Color=Color("#3A4E62") if taken else LIME
  c.draw_circle(at,33,Color(tone,0.07))
  _building(c,Rect2(at-Vector2(20,15),Vector2(40,30)),tone,14,0,time)
  _text(c,at+Vector2(-27,-34),"EMPTY" if taken else "CACHE",tone,13)
 for enemy in dungeon.enemies:
  var at: Vector2=enemy["pos"]
  var tone: Color=Color("#364456") if enemy["defeated"] else PINK
  var radius: float=40 if enemy["boss"] else 25
  c.draw_arc(at,radius,time*0.4,time*0.4+PI*1.8,40,tone,2,true)
  var diamond=PackedVector2Array([at+Vector2(0,-19),at+Vector2(16,0),at+Vector2(0,19),at+Vector2(-16,0),at+Vector2(0,-19)])
  c.draw_polyline(diamond,tone,3,true)
  _text(c,at+Vector2(-55,-56),str(enemy["name"]),tone,14)

func draw_dungeon_radar(c: CanvasItem,dungeon: RefCounted,player: Vector2,canvas: Vector2) -> void:
 var origin=Vector2(canvas.x-235,124)
 c.draw_rect(Rect2(origin-Vector2(9,27),Vector2(224,160)),Color("#071321",0.94))
 _text(c,origin-Vector2(0,8),"SUBNET // NEW TOPOLOGY",CYAN,13)
 var scale: float=4.3
 for cell in dungeon.floors:
  c.draw_rect(Rect2(origin+Vector2(cell)*scale,Vector2(scale,scale)),Color("#31516A"))
 for cache in dungeon.caches:
  c.draw_circle(origin+Vector2(cache["pos"])/dungeon.TILE*scale,2,LIME)
 c.draw_circle(origin+dungeon.exit_pos/dungeon.TILE*scale,3,VIOLET)
 c.draw_circle(origin+player/dungeon.TILE*scale,3,CYAN)

func draw_hack_space(c: CanvasItem,canvas: Vector2,time: float,integrity: float) -> void:
 c.draw_rect(Rect2(Vector2.ZERO,canvas),Color("#050C19"))
 var center=Vector2(canvas.x*0.5,canvas.y*0.48)
 var tint: Color=CYAN.lerp(PINK,1-clampf(integrity,0,1))
 for i in range(12):
  var depth: float=fposmod(float(i)/12+time*0.085,1)
  var radius: float=35+depth*depth*canvas.x*0.8
  var points=PackedVector2Array()
  for k in range(7):
   points.append(center+Vector2.RIGHT.rotated(float(k)*TAU/6+0.15*sin(time*0.2))*radius*Vector2(1,0.64))
  c.draw_polyline(points,Color(tint,0.025+depth*0.13),1,true)
 for i in range(32):
  var angle: float=i*TAU/32
  var direction: Vector2=Vector2.RIGHT.rotated(angle)*Vector2(1,0.64)
  c.draw_line(center+direction*100,center+direction*canvas.x,Color(tint,0.04),1,true)
  var radius: float=100+fposmod(time*115+i*47,720)
  c.draw_line(center+direction*radius,center+direction*(radius+17),Color(tint,0.2),2,true)
 # Calm vignette instead of full-screen random glitches / strobing.
 c.draw_rect(Rect2(0,0,canvas.x,8),Color(tint,0.35))
 c.draw_rect(Rect2(0,canvas.y-8,canvas.x,8),Color(tint,0.2))

func draw_ice_core(c: CanvasItem,at: Vector2,time: float,health: float,attacking: bool) -> void:
 var tint: Color=CYAN if attacking else PINK
 for ring in range(3):
  var radius: float=81+ring*22
  c.draw_arc(at,radius,time*(0.25+ring*0.12),time*(0.25+ring*0.12)+PI*1.5,60,Color(tint,0.14+health*0.06),1.5,true)
 var angle: float=time*0.24
 for i in range(6):
  var a: Vector2=at+Vector2.RIGHT.rotated(angle+i*TAU/6)*111
  var b: Vector2=at+Vector2.RIGHT.rotated(angle+(i+2)*TAU/6)*111
  c.draw_line(a,b,Color(tint,0.13),1,true)
