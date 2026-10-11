"""Compile the Windows UI authoring table into offline embedded catalogs.

The zh-TW sources are explicit UI keys, never document contents. Chinese script
conversion uses Windows NLS plus a small regional glossary; other languages are
authored in translations.txt. No network translator or App execution is used.
"""
import ctypes
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1] / "HeiBan.Windows" / "Localization"
CODES = ["en", "ja", "ko", "es", "fr", "de", "pt-BR", "ar"]
SOURCES = json.loads((ROOT / "Sources.json").read_text(encoding="utf-8-sig"))
translations = {}
for number, line in enumerate((ROOT / "translations.txt").read_text(encoding="utf-8-sig").splitlines(), 1):
    if not line or line.startswith("#"):
        continue
    columns = [column.replace(r"\s", " ") for column in line.split("|")]
    if len(columns) != 9:
        raise ValueError(f"Line {number}: expected 9 columns, got {len(columns)}")
    aliases = columns[0].replace(r"\n", "\n").split(";")
    values = [value.replace(r"\n", "\n") for value in columns[1:]]
    for alias in aliases:
        if alias in translations:
            raise ValueError(f"Duplicate source at line {number}: {alias}")
        translations[alias] = dict(zip(CODES, values))

missing = sorted(set(SOURCES) - set(translations))
if missing:
    print(json.dumps(missing, ensure_ascii=False, indent=2))
    print(f"Untranslated UI sources: {len(missing)}")
    if "--list-missing" in sys.argv:
        sys.exit(0)
    raise ValueError("Complete the authoring table before compiling catalogs.")

def placeholders(value):
    return sorted(re.findall(r"(?<!\{)\{(\d+)(?:,[^}:]+)?(?::([^}]+))?\}(?!\})", value))

for source in SOURCES:
    for code, value in translations[source].items():
        if not value.strip():
            raise ValueError(f"Empty translation: {code} / {source}")
        if placeholders(source) != placeholders(value):
            raise ValueError(f"Changed numeric placeholder: {code} / {source}")

if sys.platform != "win32":
    raise RuntimeError("Catalog regeneration uses Windows NLS. Existing catalogs build on all supported development hosts.")
nls = ctypes.WinDLL("kernel32", use_last_error=True).LCMapStringEx
nls.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_wchar_p, ctypes.c_int,
                ctypes.c_wchar_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ssize_t]
nls.restype = ctypes.c_int
def simplified(value):
    buffer = ctypes.create_unicode_buffer(len(value) * 2 + 2)
    count = nls("zh-CN", 0x02000000, value, len(value), buffer, len(buffer), None, None, 0)
    if count == 0:
        raise ctypes.WinError(ctypes.get_last_error())
    result = buffer[:count]
    for before, after in {
        "正体中文": "繁体中文", "滑鼠": "鼠标", "萤幕": "屏幕", "软体": "软件",
        "储存": "保存", "汇出": "导出", "汇入": "导入", "选取": "选择",
        "贴上": "粘贴", "套用": "应用", "复原": "撤销", "复写": "覆盖",
        "资料夹": "文件夹", "资料": "数据", "检视": "查看", "预设": "默认",
        "视窗": "窗口", "偏好": "偏好设置", "栏位": "字段", "图钉": "图钉",
    }.items():
        result = result.replace(before, after)
    return result

catalogs = {"zh-TW": {key: key for key in SOURCES},
            "zh-CN": {key: simplified(key) for key in SOURCES}}
catalogs.update({code: {key: translations[key][code] for key in SOURCES} for code in CODES})
target = ROOT / "Catalogs"
target.mkdir(exist_ok=True)
for code, catalog in catalogs.items():
    (target / f"{code}.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"languages": list(catalogs), "sourcesPerLanguage": len(SOURCES),
                  "authoringRows": len(translations), "missing": 0}, ensure_ascii=False))
