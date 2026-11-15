import XCTest
@testable import QuestifyCore

@MainActor
final class NewGameTypesAndAudioClipTests: XCTestCase {
    private final class StubAudioClipCapturer: PlayAudioClipCapturing {
        var nextClip: PlayRecordedAudioClip?
        var interruptedCallback: (() -> Void)?
        private(set) var cancelled = false

        func startRecording(onInterruption: @escaping () -> Void) async throws {
            cancelled = false
            interruptedCallback = onInterruption
        }

        func stopRecording() async throws -> PlayRecordedAudioClip {
            guard let nextClip else { throw PlayExperienceError.invalidAction }
            return nextClip
        }

        func cancelRecording() {
            cancelled = true
        }
    }

    func testAudioClipConfigurationAndModelEnforcesMinimumAndProducesPayload() async throws {
        XCTAssertThrowsError(try PlayAudioClipConfiguration(raw: .object(["minDurationSec": .int(0)])))
        XCTAssertThrowsError(try PlayAudioClipConfiguration(raw: .object(["minDurationSec": .int(61)])))
        let config = try PlayAudioClipConfiguration(raw: .object(["minDurationSec": .int(3)]))

        let capturer = StubAudioClipCapturer()
        capturer.nextClip = try PlayRecordedAudioClip(bytes: Data([1, 2, 3]), mimeType: "audio/m4a", durationSeconds: 2)
        let model = PlayAudioClipModel(configuration: config, capturer: capturer)
        await model.start()
        XCTAssertEqual(model.phase, .recording)
        await model.stopAndUpload { _, _ in "https://cdn.example.com/clip.m4a" }
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(model.failureReason, "duration_below_minimum")
        XCTAssertNil(model.sourcePayload)

        capturer.nextClip = try PlayRecordedAudioClip(bytes: Data([4, 5, 6]), mimeType: "audio/m4a", durationSeconds: 4)
        await model.start()
        await model.stopAndUpload { _, _ in "https://cdn.example.com/clip.m4a" }
        XCTAssertEqual(model.phase, .completed)
        XCTAssertEqual(model.sourcePayload, [
            "durationSec": .int(4),
            "mediaUrl": .string("https://cdn.example.com/clip.m4a"),
        ])

        await model.start()
        model.reset()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(capturer.cancelled)
    }

    func testScratchProgressTrackerNeverAutoWinsOnZeroThresholdAndCrossesOnce() {
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(0), CYScratchProgressTracker.defaultThreshold, accuracy: 0.0001)
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(-1), CYScratchProgressTracker.defaultThreshold, accuracy: 0.0001)
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(1.5), 1.0, accuracy: 0.0001)

        var tracker = CYScratchProgressTracker(width: 160, height: 80, threshold: 0.45)
        var crossings = 0
        for row in stride(from: 8.0, through: 72.0, by: 16.0) {
            if tracker.stamp(from: .init(x: 8, y: row), to: .init(x: 152, y: row), radius: 22) {
                crossings += 1
            }
        }
        XCTAssertEqual(crossings, 1)
        XCTAssertTrue(tracker.revealed)
        XCTAssertGreaterThanOrEqual(tracker.progress, 0.45)
    }

    func testNewMiniGamesActionCatalogProjectionAndInputContracts() throws {
        XCTAssertEqual(PlayKitActionCatalog.actions["trueFalse"], ["SUBMIT_TRUE_FALSE"])
        XCTAssertEqual(PlayKitActionCatalog.actions["imageGuess"], ["SUBMIT_IMAGE_GUESS"])
        XCTAssertEqual(PlayKitActionCatalog.actions["jigsaw"], ["SUBMIT_JIGSAW"])
        XCTAssertEqual(PlayKitActionCatalog.actions["scratchCard"], ["SUBMIT_SCRATCH_CARD"])

        let tfSegment: PlayWireValue = .object(["enabled": .bool(true), "finished": .bool(false)])
        try PlayKitInputContract.validate(kind: "trueFalse", action: "SUBMIT_TRUE_FALSE", payload: ["answer": .bool(true)], segment: tfSegment)
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "trueFalse", action: "SUBMIT_TRUE_FALSE", payload: ["answer": .string("yes")], segment: tfSegment))

        let igSegment: PlayWireValue = .object(["enabled": .bool(true), "revealLevel": .int(1), "totalClues": .int(2), "finished": .bool(false)])
        try PlayKitInputContract.validate(kind: "imageGuess", action: "SUBMIT_IMAGE_GUESS", payload: ["action": .string("REVEAL_STEP")], segment: igSegment)
        try PlayKitInputContract.validate(kind: "imageGuess", action: "SUBMIT_IMAGE_GUESS", payload: ["guess": .string("Bell Tower")], segment: igSegment)

        let jigsawSegment: PlayWireValue = .object(["enabled": .bool(true), "rows": .int(2), "cols": .int(2), "solved": .bool(false)])
        try PlayKitInputContract.validate(kind: "jigsaw", action: "SUBMIT_JIGSAW", payload: ["order": .array([.int(0), .int(1), .int(2), .int(3)])], segment: jigsawSegment)
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "jigsaw", action: "SUBMIT_JIGSAW", payload: ["order": .array([.int(0), .int(0), .int(2), .int(3)])], segment: jigsawSegment))

        let scratchSegment: PlayWireValue = .object(["enabled": .bool(true), "revealed": .bool(false)])
        try PlayKitInputContract.validate(kind: "scratchCard", action: "SUBMIT_SCRATCH_CARD", payload: ["progress": .number(0.5)], segment: scratchSegment)
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "scratchCard", action: "SUBMIT_SCRATCH_CARD", payload: ["progress": .number(0)], segment: scratchSegment))

        let solvedJigsaw = PlayKitScreenProjection(kind: .jigsaw, segment: .object(["solved": .bool(true), "finished": .bool(true), "passed": .bool(true)]))
        XCTAssertTrue(solvedJigsaw.complete)
        XCTAssertEqual(solvedJigsaw.reportedPass, true)
    }

    func testUG02ImageOptionAuthoringSchemaAndUG07ZeroMaxTriesRetry() throws {
        var draft = TemplateAdvancedDraft()
        draft.setCreatorEnabled(.qa, true)
        draft.set("qa", "mode", .string("PICK"))
        draft.set("qa", "title", .string("Pick photo"))
        draft.set("qa", "maxTries", .number(0))
        draft.set("qa", "options", .array([
            .object(["id": .string("o1"), "label": .string("One"), "img": .string("https://cdn.example.com/1.jpg"), "alt": .string("Photo one"), "correct": .bool(true)]),
            .object(["id": .string("o2"), "label": .string("Two"), "img": .string("https://cdn.example.com/2.jpg"), "alt": .string("Photo two"), "correct": .bool(false)]),
        ]))
        XCTAssertTrue(draft.creatorIssues(.qa).isEmpty)

        // UG-07: maxTries == 0 and sort maxAttempts == 0 remain retryable across wrong attempts when finished != true.
        let freeRetryQA: PlayWireValue = .object([
            "mode": .string("PICK"),
            "maxTries": .int(0),
            "attempts": .int(4),
            "finished": .bool(false),
            "passed": .bool(false),
            "options": .array([.object(["id": .string("o1"), "label": .string("One")])]),
        ])
        XCTAssertFalse(PlayKitScreenProjection(kind: .qa, segment: freeRetryQA).complete)
        try PlayKitInputContract.validate(kind: "qa", action: "SUBMIT_QA", payload: ["optionId": .string("o1")], segment: freeRetryQA)

        let freeRetrySort: PlayWireValue = .object([
            "maxAttempts": .int(0),
            "attempts": .int(5),
            "finished": .bool(false),
            "passed": .bool(false),
            "items": .array([.object(["id": .string("a"), "label": .string("A")]), .object(["id": .string("b"), "label": .string("B")])]),
        ])
        XCTAssertFalse(PlayKitScreenProjection(kind: .sort, segment: freeRetrySort).complete)
        try PlayKitInputContract.validate(kind: "sort", action: "SUBMIT_SORT", payload: ["order": .array([.string("a"), .string("b")])], segment: freeRetrySort)
    }
}
