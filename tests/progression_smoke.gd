extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/rhythm_combat.gd")

func _initialize() -> void:
 call_deferred("_run_tests")

func _fail(reason: String) -> void:
 push_error("CYBERLOAD PROGRESSION TEST FAIL: "+reason)
 quit(1)

func _run_tests() -> void:
 var st = State.new()
 st.credits = 1000
 st.fragments = 200
 if not st.craft_program("LOGIC_BOMB"):
  _fail("Cannot craft Logic Bomb with sufficient resources")
  return
 if st.craft_program("LOGIC_BOMB"):
  _fail("Duplicate crafting was allowed")
  return
 if not st.equip_program("LOGIC_BOMB"):
  _fail("Cannot equip owned program")
  return
 if not st.install_module("FIREWALL"):
  _fail("Cannot install a base module")
  return
 if st.install_module("FIREWALL"):
  _fail("Duplicate module purchase was allowed")
  return
 if not st.craft_chrono_hack() or not st.chrono_unlocked:
  _fail("Chrono hack failed to craft")
  return
 if st.craft_chrono_hack():
  _fail("Chrono hack purchased twice")
  return
 if st.equip_program("OVERDRIVE"):
  _fail("Locked program was equipped")
  return
 st.save_game()
 var restored = State.new()
 restored.load_game()
 if restored.active_program != "LOGIC_BOMB" or not restored.has_module("FIREWALL") or not restored.chrono_unlocked:
  _fail("Save file did not persist programs and base modules")
  return
 var novice = Combat.new()
 novice.begin("BASIC_SPIKE",{},100.0,1)
 var elite = Combat.new()
 elite.begin("BASIC_SPIKE",{},100.0,5)
 if novice.beat_duration() <= elite.beat_duration() or novice.hit_window() <= elite.hit_window():
  _fail("Elite ICE is not faster and more precise")
  return
 if novice.activate_slowmo():
  _fail("Chrono hack used without crafting")
  return
 var duel = Combat.new()
 duel.begin("LOGIC_BOMB",{"FIREWALL":true},100.0,1,true)
 if duel.result != "RUNNING" or duel.phase != "ATTACK" or duel.sequence.size() != 4:
  _fail("Moving arrow attack did not initialize")
  return
 if duel.press(duel.current_key()) or duel.index != 0:
  _fail("Early input incorrectly consumed a note")
  return
 if not duel.activate_slowmo() or duel.slowmo_charges != 1:
  _fail("Chrono hack charge did not activate")
  return
 duel.tick(1.0)
 if absf(duel.phase_clock-Combat.SLOWMO_SPEED) > 0.001 or duel.activate_slowmo():
  _fail("Slow-motion timing or overlap prevention failed")
  return
 duel.slowmo_remaining = 0.0
 for i in range(4):
  duel.tick(maxf(0.0,duel.time_until_hit(i)))
  if not duel.press(duel.current_key()):
   _fail("Correct attack arrow was not registered in target")
   return
 if duel.ice_hp >= duel.ice_max or duel.phase != "DEFEND":
  _fail("Attack did not damage ICE and change direction")
  return
 var hp_before: float = duel.player_hp
 for i in range(4):
  duel.tick(maxf(0.0,duel.time_until_hit(i)))
  if not duel.press(duel.current_key()):
   _fail("Correct defense arrow was rejected")
   return
 if duel.phase != "ATTACK" or duel.player_hp > hp_before:
  _fail("Defense did not return to attack")
  return
 if not duel.activate_slowmo() or duel.slowmo_charges != 0 or duel.activate_slowmo():
  _fail("Second Chrono charge or charge limit failed")
  return
 var missed = Combat.new()
 missed.begin("BASIC_SPIKE",{},100.0,3)
 missed.tick(missed.note_time(3)+missed.hit_window()+0.3)
 if missed.phase != "DEFEND" or missed.ice_hp != missed.ice_max:
  _fail("Expired moving arrows were not counted as misses")
  return

 print("CYBERLOAD PROGRESSION TEST PASS: craft, save, arrows, slowmo, misses, attack and defense")
 quit(0)
