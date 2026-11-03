extends Node2D
## Retained CanvasItem commands. Camera motion never rebuilds these primitives.
var bounds: Rect2
var world: RefCounted
var landscape: RefCounted
var buildings: Array=[]
var roads: Array=[]
var layer: int=0
var rebuild_count: int=0

func _draw() -> void:
 rebuild_count+=1
 if layer==1:
  for building in buildings:
   var rect: Rect2=building["rect"]
   draw_rect(Rect2(rect.position+Vector2(12,17),rect.size+Vector2(8,8)),Color(0.01,0.02,0.05,0.7))
  return
 if layer==2:
  for building in buildings:
   landscape._building(self,building["rect"],building["tint"],float(building["height"]),int(building["style"]),0.0)
  return
 var accent: Color=world.region_at(bounds.get_center())["color"]
 draw_rect(bounds,Color("#070E1B"))
 for y in range(int(ceil(bounds.position.y/96))*96,int(bounds.end.y),96):
  for x in range(int(ceil(bounds.position.x/96))*96,int(bounds.end.x),96):
   var at=Vector2(x,y)
   draw_line(at,at+Vector2(minf(24,bounds.end.x-x),0),Color(accent,0.08),1)
   draw_circle(at,1.2,Color(accent,0.18))
 for road in roads:
  var rect: Rect2=road["rect"].intersection(bounds)
  var major: bool=road["major"]
  draw_rect(rect,Color("#102335") if major else Color("#0C1B2C"))
  # Keep edges on the original road boundary, without visible chunk seams.
  var original: Rect2=road["rect"]
  for edge_y in [original.position.y,original.end.y]:
   if edge_y>=bounds.position.y and edge_y<bounds.end.y:
    draw_line(Vector2(rect.position.x,edge_y),Vector2(rect.end.x,edge_y),Color(accent,0.12),1)
  for edge_x in [original.position.x,original.end.x]:
   if edge_x>=bounds.position.x and edge_x<bounds.end.x:
    draw_line(Vector2(edge_x,rect.position.y),Vector2(edge_x,rect.end.y),Color(accent,0.12),1)
  if major:
   var middle: float=original.get_center().y
   for x in range(int(floor(rect.position.x/90))*90,int(rect.end.x),90):
    var left: float=maxf(x,rect.position.x)
    var right: float=minf(x+32,rect.end.x)
    if right<=left:continue
    for offset in [-29.0,29.0]:
     var y: float=middle+offset
     if y>=bounds.position.y and y<bounds.end.y:
      draw_line(Vector2(left,y),Vector2(right,y),Color(CYAN_TINT,0.35 if offset<0 else 0.20),2,true)
 for canal in world.canals:
  if canal.intersects(bounds):
   draw_rect(canal.intersection(bounds),Color("#0D4059"))
 # Fortress walls also use retained commands.
 for boundary in [Rect2(0,0,world.SIZE.x,64),Rect2(0,world.SIZE.y-64,world.SIZE.x,64),
  Rect2(0,0,64,world.SIZE.y),Rect2(world.SIZE.x-64,0,64,world.SIZE.y)]:
  if boundary.intersects(bounds):
   draw_rect(boundary.intersection(bounds),Color("#182B41"))
const CYAN_TINT = Color("#50E8FF")
