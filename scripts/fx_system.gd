extends RefCounted
## Bounded offline particle and impact simulator. Node2D draws the output.
const RED = Color("#FF3F73")
const BLUE = Color("#50E8FF")
const GOLD = Color("#D0F96C")
const PURPLE = Color("#B887FF")
const LIMIT = 260
var particles: Array = []
var pulses: Array = []
var rng = RandomNumberGenerator.new()
var shake_offset: Vector2 = Vector2.ZERO
var shake_time: float = 0.0
var shake_strength: float = 0.0
var flash_time: float = 0.0
var flash_max: float = 0.0
var flash_color: Color = BLUE

func _init() -> void:
 rng.randomize()

func impact(power: float = 5.0, duration: float = 0.2) -> void:
 shake_strength = maxf(shake_strength,clampf(power,0.0,22.0))
 shake_time = maxf(shake_time,clampf(duration,0.0,0.65))

func flash(color: Color, duration: float = 0.18) -> void:
 flash_color = color
 flash_time = clampf(duration,0.0,0.45)
 flash_max = flash_time

func burst(at: Vector2, kind: String = "data", screen: bool = false, count: int = 18) -> void:
 var amount: int = mini(maxi(count,0),LIMIT)
 for i in range(amount):
  if particles.size() >= LIMIT:
   particles.pop_front()
  var angle: float = rng.randf_range(-PI,PI)
  var speed: float = rng.randf_range(60.0,240.0) if kind == "ice" else rng.randf_range(38.0,155.0)
  var lifetime: float = rng.randf_range(0.48,0.98)
  particles.append({
   "pos":at+Vector2(rng.randf_range(-8.0,8.0),rng.randf_range(-8.0,8.0)),
   "vel":Vector2.RIGHT.rotated(angle)*speed,"life":lifetime,"max_life":lifetime,
   "size":rng.randf_range(4.0,12.0) if kind == "ice" else rng.randf_range(2.0,7.0),
   "kind":kind,"screen":screen
  })
 if pulses.size() >= 20:
  pulses.pop_front()
 pulses.append({"pos":at,"age":0.0,"duration":0.55,"kind":kind,"screen":screen})

func tint(kind: String, fraction: float) -> Color:
 var t: float = clampf(fraction,0.0,1.0)
 if kind == "ice" and t <= 0.0:
  return RED
 if kind == "ice" and t >= 1.0:
  return BLUE
 match kind:
  "ice": return RED.lerp(BLUE,smoothstep(0.17,0.85,t))
  "damage": return RED.lerp(PURPLE,t)
  "upgrade": return PURPLE.lerp(BLUE,t)
  "shield": return BLUE.lerp(GOLD,t)
  "dev": return RED.lerp(GOLD,t)
  _: return GOLD.lerp(BLUE,t)

func update(delta: float) -> void:
 var step: float = clampf(delta,0.0,0.15)
 shake_time = maxf(0.0,shake_time-step)
 if shake_time > 0.0:
  shake_offset = Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*shake_strength
  shake_strength *= maxf(0.0,1.0-step*5.0)
 else:
  shake_offset = Vector2.ZERO
  shake_strength = 0.0
 flash_time = maxf(0.0,flash_time-step)
 for i in range(particles.size()-1,-1,-1):
  var p: Dictionary = particles[i]
  p["life"] = float(p["life"])-step
  if float(p["life"]) <= 0.0:
   particles.remove_at(i)
   continue
  p["pos"] = Vector2(p["pos"])+Vector2(p["vel"])*step
  p["vel"] = Vector2(p["vel"])*maxf(0.0,1.0-step*2.1)
  particles[i] = p
 for i in range(pulses.size()-1,-1,-1):
  var pulse: Dictionary = pulses[i]
  pulse["age"] = float(pulse["age"])+step
  if float(pulse["age"]) >= float(pulse["duration"]):
   pulses.remove_at(i)
  else:
   pulses[i] = pulse

func clear_screen() -> void:
 for i in range(particles.size()-1,-1,-1):
  if bool(particles[i]["screen"]):
   particles.remove_at(i)
 for i in range(pulses.size()-1,-1,-1):
  if bool(pulses[i]["screen"]):
   pulses.remove_at(i)
