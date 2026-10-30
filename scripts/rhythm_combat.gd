extends RefCounted
## One moving beat-lane; attacks approach from left, ICE attacks from right.
## All visual coordinates and hit decisions share the same phase_clock.
const KEYS = ["UP", "RIGHT", "DOWN", "LEFT"]
const NOTES_PER_PHASE = 4
const SLOWMO_SECONDS = 7.0
const SLOWMO_SPEED = 0.52
const MAX_SLOWMO_CHARGES = 2
const MAX_BOMB_CHARGES = 2
var phase: String = "ATTACK"
var result: String = "IDLE"
var sequence: Array = []
var index: int = 0
var hits: int = 0
var mistakes: int = 0
var phase_clock: float = 0.0
var ice_hp: float = 100.0
var ice_max: float = 100.0
var player_hp: float = 100.0
var program: String = "BASIC_SPIKE"
var modules: Dictionary = {}
var level: int = 1
var turn: int = 0
var feedback: String = "READY"
var chrono_unlocked: bool = false
var slowmo_charges: int = 0
var slowmo_remaining: float = 0.0
var rng = RandomNumberGenerator.new()
var dev_overkill: bool = false
var bomb_charges: int = 0
var quick_loot: bool = false

func begin(program_id: String, base_modules: Dictionary, integrity: float, difficulty: int = 1, has_chrono: bool = false, fast_core: bool = false) -> void:
 program = program_id
 modules = base_modules.duplicate(true)
 level = clampi(difficulty,1,5)
 quick_loot = fast_core
 bomb_charges = 1 if fast_core else MAX_BOMB_CHARGES
 chrono_unlocked = has_chrono
 slowmo_charges = MAX_SLOWMO_CHARGES if has_chrono else 0
 slowmo_remaining = 0.0
 ice_max = (40.0+level*9.0) if quick_loot else 70.0+level*18.0
 ice_hp = ice_max
 player_hp = clampf(integrity,1.0,100.0)
 phase = "ATTACK"
 result = "RUNNING"
 turn = 1
 rng.randomize()
 _next_sequence()
 feedback = "WATCH THE INCOMING ARROWS"

func beat_duration() -> float:
 # Level 1 = 1.50 s; level 5 = 0.66 s.
 var seconds: float = (1.55-0.15*float(level-1)) if quick_loot else (1.70-0.17*float(level-1))
 if program == "OVERDRIVE" and phase == "ATTACK":
  seconds *= 0.92
 return seconds

func hit_window() -> float:
 # SYNC expands the center-circle timing tolerance.
 return (0.44 if quick_loot else 0.40)-0.025*float(level-1)+(0.07 if modules.get("SYNC",false) else 0.0)

func lead_in() -> float:
 return beat_duration()*1.25

func travel_time() -> float:
 return beat_duration()*2.35

func note_time(note: int) -> float:
 return lead_in()+float(note)*beat_duration()

func time_until_hit(note: int) -> float:
 return note_time(note)-phase_clock

func bpm() -> int:
 return int(round(60.0/beat_duration()))

func current_key() -> int:
 return int(sequence[index]) if index < sequence.size() else -1

func _next_sequence() -> void:
 sequence.clear()
 for i in range(NOTES_PER_PHASE):
  sequence.append(rng.randi_range(0,3))
 index = 0
 hits = 0
 mistakes = 0
 phase_clock = 0.0

func activate_bomb() -> bool:
 if result != "RUNNING" or phase != "ATTACK" or bomb_charges <= 0:
  return false
 bomb_charges -= 1
 ice_hp = maxf(0.0,ice_hp-(85.0 if quick_loot else 64.0+level*6.0))
 feedback = "CODE BOMB // ICE DETONATED"
 if ice_hp <= 0.0:
  result = "WIN"
  return true
 phase = "DEFEND"
 _next_sequence()
 return true

func activate_slowmo() -> bool:
 if result != "RUNNING" or not chrono_unlocked or slowmo_charges <= 0 or slowmo_remaining > 0.0:
  return false
 slowmo_charges -= 1
 slowmo_remaining = SLOWMO_SECONDS
 feedback = "CHRONO HACK // TIME DILATED"
 return true

func tick(delta: float) -> void:
 if result != "RUNNING":
  return
 var real_delta: float = maxf(0.0,delta)
 var slowed: float = minf(real_delta,slowmo_remaining)
 phase_clock += slowed*SLOWMO_SPEED+(real_delta-slowed)
 slowmo_remaining = maxf(0.0,slowmo_remaining-real_delta)
 # Late arrows expire after the generous symmetric hit window.
 while result == "RUNNING" and index < sequence.size() and phase_clock > note_time(index)+hit_window():
  mistakes += 1
  feedback = "MISSED ARROW"
  _advance()

func press(direction: int) -> bool:
 if result != "RUNNING" or direction < 0 or direction >= KEYS.size() or current_key() < 0:
  return false
 var offset: float = absf(time_until_hit(index))
 if offset > hit_window():
  feedback = "WAIT FOR THE TARGET CIRCLE"
  return false
 var correct: bool = direction == current_key()
 if correct:
  hits += 1
  # The developer cheat is deliberately instant, not turn-end damage.
  if dev_overkill and phase == "ATTACK":
   ice_hp = 0.0
   result = "WIN"
   feedback = "DEV OVERKILL // ICE SHATTERED"
   return true
  if phase == "DEFEND":
   feedback = "PERFECT BLOCK" if offset <= 0.10 else "ICE BLOCKED"
  else:
   feedback = "PERFECT HIT" if offset <= 0.10 else "GOOD HIT"
 else:
  mistakes += 1
  feedback = "WRONG DIRECTION"
 _advance()
 return correct

func _advance() -> void:
 index += 1
 if index >= sequence.size():
  _resolve_turn()

func _resolve_turn() -> void:
 if phase == "ATTACK":
  var base_damage: float = 58.0
  match program:
   "LOGIC_BOMB": base_damage = 74.0
   "OVERDRIVE": base_damage = 67.0
  if modules.get("AMPLIFIER",false):
   base_damage += 12.0
  if dev_overkill:
   base_damage *= 80.0
  ice_hp = maxf(0.0,ice_hp-base_damage*float(hits)/float(sequence.size()))
  if ice_hp <= 0.0:
   result = "WIN"
   feedback = "ICE NEUTRALIZED"
   return
  phase = "DEFEND"
  feedback = "COUNTER-ICE // WATCH RIGHT SIDE"
 else:
  # Every blocked incoming arrow prevents exactly one quarter of ICE damage.
  # A perfect defense always prevents ALL damage, including against elite ICE.
  var effective_guard: int = hits
  if program == "MIRROR_SHIELD":
   effective_guard = mini(sequence.size(),effective_guard+1)
  var unblocked: int = maxi(0,sequence.size()-effective_guard)
  var damage: float = (12.0+float(level)*2.0)*float(unblocked)/float(sequence.size())
  if modules.get("FIREWALL",false):
   damage *= 0.67
  player_hp = maxf(0.0,player_hp-damage)
  if player_hp <= 0.0:
   result = "LOSE"
   feedback = "CONNECTION LOST"
   return
  phase = "ATTACK"
  turn += 1
  feedback = "FULL BLOCK // 0 HP LOST" if unblocked == 0 else "ICE HIT // -%.1f HP" % damage
 _next_sequence()

func progress() -> float:
 if result != "RUNNING" or current_key() < 0:
  return 0.0
 return clampf(1.0-time_until_hit(index)/travel_time(),0.0,1.0)
