"""Extract attacks 1, 3 and 4 from the user-supplied four-impact reference.

Attack 2 is omitted. The fourth attack keeps its full natural fragmentation
tail. No pitch/time alteration, padding, looping or synthesized replacement.
"""
import argparse
import hashlib
import json
import math
import struct
import subprocess
import wave
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, required=True)
args = parser.parse_args()
rate = 48000
raw = subprocess.check_output(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(args.input),
                               '-ac', '1', '-ar', str(rate), '-f', 's16le', 'pipe:1'])
samples = [v[0] / 32768 for v in struct.iter_unpack('<h', raw)]
root = Path(__file__).resolve().parents[1]
cuts = [(1, .390, 1.420, 'CaneImpact1.wav'), (3, 4.100, 4.950, 'CaneImpact2.wav'),
        (4, 6.510, len(samples) / rate, 'CaneRockBreak.wav')]
peak = max(abs(x) for _, start, end, _ in cuts for x in samples[round(start * rate):round(end * rate)])
gain = .78 / peak
records = []
for number, start, end, name in cuts:
    excerpt = samples[round(start * rate):round(end * rate)]
    faded = [v * gain * max(0, min(1, i / (rate * .002), (len(excerpt) - 1 - i) / (rate * .020)))
             for i, v in enumerate(excerpt)]
    target = root / 'HeiBan.Windows/Assets' / name
    with wave.open(str(target), 'wb') as wav:
        wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(struct.pack('<h', round(x * 32767)) for x in faded))
    records.append(dict(attack=number, sourceSeconds=[start, end], file=name,
                        frames=len(excerpt), sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
metadata = dict(referenceName=args.input.name, referenceSha256=hashlib.sha256(args.input.read_bytes()).hexdigest(),
                kind='User-provided sound-effect excerpts; not HeiBan-original synthesis', omittedAttack=2,
                selection='Attacks 1, 3, 4; preserve final fragmentation tail',
                creditFromFilename='freesound_community / rock-smash-6304',
                license='No license metadata supplied; no independent authorship or rights verification claimed',
                processing=dict(channels=1, sampleRate=rate, bits=16, commonGain=gain,
                                gainDb=20 * math.log10(gain), peakTarget=.78, fadeInSeconds=.002,
                                fadeOutSeconds=.020, pitchChanged=False, speedChanged=False, fullReferenceIncluded=False),
                excerpts=records)
(root / 'HeiBan.Windows/Assets/CaneRockImpacts.source.json').write_text(
    json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(metadata, ensure_ascii=False))
