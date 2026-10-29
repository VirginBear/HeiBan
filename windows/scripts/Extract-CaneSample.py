"""Rebuild the one-shot cane cue from the user-supplied reference; no full MP3 is shipped."""
from pathlib import Path
import argparse, hashlib, json, math, struct, subprocess, wave

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input',type=Path,required=True)
args=parser.parse_args()
start=31.990
duration=.260
rate=48000
# Decode before seeking: MP3 delay is resolved by ffmpeg and the window is
# measured on the decoded timeline, rather than an approximate packet seek.
raw=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(args.input),
    '-ss',f'{start:.3f}','-t',f'{duration:.3f}','-ac','1','-ar',str(rate),
    '-f','s16le','-c:a','pcm_s16le','pipe:1'],capture_output=True,check=True).stdout
samples=[v[0]/32768 for v in struct.iter_unpack('<h',raw)]
assert len(samples)==round(duration*rate),'Unexpected decoded window length'
peak=max(abs(v) for v in samples)
gain=.82/peak
for i,value in enumerate(samples):
    # Fades touch only the quiet cut edges, not the attack or natural decay.
    fade=min(1,i/(rate*.002),(len(samples)-1-i)/(rate*.010))
    samples[i]=value*gain*max(0,fade)
root=Path(__file__).resolve().parents[1]
target=root/'HeiBan.Windows/Assets/CaneSnap.wav'
with wave.open(str(target),'wb') as output:
    output.setnchannels(1);output.setsampwidth(2);output.setframerate(rate)
    output.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in samples))
metadata={'kind':'User-provided reference excerpt; not HeiBan-original synthesis',
    'referenceName':args.input.name,'referenceSha256':hashlib.sha256(args.input.read_bytes()).hexdigest(),
    'requestedWindowSeconds':[30,33],'selectedSourceSeconds':[start,start+duration],
    'purpose':'One isolated cane swing, replacing the previously synthesized cue',
    'creditFromFilename':'77音效','license':'No license information in supplied MP3 metadata; no claim of original authorship or independent rights verification',
    'processing':{'channels':1,'sampleRate':rate,'bitsPerSample':16,'durationSeconds':duration,
    'linearGain':gain,'gainDb':20*math.log10(gain),'peakTarget':.82,'fadeInSeconds':.002,'fadeOutSeconds':.010,
    'pitchChanged':False,'speedChanged':False,'fullReferenceIncluded':False},
    'outputSha256':hashlib.sha256(target.read_bytes()).hexdigest()}
(root/'HeiBan.Windows/Assets/CaneSnap.source.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'selectedSourceSeconds':metadata['selectedSourceSeconds'],'durationSeconds':duration,
    'gainDb':metadata['processing']['gainDb'],'bytes':target.stat().st_size,'sha256':metadata['outputSha256']},ensure_ascii=False))
