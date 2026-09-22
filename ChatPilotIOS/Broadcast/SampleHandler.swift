import Foundation
import ReplayKit
import CryptoKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let work = DispatchQueue(label: "chatpilot.broadcast")
    private let frameSlot = DispatchSemaphore(value: 1)
    private let reader = ScreenReader()
    private var timer: DispatchSourceTimer?
    private var request: Task<Void, Never>?
    private var requestID = UUID()
    private var gate = ContextGate()
    private var state = BroadcastState()
    private var lastFrame = Date.distantPast
    private var lastOCR = Date.distantPast
    private var configFingerprint = Data()
    private var paused = false
    private var ended = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        work.async { [weak self] in
            guard let self else { return }
            do {
                guard SharedStore.available, SharedStore.settings.consent else { throw PilotError.configuration }
                _ = try SharedStore.settings.validatedURL()
                _ = try KeychainStore.load()
                self.state.running = true
                self.state.message = "广播已开启：切到聊天并在回复键盘点击连接。"
                self.publish()
                let timer = DispatchSource.makeTimerSource(queue: self.work)
                timer.schedule(deadline: .now() + 1, repeating: 1)
                timer.setEventHandler { [weak self] in self?.tick() }
                self.timer = timer
                timer.resume()
            } catch { self.finish(error.localizedDescription) }
        }
    }

    override func broadcastPaused() {
        work.async { [weak self] in
            guard let self else { return }
            self.paused = true
            self.invalidate("录屏暂停，候选已清除。")
            self.publish()
        }
    }
    override func broadcastResumed() {
        work.async { [weak self] in self?.paused = false }
    }
    override func broadcastFinished() {
        work.async { [weak self] in self?.end() }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, frameSlot.wait(timeout: .now()) == .success else { return }
        work.async { [weak self] in
            guard let self else { return }
            defer { self.frameSlot.signal() }
            autoreleasepool { self.process(sampleBuffer) }
        }
    }

    private func allowed(_ control: Control) -> Bool {
        !ended && !paused && SharedStore.settings.consent && control.permitsAnalysis() &&
        (SharedStore.read("stop.json", as: StopSignal.self)?.at ?? .distantPast) < control.startedAt
    }

    private func process(_ sample: CMSampleBuffer) {
        guard !ended else { return }
        lastFrame = Date()
        let control = SharedStore.control
        guard allowed(control) else { return }
        let settings = SharedStore.settings
        let config = (try? JSONEncoder().encode(settings)) ?? Data()
        if state.session != control.session || config != configFingerprint {
            invalidate("已连接当前会话，等待画面稳定。")
            state.session = control.session
            configFingerprint = config
        }
        let now = Date()
        guard now.timeIntervalSince(lastOCR) >= 1.5 else { return }
        lastOCR = now
        do {
            _ = try settings.validatedURL()
            let result = try reader.read(sample, settings: settings)
            state.languages = result.languages
            let fingerprint = result.transcript.isEmpty ? "" : SHA256.hash(data: Data(result.transcript.utf8)).map { String(format: "%02x", $0) }.joined()
            if gate.observe(fingerprint, now: now) {
                cancelRequest()
                state.payload = nil
                state.generatedAt = nil
                state.contextID = UUID().uuidString
                state.sourcePreview = String(result.transcript.suffix(220))
                state.message = fingerprint.isEmpty ? "未读到文字，请调整识别区域。" : "画面有变化，等待稳定后生成。"
            }
            guard request == nil, gate.ready(now: now, interval: settings.requestInterval) else {
                publish(); return
            }
            gate.begin(now: now)
            state.message = "正在生成三条回复…"
            publish()
            let generation = gate.generation
            let id = UUID()
            requestID = id
            let sessionID = control.session
            request = Task { [weak self] in
                do {
                    let payload = try await ModelClient.generate(transcript: result.transcript, settings: settings)
                    try Task.checkCancellation()
                    self?.work.async { [weak self] in
                        guard let self, self.requestID == id else { return }
                        self.request = nil
                        let current = SharedStore.control
                        guard self.allowed(current), current.session == sessionID,
                              self.gate.generation == generation,
                              Date().timeIntervalSince(self.lastFrame) < 5 else { return }
                        self.gate.succeed(generation: generation)
                        self.state.payload = payload
                        self.state.generatedAt = Date()
                        self.state.message = "建议已更新；核对当前会话后再填入。"
                        self.publish()
                    }
                } catch {
                    self?.work.async { [weak self] in
                        guard let self, self.requestID == id else { return }
                        self.request = nil
                        self.state.message = error is CancellationError ? "请求已取消。" : "生成失败，请检查模型设置／网络；稍后重试。"
                        if let safe = error as? PilotError { self.state.message = safe.localizedDescription }
                        self.publish()
                    }
                }
            }
        } catch {
            invalidate("识别失败：请确认竖屏、识别区域和系统 OCR 支持。")
            publish()
        }
    }

    private func tick() {
        guard !ended else { return }
        let control = SharedStore.control
        if let stop = SharedStore.read("stop.json", as: StopSignal.self), stop.at >= control.startedAt {
            finish("已按你的要求停止屏幕广播。")
            return
        }
        if !allowed(control) {
            invalidate("分析已暂停：请打开回复键盘并连接当前会话。")
        } else if Date().timeIntervalSince(lastFrame) > 5 {
            invalidate("暂未收到画面；请检查系统录屏状态。")
        } else if let generated = state.generatedAt, Date().timeIntervalSince(generated) >= 90 {
            // Do not re-query an unchanged chat endlessly. User may reconnect to refresh.
            state.payload = nil
            state.generatedAt = nil
            state.sourcePreview = ""
            state.message = "建议已过期，点击重新连接可刷新。"
        }
        publish()
    }

    private func cancelRequest() {
        requestID = UUID()
        request?.cancel()
        request = nil
    }
    private func invalidate(_ message: String) {
        cancelRequest()
        gate.reset()
        state.payload = nil
        state.generatedAt = nil
        state.sourcePreview = ""
        state.contextID = ""
        state.message = message
    }
    private func publish() {
        state.updated = Date()
        do { try SharedStore.write(state, to: "state.json") }
        catch {
            cancelRequest()
            // Fail closed if the shared state cannot be safely delivered.
            if !ended { finish("无法写入受保护的共享状态，屏幕广播已停止。") }
        }
    }
    private func finish(_ message: String) {
        end()
        finishBroadcastWithError(NSError(domain: "ChatPilot", code: 2,
                                         userInfo: [NSLocalizedDescriptionKey: message]))
    }
    private func end() {
        guard !ended else { return }
        ended = true
        timer?.cancel(); timer = nil
        invalidate("屏幕广播已结束。")
        state.running = false
        state.languages = []
        state.session = ""
        state.updated = Date()
        try? SharedStore.write(state, to: "state.json")
    }
}
