extends SceneTree
## Demonstration-state captures; uses a graphical Godot session and never writes saves.
const State=preload("res://scripts/game_state.gd")
var game: Node2D
var folder: String=ProjectSettings.globalize_path("res://docs/screenshots")
func _initialize() -> void:call_deferred("run")
func snap(label: String) -> void:
 game._process(0)
 game.queue_redraw()
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
 var args=OS.get_cmdline_user_args()
 if not args.is_empty():folder=args[0]
 DirAccess.make_dir_recursive_absolute(folder)
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 game.state=State.new()
 game.music.enabled=true
 game.audio.enabled=false
 game.title_open=true
 game.save_available=true
 await snap("title")
 game._enter_homebase()
 game._open_subnets()
 await snap("subnet-selection")
 game._start_flight(1,false)
 game.flight.distance=6200
 game.flight.energy=84
 game.flight.kills=14
 game.flight.score=1120
 game.flight.obstacles=[{"x":7090.0,"gap":330.0,"size":230.0}]
 for i in range(5):game.flight.spawn_enemy(Vector2(650+i*115,230+sin(i*2.0)*95),"TANK" if i==3 else "DRONE")
 for i in range(35):game.flight.tick(1.0/60,Vector2.ZERO,true)
 game.touch_controls_enabled=true
 await snap("shooter")
 for id in range(3):
  game._start_flight(id,false)
  game.flight._begin_boss()
  game.flight.boss_clock=5.0
  game.flight.boss_attack=2
  game.flight.boss_delay=0
  game.flight.energy=100
  game.flight.tick(0.016)
  await snap(["aegis-boss","mirror-boss","hydra-boss"][id])
 game._open_pause()
 await snap("pause")
 game.queue_free()
 await process_frame
 await create_timer(0.15).timeout
 print("CYBERLOAD V08 VISUAL PASS")
 quit()
