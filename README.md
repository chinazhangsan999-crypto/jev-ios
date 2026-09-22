# ChatPilot iOS（录屏实时聊天助手原型）

ChatPilot 是一个 **iOS 17+、用户主动开启系统屏幕广播** 的聊天回复辅助原型。广播扩展只截取配置的竖屏聊天区域，在设备上用 Vision OCR 提取文字，然后把文字（不是截图）发送到用户配置的 OpenAI Chat Completions 兼容 HTTPS 接口。回复键盘展示三条候选；只有用户点选后才填入当前输入框，**不会自动发送**。

> 这是源码原型，不是已经签名的 IPA，也没有完成真机稳定性或任何聊天 App 的兼容性验证。左右气泡位置并不能证明发送者身份，模型摘要也不是对方真实意图。

## 已实现

- SwiftUI 主 App：隐私同意、接口、模型、API Key、回复语言/风格、识别范围、请求间隔和广播状态。
- ReplayKit Broadcast Upload Extension：竖屏帧裁剪、方向处理、Vision OCR、变化去重、2 秒稳定窗、请求节流、取消过期请求、90 秒候选有效期和停止信号。
- 自定义回复键盘：显式连接会话、可见心跳、三条候选及中文译文、填入前再次检查会话/上下文/时效；不模拟发送键。
- App Group 短期状态及共享 Keychain。键盘不拥有 Keychain entitlement；截图不写盘。停止后清除临时上下文。
- XcodeGen 工程配置和关键状态机/解析测试。

## 编译前准备

首次在 macOS/Xcode 编译时，请按 [`ChatPilotIOS/MACOS_XCODE_FIRST_BUILD.md`](ChatPilotIOS/MACOS_XCODE_FIRST_BUILD.md) 逐步执行并记录结果。

需要 macOS、Xcode 15+、XcodeGen，以及可为 App 与两个扩展签名的 Apple Developer Team。可先运行 `./Scripts/bootstrap-macos.sh` 检查 Xcode，并通过 Homebrew 安装 XcodeGen。仓库当前使用占位标识，必须统一替换：

1. 在 `ChatPilotIOS/project.yml` 中把三个 `PRODUCT_BUNDLE_IDENTIFIER` 和测试标识换成你控制的唯一域名，并填写 `DEVELOPMENT_TEAM`。
2. 在三个 `Configuration/*.entitlements` 里把 `group.com.example.chatpilot` 换成你的 App Group；在三个 Info.plist 的 `AppGroup` 同步修改。
3. 在 App 与广播扩展 entitlements 里把 `com.example.chatpilot.shared` 换成你的 Keychain Access Group；同步修改 App/Broadcast Info.plist 的 `KeychainGroup`。键盘不需要该组。
4. 在 `App-Info.plist` 把 `BroadcastExtensionBundleID` 改成实际广播扩展 Bundle ID。
5. 在 Apple Developer Portal/Xcode Signing & Capabilities 为三个 target 启用相同 App Group；只为 App 与广播扩展启用相同 Keychain Sharing。

生成并编译：

```bash
cd ChatPilotIOS
./Scripts/build-ios.sh
```

共享模型的跨平台测试可以在 Linux 或 macOS 直接运行：

```bash
cd ChatPilotIOS
swift test
```

配置真实签名后，可在 macOS 生成 development archive 和 IPA：

```bash
cd ChatPilotIOS
./Scripts/archive-ios.sh
```

ReplayKit 广播、跨 App 键盘和共享钥匙串的最终验证必须使用已签名真机；Swift Package/模拟器测试不能替代真机验证。

## 安装与使用

1. 用 Xcode 打开生成的 `ChatPilot.xcodeproj`，选择你的 Team 与 iPhone，编译运行主 App。
2. 在主 App 填写 Chat Completions **完整 HTTPS 路径**、有效模型名和 API Key，阅读隐私说明，开启同意开关并保存。不要把密钥提交到源码。
3. 前往 iPhone **设置 → 通用 → 键盘 → 键盘 → 添加新键盘**，添加“ChatPilot 回复”；进入该键盘并打开“允许完全访问”。iOS 要求完全访问才能让键盘访问 App Group，键盘本身不读取 API Key。
4. 回到主 App，长按“开始”区域的系统广播按钮，选 `ChatPilot Broadcast` 并开始。应用不录音。
5. 打开目标聊天，保持竖屏，切换到 ChatPilot 回复键盘，点击“连接当前会话”。候选出现后核对上下文，点一条将它填入输入框，再由你手动点击聊天 App 的发送按钮。
6. **每次切换联系人、群组或 App 都要重新点击连接**。离开键盘会撤销分析租约；连接最长 10 分钟，之后重新连接。
7. 要暂停/停止分析，在主 App 点“暂停分析并清除临时内容”，并通过 iOS 录屏红色状态指示停止系统广播。

## 数据说明

- 处理：广播扩展在内存中缩放并 OCR 配置区域；不会保存或上传截图，不处理音频。
- 发送：最多约 6,000 个字符的 OCR 聊天文字、回复语言和风格会发送到你填写的模型接口。服务商可能按其条款记录数据，请自行确认。
- 本地：设置持久保存在 App Group；API Key 保存在 `WhenUnlockedThisDeviceOnly` 共享钥匙串。OCR 预览、候选和控制状态临时写入受数据保护的 App Group 文件，停止时清除。
- 边界：ReplayKit 没有提供可靠的当前前台聊天 App 白名单。本原型用“回复键盘可见 + 用户连接 + 短租约”降低误采风险，但不能证明画面来自特定 App。

## OCR / 广播排查

- **无文字**：确认竖屏，调节顶部/底部裁剪；聊天文字需位于两条比例线之间。首版不支持横屏和可靠群聊身份。
- **越南语识别差**：状态中实际语言取决于当前 iOS `VNRecognizeTextRequest` 支持列表；模型支持越南语不等于系统 OCR 支持。请用包含声调的真实对话在目标 iOS/iPhone 上验证。
- **一直提示未连接**：确认已打开“允许完全访问”，三个 target 的 App Group 完全一致且 provisioning profile 含该 capability。
- **钥匙串失败**：确认 App 与广播扩展使用同一 Team、同一 Keychain Access Group；锁屏时 `WhenUnlockedThisDeviceOnly` 项不可读。
- **没有广播扩展**：确认 `BroadcastExtensionBundleID`、扩展 Bundle ID 和签名一致，删除旧 App 后重新安装。
- **生成失败**：检查 HTTPS 完整路径、模型名、额度和接口是否兼容非流式 Chat Completions。客户端拒绝重定向，响应上限 128 KB。
- **候选消失**：键盘隐藏、录屏暂停、画面超过 5 秒未到达、会话变化或候选超过 90 秒都会故障关闭并清空候选，这是预期行为。

## 验证状态（2026-09-22）

| 层级 | 状态 |
| --- | --- |
| 源码与配置 | 已实现并完成 Linux 上语法/结构检查；见 `ChatPilotIOS/` |
| Xcode/iOS SDK 编译 | **未执行**：当前容器没有 macOS/Xcode/iOS SDK |
| 可移植核心测试 | **已在 Linux 执行**：Swift 6.2.4，7 项测试通过 |
| iOS XCTest | **未执行**：iOS target 仍需要 Xcode/iOS SDK |
| 模拟器运行 | **未执行** |
| iPhone 签名安装 | **未执行** |
| ReplayKit + 键盘并用、后台、锁屏、方向、内存/发热、越南语声调 | **待真机验证** |
| App Store / TestFlight 审核 | 未提交，不作通过保证 |

## 目录

- `App/`：SwiftUI 主 App 与系统广播选择器。
- `Broadcast/`：ReplayKit handler 和 Vision OCR。
- `Keyboard/`：回复键盘。
- `Shared/`：数据模型、共享存储、钥匙串、模型客户端。
- `Configuration/`：Info.plist 与 entitlements 占位配置。
- `Tests/`：关键安全/生命周期测试。
- `START_HERE.md`、`CHAT_CONTEXT.md`：需求与原始交接背景。
