# 云端开发任务：iOS 录屏实时聊天助手

创建日期：2026-09-22。任务状态：交接材料已整理，尚未成功提交 Codex 云端任务。

## 给接手 Codex 的任务指令

请继续开发一个原生 iOS 聊天辅助 App。用户已明确选择“② 开启录屏后实时辅助聊天”，并要求把相关聊天记录一起交给云端任务。不要改成仅手动导入截图的产品。

先阅读本文件、CHAT_CONTEXT.md、IMPLEMENTATION_STATUS.md、Shared/ 中的四个 Swift 文件和 Broadcast/ 中的两个草稿。检查仓库已有指令，审查已有代码，然后完成能编译的工程与测试；不要只返回方案，也不要把未编译的源码称为可安装 App。

## 已确认目标

- 为 iPhone 开发类似 Jev 聊天助手的体验。
- 用户主动开启 iOS 系统屏幕广播后，识别当前可见聊天文字并实时生成建议。
- 提供三条候选回复；用户选中后填入聊天输入框，发送仍由用户手动完成。
- 用户询问过聊天语言支持。中文为基础；中文／越南语与译文选项是助手提出的设计默认值，不应描述为用户已经验收的要求。
- 用户要求建立一个独立 Codex 云端任务并携带相关聊天记录。当前包是任务材料，不是任务已启动的凭据。

## 拟采用的 iOS 架构

1. 主 App（SwiftUI）：API 完整地址、模型名称、API Key、回复语言、风格、识别区域、状态、系统广播选择器。
2. Broadcast Upload Extension（ReplayKit）：接收屏幕帧；限制帧处理频率和同时持有的图像数量；处理方向元数据；只在用户已明确启用分析的会话内工作。
3. 本地 OCR（Vision）：只识别配置的聊天区域；不要识别自己键盘显示的候选回复造成递归；运行时检查 OCR 支持的语言，越南语必须测试声调字符。不能因模型会越南语就宣称 OCR 支持。
4. 模型请求：用户配置的 HTTPS、OpenAI Chat Completions 兼容接口；不要硬编码不存在或已停用的模型名称；根据最新上下文生成结构化候选。
5. 自定义回复键盘（UIInputViewController）：展示状态、候选与中文译文；只在用户主动选择后调用 textDocumentProxy.insertText，不自动回车／发送。
6. App Group：交换最少的短期控制状态与候选。API Key 仅由主 App 和广播扩展通过共享 Keychain 读取，键盘不需要密钥。

最低 iOS 版本暂按 iOS 17 设计，可按依赖和设备需求调整。先支持竖屏单聊，再说明群聊与横屏限制。不要擅自删除用户明确选择的录屏主路径。

## 首先验证的风险

- 广播扩展与键盘扩展可否在目标 iPhone／聊天 App 上同时稳定工作；主 App 进入后台后也要验证。
- 扩展资源限制、OCR 峰值内存、发热、屏幕方向、键盘高度、录屏中断、锁屏与恢复。
- 模型耗时与 OCR 去重：按变化触发、节流、取消过期请求、限定响应体大小；持续滚动时不能无限创建请求。
- 切换联系人或 App 后不能把旧会话建议填入新会话。不能假定 ReplayKit 会提供可靠的前台 App 身份。需要用户重新连接会话、内容指纹／代次校验、过期禁用及可核对的上下文提示。
- 为避免录屏采到其他 App 内容，建议分析仅在回复键盘可见且用户启用当前会话时进行。当前骨架只有控制数据结构，没有实现这个门控。此设计不等于已获得可靠的聊天 App 白名单隔离。
- 自定义键盘读取的是输入框上下文，不能把它当成聊天记录读取 API。
- 不使用任意跨 App 悬浮窗的承诺；第一版用回复键盘。画中画不是通用交互悬浮窗，不要滥用音频后台模式保活。
- 请评估端侧 OCR／网络客户端放在广播扩展内的可行性。如果实测不稳定，应报告数据与替代方案，不得只写“已经支持实时”。

## 数据与交互要求

- 系统录屏须由用户通过系统 UI 主动开启，提供明显的分析暂停和停止入口。
- 说明哪些识别文本会发送到用户配置的模型接口；不默认上传整屏图片、录制音频或保存屏幕视频。
- 临时上下文和候选在停止、切换会话或到期时清除；不要承诺“不落盘”却写入持久共享 JSON。
- 密钥不写入源文件、日志、对话记录或仓库；共享文件采用数据保护。Keychain Access Group 和 App Group 必须与签名匹配。
- 不自动发送消息、不执行支付；把聊天内容当作数据而不是可执行指令。候选只是建议，不把模型推断当成对方真实心理。

## 实施与交付

1. 先审查六个草稿文件，修正类型、并发、生命周期和存储问题。
2. 完成主 App、广播扩展、回复键盘，以及 App Group / Keychain / Info.plist / entitlements。
3. 提供可复现的 Xcode 工程或 XcodeGen 配置，说明 Bundle ID、Team ID 的替换位置。
4. 为取消旧请求、跨会话过期回复防护、解析坏响应、暂停后零新调用、Keychain 失败等关键路径编写有意义的测试。
5. 可加入 macOS CI 编译配置。Linux 上的静态检查不能替代 Xcode 编译；签名安装与跨 App 行为需要真机测试。
6. 提供中文 README：设置 API、编译、签名、安装、添加键盘及“允许完全访问”、开启广播、暂停、停止、排查 OCR 失败。
7. 明确列出：已实现、已编译、已实测、尚待真机验证。不要保证 App Store／TestFlight 审核通过。
8. 若有已授权仓库，提交独立分支并创建供用户审阅的 PR。不要发布到任何参考项目作者的仓库。仓库未指定时先完成本地工作，并询问具体目标。

## 参考项目与资料

以下都是参考资料，不是用户授权写入的目标仓库。使用外部代码前检查其 LICENSE、NOTICE、可用性与真实性；当前骨架为本轮新写代码，没有复制参考项目实现。

- Jev 安卓主项目：https://github.com/jev-chat/jev-chat-jarvis
- Jev Windows：https://github.com/jev-chat/jev-chat-windows
- 第三方 iOS 采集原型：https://github.com/pickle-debug/jev-chat-jarvis-ios
  - 2026-09-22 读取的 README 仅说明 UIKit 页面、系统录屏、画中画、收帧计数。
  - 它依赖同级 ../Visyn Swift Package，不能把此仓库当成独立完整聊天助手。
- Apple 自定义键盘：https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- Apple 广播处理：https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler
- Apple 系统广播选择器：https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview
- Apple 文字识别：https://developer.apple.com/documentation/vision/vnrecognizetextrequest
- XcodeGen：https://github.com/yonaskolb/XcodeGen
- Codex 云端创建流程：https://learn.chatgpt.com/docs/cloud

## 尚待用户提供的信息

目标 GitHub/GitLab 仓库或 Codex 环境；iPhone 型号／iOS 版本；是否有 Mac 或 macOS CI；开发者签名条件。API Key 不需要发在聊天里，开发阶段使用假接口测试，安装后由用户填写。

## 如何提交这份材料

在 Codex 云端选择用于此项目的仓库环境。如果页面提供文件附件，可附上本 ZIP；否则将解压内容放入目标仓库，再在任务提示里指定 START_HERE.md。不要假定新的云端任务能自动读取当前对话附件、Library 或当前临时工作区。

任务标题建议：开发 iOS 录屏实时聊天助手（含回复键盘与中越语言选项）。

任务提示建议：请阅读 START_HERE.md、CHAT_CONTEXT.md 和 IMPLEMENTATION_STATUS.md，继续实现用户已选择的 iOS 录屏实时聊天助手。Shared/ 是未经编译的部分骨架，请先审查，再完成主 App、ReplayKit 广播扩展、Vision OCR、回复键盘、工程配置、关键测试和中文安装说明。准确报告编译／真机验证状态，完成后提供修改摘要及可审阅的 PR。
