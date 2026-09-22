import Foundation
import Testing

@testable import ChatPilotCore

@Test func configurationAcceptsOnlyConstrainedHTTPS() throws {
  var settings = Settings()
  settings.model = "model"
  #expect(throws: Never.self) { try settings.validatedURL() }

  for endpoint in [
    "http://example.com/v1/chat/completions",
    "https://user:password@example.com/path",
    "https://example.com/path?token=secret",
    "not a url",
  ] {
    settings.endpoint = endpoint
    #expect(throws: PilotError.self) { try settings.validatedURL() }
  }
}

@Test func configurationRejectsUnsafeCropAndAggressivePolling() {
  var settings = Settings()
  settings.model = "model"
  settings.cropTop = 0.30
  settings.cropBottom = 0.40
  #expect(throws: PilotError.self) { try settings.validatedURL() }
  settings.cropBottom = 0.50
  settings.requestInterval = 7
  #expect(throws: PilotError.self) { try settings.validatedURL() }
}

@Test func responseRequiresThreeDistinctBoundedReplies() throws {
  let valid =
    #"{"summary":"摘要","replies":[{"text":" 一 ","translation":"1"},{"text":"二","translation":"2"},{"text":"三","translation":"3"}]}"#
  let parsed = try SuggestionPayload.parse("```json\n\(valid)\n```")
  #expect(parsed.replies.map(\.text) == ["一", "二", "三"])

  let duplicate =
    #"{"summary":"摘要","replies":[{"text":"Same","translation":"1"},{"text":" same ","translation":"2"},{"text":"three","translation":"3"}]}"#
  #expect(throws: Error.self) { try SuggestionPayload.parse(duplicate) }
  #expect(throws: Error.self) { try SuggestionPayload.parse("not-json") }
}

@Test func changedContextCannotCompleteAnOldGeneration() {
  let start = Date(timeIntervalSince1970: 100)
  var gate = ContextGate()
  let observedFirst = gate.observe("first", now: start)
  #expect(observedFirst)
  #expect(!gate.ready(now: start.addingTimeInterval(1), interval: 8))
  #expect(gate.ready(now: start.addingTimeInterval(9), interval: 8))
  let staleGeneration = gate.generation
  gate.begin(now: start.addingTimeInterval(9))
  let observedSecond = gate.observe("second", now: start.addingTimeInterval(10))
  #expect(observedSecond)
  gate.succeed(generation: staleGeneration)
  #expect(gate.ready(now: start.addingTimeInterval(18), interval: 8))
}

@Test func analysisFailsClosedForPauseStopConsentAndStaleHeartbeat() {
  let now = Date(timeIntervalSince1970: 1_000)
  var control = Control(
    startedAt: now.addingTimeInterval(-1), keyboardHeartbeat: now,
    armedUntil: now.addingTimeInterval(60), stop: false)
  #expect(
    AnalysisPolicy.permits(
      ended: false, paused: false, consent: true,
      control: control, stop: nil, now: now))
  #expect(
    !AnalysisPolicy.permits(
      ended: false, paused: true, consent: true,
      control: control, stop: nil, now: now))
  #expect(
    !AnalysisPolicy.permits(
      ended: false, paused: false, consent: false,
      control: control, stop: nil, now: now))
  #expect(
    !AnalysisPolicy.permits(
      ended: false, paused: false, consent: true,
      control: control, stop: StopSignal(at: now), now: now))
  control.keyboardHeartbeat = now.addingTimeInterval(-4)
  #expect(
    !AnalysisPolicy.permits(
      ended: false, paused: false, consent: true,
      control: control, stop: nil, now: now))
}

@Test func suggestionsExpireAndMustMatchTheSession() {
  let now = Date(timeIntervalSince1970: 2_000)
  let control = Control(
    startedAt: now.addingTimeInterval(-1), keyboardHeartbeat: now,
    armedUntil: now.addingTimeInterval(60), stop: false)
  let payload = SuggestionPayload(
    summary: "s",
    replies: [
      Candidate(text: "1", translation: ""), Candidate(text: "2", translation: ""),
      Candidate(text: "3", translation: ""),
    ])
  var state = BroadcastState(
    updated: now, running: true, message: "", session: control.session,
    contextID: "context", sourcePreview: "", payload: payload,
    generatedAt: now, languages: [])
  #expect(state.isFresh(control: control, now: now))
  state.session = UUID().uuidString
  #expect(!state.isFresh(control: control, now: now))
  state.session = control.session
  state.generatedAt = now.addingTimeInterval(-91)
  #expect(!state.isFresh(control: control, now: now))
}

@Test func keychainFailuresHaveActionableMessages() {
  #expect(PilotError.keychain(-34018).localizedDescription.contains("Keychain Sharing"))
  #expect(PilotError.missingKey.localizedDescription.contains("API Key"))
}
