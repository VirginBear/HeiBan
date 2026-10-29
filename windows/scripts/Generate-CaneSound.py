"""Create HeiBan's original short rattan/board snap. No third-party audio samples."""
from pathlib import Path
import math, random, struct, wave

rate=32000
duration=.25
rng=random.Random(20261029)
samples=[]
previous=0.0
for index in range(int(rate*duration)):
    t=index/rate
    noise=rng.uniform(-1,1)
    high=noise-previous*.85
    previous=noise
    # A brief swish precedes the sharp snap at the animation's contact frame.
    swish=high*.13*math.sin(math.pi*min(t/.075,1))**2 if t<.075 else 0
    u=max(0,t-.075)
    snap=(high*.66*math.exp(-u/0.008)+noise*.18*math.exp(-u/.04)) if t>=.075 else 0
    knock=(math.sin(2*math.pi*760*u)+.35*math.sin(2*math.pi*1570*u))*.22*math.exp(-u/.035) if t>=.075 else 0
    fade=min(1,t/.003,(duration-t)/.015)
    samples.append((swish+snap+knock)*max(0,fade))
peak=max(abs(s) for s in samples)
target=Path(__file__).resolve().parents[1]/'HeiBan.Windows/Assets/CaneSnap.wav'
with wave.open(str(target),'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(b''.join(struct.pack('<h',round(s/peak*.85*32767)) for s in samples))
print(f'{target.name}: original PCM16 mono, {rate} Hz, {duration:.2f} seconds, {target.stat().st_size} bytes')
