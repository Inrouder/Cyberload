extends SceneTree
const Game=preload("res://scripts/main.gd")
const State=preload("res://scripts/game_state.gd")
const Music=preload("res://scripts/cyber_music.gd")
var originals: Dictionary={}
var instance: Node=null
func _initialize() -> void:call_deferred("_run")
func cleanup() -> void:
 for path in originals:
  if originals[path]==null:
   if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
  else:
   var file=FileAccess.open(path,FileAccess.WRITE)
   file.store_buffer(originals[path])
 if FileAccess.file_exists(State.SAVE_PATH+".tmp"):DirAccess.remove_absolute(State.SAVE_PATH+".tmp")
func check(value: bool,message: String) -> bool:
 if not value:
  cleanup()
  push_error("CYBERLOAD SESSION FAIL: "+message)
  quit(1)
 return value
func _run() -> void:
 for path in [State.SAVE_PATH,State.SAVE_PATH+".before_new_game.bak","user://cyberload_audio.cfg"]:
  originals[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 var game=Game.new()
 instance=game
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 if not check(game.title_open and not game.save_available,"Fresh boot has no true title/load state"):return
 var original_x: float=game.base_player.x
 game._physics_process(5)
 if not check(game.title_open and game.base_player.x==original_x and not FileAccess.file_exists(State.SAVE_PATH),"Title menu starts gameplay or creates a save"):return
 game._audio_click(game.shell.music_rect(Vector2(1280,720)).get_center(),Vector2(1280,720))
 if not check(not FileAccess.file_exists(State.SAVE_PATH),"Music toggle creates a fake game save"):return
 var legacy=FileAccess.open(State.SAVE_PATH,FileAccess.WRITE)
 legacy.store_string('{"version":9,"credits":777,"fragments":19,"mesh_level":4}')
 legacy.close()
 var previous: PackedByteArray=FileAccess.get_file_as_bytes(State.SAVE_PATH)
 game.save_available=State.has_game()
 game._request_new_game()
 if not check(game.new_game_confirm and FileAccess.get_file_as_bytes(State.SAVE_PATH)==previous,"New-game first click overwrites old save"):return
 game.new_game_confirm=false
 game._continue_game()
 if not check(not game.title_open and game.state.credits==777 and game.state.mesh_level==4,"Legacy save cannot be loaded from title"):return
 game._start_flight(1)
 game.flight.distance=4700
 game.flight.kills=17
 game.flight.energy=63
 game.flight._set_checkpoint()
 game._open_pause()
 var distance: float=game.flight.distance
 game._physics_process(5)
 if not check(game.flight.distance==distance,"Pause does not freeze the shooter"):return
 if not check(game._save_session(),"Shooter checkpoint save failed"):return
 game.title_open=true
 game._continue_game()
 if not check(game.world_mode==4 and game.flight.id==1 and game.flight.distance==distance and game.flight.kills==17 and game.flight.energy==63,"Load loses shooter checkpoint data"):return
 game.flight.result="LOSE"
 game._tick_flight(0.016)
 if not check(game.state.session.get("kind","")=="FLIGHT","Defeat discards the retry checkpoint on restart"):return
 game.title_open=true
 game._continue_game()
 if not check(game.world_mode==4 and game.flight.result=="RUNNING","Defeated run cannot resume its checkpoint"):return
 game.flight.result="WIN"
 game._tick_flight(0.016)
 var credits: int=game.state.credits
 var count: int=game.state.flight_runs
 game._tick_flight(0.016)
 if not check(game.state.credits==credits and game.state.flight_runs==count and game.state.session.get("kind","")=="HOMEBASE","Victory reward can be claimed twice or replayed on load"):return
 game.title_open=true
 game.new_game_confirm=false
 game._request_new_game()
 game._request_new_game()
 if not check(game.state.credits==90 and State.has_game(State.SAVE_PATH+".before_new_game.bak"),"Confirmed new game has no recoverable backup"):return
 var backup=State.new()
 var file=FileAccess.open(State.SAVE_PATH+".before_new_game.bak",FileAccess.READ)
 var payload: Variant=JSON.parse_string(file.get_as_text())
 file.close()
 if not check(int(payload["credits"])==credits,"Backup is not the previous complete game"):return
 game.state.session={"kind":"FLIGHT","checkpoint":[]}
 game.state.save_game()
 game.title_open=true
 game._continue_game()
 if not check(game.world_mode==2,"Bad checkpoint does not fall back to the base"):return
 # Four real audio resources, rather than just renamed sound effects.
 if not check(Music.TRACKS.size()==4,"Music contexts missing"):return
 var durations: Dictionary={}
 for name in Music.TRACKS:
  var stream: AudioStreamOggVorbis=Music.TRACKS[name]
  if not check(stream.get_length()>10 and stream.get_length()<30,"Music loop duration invalid: "+str(name)):return
  durations[int(stream.get_length()*100)]=true
 if not check(durations.size()==4,"Music contexts all reuse the same loop"):return
 game.queue_free()
 instance=null
 await process_frame
 cleanup()
 print("CYBERLOAD SESSION PASS: title freeze, legacy load, safe new game/backup, paused checkpoint resume, one-time rewards and four real music loops")
 quit(0)
