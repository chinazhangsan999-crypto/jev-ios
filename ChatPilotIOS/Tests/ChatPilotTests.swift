import XCTest
@testable import ChatPilot

final class ChatPilotTests: XCTestCase {
    func testRejectsUnsafeOrIncompleteConfiguration() {
        var value = Settings()
        value.model = "test-model"
        XCTAssertNoThrow(try value.validatedURL())
        value.endpoint = "http://example.com/v1/chat/completions"
        XCTAssertThrowsError(try value.validatedURL())
        value.endpoint = "https://user:password@example.com/path"
        XCTAssertThrowsError(try value.validatedURL())
        value.endpoint = "https://example.com/path?key=secret"
        XCTAssertThrowsError(try value.validatedURL())
    }

    func testParsesExactlyThreeDistinctRepliesAndCodeFence() throws {
        let json = #"{"summary":"摘要","replies":[{"text":"一","translation":"1"},{"text":"二","translation":"2"},{"text":"三","translation":"3"}]}"#
        XCTAssertEqual(try SuggestionPayload.parse("```json\n\(json)\n```").replies.count, 3)
        let duplicate = #"{"summary":"摘要","replies":[{"text":"一","translation":"1"},{"text":"一","translation":"2"},{"text":"三","translation":"3"}]}"#
        XCTAssertThrowsError(try SuggestionPayload.parse(duplicate))
        XCTAssertThrowsError(try SuggestionPayload.parse("not-json"))
    }

    func testContextGateRejectsOldGeneration() {
        let start = Date(timeIntervalSince1970: 100)
        var gate = ContextGate()
        XCTAssertTrue(gate.observe("first", now: start))
        XCTAssertFalse(gate.ready(now: start.addingTimeInterval(1), interval: 8))
        XCTAssertTrue(gate.ready(now: start.addingTimeInterval(9), interval: 8))
        let oldGeneration = gate.generation
        gate.begin(now: start.addingTimeInterval(9))
        XCTAssertTrue(gate.observe("second", now: start.addingTimeInterval(10)))
        gate.succeed(generation: oldGeneration)
        XCTAssertTrue(gate.ready(now: start.addingTimeInterval(18), interval: 8))
    }

    func testPauseStopAndConsentFailClosed() {
        let now = Date()
        var control = Control(startedAt: now.addingTimeInterval(-1), keyboardHeartbeat: now,
                              armedUntil: now.addingTimeInterval(60), stop: false)
        XCTAssertTrue(AnalysisPolicy.permits(ended: false, paused: false, consent: true,
                                             control: control, stop: nil, now: now))
        XCTAssertFalse(AnalysisPolicy.permits(ended: false, paused: true, consent: true,
                                              control: control, stop: nil, now: now))
        XCTAssertFalse(AnalysisPolicy.permits(ended: false, paused: false, consent: false,
                                              control: control, stop: nil, now: now))
        XCTAssertFalse(AnalysisPolicy.permits(ended: false, paused: false, consent: true,
                                              control: control, stop: StopSignal(at: now), now: now))
        control.keyboardHeartbeat = now.addingTimeInterval(-5)
        XCTAssertFalse(AnalysisPolicy.permits(ended: false, paused: false, consent: true,
                                              control: control, stop: nil, now: now))
    }

    func testCandidateMustStillBeFreshAtInsertionTime() {
        let now = Date()
        let control = Control(startedAt: now.addingTimeInterval(-1), keyboardHeartbeat: now,
                              armedUntil: now.addingTimeInterval(60), stop: false)
        let payload = SuggestionPayload(summary: "s", replies: [Candidate(text: "1", translation: ""), Candidate(text: "2", translation: ""), Candidate(text: "3", translation: "")])
        var state = BroadcastState(updated: now, running: true, message: "", session: control.session,
                                   contextID: "context", sourcePreview: "", payload: payload,
                                   generatedAt: now, languages: [])
        XCTAssertTrue(state.isFresh(control: control, now: now))
        state.generatedAt = now.addingTimeInterval(-91)
        XCTAssertFalse(state.isFresh(control: control, now: now))
    }

    func testKeychainFailureHasActionableMessage() {
        XCTAssertTrue(PilotError.keychain(-34018).localizedDescription.contains("Keychain Sharing"))
        XCTAssertTrue(PilotError.missingKey.localizedDescription.contains("API Key"))
    }
}
