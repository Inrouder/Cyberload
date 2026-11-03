extends "res://scripts/main.gd"
var draws: Array[int]=[]
var meshes: Array[int]=[]
var processes: Array[int]=[]
func _draw() -> void:
 var start: int=Time.get_ticks_usec()
 super._draw()
 draws.append(Time.get_ticks_usec()-start)
func _mesh_update(delta: float) -> void:
 var start: int=Time.get_ticks_usec()
 super._mesh_update(delta)
 meshes.append(Time.get_ticks_usec()-start)
func _process(delta: float) -> void:
 var start: int=Time.get_ticks_usec()
 super._process(delta)
 processes.append(Time.get_ticks_usec()-start)
