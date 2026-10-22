#!/usr/bin/env python3
"""Generate Mac-only offline guide editions. No Windows files or runtime translation services required."""
from pathlib import Path
import html,json,hashlib
root=Path(__file__).resolve().parents[1]
release=json.loads((root/'Release.json').read_text())
languages={'zh-TW':'正體中文','zh-CN':'简体中文','en':'English','ja':'日本語','ko':'한국어','es':'Español','fr':'Français','de':'Deutsch','pt-BR':'Português (Brasil)','ar':'العربية'}
target=root/'Sources/HeiBanMac/Resources/Guides';target.mkdir(parents=True,exist_ok=True)
docs=root/'docs/guides';docs.mkdir(parents=True,exist_ok=True)
manifest={'version':release['version'],'build':release['build'],'editions':[]}
for code in languages:
    source=json.loads((root/f'Documentation/Guides/{code}.json').read_text())
    options=''.join(f'<option value="{c}" {"selected" if c==code else ""}>{html.escape(n)}</option>' for c,n in languages.items())
    picker=f'<label>{html.escape(source["languageLabel"])} <select onchange="location.href=this.value+\'.html\'">{options}</select></label>'
    if code=='zh-TW':
        output=(root/'Sources/HeiBanMac/Resources/HeiBanUserGuide.html').read_text().replace('<nav>',picker+'<nav>',1)
    else:
        sections=''.join(f'<section id="{s["id"]}"><h2>{i+1:02} · {html.escape(s["title"])}</h2>'+''.join(f'<p>{html.escape(p)}</p>' for p in s['paragraphs'])+'</section>' for i,s in enumerate(source['sections']))
        navigation=''.join(f'<a href="#{s["id"]}">{html.escape(s["title"])}</a>' for s in source['sections'])
        output=f'''<!doctype html><html lang="{code}" dir="{'rtl' if code=='ar' else 'ltr'}"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(source['title'])}</title><style>
:root{{color-scheme:light}}*{{box-sizing:border-box}}body{{margin:0;background:#f5f7f3;color:#203b2e;font:16px/1.85 system-ui,sans-serif}}header,main{{max-width:1000px;margin:auto;padding:24px}}header{{background:white;border-bottom:1px solid #dce5da}}h1{{font-size:28px}}input,select{{font:inherit;padding:8px;border:1px solid #bdcfc3;border-radius:8px;max-width:100%}}nav{{display:flex;flex-wrap:wrap;gap:8px;margin-top:20px}}a{{color:#39735a}}section{{background:white;border:1px solid #dce5da;border-radius:14px;padding:22px;margin-bottom:18px;scroll-margin-top:20px}}h2{{font-size:20px}}p{{white-space:pre-line}}label{{display:inline-flex;gap:8px;flex-wrap:wrap}}[hidden]{{display:none}}footer{{padding:20px}}@media print{{nav,input,select{{display:none}}section{{break-inside:avoid}}}}
</style><header><h1>{html.escape(source['title'])}</h1><p>macOS · {release['version']} · {release['build']}</p>{picker}<p><input id="search" type="search" placeholder="{html.escape(source['search'],quote=True)}" aria-label="{html.escape(source['search'],quote=True)}"></p><nav>{navigation}</nav></header><main>{sections}<footer>HeiBan macOS {release['version']} · <a href="zh-TW.html">正體中文 · 21 章完整圖解</a></footer></main><script>document.querySelector('#search').addEventListener('input',e=>{{const q=e.target.value.trim().toLocaleLowerCase();document.querySelectorAll('section').forEach(s=>s.hidden=q&&!s.textContent.toLocaleLowerCase().includes(q))}});</script></html>'''
    data=output.encode()
    (target/f'{code}.html').write_bytes(data);(docs/f'{code}.html').write_bytes(data)
    manifest['editions'].append({'language':code,'chapters':21 if code=='zh-TW' else len(source['sections']),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
(target/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f"Generated {len(languages)} native Mac guide editions (zh-TW 21 chapters; localized 13-topic overview).")
