"""Compose original looping electronic music; NumPy + ffmpeg, no external samples."""
from pathlib import Path
import subprocess
import numpy as np
import wave
import tempfile

RATE = 32000
TRACKS = {'menu': (96, .45), 'explore': (108, .65), 'flight': (128, 1.), 'boss': (144, 1.15)}

def compose(name, bpm, drive):
    beat = 60 / bpm
    n = int(round(32 * beat * RATE))
    mix = np.zeros((n, 2), dtype=np.float64)
    rng = np.random.default_rng(8142 + list(TRACKS).index(name))
    roots = [45, 41, 48, 43]  # A minor / F / C / G, eight beats each.
    def note(midi, start, duration, gain, voice='lead', pan=0.):
        length = int(duration * RATE)
        t = np.arange(length) / RATE
        f = 440 * 2 ** ((midi - 69) / 12)
        if voice == 'pad':
            signal = np.sin(2*np.pi*f*t) + .25*np.sin(2*np.pi*f*1.003*t) + .12*np.sin(4*np.pi*f*t)
            env = np.minimum(t / .18, 1) * np.minimum((duration-t)/.3, 1)
        else:
            signal = np.sin(2*np.pi*f*t) + .22*np.sin(4*np.pi*f*t) + .08*np.sin(6*np.pi*f*t)
            env = np.minimum(t/.006, 1)*np.exp(-t/(duration*.38))
        signal = signal*env*gain
        offset = int(start * RATE)
        indexes = (np.arange(length) + offset) % n  # Tail wraps across the loop seam.
        mix[indexes, 0] += signal*np.sqrt((1-pan)*.5)
        mix[indexes, 1] += signal*np.sqrt((1+pan)*.5)
    for chord, root in enumerate(roots):
        for interval in [12, 15 if chord < 2 else 16, 19]:
            note(root+interval, chord*8*beat, 8*beat+.4, .045, 'pad', (interval-16)*.10)
    for step in range(64):
        root = roots[step//16]
        note(root, step*beat*.5, beat*.42, .085*drive, 'bass')
        pattern = [12, 19, 24, 15, 19, 27, 24, 19]
        if name != 'menu' or step%2 == 0:
            note(root+pattern[step%8], step*beat*.5, beat*.68, .036*drive, 'lead', np.sin(step*1.7)*.5)
    # A gentle four-bar melodic phrase, with eighth-note echoes.
    for index, pitch in enumerate([76, 79, 81, 79, 74, 72, 74, 71]):
        if name == 'menu' and index%2: continue
        start = index*4*beat + beat
        note(pitch, start, beat*1.6, .045)
        note(pitch, start+beat*.75, beat, .017, pan=.65)
    for b in range(32):
        length = int(.22*RATE)
        t = np.arange(length)/RATE
        kick = np.sin(2*np.pi*(48*t + 7*(1-np.exp(-t*35))))*np.exp(-t*24)*.23*drive
        indexes = (np.arange(length) + int(b*beat*RATE)) % n
        mix[indexes] += kick[:,None]*.707
        if b%4 in [1,3]:
            noise = rng.uniform(-1,1,length)
            snare = (noise*.6 + np.sin(2*np.pi*185*t)*.4)*np.exp(-t*28)*.12*drive
            mix[indexes] += snare[:,None]*.707
        for half in range(2):
            size=int(.065*RATE); t=np.arange(size)/RATE
            noise=rng.uniform(-1,1,size); noise=np.diff(noise,prepend=0)
            hat=noise*np.exp(-t*75)*.025*drive
            indexes=(np.arange(size)+int((b+half*.5)*beat*RATE))%n
            mix[indexes, half] += hat
    # Soft saturation prevents clipping. No normalisation pumps between tracks.
    mix=np.tanh(mix*1.3)*.8
    return (np.clip(mix,-1,1)*32767).astype('<i2')

if __name__ == '__main__':
    folder=Path(__file__).resolve().parents[1]/'assets'/'music'
    folder.mkdir(parents=True,exist_ok=True)
    for name, (bpm, drive) in TRACKS.items():
        pcm=compose(name,bpm,drive)
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'loop.wav'
            with wave.open(str(source),'wb') as f:
                f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-c:a','libvorbis','-q:a','4',str(folder/(name+'.ogg'))],check=True)
        print(name, 'seconds', round(len(pcm)/RATE,2), 'peak', round(float(np.abs(pcm.astype(float)).max()/32767),3))
