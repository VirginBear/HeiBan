#!/usr/bin/env python3
"""Build Mac-owned, editable, infinite guide works from committed localized content.

No Windows files, user library, network, clock or machine-specific paths are read.
Outputs are deterministic supplied assets; installed user exercises are never updated here.
"""
from pathlib import Path
import json, math, hashlib

root = Path(__file__).resolve().parents[1]
source = root / 'Documentation/QuickStart'
target = root / 'Sources/HeiBanMac/Resources/Guides'
target.mkdir(parents=True, exist_ok=True)
board_id = 'heiban-macos-quickstart-v3'
stamp = '2026-10-23T00:00:00Z'
manifest = {'schema': 3, 'boardID': board_id, 'editions': []}
expected = {'zh-TW','zh-CN','en','ja','ko','es','fr','de','pt-BR','ar'}
if {p.stem for p in source.glob('*.json')} != expected:
    raise ValueError('Mac QuickStart needs exactly the ten committed language sources')
for path in sorted(source.glob('*.json')):
    content = json.loads(path.read_text(encoding='utf-8'))
    if len(content['chapters']) != 25:
        raise ValueError(f'{path.name}: expected 25 chapters')
    objects, pins = [], []
    def object_(kind, x, y, width, height, **fields):
        item = dict(id=f'mac-guide-{path.stem}-{len(objects)+1}', boardId=board_id,
                    type=kind, x=x, y=y, width=width, height=height, rotation=0,
                    strokeColor='#24533d', strokeWidth=3, fillColor='none', opacity=1,
                    zIndex=len(objects)+1, createdAt=stamp, updatedAt=stamp, isLocked=False)
        item.update(fields)
        objects.append(item)
    def text(body, x, y, width, height, size=20):
        object_('text', x, y, width, height, text=body, fontSize=size, fontFamily='PingFang TC', align='left')
    text(content['title'], 100, 80, 1280, 100, 46)
    text(content['intro'], 100, 210, 1280, 200, 20)
    text('\n'.join(f'{i:02} · {chapter["title"]}' for i, chapter in enumerate(content['chapters'], 1)),
         100, 430, 1200, 730, 20)
    for index, chapter in enumerate(content['chapters']):
        y = 1350 + index * 1100
        text(f'{index+1:02} · {chapter["title"]}', 100, y, 1200, 100, 34)
        text(chapter['body'], 100, y+120, 1120, 800, 20)
        pins.append(dict(id=f'mac-guide-chapter-{index+1}', boardId=board_id,
                         name=f'{index+1:02} · {chapter["title"]}', x=820, y=y+420,
                         zoom=0.75, isWorldSpace=True, color='#5d9477', textColor='#24533d', createdAt=stamp))
        # Editable demonstrations are supplied geometry, not flattened screenshots.
        kind = ['rect', 'circle', 'triangle', 'diamond', 'polygon'][index % 5]
        extra = {'polygonSides': 5} if kind == 'polygon' else {}
        if kind == 'triangle':
            extra['points'] = json.dumps([{'x':1420,'y':y+140}, {'x':1560,'y':y+340}, {'x':1280,'y':y+340}])
        object_(kind, 1280, y+140, 280, 200, fillColor='#dcf1df', **extra)
        points = [dict(x=1280+step*6, y=y+440+math.sin(step/6)*28, pressure=0.7) for step in range(49)]
        object_('stroke', 1280, y+412, 288, 56, strokeWidth=5,
                points=json.dumps(points, separators=(',', ':')), brushKind='pen')
        # Sparse points deliberately make line/circle intersection practice possible.
        object_('stroke', 1280, y+560, 280, 1, strokeWidth=4,
                points=json.dumps([dict(x=1280,y=y+560,pressure=0.8),dict(x=1560,y=y+560,pressure=0.8)]))
    board = dict(id=board_id, title=content['title'], ownerId='local_user',
                 backgroundColor='#ffffff', gridColor='#d9e5da', gridStyle='dots',
                 boardTheme='whiteboard', canvasMode='infinite', canvasPreset='infinite',
                 createdAt=stamp, updatedAt=stamp, revision=1, pins=pins)
    doc = dict(schemaVersion='1.0.0', version='1.0', board=board, objects=objects)
    payload = (json.dumps(doc, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    name = f'QuickStart-{path.stem}.heiban'
    (target/name).write_bytes(payload)
    manifest['editions'].append(dict(language=path.stem, file=name, chapters=25, objects=len(objects),
                                    bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest()))
(target/'quickstart-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Generated {len(manifest["editions"])} Mac guide assets, 25 chapters each.')
