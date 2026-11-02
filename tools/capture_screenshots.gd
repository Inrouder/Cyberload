extends SceneTree
## Run with a graphical display: godot --path . --script res://tools/capture_screenshots.gd
## Optional output folder follows -- (defaults to docs/screenshots).
const State = preload("res://scripts/game_state.gd")
var game: Node2D
var output: String

func _initialize() -> void:
 call_deferred("_run")

func _capture(label: String) -> void:
 game.camera_follow=game._current_pos()
 game.camera_mode=game.world_mode
 game.fx.shake_offset=Vector2.ZERO
 game.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var picture: Image=root.get_texture().get_image()
 if picture.save_png(output.path_join(label+".png"))!=OK:
  push_error("Unable to save rendered screenshot: "+label)
  quit(1)

func _run() -> void:
 var arguments: PackedStringArray=OS.get_cmdline_user_args()
 output=arguments[0] if not arguments.is_empty() else ProjectSettings.globalize_path("res://docs/screenshots")
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 # Use demonstration state in memory; screenshots never write to the player's save.
 game.state=State.new()
 game.state.clearance_level=2
 game.runner_mesh.setup_saved(game.state.mesh_cells,game.state.mesh_mode,game.state.mesh_level)
 game.elapsed=6.5
 game._enter_withnet()
 game.player=game.open_world.find_clear(Vector2(2450,1150))
 game.zone_access=true
 game.notification_timer=0
 await _capture("dataverse")
 game._enter_dungeon(2)
 game.dungeon.setup(2,false,17326)
 game.dungeon_player=game.dungeon.spawn
 game.notification_timer=0
 await _capture("subnet")
 game._start_duel(false,true)
 game.duel.phase_clock=game.duel.note_time(0)-0.7
 await _capture("netduel")
 game.queue_free()
 await process_frame
 call_deferred("_finish")

func _finish() -> void:
 print("CYBERLOAD VISUAL CAPTURE PASS")
 quit(0)
