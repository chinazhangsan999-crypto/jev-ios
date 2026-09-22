# 实施状态

更新日期：2026-09-22。

## 已实现（源码层面）

- SwiftUI 主 App 设置页、API Key 共享钥匙串、系统广播选择器、状态轮询、停止与临时数据清理。
- 主 App 与回复键盘已补充状态层级、密钥保存提示、操作引导、Dynamic Type、VoiceOver 标签及至少 44 点的原生交互控件；视觉效果仍待 Xcode Preview/模拟器核对。
- ReplayKit Broadcast Upload Extension：单帧背压、方向处理、竖屏区域裁剪、Vision OCR、支持语言运行时筛选、内容指纹、稳定/间隔节流、旧请求取消、会话代次校验、响应大小限制及故障关闭。
- 回复键盘：明确连接当前会话、仅可见时续租、显示摘要/三条候选/译文、点击时重新检查新鲜度和 context ID、只填入不发送。
- App Group 单写者文件协议、共享 Keychain（键盘无权限）、Info.plist、entitlements、隐私清单和 XcodeGen 配置。
- 单元测试：新增可在 Linux/macOS 执行的 Swift Package 测试，并保留 iOS XCTest；覆盖不安全 URL/坏响应、严格三候选、旧代次、暂停/停止/无同意时零许可、过期候选、Keychain 错误文案。
- 中文编译、签名、安装、使用、数据范围及故障排查说明；新增 macOS 环境检查、模拟器构建和 development IPA 归档脚本。

## 已检查

- 在 Linux 使用 Swift 6.2.4 成功构建 `ChatPilotCore` 并运行 7 项测试；另对所有 Swift 文件执行 parser 检查。
- 使用 Python `plistlib` 检查所有 plist/entitlements/privacy manifest。
- 使用 Ruby YAML 解析器检查 `project.yml`。

以上检查不是 Xcode 编译。

## 未编译 / 未实测

当前执行环境不是 macOS，没有 Xcode、iOS SDK 或 iOS 模拟器，因此尚未执行 XcodeGen 生成后的 `xcodebuild` 或 iOS XCTest target。可移植 Swift Package 测试已运行，但没有生成 IPA。

尚未在 iPhone 上验证：签名和 capability、ReplayKit 与第三方聊天 App/键盘同时运行、主 App 后台、锁屏恢复、广播中断、键盘高度、长时间内存/耗电/发热、网络延时、不同屏幕与聊天布局、越南语声调 OCR、群聊或横屏。App Store/TestFlight 未提交且不保证审核结果。

## 安全边界与已知限制

- 第一版仅竖屏单聊；左右位置不是身份认证。
- ReplayKit 不提供可靠的前台 App 身份。本实现以键盘可见心跳、用户连接、会话 ID、短期候选和切换后重新连接降低误用，但不能构成 App 白名单隔离。
- OCR 文本会发往用户配置的模型服务；截图不写盘、不上传，不采集音频。
- 临时上下文会写入受数据保护的共享容器以供扩展通信，不应描述成“完全不落盘”。
- 要发布或真机安装，必须把 `com.example`、App Group、Keychain Group 和 Team 替换为开发者实际值。
