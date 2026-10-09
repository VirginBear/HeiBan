#!/usr/bin/env python3
"""Package existing platform builds for public download; never reads a user's library.

Copyright (C) 2026 VirginBear and HeiBan contributors.
SPDX-License-Identifier: GPL-3.0-only

Original Windows artifacts are preserved. Public ZIPs add installation instructions
and licenses; checksums describe the resulting download, not the old private ZIP.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
NOTICE = (ROOT / "THIRD_PARTY_NOTICES.md").read_text().replace(
    "(docs/", "(https://github.com/VirginBear/HeiBan/blob/main/docs/"
).replace("(windows/", "(https://github.com/VirginBear/HeiBan/blob/main/windows/")
INSTRUCTIONS = """HeiBan 黑板 — 公開預覽 / GPL-3.0-only

安裝／更新／作品位置：
https://github.com/VirginBear/HeiBan/blob/main/docs/INSTALL.zh-TW.md
快速開始：
https://github.com/VirginBear/HeiBan/blob/main/docs/QUICK_START.zh-TW.md
原始碼與完整 GPL 授權：
https://github.com/VirginBear/HeiBan

Mac：DMG 中把 HeiBan.app 拖到 Applications；ZIP 完整解壓後移到應用程式。
Windows Installer：完整解壓 ZIP，執行 HeiBan-Setup-….exe。
Windows Portable：完整解壓到可寫入資料夾，執行 HeiBan.exe。
Portable 全部 DLL／PRI／Assets／portable.dat 都要保留，作品在 Data。

這是預覽，不宣稱全部功能／装置已驗收。Mac 未 Apple 公證、Windows 未
Authenticode 簽章；有系統提示時請先確認來源、SHA-256 與官方安裝說明。
Windows 透明螢幕畫布／雷射等仍未提供；包內舊手冊以最新線上文件為準。
公開包不含使用者作品。更新前請備份 .heiban 原稿。

Copyright (C) 2026 VirginBear and HeiBan contributors.
本軟體不提供保證，詳見 LICENSE；第三方元件依 third-party/ 原授權。
""".replace("装置", "裝置")


def common_files(platform: str) -> dict[str, bytes]:
    files = {
        "LICENSE": (ROOT / "LICENSE").read_bytes(),
        "THIRD_PARTY_NOTICES.md": NOTICE.encode(),
        "INSTALL-README.txt": INSTRUCTIONS.encode(),
    }
    if platform == "macos":
        return files
    exception = ROOT / "windows/LICENSE-WINDOWS-EXCEPTION.txt"
    if not exception.is_file():
        raise ValueError("Windows SDK distribution requires the approved GPL section 7 exception")
    files["INSTALL-README.txt"] += (
        "\nWindows 安裝／使用前請閱讀 WINDOWS-RUNTIME-TERMS.txt 與 third-party/。\n"
        "Windows 限定 SDK 例外見 LICENSE-WINDOWS-EXCEPTION.txt；HeiBan 本身仍須 GPL 開源。\n"
    ).encode()
    files["LICENSE-WINDOWS-EXCEPTION.txt"] = exception.read_bytes()
    files["WINDOWS-RUNTIME-TERMS.txt"] = (
        "Windows runtime terms / Microsoft 元件條款\n\n"
        "Before installing or using the bundled Microsoft Windows components, "
        "you must read and agree to their original license terms in third-party/. "
        "Do not install or use these bundled components if you do not agree.\n"
        "安裝或使用附帶的 Microsoft Windows 元件前，必須閱讀並同意 third-party/ 的原始條款；"
        "若不同意，請勿安裝或使用這些元件。此要求僅適用於這些元件，不變更 HeiBan 的 GPL 權利。\n"
    ).encode()
    for path in (ROOT / "docs/third-party").iterdir():
        if path.is_file():
            files[f"third-party/{path.name}"] = path.read_bytes()
    files["third-party/WINDOWS-NOTICES.md"] = (ROOT / "windows/docs/THIRD_PARTY_NOTICES.md").read_bytes()
    files["third-party/ChineseTraditional.isl"] = (ROOT / "windows/HeiBan.Windows/Packaging/ChineseTraditional.isl").read_bytes()
    return files


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def finish(folder: Path, files: list[Path], platform: str, version: str) -> None:
    metadata = [{"filename": p.name, "bytes": p.stat().st_size, "sha256": sha256(p)} for p in files]
    (folder / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['filename']}\n" for a in metadata))
    (folder / "PUBLIC_ARTIFACTS.json").write_text(json.dumps({
        "platform": platform, "version": version, "license": "GPL-3.0-only",
        "additionalPermission": "LICENSE-WINDOWS-EXCEPTION.txt" if platform.startswith("windows") else None,
        "preview": True, "artifacts": metadata,
    }, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"platform": platform, "output": str(folder), "files": [a['filename'] for a in metadata]}, ensure_ascii=False))


def package_mac() -> None:
    manifest = json.loads((ROOT / "macos/Release.json").read_text())
    version = manifest["version"]
    app = ROOT / "macos/dist/HeiBan.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info["CFBundleShortVersionString"] != version or info["CFBundleVersion"] != manifest["build"]:
        raise ValueError("Build the current Mac release before packaging")
    if "LSEnvironment" in info:
        raise ValueError("Review/data-isolation builds must not be shipped")
    binary = app / "Contents/MacOS/HeiBanMac"
    architecture = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip()
    if architecture != "arm64":
        raise ValueError("This publication is explicitly ARM64; update names/docs for other architectures")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    folder = ROOT / "macos/dist/public"
    folder.mkdir(parents=True, exist_ok=True)
    stem = f"HeiBan-macOS-{version}-arm64"
    with tempfile.TemporaryDirectory(prefix="heiban-public-mac-") as temporary:
        stage = Path(temporary)
        shutil.copytree(app, stage / "HeiBan.app", symlinks=True)
        for name, data in common_files("macos").items():
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        archive = folder / f"{stem}.zip"
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", str(stage), str(archive)], check=True)
        (stage / "Applications").symlink_to("/Applications")
        image = folder / f"{stem}.dmg"
        subprocess.run(["hdiutil", "create", "-volname", f"HeiBan {version}", "-srcfolder", str(stage), "-ov", "-format", "UDZO", str(image)], check=True)
    guide = folder / f"HeiBan-User-Guide-macOS-{version}.html"
    shutil.copy2(ROOT / "macos/docs/USER_GUIDE.zh-TW.html", guide)
    finish(folder, [archive, image, guide], "macos-arm64", version)


def package_windows() -> None:
    project = ET.parse(ROOT / "windows/HeiBan.Windows/HeiBan.Windows.csproj")
    version = project.findtext(".//Version")
    original_manifest = json.loads((ROOT / "windows/docs/ARTIFACTS_2026-10-09_preview5.json").read_text())
    if version != original_manifest["version"]:
        raise ValueError("The original artifact manifest must match the Windows source version")
    originals = {a["filename"]: a for a in original_manifest["artifacts"]}
    folder = ROOT / "windows/dist/public"
    folder.mkdir(parents=True, exist_ok=True)
    files = []
    for runtime, arch in [("win-arm64", "arm64"), ("win-x64", "x64")]:
        exe_name = f"HeiBan-Setup-{version}-{arch}.exe"
        portable_name = f"HeiBan-Windows-Portable-{version}-{runtime}.zip"
        for name in [exe_name, portable_name]:
            source = ROOT / "windows/dist" / name
            original = originals[name]
            if source.stat().st_size != original["bytes"] or sha256(source) != original["sha256"]:
                raise ValueError(f"Original artifact integrity mismatch: {name}")
        installer = folder / f"HeiBan-Windows-Installer-{version}-{runtime}.zip"
        with zipfile.ZipFile(installer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            archive.write(ROOT / "windows/dist" / exe_name, exe_name)
            for name, data in common_files("windows").items():
                archive.writestr(name, data)
        portable = folder / portable_name
        with zipfile.ZipFile(ROOT / "windows/dist" / portable_name) as source:
            executable = next(PurePosixPath(n) for n in source.namelist() if PurePosixPath(n).name == "HeiBan.exe")
            prefix = "" if str(executable.parent) == "." else str(executable.parent) + "/"
            with zipfile.ZipFile(portable, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for item in source.infolist():
                    path = PurePosixPath(item.filename)
                    if path.is_absolute() or ".." in path.parts:
                        raise ValueError("Unsafe ZIP member")
                    if "Data" in path.parts and not item.is_dir() and item.file_size:
                        raise ValueError("User data must not be published")
                    archive.writestr(item, source.read(item))
                for name, data in common_files("windows").items():
                    archive.writestr(prefix + name, data)
        files.extend([installer, portable])
    # Latest source guide remains a separate asset: the old compiled app's bundled
    # guide is not silently replaced without rebuilding the Windows product.
    guide = folder / f"HeiBan-User-Guide-Windows-{version}.html"
    shutil.copy2(ROOT / "windows/HeiBan.Windows/Assets/HeiBanUserGuide.html", guide)
    finish(folder, files + [guide], "windows-arm64-x64", version)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["macos", "windows"], required=True)
    args = parser.parse_args()
    if args.platform == "macos":
        package_mac()
    else:
        package_windows()
