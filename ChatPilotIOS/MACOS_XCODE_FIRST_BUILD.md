# macOS / Xcode 首次真实编译指南

本指南用于第一次在 **macOS + Xcode 15 或更新版本**下生成工程、编译主 App／ReplayKit 广播扩展／回复键盘，并运行 iOS XCTest。Linux 上的 `swift test` 不能替代本流程。

## 1. 准备清单

- macOS 13 或更新版本。
- Xcode 15 或更新版本；首次启动完成组件安装并接受许可。
- 一个可登录 Xcode 的 Apple ID。真机、App Group 和 Keychain Sharing 建议使用有效 Apple Developer Team。
- 一台 iOS 17 或更新版本的 iPhone，用于后续 ReplayKit 与键盘联动验证。
- 不要把 Apple ID 密码、API Key、签名证书或 provisioning profile 提交到 Git。

确认工具：

```bash
cd ChatPilotIOS
./Scripts/bootstrap-macos.sh
sudo xcodebuild -license accept   # 仅在 Xcode 提示未接受许可时执行
xcode-select -p
xcodebuild -version
xcodegen --version
swift --version
```

如果安装了多个 Xcode，可显式选择：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 2. 创建 Apple 标识和 capability

在 Apple Developer Portal 或 Xcode 中准备以下唯一标识。请将 `YOUR_ORG` 换成你控制的反向域名，不要照抄示例：

| 用途 | 示例 |
| --- | --- |
| 主 App | `com.YOUR_ORG.chatpilot` |
| Broadcast Extension | `com.YOUR_ORG.chatpilot.broadcast` |
| Keyboard Extension | `com.YOUR_ORG.chatpilot.keyboard` |
| Tests | `com.YOUR_ORG.chatpilot.tests` |
| App Group | `group.com.YOUR_ORG.chatpilot` |
| Keychain Group 后缀 | `com.YOUR_ORG.chatpilot.shared` |

Capability 对应关系：

- 主 App：App Groups、Keychain Sharing。
- Broadcast Extension：同一个 App Group、同一个 Keychain Sharing。
- Keyboard Extension：同一个 App Group；**不要**加入 Keychain Sharing。

键盘不读取 API Key；只有主 App 和广播扩展共享密钥。

## 3. 替换仓库中的占位签名值

编辑 `project.yml`：

1. 把 `DEVELOPMENT_TEAM: ""` 改成 Xcode 显示的 Team ID。
2. 替换四个 `PRODUCT_BUNDLE_IDENTIFIER`。

编辑以下文件，把 `group.com.example.chatpilot` 全部替换为真实 App Group：

- `Configuration/App-Info.plist`
- `Configuration/Broadcast-Info.plist`
- `Configuration/Keyboard-Info.plist`
- `Configuration/App.entitlements`
- `Configuration/Broadcast.entitlements`
- `Configuration/Keyboard.entitlements`

在 App 和 Broadcast 的 Info.plist / entitlements 中，把 `com.example.chatpilot.shared` 替换为真实 Keychain Group 后缀。保留 `$(AppIdentifierPrefix)`，不要手工猜测 Team 前缀。

在 `Configuration/App-Info.plist` 中，把 `BroadcastExtensionBundleID` 改成真实广播扩展 Bundle ID。

检查是否仍有占位符：

```bash
rg -n 'com\.example|DEVELOPMENT_TEAM: ""' project.yml Configuration
```

预期结果：**没有输出**。如果有输出，先不要归档。

## 4. 运行可移植核心测试

```bash
swift test
```

预期：7 项测试通过。这一步验证配置、解析、会话门控和过期逻辑，但不会加载 ReplayKit、Vision、UIKit 或 SwiftUI。

## 5. 生成 Xcode 工程

```bash
xcodegen generate
open ChatPilot.xcodeproj
```

每次修改 `project.yml` 后都要重新运行 `xcodegen generate`。生成的 `.xcodeproj` 被 `.gitignore` 忽略，配置源以 `project.yml` 为准。

在 Xcode 中检查：

1. Scheme 选择 `ChatPilot`。
2. 主 App、Broadcast、Keyboard 三个 target 的 Signing Team 一致。
3. 三个 target 均没有红色签名错误。
4. 主 App 的 Build Phases 中嵌入两个扩展。
5. Deployment Target 为 iOS 17.0。

## 6. 第一次模拟器 Build + Test

先列出可用模拟器：

```bash
xcrun simctl list devices available
```

如果有 `iPhone 16`：

```bash
./Scripts/build-ios.sh
```

如果设备名不同：

```bash
CHATPILOT_DESTINATION='platform=iOS Simulator,name=iPhone 15 Pro' \
  ./Scripts/build-ios.sh
```

也可以直接执行并保留完整日志：

```bash
set -o pipefail
xcodegen generate
xcodebuild -project ChatPilot.xcodeproj \
  -scheme ChatPilot \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  clean build test | tee first-build.log
```

只有出现 `** BUILD SUCCEEDED **` 和 `** TEST SUCCEEDED **` 才能标记为“已通过 Xcode 编译”。Swift parser 或 `swift test` 通过不等于 iOS target 编译通过。

## 7. 常见首次编译问题

### 找不到模拟器

用 `xcrun simctl list devices available` 取得真实名称，通过 `CHATPILOT_DESTINATION` 传入。必要时在 Xcode → Settings → Platforms 安装 iOS Simulator Runtime。

### Provisioning profile 不含 App Group / Keychain Group

确认标识已在 Developer Portal 注册，并重新生成 profile；三个 target 的 App Group 字符串必须逐字相同，主 App 与 Broadcast 的 Keychain Group 必须逐字相同。

### 广播扩展未出现在系统广播列表

核对：

- `BroadcastExtensionBundleID` 与广播 target Bundle ID 一致。
- Broadcast target 已嵌入主 App。
- `NSExtensionPointIdentifier` 是 `com.apple.broadcast-services-upload`。
- 删除设备上的旧版本后重新安装。

### 键盘无法读取候选

确认 Keyboard target 的 App Group 正确；安装后前往“设置 → 通用 → 键盘 → 键盘 → 添加新键盘”，添加 ChatPilot 并打开“允许完全访问”。键盘不应拥有 Keychain Group。

### Swift 并发或 extension-safe API 错误

保留完整 Xcode 版本和错误日志，不要通过关闭所有并发检查或 `APPLICATION_EXTENSION_API_ONLY` 来掩盖问题。按具体诊断修复源码。

## 8. 第一次真机安装

1. iPhone 连接 Mac，解锁并信任电脑。
2. Xcode 的运行目标选择该 iPhone。
3. 在 Xcode → Settings → Accounts 登录开发者账号。
4. 三个 target 选择同一 Team，并确认 Signing 状态正常。
5. 点击 Run。首次安装后若系统要求，在设备设置中启用开发者模式。
6. 主 App 启动成功后，再安装回复键盘并开启“允许完全访问”。

不要把“安装成功”等同于功能验证完成。

## 9. 真机最低验收清单

- [ ] 主 App 启动且设置页无明显布局截断（含大号 Dynamic Type）。
- [ ] API Key 可保存、删除，源码和日志中不出现明文密钥。
- [ ] 系统广播选择器能看到 `ChatPilot Broadcast`。
- [ ] 广播启动、暂停、恢复、停止时状态正确，停止后没有新模型调用。
- [ ] 键盘可连接，会话切换后旧候选不能填入。
- [ ] 三条候选可见；点选只填入，不自动发送。
- [ ] 中文 OCR 实测；越南语使用带声调样本单独记录结果。
- [ ] 锁屏／解锁、主 App 后台、网络中断、聊天持续滚动均不会无限创建请求。
- [ ] 观察至少 15 分钟的内存、耗电和发热。

测试时使用非敏感对话和测试模型账号。

## 10. 生成 development Archive / IPA

只有模拟器 Build/Test 和真机冒烟测试通过后再运行：

```bash
./Scripts/archive-ios.sh
```

输出位置：

- `build/ChatPilot.xcarchive`
- `build/export/` 下的 development IPA

安装 IPA 仍要求设备包含在相应开发 profile 中。不要把 development IPA 当作 App Store/TestFlight 包。

## 11. 回传首次编译结果

如果失败，请提供以下内容（先删除用户名、路径中的隐私信息和任何密钥）：

```bash
xcodebuild -version
xcodegen --version
xcrun simctl list devices available
rg -n 'error:|warning:' first-build.log
```

同时说明：Mac 型号/macOS、Xcode 版本、iPhone 型号/iOS、使用的模拟器名称，以及失败发生在主 App、Broadcast、Keyboard 还是 Tests。不要发送 Apple ID 密码、API Key 或证书私钥。
