"""Build menu SVGs from the original toolbar outline catalog; no second drawing catalog."""
import re
from pathlib import Path
from html import escape
root=Path(__file__).resolve().parents[1]/"HeiBan.Windows"
source=(root/"Views/ToolIcons.cs").read_text(encoding="utf-8-sig")
paths=dict(re.findall(r'^\s*\["([^"\n]+)"\]\s*=\s*"([^"\n]+)"',source,re.M))
assert "settings" in paths and "screen" in paths
out=root/"Assets/MenuIcons";out.mkdir(exist_ok=True)
for key,path in paths.items():
    text=f'<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><path d="{escape(path,quote=True)}" fill="none" stroke="#315D49" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>\n'
    (out/(key+".svg")).write_text(text,encoding="utf-8")
print(f"Generated {len(paths)} outline menu icons from ToolIcons.cs")
