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
SECTIONS = ['language', 'start', 'library', 'paper', 'navigate', 'workspace', 'radial', 'brush',
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
:root{color-scheme:light;--bg:#f8faf8;--paper:#fff;--fg:#1c3029;--muted:#586e64;--line:#dce6df;--accent:#236249}
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
    'zh-TW':'實際 Windows 程式畫面，使用示範作品及正體中文介面；按鈕文字會隨介面語言切換。 部分截圖來自前一試用版；本批工具列排列請以目前程式及文字說明為準。',
    'zh-CN':'实际 Windows 程序画面，使用示例作品和繁体中文界面；按钮文字随界面语言切换。 部分截图来自上一试用版；本批工具栏布局请以当前程序及文字说明为准。',
    'en':'Actual Windows app with a sample work and Traditional Chinese UI. Button labels follow your interface language. Some images show the preceding trial; refer to the current app and text for the revised toolbar layout.',
    'ja':'サンプル作品を使った実際のWindows画面（繁体字中国語）です。ボタン名は設定言語に切り替わります。 一部は前の試用版の画面です。変更後のツール配置は現在のアプリと説明を参照してください。',
    'ko':'예제 작품을 사용한 실제 Windows 앱 화면입니다(번체 중국어). 버튼 이름은 인터페이스 언어에 따라 바뀝니다. 일부 이미지는 이전 체험판입니다. 바뀐 도구 배치는 현재 앱과 설명을 참고하세요.',
    'es':'Pantalla real de Windows con un ejemplo y la interfaz en chino tradicional. Los botones siguen el idioma elegido. Algunas imágenes corresponden a la prueba anterior; consulta la aplicación y el texto para la nueva barra.',
    'fr':'Écran réel de l’application Windows avec un exemple en chinois traditionnel. Les boutons suivent la langue de l’interface. Certaines images proviennent de l’essai précédent ; consultez l’application et le texte pour la nouvelle disposition.',
    'de':'Tatsächliche Windows-App mit einem Beispiel und traditionell chinesischer Oberfläche. Schaltflächen folgen Ihrer Sprache. Einige Bilder stammen aus dem vorherigen Teststand; für die neue Werkzeuganordnung gelten die aktuelle App und der Text.',
    'pt-BR':'Tela real do aplicativo Windows com um exemplo em chinês tradicional. Os botões seguem o idioma da interface. Algumas imagens são da versão de teste anterior; consulte o aplicativo atual e o texto para a nova barra.',
    'ar':'صورة فعلية لتطبيق Windows مع عمل تجريبي وواجهة بالصينية التقليدية. تتبع أسماء الأزرار لغة الواجهة المختارة. بعض الصور من النسخة التجريبية السابقة؛ راجع التطبيق الحالي والنص لتخطيط الشريط المعدّل.'}

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

def practice_document(code, rows):
    """One infinite editable note, with the complete manual and chapter pins.

    Tool coverage is tied to the runtime catalog so a new tool cannot silently
    disappear from the supplied guide. No user work or live app state is read.
    """
    import math
    titles={'zh-TW': '操作說明 · 全工具指南', 'en': 'User guide · All tools', 'ja': '操作ガイド · 全ツール', 'ko': '사용 설명 · 모든 도구', 'es': 'Guía de uso · Todas las herramientas', 'fr': 'Mode d’emploi · Tous les outils', 'de': 'Bedienungsanleitung · Alle Werkzeuge', 'pt-BR': 'Guia de uso · Todas as ferramentas', 'ar': 'دليل الاستخدام · جميع الأدوات'}
    titles['zh-CN']=simplify(titles['zh-TW'])
    pages=[{'id':'quickstart-all-tools','index':0,'title':rows['title'][0]}]
    board={'id':'heiban-windows-quickstart-v2','title':titles[code],'ownerId':'local_user',
           'backgroundColor':'#ffffff','gridColor':'#b9cec3','gridStyle':'dots','boardTheme':'whiteboard',
           'canvasMode':'infinite','canvasPreset':'infinite',
           'pages':pages,'activePageId':pages[0]['id'],'revision':1,'pins':[]}
    translations=json.loads((ROOT/f'HeiBan.Windows/Localization/Catalogs/{code}.json').read_text(encoding='utf-8-sig'))
    tool_source=(ROOT/'HeiBan.Windows.Core/Engine/ToolbarPreferences.cs').read_text(encoding='utf-8-sig')
    names=dict(re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]+)"',tool_source))
    actual=set(re.findall(r'"([^"]+)"',re.search(r'AllDefaultTools\s*=\s*\[(.*?)\];',tool_source,re.S)[1]))
    tool_sections={
        'workspace':['dock'], 'navigate':['viewLock'],
        'brush':['pen','highlighter','paint','brush','tape'],
        'shapes':['shapes','curve','magnet'], 'selection':['select','lasso'],
        'properties':['dash','extension'], 'text':['text','sticky'], 'eraser':['eraser'],
        'ruler':['ruler'], 'compass':['compass'], 'laser':['laser','cane'],
        'utilities':['calculator','timer'], 'images':['image','screenshot'],
        'pins':['pins'], 'shortcuts':['undo','redo','clearAll'], 'ux20':['layers']}
    covered=[tool for tools in tool_sections.values() for tool in tools]
    if set(covered)!=actual or len(covered)!=len(actual):raise ValueError('Practice guide tool coverage differs from runtime catalog')
    items=[]
    def add(kind, x,y,w,h,**values):
        item={'id':f'quickstart-{code}-{len(items)+1}','boardId':board['id'],'pageId':pages[0]['id'],
              'type':kind,'x':x,'y':y,'width':w,'height':h,'zIndex':len(items),
              'strokeColor':'#24533d','strokeWidth':4,'fillColor':'none','opacity':1,'isLocked':False}
        item.update(values);items.append(item)
    def text(value,y,size=18,color='#24533d'):
        # Conservative allocation also covers wide CJK glyphs; text remains
        # editable, with deliberate free space between chapters for practice.
        height=max(48,math.ceil(len(value)/42)*30+20)
        add('text',40,y,900,height,text=value,fontSize=size,strokeColor=color)
        return y+height+12
    y=text(titles[code],28,32)
    y=text(rows['workspace'][-1],y)
    y=text(' · '.join(f'{i:02} {rows[key][0]}' for i,key in enumerate(SECTIONS,1)),y,16)
    for number,key in enumerate(SECTIONS,1):
        y+=56
        chapter_y=y
        y=text(f'{number:02} · {rows[key][0]}',y,28)
        if key in tool_sections:
            y=text(' · '.join(translations.get(names[tool],names[tool]) for tool in tool_sections[key]),y,17,'#57816c')
        for paragraph in rows[key][1:]:y=text(paragraph,y)
        board['pins'].append({'id':f'quickstart-section-{key}','boardId':board['id'],
                             'x':490,'y':chapter_y-36,'name':f'{number:02} · {rows[key][0]}',
                             'zoom':1,'isWorldSpace':True,'color':'#5d9477','textColor':'#24533d'})
        if key in ('brush','eraser'):
            for i,color in enumerate(['#24533d','#4189c7','#d79126']):
                pts=[{'x':70+j*10,'y':y+30+i*55+math.sin(j/4)*15,'pressure':1} for j in range(60)]
                add('stroke',66,y+10+i*55,610,42,points=json.dumps(pts,separators=(',',':')),strokeColor=color,strokeWidth=4+i*2)
            add('highlighter',700,y+38,160,20,points=json.dumps([{'x':710,'y':y+48},{'x':850,'y':y+48}]),strokeWidth=20,strokeColor='#d9b927',opacity=.45)
            y+=240
        elif key=='shapes':
            add('rect',70,y+24,170,110,fillColor='#dcebdd')
            add('circle',300,y+24,110,110,strokeColor='#4189c7')
            add('triangle',474,y+24,160,110,fillColor='#fff0ab',points=json.dumps([{'x':554,'y':y+24},{'x':474,'y':y+134},{'x':634,'y':y+134}]))
            add('arrow',690,y+24,150,100,x1=690,y1=y+124,x2=840,y2=y+24,strokeColor='#ba652b')
            y+=210
    board['itemCount']=len(items)
    return {'schemaVersion':'1.0.0','version':'1.0','board':board,'objects':items}

catalogs={code:read(code) for code in LANGUAGES if code!='zh-CN'}
catalogs['zh-CN']={key:[simplify(value) for value in values] for key,values in catalogs['zh-TW'].items()}
TARGET.mkdir(exist_ok=True,parents=True)
manifest={'schema':1,'defaultLanguage':'zh-TW','sections':SECTIONS,'languageCodes':list(LANGUAGES),
          'scope':'Bundled offline help, not app execution or native-language review','pages':[]}
manifest['screenshots']=[{'file':'images/'+name,'sha256':hashlib.sha256((TARGET/'images'/name).read_bytes()).hexdigest()} for name in SCREENSHOTS.values()]
manifest['practiceDocuments']=[]
for code in LANGUAGES:
    practice=json.dumps(practice_document(code,catalogs[code]),ensure_ascii=False,indent=2).encode('utf-8')
    filename=f'QuickStart-{code}.heiban';(TARGET/filename).write_bytes(practice)
    manifest['practiceDocuments'].append({'language':code,'file':filename,'bytes':len(practice),'sha256':hashlib.sha256(practice).hexdigest(),
                                         'canvasMode':'infinite','chapters':len(SECTIONS),'toolKeys':list(re.findall(r'"([^"]+)"',re.search(r'AllDefaultTools\s*=\s*\[(.*?)\];',(ROOT/'HeiBan.Windows.Core/Engine/ToolbarPreferences.cs').read_text(encoding='utf-8-sig'),re.S)[1]))})
    data=render(code,catalogs[code]).encode('utf-8')
    (TARGET/f'{code}.html').write_bytes(data)
    manifest['pages'].append({'language':code,'file':f'{code}.html','sections':len(SECTIONS),
                            'paragraphs':sum(len(catalogs[code][s])-1 for s in SECTIONS),
                            'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
(TARGET/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(TARGET.parent/'HeiBanUserGuide.html').write_text(render('zh-TW',catalogs['zh-TW'],legacy=True),encoding='utf-8')
print(json.dumps({'languages':list(LANGUAGES),'sectionsPerGuide':len(SECTIONS),'pages':len(manifest['pages']),
                 'paragraphsPerGuide':{p['language']:p['paragraphs'] for p in manifest['pages']}},ensure_ascii=False))
