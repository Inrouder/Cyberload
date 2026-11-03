extends Node2D
## Spatially culled static layers; no full-map texture, readback or per-frame rebuild.
const Chunk = preload("res://scripts/world_chunk.gd")
const CHUNK_SIZE = 512.0
const OVERHANG = 400.0
var chunks: Dictionary={}
var active: Dictionary={}
var cell_range: Rect2i=Rect2i(-100,-100,0,0)

func setup(world: RefCounted,landscape: RefCounted) -> void:
 for child in get_children():
  remove_child(child)
  child.queue_free()
 chunks.clear()
 active.clear()
 cell_range=Rect2i(-100,-100,0,0)
 z_index=-20
 var walls: Dictionary={}
 for building in world.walls:
  var cell=Vector2i(floor(Vector2(building["rect"].position).x/CHUNK_SIZE),floor(Vector2(building["rect"].position).y/CHUNK_SIZE))
  if not walls.has(cell):walls[cell]=[]
  walls[cell].append(building)
 for y in range(int(ceil(world.SIZE.y/CHUNK_SIZE))):
  for x in range(int(ceil(world.SIZE.x/CHUNK_SIZE))):
   var cell=Vector2i(x,y)
   var bounds=Rect2(Vector2(cell)*CHUNK_SIZE,Vector2(CHUNK_SIZE,CHUNK_SIZE))
   bounds=bounds.intersection(Rect2(Vector2.ZERO,world.SIZE))
   var local_roads: Array=[]
   for road in world.roads:
    if bounds.intersects(road["rect"]):local_roads.append(road)
   var layers: Array=[]
   for layer in range(3):
    if layer>0 and not walls.has(cell):continue
    var item=Chunk.new()
    item.bounds=bounds
    item.world=world
    item.landscape=landscape
    item.layer=layer
    item.z_index=layer
    item.buildings=walls.get(cell,[])
    item.roads=local_roads
    item.visible=false
    add_child(item)
    layers.append(item)
   chunks[cell]=layers

func update_view(view: Rect2) -> void:
 var expanded: Rect2=view.grow(OVERHANG)
 var first=Vector2i(floor(expanded.position.x/CHUNK_SIZE),floor(expanded.position.y/CHUNK_SIZE))
 var last=Vector2i(floor(expanded.end.x/CHUNK_SIZE),floor(expanded.end.y/CHUNK_SIZE))
 var next_range=Rect2i(first,last-first+Vector2i.ONE)
 if next_range==cell_range:return
 cell_range=next_range
 var next: Dictionary={}
 for y in range(first.y,last.y+1):
  for x in range(first.x,last.x+1):
   var cell=Vector2i(x,y)
   if not chunks.has(cell):continue
   next[cell]=true
   if not active.has(cell):
    for item in chunks[cell]:item.visible=true
 for cell in active:
  if not next.has(cell):
   for item in chunks[cell]:item.visible=false
 active=next

func rebuilds() -> int:
 var total: int=0
 for layers in chunks.values():
  for item in layers:total+=item.rebuild_count
 return total
