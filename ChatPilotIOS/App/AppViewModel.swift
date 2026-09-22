import Combine
import Foundation
import Security

@MainActor
final class AppViewModel: ObservableObject {
  @Published var settings = SharedStore.settings
  @Published var apiKey = ""
  @Published var state = SharedStore.state
  @Published var notice = ""
  @Published private(set) var hasStoredKey = false
  private var timer: Timer?

  init() {
    hasStoredKey = (try? KeychainStore.load()) != nil
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.state = SharedStore.state }
    }
  }

  func save() {
    do {
      _ = try settings.validatedURL()
      try SharedStore.write(settings, to: SharedFile.settings)
      if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try KeychainStore.save(apiKey)
        apiKey = ""
        hasStoredKey = true
      } else {
        _ = try KeychainStore.load()
      }
      notice = "设置已保存。API Key 仅存入共享钥匙串。"
    } catch { notice = error.localizedDescription }
  }

  func stopAndClear() {
    do {
      try SharedStore.write(StopSignal(), to: SharedFile.stop)
      if var control = SharedStore.read(SharedFile.control, as: Control.self) {
        control.stop = true
        control.armedUntil = .distantPast
        try SharedStore.write(control, to: SharedFile.control)
      }
      notice = "已发出停止信号；请在系统录屏界面确认广播停止。临时候选已清除。"
      state = BroadcastState(message: notice)
      // The broadcast extension is the sole state writer while running.
      if !SharedStore.state.running { try? SharedStore.remove(SharedFile.state) }
    } catch { notice = error.localizedDescription }
  }

  func clearKey() {
    let status = KeychainStore.delete()
    if status == errSecSuccess || status == errSecItemNotFound {
      hasStoredKey = false
      notice = "API Key 已删除。"
    } else {
      notice = "删除失败（\(status)）。"
    }
  }

  var canSave: Bool {
    (try? settings.validatedURL()) != nil
      && (hasStoredKey || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
}
