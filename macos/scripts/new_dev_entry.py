#!/usr/bin/env python3
"""建立不覆寫既有紀錄的開發日誌，並更新日誌索引。只使用標準函式庫。"""
import argparse
from datetime import date
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", required=True, help="這批工作名稱")
    parser.add_argument("--date", type=date.fromisoformat, default=date.today(), help="YYYY-MM-DD，預設本機今日")
    args = parser.parse_args()
    if not args.title.strip() or "\n" in args.title:
        parser.error("title 必須為非空白的單行文字")
    directory = Path(__file__).resolve().parents[1] / "docs/development"
    logs = directory / "logs" / args.date.isoformat()
    logs.mkdir(parents=True, exist_ok=True)
    number = 1
    while True:
        path = logs / f"{number:02}.zh-TW.md"
        try:
            # exclusive create：平行開工也不能覆寫另一人的日誌。
            with path.open("x", encoding="utf-8") as file:
                file.write(f"""# {args.date} · {args.title.strip()}

狀態：進行中。平台：macOS。

## 目的與授權範圍

待填：使用者需求、這批要交付什麼、平台與變更限制。

## 起始狀態

待填：Git 既有變更、目前版本、已知問題。

## 進行紀錄

待填：盤點、決定、修改、困難、失敗方案與排解；按實際順序追加。

## 變更與證據

待填：具體檔案與理由、命令、結果。未執行的測試／操作明確標示。

## 結果、風險與下一步

待填：實際完成、尚未完成、交接注意；同步 CURRENT_STATUS／ISSUE_HISTORY／DECISIONS。
""")
            break
        except FileExistsError:
            number += 1
    rows = []
    for entry in sorted((directory / "logs").glob("*/*.md"), reverse=True):
        title = entry.read_text(encoding="utf-8").splitlines()[0].removeprefix("# ")
        label = title.replace("[", "\\[").replace("]", "\\]")
        rows.append(f"- [{label}]({entry.relative_to(directory).as_posix()})")
    index = """# Mac 開發日誌

每批工作一份文件，進行中可追加；保留成功與失敗過程，不覆寫歷史。
此索引由 `macos/scripts/new_dev_entry.py` 生成；實際內容由開發者填寫。
歷史變更摘要及曾遇問題另見 [ISSUE_HISTORY](ISSUE_HISTORY.zh-TW.md)。

""" + "\n".join(rows) + "\n"
    (directory / "DEVELOPMENT_LOG.zh-TW.md").write_text(index, encoding="utf-8")
    print(path)


if __name__ == "__main__":
    main()
