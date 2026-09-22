#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build}"
cd "$ROOT"

if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null || ! command -v xcodegen >/dev/null; then
  echo "错误：归档需要安装 Xcode 15+ 与 XcodeGen 的 macOS。" >&2
  exit 2
fi
if grep -R -q 'com\.example\|DEVELOPMENT_TEAM: ""' project.yml Configuration; then
  echo "错误：请先替换 com.example 标识并在 project.yml 填写 DEVELOPMENT_TEAM。" >&2
  exit 3
fi

mkdir -p "$OUTPUT"
xcodegen generate
xcodebuild -project ChatPilot.xcodeproj -scheme ChatPilot \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUTPUT/ChatPilot.xcarchive" \
  -allowProvisioningUpdates clean archive

cat > "$OUTPUT/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>development</string>
<key>signingStyle</key><string>automatic</string>
<key>stripSwiftSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$OUTPUT/ChatPilot.xcarchive" \
  -exportPath "$OUTPUT/export" \
  -exportOptionsPlist "$OUTPUT/ExportOptions.plist" \
  -allowProvisioningUpdates

echo "归档：$OUTPUT/ChatPilot.xcarchive"
echo "开发版 IPA：$OUTPUT/export/"
