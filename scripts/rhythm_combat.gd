extends RefCounted
## Offline rhythm battle state machine. One input per beat, attack/defend alternation.
## Game graphics and touch buttons are kept in main.gd; this class owns the rules.
const KEYS = ["UP", "RIGHT", "DOWN", "LEFT"]
const BEAT_SECONDS = 0.72
var phase: String = "ATTACK"
var result: String = "IDLE"
var sequence: Array = []
var index: int = 0
var hits: int = 0
var mistakes: int = 0
var beat_clock: float = 0.0
var ice_hp: float = 100.0
var ice_max: float = 100.0
var player_hp: float = 100.0
var program: String = "BASIC_SPIKE"
var modules: Dictionary = {}
var level: int = 1
var turn: int = 0
var feedback: String = "READY"
var rng = RandomNumberGenerator.new()

func begin(program_id: String, base_modules: Dictionary, integrity: float, difficulty: int = 1) -> void:
 program = program_id
 modules = base_modules.duplicate(true)
 level = clampi(difficulty,1,5)
 ice_max = 72.0 + level * 25.0
 ice_hp = ice_max
 player_hp = clampf(integrity,1.0,100.0)
 phase = "ATTACK"
 result = "RUNNING"
 turn = 1
 rng.randomize()
 _next_sequence()
 feedback = "UPLOAD YOUR ATTACK SEQUENCE"

func _next_sequence() -> void:
 sequence.clear()
 for i in range(4):
  sequence.append(rng.randi_range(0,3))
 index = 0
 hits = 0
 mistakes = 0
 beat_clock = 0.0

func current_key() -> int:
 if index >= sequence.size():
  return -1
 return int(sequence[index])

func beat_duration() -> float:
 return 0.68 if program == "OVERDRIVE" and phase == "ATTACK" else BEAT_SECONDS

func tick(delta: float) -> void:
 if result != "RUNNING":
  return
 beat_clock += maxf(0.0,delta)
 if beat_clock > beat_duration():
  mistakes += 1
  feedback = "MISSED BEAT"
  _advance()

func press(direction: int) -> bool:
 if result != "RUNNING" or direction < 0 or direction > 3:
  return false
 var window = 0.105 if modules.get("SYNC", false) else 0.145
 var on_time = beat_clock >= window and beat_clock <= beat_duration()-0.05
 var correct = direction == current_key() and on_time
 if correct:
  hits += 1
  feedback = "PERFECT INPUT" if absf(beat_clock-beat_duration()*0.5) < 0.13 else "GOOD INPUT"
 else:
  mistakes += 1
  feedback = "WRONG INPUT" if direction != current_key() else "TIMING ERROR"
 _advance()
 return correct

func _advance() -> void:
 index += 1
 beat_clock = 0.0
 if index >= sequence.size():
  _resolve_turn()

func _resolve_turn() -> void:
 if phase == "ATTACK":
  var base_damage = 14.0
  match program:
   "LOGIC_BOMB": base_damage = 22.0
   "OVERDRIVE": base_damage = 18.0
  if modules.get("AMPLIFIER", false):
   base_damage += 6.0
  var damage = base_damage * float(hits) / float(sequence.size())
  ice_hp = maxf(0.0,ice_hp-damage)
  if ice_hp <= 0.0:
   result = "WIN"
   feedback = "ICE NEUTRALIZED"
   return
  phase = "DEFEND"
  feedback = "COUNTER-ICE  //  DEFEND"
 else:
  var effective_guard = hits
  if program == "MIRROR_SHIELD":
   effective_guard = mini(4,effective_guard+1)
  var damage = maxf(0.0,18.0+float(level)*3.0-effective_guard*5.0)
  if modules.get("FIREWALL",false):
   damage *= 0.67
  player_hp = maxf(0.0,player_hp-damage)
  if player_hp <= 0.0:
   result = "LOSE"
   feedback = "CONNECTION LOST"
   return
  phase = "ATTACK"
  turn += 1
  feedback = "COUNTER DEFLECTED  //  ATTACK"
 _next_sequence()

func progress() -> float:
 return clampf(beat_clock/beat_duration(),0.0,1.0)
