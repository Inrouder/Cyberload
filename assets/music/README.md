# Original Cyberload music

Four original electronic loops composed procedurally for this project with `tools/compose_music.py`. No third-party samples, recordings or melodies were imported. Runtime files are stereo Ogg Vorbis at 32 kHz.

| Track | Tempo | Length | Use |
| --- | ---: | ---: | --- |
| menu.ogg | 96 BPM | 20 s | Title screen |
| explore.ogg | 108 BPM | 17.78 s | Base and exploration |
| flight.ogg | 128 BPM | 15 s | Shooter subnet cruise |
| boss.ogg | 144 BPM | 13.33 s | Bosses and ICE duels |

Each loop contains a chord progression, bass pattern, arpeggio, melodic phrase, kick, snare and hi-hats. Tails wrap into the start of the loop. Two playback voices crossfade between contexts; decoding is handled by Godot, with no runtime music synthesis. Music and sound effects have independent switches. Music volume is adjustable in the title/pause screen.

Regenerate with Python 3, NumPy and ffmpeg (`libvorbis`):

```bash
python tools/compose_music.py
```

The composer dependencies are needed only to regenerate assets. Players and the APK build do not need Python, NumPy or ffmpeg.
