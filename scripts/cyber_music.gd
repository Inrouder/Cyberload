extends Node
## Original pre-rendered loops. Two decoder voices crossfade; no music synthesis in frames.
const TRACKS = {
 "menu":preload("res://assets/music/menu.ogg"),
 "explore":preload("res://assets/music/explore.ogg"),
 "flight":preload("res://assets/music/flight.ogg"),
 "boss":preload("res://assets/music/boss.ogg")
}
var enabled: bool=true
var volume: float=0.65
var ducked: bool=false
var current: String=""
var voices: Array[AudioStreamPlayer]=[]
var gains: Array[float]=[0.0,0.0]
var active: int=0

func _ready() -> void:
 if DisplayServer.get_name()=="headless":return
 for i in range(2):
  var voice=AudioStreamPlayer.new()
  voice.volume_db=-80
  add_child(voice)
  voices.append(voice)

func select(track: String) -> void:
 if not TRACKS.has(track) or track==current:return
 current=track
 if voices.is_empty():return
 active=1-active
 var stream: AudioStreamOggVorbis=TRACKS[track]
 stream.loop=true
 voices[active].stream=stream
 gains[active]=0
 voices[active].volume_db=-80
 voices[active].play()
 voices[active].stream_paused=not enabled

func _process(delta: float) -> void:
 for i in range(voices.size()):
  gains[i]=move_toward(gains[i],1.0 if i==active else 0.0,delta*1.1)
  if voices[i].stream_paused==enabled:voices[i].stream_paused=not enabled
  var gain: float=gains[i]*clampf(volume,0,1)*(0.4 if ducked else 1.0)
  var decibels: float=-16+linear_to_db(maxf(gain,0.0001))
  if not is_equal_approx(voices[i].volume_db,decibels):voices[i].volume_db=decibels
  if i!=active and gains[i]<=0 and voices[i].playing:voices[i].stop()

func _exit_tree() -> void:
 for voice in voices:
  if is_instance_valid(voice):
   voice.stop()
   voice.stream=null
