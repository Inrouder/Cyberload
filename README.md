# CYBERLOAD // NET//RUNNER
2D neon cyberspace prototype written in Godot 4. Explore the Withnet, find the ICE gate, solve a code-matrix breach, and enter the Darknet labyrinth.

## Mobile visual test v0.2.0
The Android build now uses landscape display (1280x720 logical coordinates, aspect expand). It includes a more legible mobile HUD, larger touch controls, animated network packets, pulsing ICE barrier and a motion trail for the player Bit. The interface is drawn directly in GDScript.

**Installation:** This CI pipeline generates a new Android debug keystore for each workflow run. If Android reports an incompatible app signature when updating, uninstall the previous test APK before installing the new one. Debug uninstall removes locally stored app data. Stable upgrade signing will be configured for production builds.

## Controls
- **WASD / arrows** move
- **E / Space** interact with an ICE gate
- Tap the screen for mobile controls and hacking
- In breach mode, select alternating row/column matrix cells to match a target sequence. Restart after an unsuccessful attempt.

## Run locally
Open `project.godot` in Godot 4.4.1, press F5.

## Android APK
Open **Actions → Android Debug APK → Run workflow**, or push to `main`. After the build finishes, download **Cyberload-debug-apk** from the run's **Artifacts** section. Extract the ZIP and install the .apk. This is a testing build signed with the Android debug key, not a Play Store release.

Source: `scripts/main.gd`, main scene: `scenes/main.tscn`.

## Planned
Rhythm combat, additional ICE, save data, local WLAN multiplayer, accessibility and music options.
