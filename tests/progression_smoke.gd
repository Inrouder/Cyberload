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
 if st.equip_program("OVERDRIVE"):
  _fail("Locked program was equipped")
  return
 st.save_game()
 var restored = State.new()
 restored.load_game()
 if restored.active_program != "LOGIC_BOMB" or not restored.has_module("FIREWALL"):
  _fail("Save file did not persist programs and base modules")
  return
 var duel = Combat.new()
 duel.begin("LOGIC_BOMB",{"FIREWALL":true},100.0,1)
 if duel.result != "RUNNING" or duel.phase != "ATTACK" or duel.sequence.size() != 4:
  _fail("Combat did not initialize attack phase")
  return
 for i in range(4):
  duel.beat_clock = 0.34
  if not duel.press(duel.current_key()):
   _fail("Correct rhythm input was not accepted")
   return
 if duel.ice_hp >= duel.ice_max or duel.phase != "DEFEND":
  _fail("Attack did not damage ICE or switch to defense")
  return
 var hp_before = duel.player_hp
 for i in range(4):
  duel.beat_clock = 0.34
  duel.press(duel.current_key())
 if duel.phase != "ATTACK" or duel.player_hp > hp_before:
  _fail("Defense did not return to player turn")
  return
 print("CYBERLOAD PROGRESSION TEST PASS: craft, equip, base upgrades, save/load, attack, defense")
 quit(0)
