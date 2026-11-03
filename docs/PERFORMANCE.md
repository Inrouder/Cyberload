# Open-World-Performance in v0.7.1

Die aufwendige Architektur und die Minikarte wurden in v0.7.0 bei jedem Bild erneut aus GDScript-Zeichenbefehlen aufgebaut. Dazu kamen Sichtlinienprüfungen pro Bot und Physikschritt sowie gleichzeitig fällige Wegsuchen.

## Änderungen

- Statische Geometrie liegt in **512-Pixel-Abschnitten** aus beibehaltenen CanvasItem-Zeichenbefehlen. Straßen, Schatten und Gebäude haben getrennte Ebenen. Nur lokale Abschnitte sind sichtbar; beim Kameraschwenk bleiben vorhandene Zeichenbefehle erhalten. Der Cache benutzt keine riesige Welttextur und keinen GPU-Readback.
- Die statische Minikarte wird einmal als **213 × 105 Pixel** große Textur angelegt. Positionsmarker und Zugangsstatus bleiben dynamisch.
- Portale, Wachen, Erz, Minen und Mesh-Gegner werden anhand des sichtbaren Kameraausschnitts ausgewählt. Versteckte Bot-Körper werden weiterhin erst in der Nähe gezeigt. Animierte Portale, Wasser, Runner, Bots und Hacks bleiben aktiv.
- Bei aktiven Bots laufen Sichtprüfungen zeitversetzt etwa alle 120 ms; schlafende Hinterhalt-Bots brauchen dafür keine Sichtstrahlen. **Jeder Schuss prüft die aktuelle Sichtlinie zusätzlich sofort.**
- Höchstens **eine neue Wegsuche pro Physikschritt** verhindert gleichzeitige Lastspitzen. Wartende Bots behalten ihren bestehenden Weg; versetzte Wiederholungsintervalle verhindern, dass ein Bot alle Anfragen belegt.
- Mesh-Verbindungen werden bei Änderungen am Körper vorbereitet. Pro Bild wird jede Bauteilposition nur einmal animiert; wiederholte Nachbarsuchen über alle Bauteile entfallen.

## Vergleichsmessung

Godot **4.4.1**, Linux, Headless-Modus, dieselbe Szene und Instrumentierung vor und nach der Änderung. 600 Bilder, drei Aufenthaltsorte: Neon Bazaar, ein Flüssigdatengebiet in der Frontier und Cipher Citadel. 56 Mesh-Gegner bleiben vorhanden; die Bot-Simulation erhält jeweils 1/60 s. Automatische ICE-Duelle sind für die Messung deaktiviert.

| CPU-Arbeit | v0.7.0 Mittel | v0.7.1 Mittel | v0.7.0 P95 | v0.7.1 P95 |
| --- | ---: | ---: | ---: | ---: |
| Hauptknoten: Zeichenbefehle aufbauen | 3,943 ms | 1,257 ms | 6,671 ms | 1,859 ms |
| Mesh-KI und Geschosse | 0,179 ms | 0,109 ms | 0,306 ms | 0,222 ms |

Die Zeit für die laufenden Zeichenbefehle im Hauptknoten fällt damit um rund **68 %**, die für KI und Geschosse um rund **39 %**. Die Messung enthält keine GPU-Rasterzeit. Der einmalige Aufbau neu sichtbarer Cache-Abschnitte liegt außerhalb der gemessenen `_draw()`-Funktion des Hauptknotens. Es handelt sich deshalb weder um eine vollständige Framezeit noch um eine Zusage für eine bestimmte Android-Bildrate. Ein echter Gerätetest bleibt erforderlich.

Den aktuellen Stand messen:

```bash
godot --headless --path . --script res://tools/benchmark_open_world.gd
```

Das JSON-Ergebnis enthält Anzahl, Mittelwert, P95 und Maximum in Mikrosekunden. Die Funktionstests prüfen bewusst strukturelle Grenzen statt schwankender Laufzeit-Schwellen:

```bash
godot --headless --path . --script res://tests/performance_smoke.gd
```

Geprüft werden unveränderte statische Zeichenbefehle über mehrere Bilder, vollständige Gebäudezuordnung, feste Radartextur, Kamera- und Weltwechsel, begrenzte und faire Wegsuche, sofortige Deckungsprüfung beim Schießen und korrektes Aktualisieren von Mesh-Verbindungen nach Änderungen im Editor.
