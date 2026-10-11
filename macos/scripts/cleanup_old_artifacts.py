#!/usr/bin/env python3
"""成功封裝後，只清理 Mac dist 中可辨識的舊 HeiBan 成品，保留文件。"""

import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess


def numbers(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d+(?:\.\d+)*", value):
        raise ValueError(f"Invalid version: {value!r}")
    return tuple(int(part) for part in value.split("."))


def main():
    macos = Path(__file__).resolve().parents[1]
    dist = macos / "dist"
    release = json.loads((macos / "Release.json").read_text())
    current = (numbers(release["version"]), numbers(release["build"]))
    app = dist / "HeiBan.app"
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    # 失敗／尚未封裝的新版本不能成為刪除舊成品的依據。
    if info.get("CFBundleIdentifier") != "com.bear.HeiBan" or (
        info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")
    ) != (release["version"], release["build"]):
        raise RuntimeError("Current App does not match Release.json; cleanup cancelled")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)

    targets = []
    for candidate in sorted((dist / "archive").glob("*.app")):
        if candidate.is_symlink():
            continue
        try:
            with (candidate / "Contents/Info.plist").open("rb") as stream:
                old = plistlib.load(stream)
            version = (numbers(old["CFBundleShortVersionString"]), numbers(old["CFBundleVersion"]))
        except (OSError, ValueError, KeyError, plistlib.InvalidFileException):
            continue  # 無法確認來源的資料不能靠檔名直接刪除。
        if old.get("CFBundleIdentifier") == "com.bear.HeiBan" and version <= current:
            targets.append(candidate)

    for candidate in sorted((dist / "public").glob("HeiBan-macOS-*")):
        match = re.fullmatch(r"HeiBan-macOS-(\d+\.\d+\.\d+)-(?:arm64|x64|universal)\.(?:zip|dmg)", candidate.name)
        if match and candidate.is_file() and not candidate.is_symlink() and numbers(match[1]) < current[0]:
            targets.append(candidate)

    freed = 0
    for candidate in targets:
        if candidate.is_dir():
            size = sum(p.stat().st_size for p in candidate.rglob("*") if p.is_file() and not p.is_symlink())
            shutil.rmtree(candidate)
        else:
            size = candidate.stat().st_size
            candidate.unlink()
        freed += size
        print(f"Removed {candidate.relative_to(macos)} ({size} bytes)")
    print(f"Kept {app}; removed {len(targets)} old artifacts, {freed} bytes")


if __name__ == "__main__":
    main()
