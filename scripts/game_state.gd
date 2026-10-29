extends RefCounted
## Local, offline-first progression. Never stores real device/network data.
const SAVE_PATH = "user://cyberload_save_v03.json"

var credits: int = 90
var fragments: int = 0
var trace: float = 0.0
var integrity: float = 100.0
var speed_level: int = 0
var buffer_level: int = 0
var scan_level: int = 0
var mission_stage: int = 0
var darknet_runs: int = 0
var breaches: int = 0
var collected_orbs: Dictionary = {}
var node_claims: Dictionary = {}
var hidden_revealed: bool = false
var contract_bonus_claimed: bool = false
# v0.5: structures and crafted hacks are stored in the same legacy save file.
# The player starts with BASIC_SPIKE; older v0.3/v0.4 saves load safely.
const PROGRAMS = ["BASIC_SPIKE", "LOGIC_BOMB", "MIRROR_SHIELD", "OVERDRIVE"]
const RECIPES = {
 "LOGIC_BOMB": {"credits":70, "fragments":8},
 "MIRROR_SHIELD": {"credits":95, "fragments":12},
 "OVERDRIVE": {"credits":130, "fragments":16}
}
const MODULE_PRICES = {
 "FIREWALL": {"credits":75, "fragments":6},
 "AMPLIFIER": {"credits":100, "fragments":10},
 "SYNC": {"credits":105, "fragments":9}
}
var owned_programs: Array = ["BASIC_SPIKE"]
var active_program: String = "BASIC_SPIKE"
var installed_modules: Dictionary = {}
var ice_wins: int = 0
var ice_losses: int = 0

func craft_program(program: String) -> bool:
 if not RECIPES.has(program) or owned_programs.has(program):
  return false
 var cost: Dictionary = RECIPES[program]
 if not buy(int(cost["credits"]), int(cost["fragments"])):
  return false
 owned_programs.append(program)
 save_game()
 return true

func equip_program(program: String) -> bool:
 if not owned_programs.has(program):
  return false
 active_program = program
 save_game()
 return true

func install_module(module: String) -> bool:
 if installed_modules.get(module, false) or not MODULE_PRICES.has(module):
  return false
 var cost: Dictionary = MODULE_PRICES[module]
 if not buy(int(cost["credits"]), int(cost["fragments"])):
  return false
 installed_modules[module] = true
 save_game()
 return true

func has_module(module: String) -> bool:
 return bool(installed_modules.get(module,false))


func mission_text() -> String:
 match mission_stage:
  0: return "01 / Harvest data at NODE 00"
  1: return "02 / Activate NODE 01 scan"
  2: return "03 / Breach the red ICE gate"
  3: return "04 / Collect 3 darknet packets"
  4: return "05 / Escape through the darknet exit"
  _: return "CONTRACT COMPLETE  //  explore & upgrade"

func on_event(event_name: String) -> String:
 var expected = ["data", "scan", "breach", "darkloot", "escape"]
 if mission_stage < expected.size() and expected[mission_stage] == event_name:
  mission_stage += 1
  credits += 45
  fragments += 2
  if mission_stage == 5:
   credits += 180
   fragments += 12
   save_game()
   return "CONTRACT COMPLETE  +225 CREDITS  +14 DATA"
  save_game()
  return "MISSION UPDATED  +45 CREDITS  +2 DATA"
 return ""

func buy(cost_credits: int, cost_fragments: int) -> bool:
 if credits < cost_credits or fragments < cost_fragments:
  return false
 credits -= cost_credits
 fragments -= cost_fragments
 save_game()
 return true

func save_game() -> void:
 var payload = {
  "version": 5,
  "credits": credits, "fragments": fragments,
  "trace": trace, "integrity": integrity,
  "speed_level": speed_level, "buffer_level": buffer_level,
  "scan_level": scan_level, "mission_stage": mission_stage,
  "darknet_runs": darknet_runs, "breaches": breaches,
  "collected_orbs": collected_orbs, "node_claims": node_claims,
  "hidden_revealed": hidden_revealed,
  "contract_bonus_claimed": contract_bonus_claimed,
  "owned_programs": owned_programs,
  "active_program": active_program,
  "installed_modules": installed_modules,
  "ice_wins": ice_wins,
  "ice_losses": ice_losses
 }
 var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify(payload, "\t"))

func load_game() -> void:
 if not FileAccess.file_exists(SAVE_PATH):
  return
 var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
 if file == null:
  return
 var value = JSON.parse_string(file.get_as_text())
 if typeof(value) != TYPE_DICTIONARY:
  return
 credits = maxi(0, int(value.get("credits", credits)))
 fragments = maxi(0, int(value.get("fragments", fragments)))
 trace = clampf(float(value.get("trace", trace)), 0.0, 100.0)
 integrity = clampf(float(value.get("integrity", integrity)), 1.0, 100.0)
 speed_level = clampi(int(value.get("speed_level", 0)), 0, 5)
 buffer_level = clampi(int(value.get("buffer_level", 0)), 0, 2)
 scan_level = clampi(int(value.get("scan_level", 0)), 0, 5)
 mission_stage = clampi(int(value.get("mission_stage", 0)), 0, 5)
 darknet_runs = maxi(0, int(value.get("darknet_runs", 0)))
 breaches = maxi(0, int(value.get("breaches", 0)))
 collected_orbs = value.get("collected_orbs", {})
 node_claims = value.get("node_claims", {})
 hidden_revealed = bool(value.get("hidden_revealed", false))
 contract_bonus_claimed = bool(value.get("contract_bonus_claimed", false))
 var stored_programs = value.get("owned_programs", ["BASIC_SPIKE"])
 owned_programs = ["BASIC_SPIKE"]
 if typeof(stored_programs) == TYPE_ARRAY:
  for program in stored_programs:
   if PROGRAMS.has(str(program)) and not owned_programs.has(str(program)):
    owned_programs.append(str(program))
 active_program = str(value.get("active_program", "BASIC_SPIKE"))
 if not owned_programs.has(active_program):
  active_program = "BASIC_SPIKE"
 var stored_modules = value.get("installed_modules", {})
 installed_modules = {}
 if typeof(stored_modules) == TYPE_DICTIONARY:
  for module in MODULE_PRICES.keys():
   if bool(stored_modules.get(module, false)):
    installed_modules[module] = true
 ice_wins = maxi(0,int(value.get("ice_wins",0)))
 ice_losses = maxi(0,int(value.get("ice_losses",0)))
