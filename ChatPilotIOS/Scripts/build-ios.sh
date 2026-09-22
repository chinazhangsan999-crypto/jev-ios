#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${CHATPILOT_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"
cd "$ROOT"

for tool in xcodegen xcodebuild; do
  if ! command -v "$tool" >/dev/null; then
    echo "错误：缺少 $tool。本脚本必须在安装 Xcode 15+ 与 XcodeGen 的 macOS 上运行。" >&2
    exit 2
  fi
done

if [[ "$(uname -s)" != Darwin ]]; then
  echo "错误：iOS SDK 和签名工具只随 macOS Xcode 提供。" >&2
  exit 2
fi

if grep -R -q 'com\.example\|DEVELOPMENT_TEAM: ""' project.yml Configuration; then
  echo "错误：仍有 com.example 或空 DEVELOPMENT_TEAM。请先按 README 替换签名标识。" >&2
  exit 3
fi

xcodegen generate
xcodebuild -project ChatPilot.xcodeproj -scheme ChatPilot \
  -destination "$DESTINATION" clean build test

echo "模拟器编译与测试通过。真机安装仍需在 Xcode 中选择签名设备验证。"
