extends SceneTree
## v0.6 Red Zone boundary, enemy patrol and clearance regression coverage.
const State = preload("res://scripts/game_state.gd")
const RedZone = preload("res://scripts/red_zone.gd")

func _initialize() -> void:
 call_deferred("_run")

func _fail(reason: String) -> void:
 push_error("CYBERLOAD RED ZONE TEST FAIL: "+reason)
 quit(1)

func _run() -> void:
 var z = RedZone.new()
 z.reset_guards()
 if z.guards.size() != 3 or z.active_count() != 3:
  _fail("Expected three active ICE guards")
  return
 if not z.is_crossing_border(Vector2(1391,500),Vector2(1400,500)):
  _fail("Firewall border crossing not detected")
  return
 if z.is_crossing_border(Vector2(1500,500),Vector2(1510,500)):
  _fail("Normal Red Zone travel falsely trips border")
  return
 var guard_position: Vector2 = z.guards[0]["pos"]
 if z.tick(0.016,guard_position,false) != -1:
  _fail("Guards engage without Red Zone access")
  return
 if z.tick(0.016,guard_position,true) != 0:
  _fail("Guard 0 fails to detect player and initiate combat")
  return
 if not z.defeat(0) or z.active_count() != 2:
  _fail("Defeated guard was not disabled")
  return
 if z.defeat(0):
  _fail("Defeated guard can be looted twice")
  return
 var st = State.new()
 st.credits = 1000
 st.fragments = 200
 st.clearance_level = 0
 if st.can_bypass_red_zone():
  _fail("New players should not bypass the wall")
  return
 if not st.upgrade_clearance() or st.clearance_level != 1:
  _fail("First clearance upgrade failed")
  return
 if st.can_bypass_red_zone():
  _fail("Level 1 must still require a breach")
  return
 if not st.upgrade_clearance() or not st.can_bypass_red_zone():
  _fail("Level 2 does not grant automatic entry")
  return
 if st.upgrade_clearance():
  _fail("Clearance exceeded maximum level")
  return
 st.save_game()
 var restored = State.new()
 restored.load_game()
 if restored.clearance_level != 2 or not restored.can_bypass_red_zone():
  _fail("Clearance level not persisted")
  return
 print("CYBERLOAD RED ZONE TEST PASS: border, guards, duels, clearance progression and persistence")
 quit(0)
