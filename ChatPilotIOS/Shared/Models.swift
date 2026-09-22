import Foundation

struct Settings: Codable {
    var endpoint = "https://openrouter.ai/api/v1/chat/completions"
    var model = ""
    var replyLanguage = "越南语"
    var style = "自然、简短；附中文译文；不要臆测对方真实意图"
    var consent = false
    // Screen fractions measured from the TOP, in the displayed orientation.
    var cropTop = 0.12
    var cropBottom = 0.52
    var requestInterval: Double = 12

    func validatedURL() throws -> URL {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.fragment == nil,
              url.query == nil, !model.trimmingCharacters(in: .whitespaces).isEmpty,
              cropTop >= 0, cropBottom <= 0.65, cropBottom - cropTop >= 0.15,
              requestInterval >= 8 else { throw PilotError.configuration }
        return url
    }
}

struct Candidate: Codable, Equatable {
    var text: String
    var translation: String
}

struct SuggestionPayload: Codable {
    var summary: String
    var replies: [Candidate]

    static func parse(_ content: String) throws -> SuggestionPayload {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            var lines = text.components(separatedBy: "\n")
            lines.removeFirst()
            if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
            text = lines.joined(separator: "\n")
        }
        guard let data = text.data(using: .utf8) else { throw PilotError.response }
        let result = try JSONDecoder().decode(SuggestionPayload.self, from: data)
        guard result.replies.count == 3,
              result.replies.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 500 && $0.translation.count <= 1000 }),
              Set(result.replies.map(\.text)).count == 3 else { throw PilotError.response }
        return result
    }
}

struct Control: Codable {
    var session = UUID().uuidString
    var startedAt = Date()
    var keyboardHeartbeat: Date = .distantPast
    var armedUntil: Date = .distantPast
    var stop = false
    func permitsAnalysis(now: Date = Date()) -> Bool {
        !stop && now < armedUntil && now.timeIntervalSince(keyboardHeartbeat) < 4
    }
}

struct StopSignal: Codable { var at = Date() }

/// Shared deterministic state machine; no screen data is stored by this type.
struct ContextGate {
    private(set) var fingerprint = ""
    private(set) var generation = 0
    private(set) var stableSince = Date.distantPast
    private(set) var submitted = ""
    private(set) var lastAttempt = Date.distantPast

    mutating func observe(_ value: String, now: Date) -> Bool {
        guard value != fingerprint else { return false }
        fingerprint = value
        generation += 1
        stableSince = now
        return true
    }
    func ready(now: Date, interval: Double) -> Bool {
        !fingerprint.isEmpty && fingerprint != submitted &&
        now.timeIntervalSince(stableSince) >= 2 &&
        now.timeIntervalSince(lastAttempt) >= max(8, interval)
    }
    mutating func begin(now: Date) { lastAttempt = now }
    mutating func succeed(generation expected: Int) {
        if generation == expected { submitted = fingerprint }
    }
    mutating func reset() { self = ContextGate() }
}

struct BroadcastState: Codable {
    var updated = Date()
    var running = false
    var message = "尚未开启屏幕广播"
    var session = ""
    var contextID = ""
    var sourcePreview = ""
    var payload: SuggestionPayload?
    var generatedAt: Date?
    var languages: [String] = []
    var id: String { session + contextID + (generatedAt?.description ?? "") }
    func isFresh(control: Control, now: Date = Date()) -> Bool {
        running && control.permitsAnalysis(now: now) && session == control.session &&
        now.timeIntervalSince(updated) < 6 &&
        generatedAt.map { now.timeIntervalSince($0) < 90 } == true && payload != nil
    }
}

enum PilotError: LocalizedError {
    case configuration, keychain(Int32), missingKey, response, http(Int), oversized
    var errorDescription: String? {
        switch self {
        case .configuration: return "检查 HTTPS 接口、模型名称和识别区域设置。"
        case .keychain(let code): return "钥匙串访问失败（\(code)），请检查签名与 Keychain Sharing。"
        case .missingKey: return "请先在主 App 保存 API Key。"
        case .response: return "模型未返回有效的三条回复，请换用支持 JSON 指令的聊天模型。"
        case .http(let code): return "模型接口返回 HTTP \(code)。检查额度、模型与权限。"
        case .oversized: return "接口响应过大，已停止读取。"
        }
    }
}
