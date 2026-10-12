#!/usr/bin/env python3
"""檢查 Mac 自有詞庫與已接線的 UI 常值，不讀 Windows runtime 或翻譯作品。"""
from pathlib import Path
import json, re
root = Path(__file__).resolve().parents[1]
keys = set()
for source in (root / 'Sources/HeiBanMac').rglob('*.swift'):
    keys.update(re.findall(r'L10n.t\("([^"\\]+)"\)', source.read_text()))
errors = []
for code in ['zh-TW', 'zh-CN', 'en', 'ja', 'ko', 'es', 'fr', 'de', 'pt-BR', 'ar']:
    catalog = json.loads((root / 'Sources/HeiBanMac/Resources/Localization' / (code + '.json')).read_text())
    missing = sorted(key for key in keys if not catalog.get(key))
    if missing: errors.append((code, missing))
print(f'{len(keys)} connected UI literals; 10 bundled catalogs')
for code, missing in errors: print(code, 'missing:', missing)
raise SystemExit(bool(errors))
