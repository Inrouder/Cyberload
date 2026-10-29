# CYBERLOAD // NET.RUNNER

**v0.4.0 — Homebase & Network Districts Update**

A mobile-first, offline, code-drawn 2D cyberpunk exploration prototype made with **Godot 4.4.1 / GDScript**.

![Cyberload icon](assets/icon.svg)

## What's new in v0.4

- Every app launch **starts in the private Homebase**, including returning players; existing v0.3 save files and earned resources remain compatible.
- Homebase is a safe, freely navigable room with a central system kernel and five interactive terminals: **UPLINK**, **CORE**, **WORKSHOP**, **ARCHIVE**, **OPS**.
- **UPLINK** takes you into the public Withnet. Interact with the **HOMEBASE** portal on the west end of the Withnet highway to return at any time.
- Withnet is divided into **Sector A / Public Data**, **Sector B / Services**, and **Sector C / Red Zone**. Its main east-west data highway, branch lanes, district boundaries, labels and animated traffic replace the old crisscross connections.
- The upper-right **network overview mini-map** shows your bit, node locations, the Homebase connection, and the ICE gate.
- The **RELAY** node now has a return-to-Homebase action instead of merely changing your Withnet position.
- Headless world integration checks verify startup location and Base → Withnet → Base transitions in GitHub Actions.

### Suggested first mission

1. Fly from your spawning circle in Homebase to **UPLINK // 00**, tap **HACK** and select **ENTER WITHNET**.
2. Travel east along the cyan **data highway** into **Sector A**, and harvest **NODE // 00** data.
3. Go to **NODE // 01** (Scanner) in Sector A and reveal the secret vault.
4. Continue along the highway to the red ICE gate in **Sector C**, breach it, gather all three Darknet packets, and escape.
5. Return to Homebase with the western portal or the Service-sector Relay console.

## Gameplay loop
1. Explore the open **Withnet** as a glowing data bit.
2. Approach a colored Node and tap **HACK** to open its terminal.
3. Extract data, scan for hidden nodes, buy upgrades, heal, or accept a risk.
4. Breach the red ICE gateway with a timed alternating row/column code matrix.
5. Enter a dangerous **Darknet maze**: collect three packets, dodge the moving ICE sentinel, and escape through the exit.
6. Spend credits/fragments, increase buffer and speed, and complete the five-stage contract.

## Functional nodes

| ID | Type | Operations |
|---|---|---|
| 00 | DATA | Extract one-time credits and fragments |
| 01 | SCAN | Reveal hidden GHOST node; lower trace |
| 02 | UPGRADE | Buy speed or buffer upgrades |
| 03 | MARKET | Buy trace scrub or restore HP |
| 04 | MISSION | View current story contract |
| 05 | RELAY | Repair and fast-travel back to uplink |
| 06 | ANOMALY | Trade risk/trace for valuable rare cache |
| 07 | SECRET VAULT | Scanned hidden bonus cache |

Free roaming data pickups, a moving ICE sentinel, a 3-packet Darknet extraction condition, buffer upgrades, an integrity meter and trace risk all work without any internet connection.

## Input

**Android:** drag the left joystick and tap **HACK** near a base terminal, public node or ICE gate. In a terminal, tap option 1 or 2. Tap the title to see the operator log. In the code matrix, tap cells in alternating same-column / same-row order.

**Desktop:** WASD / arrow keys move, E / Space interact, 1 or 2 choose node operations, M / Tab open operator log, Escape close.

## Save system

Game data is stored locally in `user://cyberload_save_v03.json` by `scripts/game_state.gd`. It includes wallet, upgrades, mission stage, cleared caches and discovered secrets. No login, telemetry or network permissions are used. Changes to save schema should be versioned carefully. Uninstalling the debug APK deletes this data.

## Graphic design

All gameplay graphics are generated in `scripts/main.gd` using Godot 2D drawing commands. The actual app icon is `assets/icon.svg`: a cyan data core breaching a pink ICE firewall ring. Before Android export, `tools/make_icons.py` converts that SVG to a classic 192px PNG and 432px adaptive foreground/background layers.

To generate Android PNGs locally (optional):
```bash
python -m pip install cairosvg
python tools/make_icons.py
```

## Build and test

- Install **Godot 4.4.1**, open `project.godot`, run F5.
- GitHub Actions workflow `.github/workflows/android-apk.yml` runs project import and smoke tests and exports an arm64 debug APK.
- Open **Actions → Android Debug APK → latest successful run → Artifacts → Cyberload-debug-apk**.
- Unzip the artifact and install the APK on your Android phone.

**Signing caveat:** the workflow currently creates a new temporary debug keystore on each run. This prevents seamless upgrades between debug APKs. A persistent signing key stored as GitHub Actions secrets is required before user data and update continuity matter.

## Source structure

| File | Responsibility |
|---|---|
| `project.godot` | Engine, render, landscape, icon and input settings |
| `scenes/main.tscn` | Scene entry point |
| `scripts/main.gd` | Open map, maze, input, effects, breach, nodes, game UI |
| `scripts/game_state.gd` | Economy, upgrades, contract progression, local save |
| `assets/icon.svg` | Editable vector brand icon |
| `tools/make_icons.py` | Generates PNG launcher icons for Android |
| `export_presets.cfg` | Android ID, version and icon resource paths |

## Planned milestones

- v0.4: procedural network maps, inventory/deck building, varied ICE guards and richer missions.
- v0.5: rhythm combat (attack / defend), simulated netrunner bot.
- v0.6+: WLAN room discovery and synchronized turn-based netrunner battles, then Bluetooth evaluation.

This repository is a **playable prototype**, not a production release. See the GitHub Actions log if an export fails.
