# Subnet Strike — v0.8.0

## Starting and saving

The title screen offers **Neues Spiel** and **Spiel laden**. Loading is disabled until a valid game exists. A new game requires a second confirmation when a save file is already present; the previous file is copied to `cyberload_save_v03.json.before_new_game.bak` before replacement. If the backup fails, the old game remains intact. Saves are written to a temporary file and renamed into place.

Existing saves load with their previous progress. Normal exploration resumes at the last saved Withnet position, or in the base for legacy saves and dungeon sessions. Shooter runs resume at a section checkpoint or the boss entrance. They do not reconstruct every in-flight projectile. Press Pause → **Speichern & Hauptmenü** to leave safely. Android app suspension pauses play and stores the current checkpoint. Audio settings are separate from game saves; changing music on the title screen never creates or overwrites a game slot.

## Entering subnets

In the base, open **UPLINK → SHOOTER SUBNETS**, or press **N** in the base/Withnet. Three marked shooter gates are also available in Withnet at `(710,550)`, `(3510,550)` and `(7280,2760)`. Existing exploration dungeons and the Darknet remain available separately.

Each new run chooses a new seed, enemy-wave spacing and gate gaps. Subnets have 18,000 / 21,000 / 24,000 world units of scrolling terrain, several section checkpoints and an end boss. Flight takes around two to three minutes before the boss, depending on subnet. Defeat supports retrying the latest checkpoint. Repeating a won run generates a fresh run. High scores, victories and run/kill counts persist. First victories give a larger reward; returning victories give a smaller reward. Rewards are applied once and the saved session is moved to the base before the result screen can be reloaded.

## Hack weapons

| Shot — E / tap to cycle | Behaviour |
| --- | --- |
| PULSE | Fast straight shots |
| SPLITTER | Three spread shots |
| ION | Slower, stronger piercing shots |

| Bomb — R / tap to select, Q / BOMB to use | Behaviour |
| --- | --- |
| LOGIC | Immediate area damage and enemy projectile clearing |
| EMP | Projectile/laser clearing and 3.5 s enemy/boss firing suppression |
| WORM | Infection damage over time and projectile clearing |

Runs start with three bombs. Every twelve kills adds a bomb, up to five. Gate walls block both friendly and hostile shots. Enemies steer toward openings. The player's collision damage has a brief invulnerability interval to avoid several hits in one frame.

## Kill-charged power-ups

Energy starts at 25, has no passive regeneration and caps at 100. Ordinary kills add 12; tanks add 22. Every eight kills repairs eight HP. Charges do not carry between runs.

| Key / touch | Cost | Effect |
| --- | ---: | --- |
| 1 SHIELD | 35 | Six seconds of protection |
| 2 OVERCLOCK | 50 | Six seconds of faster and stronger fire |
| 3 CHRONO | 65 | Four seconds of slowed enemy movement, projectiles and boss patterns |

## Boss mechanics

| Boss | Distinct mechanic | Counterplay |
| --- | --- | --- |
| AEGIS-9 | Cycles protected and vulnerable windows; aimed warning lanes become lances | Attack during an open shield window; leave the warning line; EMP opens the shield |
| MIRROR WRAITH | Creates hostile double signatures and fires aimed fan volleys; moves faster vertically | Track the bright core, destroy clones for charge and dodge aimed salvos |
| ROOT HYDRA | Three destructible weapon nodes protect the main core; paired warned laser lanes | Destroy all three nodes before attacking the core; leave the laser lanes |

All bosses intensify their attacks below 35% integrity. Lasers telegraph for just over one second before dealing damage. Entering the arena repairs up to 25 HP and creates a checkpoint; retrying that checkpoint restores the stored ship resources and restarts the boss.

## Controls

PC: WASD/arrows to steer, hold Space/F or the left mouse button in the playfield to fire, E to change shot, R to change bomb, Q to detonate, 1/2/3 for powers, Escape to pause. Android: left joystick, hold FIRE, tap BOMB, weapon/bomb selectors and the three power buttons.

F8 controls effects; F9 controls music. Both switches and music volume are also available in the title/pause UI. Original music loops for title, exploration, shooter and boss contexts crossfade without live synthesis.

## Implementation and verification

- `subnet_flight.gd`: fixed-step simulation, bounded pools, waves, gates, weapon/bomb/power logic, checkpoints and boss phases.
- `flight_view.gd`: parallax world, ship and boss drawing, HUD, touch and result layouts.
- `game_shell.gd`: title, pause, subnet selection and audio controls.
- `cyber_music.gd` and `assets/music`: two-voice playback with four pre-rendered original Ogg loops.
- `subnet_flight_smoke.gd`: all long runs reach bosses; actual shots can defeat each boss; mechanics, energy costs, bomb effects, gates, checkpoints and pool limits are exercised.
- `session_music_smoke.gd`: no gameplay/save creation in the title, old-save loading, safe new-game confirmation and backup, pause/resume, one-time rewards and actual loop resources.

The previous retained-world renderer and nine regression suites remain in place. No network connection or audio-generation dependencies are needed at runtime. Android frame rate and control feel still need testing on an actual device.

Rendered demonstration screenshots can be reproduced in a graphical session:

```bash
godot --path . --script res://tools/capture_subnet_screenshots.gd
```

The capture utility uses in-memory demonstration state and never writes a game save.
