"""Original deterministic glass-like impact cue, no recordings or external assets.

PCM16 mono, 44.1 kHz, 0.72 sec. A short noise attack plus decaying inharmonic
partials and three delayed shard bursts; peak normalized to -5 dBFS.
"""
import math
import random
import struct
import wave
from pathlib import Path

rate = 44100
rng = random.Random(20261105)
samples = []
partials = [(f, rng.random() * math.tau) for f in (1181, 1739, 2521, 3491, 4817, 6373)]
for i in range(int(rate * .72)):
    t = i / rate
    attack = min(1, t / .0015)
    noise = rng.uniform(-1, 1)
    value = .7 * noise * math.exp(-t * 70)
    value += sum(.065 * math.sin(math.tau * f * t + p) * math.exp(-t * (10 + f / 1000)) for f, p in partials)
    for start in (.047, .101, .178):
        if t >= start:
            value += .13 * noise * math.exp(-(t - start) * 38)
    samples.append(value * attack * min(1, (.72 - t) / .02))
peak = max(map(abs, samples))
output = Path(__file__).resolve().parents[1] / 'HeiBan.Windows/Assets/CaneCrack.wav'
with wave.open(str(output), 'wb') as wav:
    wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    wav.writeframes(b''.join(struct.pack('<h', round(s / peak * 18426)) for s in samples))
print(f'{output}: {len(samples)} frames, original synthesized cue')
