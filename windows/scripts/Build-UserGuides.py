"""Build self-contained help from reviewed language sources, without a network service.

Only the authoring files enter here. No user documents, preference files or live
application state are read. zh-CN uses Windows NLS and the regional glossary.
Outputs are committed assets so normal .NET builds do not require Python.
"""
import ctypes
import hashlib
import html
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'HeiBan.Windows/Documentation/Guides'
TARGET = ROOT / 'HeiBan.Windows/Assets/Guides'
LANGUAGES = {'zh-TW': '正體中文', 'zh-CN': '简体中文', 'en': 'English', 'ja': '日本語',
             'ko': '한국어', 'es': 'Español', 'fr': 'Français', 'de': 'Deutsch',
             'pt-BR': 'Português (Brasil)', 'ar': 'العربية'}
SECTIONS = ['language', 'start', 'library', 'paper', 'navigate', 'workspace', 'brush',
            'shapes', 'selection', 'properties', 'text', 'eraser', 'ruler', 'compass',
            'laser', 'utilities', 'images', 'pins', 'screen', 'files', 'shortcuts',
            'updates', 'status', 'canvas-setup', 'ux20']
META = ['title', 'subtitle', 'search', 'empty', 'toc', 'languageLabel', 'footer']

def read(code):
    rows = {}
    for number, line in enumerate((SOURCE / f'{code}.txt').read_text(encoding='utf-8-sig').splitlines(), 1):
        if not line or line.startswith('#'): continue
        key, *values = line.split('|')
        if key in rows or not values or any(not value.strip() for value in values):
            raise ValueError(f'{code}:{number}: duplicate key or empty content')
        rows[key] = values
    if list(rows) != META + SECTIONS:
        raise ValueError(f'{code}: section or metadata contract differs')
    for key in META:
        if len(rows[key]) != 1: raise ValueError(f'{code}: metadata {key}')
    for key in SECTIONS:
        if len(rows[key]) < 3: raise ValueError(f'{code}: incomplete section {key}')
    return rows

def simplify(value):
    nls = ctypes.WinDLL('kernel32', use_last_error=True).LCMapStringEx
    nls.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_wchar_p, ctypes.c_int,
                   ctypes.c_wchar_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t]
    nls.restype = ctypes.c_int
    buffer = ctypes.create_unicode_buffer(len(value)*2+2)
    count = nls('zh-CN', 0x02000000, value, len(value), buffer, len(buffer), None, None, 0)
    if not count: raise ctypes.WinError(ctypes.get_last_error())
    result = buffer[:count]
    for before, after in {'正体中文':'繁体中文','滑鼠':'鼠标','萤幕':'屏幕',
            '储存':'保存','汇出':'导出','汇入':'导入','选取':'选择','贴上':'粘贴',
            '套用':'应用','复原':'撤销','资料夹':'文件夹','资料':'数据',
            '检视':'查看','预设':'默认','视窗':'窗口','栏位':'字段','程式':'程序'}.items():
        result = result.replace(before, after)
    return result

CSS = '''
:root{color-scheme:light dark;--bg:#f8faf8;--paper:#fff;--fg:#1c3029;--muted:#586e64;--line:#dce6df;--accent:#236249}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-block-start:1.5rem}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.8 system-ui,"Segoe UI",sans-serif}
header{padding:2rem max(1.5rem,calc((100vw - 1320px)/2));background:var(--paper);border-block-end:1px solid var(--line)}
h1{font-size:2rem;line-height:1.3;margin:0 0 .3rem}header p{margin:0;color:var(--muted)}
.controls{display:flex;flex-wrap:wrap;gap:1rem;align-items:center;margin-block-start:1.2rem}
input,select{font:inherit;color:inherit;background:var(--paper);border:1px solid var(--line);border-radius:.65rem;padding:.55rem .8rem;max-width:100%}
input{width:26rem}label{display:flex;gap:.6rem;align-items:center;flex-wrap:wrap}
.layout{display:grid;grid-template-columns:250px minmax(0,1fr);gap:2rem;max-width:1320px;margin:2rem auto;padding-inline:1.5rem}
aside{position:sticky;inset-block-start:1rem;align-self:start;max-height:calc(100vh - 2rem);overflow:auto}
nav a{display:block;padding:.35rem .5rem;border-radius:.4rem;color:var(--muted);text-decoration:none;font-size:.92rem}
nav a:hover,nav a:focus-visible{background:var(--line);color:var(--accent)}
section{background:var(--paper);padding:1.5rem 2rem;margin-block-end:1.4rem;border:1px solid var(--line);border-radius:1rem}
h2{margin:0 0 .8rem;font-size:1.35rem;line-height:1.5}h2 span{color:var(--accent);margin-inline-end:.65rem;font-size:.95rem;font-variant-numeric:tabular-nums}
p{margin:.6rem 0;overflow-wrap:anywhere}bdi{unicode-bidi:isolate}kbd{font: .9em ui-monospace,monospace;border:1px solid var(--line);border-radius:.25rem;padding:0 .2rem;white-space:nowrap}
figure{margin:1rem 0}figure img{display:block;width:100%;height:auto;border:1px solid var(--line);border-radius:.7rem}figcaption{font-size:.85rem;color:var(--muted);margin-block-start:.4rem}
#empty{padding:1rem;color:var(--muted)}footer{padding:1rem 0 2rem;color:var(--muted);font-size:.9rem}
[hidden]{display:none!important}a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid var(--accent);outline-offset:3px}
@media(max-width:800px){.layout{grid-template-columns:1fr;gap:1rem;margin:1rem auto}aside{position:static;max-height:18rem}section{padding:1rem 1.2rem}header{padding:1.5rem}}
@media(prefers-color-scheme:dark){:root{--bg:#14231d;--paper:#1b2d24;--fg:#e4eee7;--muted:#b4c8bb;--line:#344d3d;--accent:#9fd4b6}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
@media print{header .controls,aside{display:none}.layout{display:block;max-width:none;margin:0;padding:0}section{break-inside:avoid;border:0;border-block-end:1px solid #ccc;border-radius:0}body,section,header{background:white;color:black}section[hidden]{display:block!important}}
'''
SCRIPT = '''
const input=document.querySelector('#search');
input.addEventListener('input',()=>{
 const q=input.value.trim().toLocaleLowerCase(document.documentElement.lang);
 let matches=0;
 for(const section of document.querySelectorAll('section')){
  const show=!q||section.textContent.toLocaleLowerCase(document.documentElement.lang).includes(q);
  section.hidden=!show;
  document.querySelector('nav a[href="#'+section.id+'"]').hidden=!show;
  if(show)matches++;
 }
 document.querySelector('#empty').hidden=matches>0;
});
document.querySelector('#guide-language').addEventListener('change',event=>{
 const target=new URL(event.target.selectedOptions[0].dataset.path,location.href);
 target.hash=location.hash;
 location.href=target.href;
});
'''

TOKEN = re.compile(r'(Ctrl(?:\+[A-Za-z]+)+|Win\+Shift\+S|#[A-Z]{6}|%LOCALAPPDATA%\\HeiBan\\[A-Za-z]+\\|\.blackboard\.json|\.heiban|(?:Data/|portable\.dat)|SHA-256|Authenticode|foreignObject|[0-9]+(?:[.:×/–][0-9]+)+(?:%| pt)?)')
def prose(value):
    # Isolate file names, numeric notation and shortcuts inside RTL prose; never reverse key order.
    return ''.join(f'<bdi dir="ltr">{html.escape(part)}</bdi>' if TOKEN.fullmatch(part)
                   else html.escape(part) for part in TOKEN.split(value))

SCREENSHOTS={'workspace':'toolbar-labeled.jpg','shapes':'triangle-preview.jpg','selection':'object-properties.jpg','files':'pdf-pages.jpg'}
CAPTIONS={
    'zh-TW':'實際 Windows 程式畫面，使用示範作品及正體中文介面；按鈕文字會隨介面語言切換。',
    'zh-CN':'实际 Windows 程序画面，使用示例作品和繁体中文界面；按钮文字随界面语言切换。',
    'en':'Actual Windows app with a sample work and Traditional Chinese UI. Button labels follow your interface language.',
    'ja':'サンプル作品を使った実際のWindows画面（繁体字中国語）です。ボタン名は設定言語に切り替わります。',
    'ko':'예제 작품을 사용한 실제 Windows 앱 화면입니다(번체 중국어). 버튼 이름은 인터페이스 언어에 따라 바뀝니다.',
    'es':'Pantalla real de Windows con un ejemplo y la interfaz en chino tradicional. Los botones siguen el idioma elegido.',
    'fr':'Écran réel de l’application Windows avec un exemple en chinois traditionnel. Les boutons suivent la langue de l’interface.',
    'de':'Tatsächliche Windows-App mit einem Beispiel und traditionell chinesischer Oberfläche. Schaltflächen folgen Ihrer Sprache.',
    'pt-BR':'Tela real do aplicativo Windows com um exemplo em chinês tradicional. Os botões seguem o idioma da interface.',
    'ar':'صورة فعلية لتطبيق Windows مع عمل تجريبي وواجهة بالصينية التقليدية. تتبع أسماء الأزرار لغة الواجهة المختارة.'}

def render(code,rows,legacy=False):
    metadata={key:html.escape(rows[key][0],quote=True) for key in META}
    direction='rtl' if code=='ar' else 'ltr'
    options=''.join(f'<option value="{lang}" data-path="{"Guides/" if legacy else ""}{lang}.html"'
                     f'{" selected" if lang==code else ""}>{name}</option>' for lang,name in LANGUAGES.items())
    navigation=''.join(f'<a href="#{key}">{number:02} · {html.escape(rows[key][0])}</a>'
                       for number,key in enumerate(SECTIONS,1))
    def section(number,key):
        figure=''
        if key in SCREENSHOTS:
            filename=SCREENSHOTS[key]
            if not (TARGET/'images'/filename).is_file():raise ValueError(f'Missing real app screenshot: {filename}')
            image_path=('Guides/' if legacy else '')+'images/'+filename
            figure=f'<figure><a href="{image_path}"><img src="{image_path}" alt="{html.escape(rows[key][0],quote=True)}" loading="lazy"></a><figcaption>{html.escape(CAPTIONS[code])}</figcaption></figure>'
        return f'<section id="{key}"><h2><span dir="ltr">{number:02}</span>{html.escape(rows[key][0])}</h2>'+''.join(f'<p>{prose(p)}</p>' for p in rows[key][1:])+figure+'</section>'
    sections=''.join(section(number,key) for number,key in enumerate(SECTIONS,1))
    return f'''<!doctype html>
<html lang="{code}" dir="{direction}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{metadata['title']}</title><style>{CSS}</style></head>
<body><header><h1>{metadata['title']}</h1><p>{metadata['subtitle']}</p><div class="controls"><input id="search" type="search" aria-label="{metadata['search']}" placeholder="{metadata['search']}"><label>{metadata['languageLabel']}<select id="guide-language" aria-label="{metadata['languageLabel']}" dir="ltr">{options}</select></label></div></header>
<div class="layout"><aside><nav aria-label="{metadata['toc']}">{navigation}</nav></aside><main><p id="empty" role="status" aria-live="polite" hidden>{metadata['empty']}</p>{sections}<footer>{metadata['footer']}</footer></main></div><script>{SCRIPT}</script></body></html>
'''

catalogs={code:read(code) for code in LANGUAGES if code!='zh-CN'}
catalogs['zh-CN']={key:[simplify(value) for value in values] for key,values in catalogs['zh-TW'].items()}
TARGET.mkdir(exist_ok=True,parents=True)
manifest={'schema':1,'defaultLanguage':'zh-TW','sections':SECTIONS,'languageCodes':list(LANGUAGES),
          'scope':'Bundled offline help, not app execution or native-language review','pages':[]}
manifest['screenshots']=[{'file':'images/'+name,'sha256':hashlib.sha256((TARGET/'images'/name).read_bytes()).hexdigest()} for name in SCREENSHOTS.values()]
for code in LANGUAGES:
    data=render(code,catalogs[code]).encode('utf-8')
    (TARGET/f'{code}.html').write_bytes(data)
    manifest['pages'].append({'language':code,'file':f'{code}.html','sections':len(SECTIONS),
                            'paragraphs':sum(len(catalogs[code][s])-1 for s in SECTIONS),
                            'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
(TARGET/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(TARGET.parent/'HeiBanUserGuide.html').write_text(render('zh-TW',catalogs['zh-TW'],legacy=True),encoding='utf-8')
print(json.dumps({'languages':list(LANGUAGES),'sectionsPerGuide':len(SECTIONS),'pages':len(manifest['pages']),
                 'paragraphsPerGuide':{p['language']:p['paragraphs'] for p in manifest['pages']}},ensure_ascii=False))
