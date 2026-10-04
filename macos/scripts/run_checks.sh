#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 [1/2] 執行 HeiBan Mac 原生引擎單元測試 (32 項斷言)..."
cd "$MACOS_DIR"
swift run HeiBanTestRunner

echo ""
echo "🚀 [2/2] 執行 HeiBanMac GUI 應用建置..."
swift build

echo ""
echo "🎉 所有檢查通過！HeiBan Mac 原生版本狀態良好！"
