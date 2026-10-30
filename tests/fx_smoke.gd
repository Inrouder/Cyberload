extends SceneTree
const Effects = preload("res://scripts/fx_system.gd")
const Combat = preload("res://scripts/rhythm_combat.gd")

func _initialize() -> void:
 call_deferred("_run")

func _fail(message: String) -> void:
 push_error("CYBERLOAD VISUAL FX FAIL: "+message)
 quit(1)

func _run() -> void:
 var fx = Effects.new()
 fx.burst(Vector2(220,150),"ice",true,36)
 if fx.particles.size() != 36 or fx.pulses.size() != 1:
  _fail("ICE cube debris and shock ring not created")
  return
 if fx.tint("ice",0.0) != Effects.RED or fx.tint("ice",1.0) != Effects.BLUE:
  _fail("ICE must dissolve from red to blue")
  return
 fx.impact(12.0,0.25)
 fx.flash(Effects.RED)
 fx.update(0.02)
 if fx.shake_time <= 0.0 or fx.flash_time <= 0.0:
  _fail("Screen shake or flash did not activate")
  return
 fx.update(0.15)
 fx.update(0.15)
 if fx.shake_offset != Vector2.ZERO:
  _fail("Shake did not expire")
  return
 fx.burst(Vector2.ZERO,"data",false,1000)
 if fx.particles.size() > Effects.LIMIT:
  _fail("Particle limit exceeded")
  return
 fx.clear_screen()
 for p in fx.particles:
  if bool(p["screen"]):
   _fail("Duel debris leaked into world")
   return
 var fighter = Combat.new()
 fighter.begin("BASIC_SPIKE",{},100.0,5)
 fighter.dev_overkill = true
 fighter.tick(fighter.time_until_hit(0))
 if not fighter.press(fighter.current_key()) or fighter.result != "WIN":
  _fail("Overkill must defeat elite ICE with one accurate arrow")
  return
 print("CYBERLOAD VISUAL FX PASS: cubes, dissolve, shake, limits and developer damage")
 quit(0)
