"""Original SVG implementation of the approved A concept, not cropped bitmap cells.

The cane follows the existing Cane.png: straight rattan and a wrapped handle.
Other undeclared tools use their existing geometry with a functional color accent.
Generated assets serve both SvgImageSource and the cached Win2D wheel renderer.
"""
import re
from pathlib import Path
from html import escape
root=Path(__file__).resolve().parents[1]/'HeiBan.Windows'
source=(root/'Views/ToolIcons.cs').read_text(encoding='utf-8-sig')
paths=dict(re.findall(r'^\s*\["([^"\n]+)"\]\s*=\s*"([^"\n]+)"',source,re.M))
constants=dict(re.findall(r'const string (Mode\w+)="([^"]+)"',source))
out=root/'Assets/MenuIcons/Duotone';out.mkdir(exist_ok=True)
ink='#38464B'
tones=dict(re.findall(r'(Brush(?:Primary|Light|Dark))="([^"]+)"',(root/'Views/ToolIcons.BrushColor.cs').read_text(encoding='utf-8-sig')))
def path(d,fill='none',stroke=ink,width=1.1,extra=''):
    return f'<path d="{escape(d,quote=True)}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def circle(x,y,r,fill,stroke=ink,width=1.1):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def rect(x,y,w,h,fill,extra=''):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="1.6" fill="{fill}" stroke="{ink}" stroke-width="1.1" {extra}/>'
art={
 'select':rect(2,2,15,15,'none','stroke-dasharray="2.3 2.3"')+path('M12,10 L23,17 L18,18 L21,23 L18,25 L15,20 L12,23 Z','#8FA9BC'),
 'pen':path('M4,21 L7,13 L17,3 Q19,1 22,4 Q24,6 22,8 L12,18 Z',tones['BrushPrimary'])+path('M4,21 L7,13 L12,18 Z','#E6ECE9')+path('M14,6 L19,11',tones['BrushLight'])+path('M5,20 L9,16')+circle(9,16,1.1,tones['BrushDark'],ink,1),
 'highlighter':path('M8,15 L17,3 Q18,2 20,4 L23,7 Q24,8 23,9 L14,20 Z',tones['BrushPrimary'])+path('M8,15 L14,20 L10,22 L5,19 Z',tones['BrushDark'])+path('M11,13 L17,17'),
 'eraser':path('M3,15 L14,3 Q15,2 17,3 L23,9 Q24,10 23,12 L13,23 L9,23 Z','#F48E82')+path('M3,15 L8,10 L17,18 L13,23 L9,23 Z','#FCF4E3')+path('M17,14 L21,10','none','#C56659',.9),
 'line':path('M4,22 L22,4','none','#66578F',1.5),
 'arrow':path('M3,21 L15,9 L12,6 L23,3 L20,14 L17,11 L5,23 Z','#D4C4F2','#66578F'),
 'shapes':rect(2,3,13,13,'#8384EC')+circle(17,17,7,'#B7A4F1'),
 'text':path('M3,4 L23,4 L23,9 L19,9 L19,8 L15,8 L15,22 L18,22 L18,24 L8,24 L8,22 L11,22 L11,8 L7,8 L7,9 L3,9 Z','#5BCCC0'),
 'sticky':path('M3,3 L23,3 L23,17 L17,23 L3,23 Z','#FFE07A')+path('M17,23 L17,17 L23,17 Z','#FFF4C5')+path('M7,8 L18,8 M7,12 L16,12 M7,16 L12,16','none','#93732C',1),
 'ruler':rect(2,7,22,12,'#8ADFD4')+path('M6,8 L6,12 M10,8 L10,11 M14,8 L14,12 M18,8 L18,11 M22,8 L22,12'),
 'compass':path('M14,6 L3,23 L6,24 L16,10 L21,24 L24,23 L18,6 Z','#87BCE8')+circle(16,6,4,'#C4E6F3')+circle(16,6,1.3,ink,ink,1)+path('M16,1 L16,2 M9,18 L18,18'),
 'laser':path('M10,13 L24,13','none','#F99191',3)+circle(8,13,3.5,'#EF555E')+circle(7,12,1.2,'#FFE1DF','none',0)+path('M3,9 L1,7 M8,5 L8,2 M3,14 L1,14','none','#ED4C55',1.1),
 'cane':path('M3,2 Q1,1 2,4 L17,19 L19,17 Z','#E5B778','#89613B',1.1)+path('M7,6 L6,7 M12,11 L11,12 M16,15 L15,16','none','#B88A4E',1)+path('M18,16 L24,22 Q26,24 24,25 L16,18 Z','#EFEAD5','#52705B',1.1)+path('M20,19 L18,21 M22,21 L20,23','none','#BEBAA4',1),
 'palette':path(paths['palette'],'#FFF1D5')+circle(7,8,1.8,'#F27468','none',0)+circle(13,6,1.8,'#F7CF39','none',0)+circle(19,9,1.8,'#66B76A','none',0)+circle(6,14,1.8,'#51B4DB','none',0),
 'layers':path('M2,17 L13,23 L24,17 L13,11 Z','#AD7FD5')+path('M2,12 L13,18 L24,12 L13,6 Z','#C39CE6')+path('M2,7 L13,13 L24,7 L13,1 Z','#DEC3F2'),
}
# The exact same monitor/window geometry in both modes; only the badge changes.
for key,badge,color in [('mode-operate','ModePointer','#8FBACC'),('mode-draw','ModePen','#FFB966')]:
    paths[key]=constants['ModeWindow']+' '+constants[badge]
    art[key]=path(constants['ModeWindow'],'none','#365F52')+path('M3,4 L18,4 L18,6 L3,6 Z','#8AD8BB','none',0)+path(constants[badge],color)
colors={'paint':'#69BBA0','curve':'#43AFCC','image':'#75B88D','screenshot':'#5A9DCB','canvasCapture':'#5A9DCB','calculator':'#62BDB4','timer':'#ECAD55','pins':'#D7798E','magnet':'#DF7272','delete':'#D87970','settings':'#5EBA9E','undo':'#649ECC','redo':'#649ECC'}
for key,d in paths.items():
    color=colors.get(key,'#7EA992')
    body=art.get(key,path(d,'none',color,1.25))
    if key in ('rect','circle','triangle','quadrilateral','diamond','pentagon','star'):
        body=path(d,'#D4C4F2','#66578F',1.1)
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26">{body}</svg>\n'
    (out/(key+'.svg')).write_text(svg,encoding='utf-8')
print(f'Generated {len(paths)} duotone SVG icons; straight cane and shared mode window retained.')
