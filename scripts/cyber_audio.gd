extends Node
## Small cached synthesised cues; no downloads, music files or per-frame allocations.
var enabled: bool = true
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var cursor: int = 0

func _ready() -> void:
 if DisplayServer.get_name()=="headless":
  return
 for i in range(6):
  var voice = AudioStreamPlayer.new()
  voice.volume_db=-22
  add_child(voice)
  voices.append(voice)
 for kind in ["tap","good","bad","breach","warning","shot","pulse"]:
  samples[kind]=_synth(kind)

func cue(kind: String) -> void:
 if not enabled or voices.is_empty() or not samples.has(kind):
  return
 var voice: AudioStreamPlayer=voices[cursor%voices.size()]
 cursor+=1
 voice.stream=samples[kind]
 voice.play()

func _synth(kind: String) -> AudioStreamWAV:
 var duration: float=0.12
 var frequency: float=480
 match kind:
  "good": frequency=880
  "bad": frequency=130
  "breach": frequency=220; duration=0.6
  "warning": frequency=340; duration=0.32
  "shot": frequency=160; duration=0.08
  "pulse": frequency=230; duration=0.08
 var rate: int=22050
 var bytes = PackedByteArray()
 bytes.resize(int(rate*duration)*2)
 for i in range(bytes.size()/2):
  var t: float=float(i)/rate
  var envelope: float=minf(1,t*160)*pow(1-t/duration,2)
  var sweep: float=frequency*(1.0+t*2.4) if kind=="breach" else frequency
  var value: float=(sin(TAU*sweep*t)+0.22*sin(TAU*sweep*2*t))*envelope*0.42
  bytes.encode_s16(i*2,int(value*32767))
 var sample=AudioStreamWAV.new()
 sample.format=AudioStreamWAV.FORMAT_16_BITS
 sample.mix_rate=rate
 sample.data=bytes
 return sample

func _exit_tree() -> void:
 for voice in voices:
  if is_instance_valid(voice):
   voice.stop()
   voice.stream=null
 samples.clear()
