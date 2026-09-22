#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "错误：Xcode/iOS SDK 只能安装在 macOS。本机系统为 $(uname -s)。" >&2
  exit 2
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "请先从 App Store 安装 Xcode 15+，启动一次并接受许可。" >&2
  exit 2
fi
if ! command -v brew >/dev/null; then
  echo "缺少 Homebrew。请从 https://brew.sh 安装后重试。" >&2
  exit 2
fi
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen --version
xcodebuild -version
