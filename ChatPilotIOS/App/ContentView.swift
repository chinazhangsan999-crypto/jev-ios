import SwiftUI

struct ContentView: View {
  @StateObject private var model = AppViewModel()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          StatusCard(state: model.state)
          if !model.notice.isEmpty {
            Label(model.notice, systemImage: "info.circle")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("当前状态")
        }

        Section {
          Toggle(isOn: $model.settings.consent) {
            Text("允许发送 OCR 聊天文字")
            Text("仅发送识别文字到你配置的模型接口")
          }
          Label("不上传截图、不录制音频、不自动发送", systemImage: "hand.raised.fill")
            .font(.footnote).foregroundStyle(.secondary)
        } header: {
          Text("隐私授权")
        } footer: {
          Text("停止、切换会话或候选过期时会清除临时上下文。模型服务商可能按其条款处理文本。")
        }

        Section {
          TextField("Chat Completions 完整 HTTPS 地址", text: $model.settings.endpoint)
            .textInputAutocapitalization(.never).keyboardType(.URL)
            .textContentType(.URL)
          TextField("模型名称（必填）", text: $model.settings.model)
            .textInputAutocapitalization(.never)
          SecureField("API Key（留空则保留已保存值）", text: $model.apiKey)
            .textContentType(.password)
          Label(
            model.hasStoredKey ? "已在共享钥匙串保存密钥" : "尚未保存密钥",
            systemImage: model.hasStoredKey ? "key.fill" : "key"
          )
          .font(.caption)
          .foregroundStyle(model.hasStoredKey ? Color.green : Color.secondary)
          Picker("回复语言", selection: $model.settings.replyLanguage) {
            Text("中文").tag("中文")
            Text("越南语（附中文译文）").tag("越南语")
            Text("英语（附中文译文）").tag("英语")
          }
          TextField("回复风格", text: $model.settings.style)
          Button {
            model.save()
          } label: {
            Label("保存并校验设置", systemImage: "checkmark.shield")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(!model.canSave)
          Button("删除 API Key", role: .destructive) { model.clearKey() }
            .disabled(!model.hasStoredKey)
        } header: {
          Text("模型与回复")
        } footer: {
          Text("接口必须是无查询参数、无账号密码的完整 HTTPS Chat Completions 地址。")
        }

        Section {
          LabeledContent(
            "顶部", value: model.settings.cropTop.formatted(.percent.precision(.fractionLength(0))))
          Slider(
            value: $model.settings.cropTop,
            in: 0...min(0.35, model.settings.cropBottom - 0.15), step: 0.01
          )
          .accessibilityLabel("识别区域顶部")
          LabeledContent(
            "底部", value: model.settings.cropBottom.formatted(.percent.precision(.fractionLength(0)))
          )
          Slider(
            value: $model.settings.cropBottom,
            in: max(0.3, model.settings.cropTop + 0.15)...0.65, step: 0.01
          )
          .accessibilityLabel("识别区域底部")
          Stepper(
            "最短请求间隔：\(Int(model.settings.requestInterval)) 秒",
            value: $model.settings.requestInterval, in: 8...60, step: 1)
        } header: {
          Text("竖屏识别区域")
        } footer: {
          Text("只识别聊天内容区域，避开输入框和 ChatPilot 回复键盘，防止候选文字被再次识别。")
        }

        Section {
          HStack {
            BroadcastPicker().frame(width: 52, height: 52)
              .accessibilityLabel("打开系统屏幕广播选择器")
            VStack(alignment: .leading, spacing: 4) {
              Text("开启系统广播").font(.headline)
              Text("长按左侧按钮，选择 ChatPilot Broadcast")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          Label("开始后前往聊天 App，切换到 ChatPilot 回复键盘并连接当前会话。", systemImage: "keyboard")
            .font(.footnote)
          Button(role: .destructive) {
            model.stopAndClear()
          } label: {
            Label("暂停分析并清除临时内容", systemImage: "stop.circle")
          }
        } header: {
          Text("开始与停止")
        }

        Section {
          DisclosureGroup("使用限制与安全提醒") {
            Text("首版仅支持竖屏单聊。左右位置不是可靠身份。切换联系人、群组或 App 后必须重新连接。候选仅供参考，填入后请核对并手动发送。")
              .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("ChatPilot")
    }
  }
}

private struct StatusCard: View {
  let state: BroadcastState

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: state.running ? "record.circle.fill" : "record.circle")
        .font(.title2)
        .foregroundStyle(state.running ? Color.red : Color.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(state.running ? "广播运行中" : "广播未运行").font(.headline)
        Text(state.message).font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}
