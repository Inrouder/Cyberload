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
 "OVERDRIVE": {"credits":130, "fragments":16},
 "CHRONO_HACK": {"credits":120, "fragments":12}
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
# v0.6 clearance is permanent. 0: hack every visit, 1: boosted breach,
# 2: bypass outer red-zone barrier. Existing saves default to 0.
var clearance_level: int = 0
var red_zone_hacks: int = 0
var defeated_guards_total: int = 0
# Permanent craftable slow-motion battle hack; independent of equipped program.
var chrono_unlocked: bool = false
# v0.7 open-world extraction and dungeon progression.
var mesh_level: int = 1
var mesh_xp: int = 0
var mesh_mode: String = "CRAWL"
var mesh_cells: Array = [{"x":0,"y":0,"type":"CORE"},{"x":-1,"y":0,"type":"LEG"},{"x":1,"y":0,"type":"LEG"}]
var mesh_kills: int = 0
var mesh_looted: Dictionary = {}
var drill_level: int = 0
var ore_inventory: Dictionary = {}
var mined_veins: Dictionary = {}
var dungeon_clears: Dictionary = {}
var dungeon_caches: Dictionary = {}
const ORE_SELL_VALUES = {"COPPER":8,"COBALT":14,"QUANTUM":24,"PHANTOM":38,"PLASMA":55,"VOID":85}


func award_mesh_xp(value: int) -> bool:
 mesh_xp += maxi(0,value)
 var levelled: bool = false
 while mesh_xp >= mesh_level*90 and mesh_level<30:
  mesh_xp-=mesh_level*90
  mesh_level+=1
  levelled = true
 save_game()
 return levelled

func upgrade_drill() -> bool:
 if drill_level >= 5:
  return false
 if not buy(70+drill_level*90,6+drill_level*6):
  return false
 drill_level += 1
 save_game()
 return true

func mine_vein(vein: Dictionary, now: int) -> bool:
 var id: String = str(vein["id"])
 if int(vein["tier"]) > drill_level or now < int(mined_veins.get(id,0)):
  return false
 var kind: String = str(vein["type"])
 var amount: int = int(vein["amount"])+int(drill_level/2)
 ore_inventory[kind] = maxi(0,int(ore_inventory.get(kind,0)))+amount
 fragments += 1+int(int(vein["tier"])/2)
 mined_veins[id] = now+180+int(vein["tier"])*45
 save_game()
 return true

func sell_ore() -> int:
 var earned: int = 0
 for kind in ORE_SELL_VALUES.keys():
  earned += maxi(0,int(ore_inventory.get(kind,0)))*int(ORE_SELL_VALUES[kind])
 if earned <= 0:
  return 0
 credits += earned
 ore_inventory.clear()
 save_game()
 return earned

func ore_total() -> int:
 var total: int = 0
 for amount in ore_inventory.values():
  total += maxi(0,int(amount))
 return total

func clearance_price() -> Dictionary:
 if clearance_level == 0:
  return {"credits":90,"fragments":8}
 if clearance_level == 1:
  return {"credits":170,"fragments":18}
 return {"credits":0,"fragments":0}

func upgrade_clearance() -> bool:
 if clearance_level >= 2:
  return false
 var price = clearance_price()
 if not buy(int(price["credits"]),int(price["fragments"])):
  return false
 clearance_level += 1
 save_game()
 return true

func can_bypass_red_zone() -> bool:
 return clearance_level >= 2

func craft_program(program: String) -> bool:
 if not RECIPES.has(program) or owned_programs.has(program):
  return false
 var cost: Dictionary = RECIPES[program]
 if not buy(int(cost["credits"]), int(cost["fragments"])):
  return false
 owned_programs.append(program)
 save_game()
 return true

func craft_chrono_hack() -> bool:
 if chrono_unlocked:
  return false
 var cost: Dictionary = RECIPES["CHRONO_HACK"]
 if not buy(int(cost["credits"]),int(cost["fragments"])):
  return false
 chrono_unlocked = true
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
  "version": 8,
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
  "ice_losses": ice_losses,
  "clearance_level": clearance_level,
  "red_zone_hacks": red_zone_hacks,
  "defeated_guards_total": defeated_guards_total,
  "chrono_unlocked": chrono_unlocked,
  "mesh_level": mesh_level,"mesh_xp": mesh_xp,
  "mesh_mode": mesh_mode,"mesh_cells": mesh_cells,
  "mesh_kills": mesh_kills,"mesh_looted": mesh_looted,
  "drill_level": drill_level,
  "ore_inventory": ore_inventory,
  "mined_veins": mined_veins,
  "dungeon_clears": dungeon_clears,
  "dungeon_caches": dungeon_caches
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
 clearance_level = clampi(int(value.get("clearance_level",0)),0,2)
 red_zone_hacks = maxi(0,int(value.get("red_zone_hacks",0)))
 defeated_guards_total = maxi(0,int(value.get("defeated_guards_total",0)))
 chrono_unlocked = bool(value.get("chrono_unlocked",false))
 mesh_level = clampi(int(value.get("mesh_level",1)),1,30)
 mesh_xp = maxi(0,int(value.get("mesh_xp",0)))
 mesh_mode = str(value.get("mesh_mode","CRAWL"))
 mesh_cells = value.get("mesh_cells",mesh_cells) if typeof(value.get("mesh_cells",mesh_cells))==TYPE_ARRAY else mesh_cells
 mesh_kills = maxi(0,int(value.get("mesh_kills",0)))
 mesh_looted = value.get("mesh_looted",{}) if typeof(value.get("mesh_looted",{}))==TYPE_DICTIONARY else {}
 drill_level = clampi(int(value.get("drill_level",0)),0,5)
 ore_inventory = value.get("ore_inventory",{}) if typeof(value.get("ore_inventory",{})) == TYPE_DICTIONARY else {}
 mined_veins = value.get("mined_veins",{}) if typeof(value.get("mined_veins",{})) == TYPE_DICTIONARY else {}
 dungeon_clears = value.get("dungeon_clears",{}) if typeof(value.get("dungeon_clears",{})) == TYPE_DICTIONARY else {}
 dungeon_caches = value.get("dungeon_caches",{}) if typeof(value.get("dungeon_caches",{})) == TYPE_DICTIONARY else {}
