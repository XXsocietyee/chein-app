import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// Page model for subpackageP3/pages/badge-3d/index. Uses the existing /badge route only.
final class ObjectBadge3DPreviewTests: XCTestCase {
    func testLoadingDoesNotReadALaterRarity() {
        let state = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.explicitZeroRoute,
            scopeMatches: true, reducedMotion: false, settled: false)
        XCTAssertEqual(state, .loading)
        XCTAssertEqual(state.accessibilityIdentifier, "objects.badge3d.loading")
        XCTAssertEqual(state.messageKey, "objects.loading")
        XCTAssertEqual(state.rarityText, "—")
        XCTAssertNotEqual(state.rarityText, "0")
    }

    func testEmptyRoutePublishesNoNumber() {
        let state = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.emptyRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        XCTAssertEqual(state, .empty)
        XCTAssertEqual(state.messageKey, "profile.badges.empty")
        XCTAssertEqual(state.rarityText, "—")
        XCTAssertNotEqual(state.rarityText, "0")
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.state(route: nil, scopeMatches: true, reducedMotion: false, settled: true), .empty)
    }

    func testExplicitZeroStaysZeroAndMissingRarityIsTheEmDash() {
        guard case .ready(let zero) = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.explicitZeroRoute,
            scopeMatches: true, reducedMotion: false, settled: true) else { return XCTFail() }
        XCTAssertEqual(zero.rarityText, "0")
        XCTAssertEqual(zero.rarityKey, "objects.rarity.0")
        XCTAssertEqual(zero.name, "Synthetic badge")
        XCTAssertFalse(zero.showsMesh)

        let missingState = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.unknownRarityRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        guard case .unknown(let missing) = missingState else { return XCTFail() }
        XCTAssertEqual(missing.rarityText, "—")
        XCTAssertNil(missing.rarityKey)
        XCTAssertNotEqual(missing.rarityText, "0")
        XCTAssertEqual(missing.styleKey, "objects.pin")
        XCTAssertEqual(missing.hintKey, "objects.badge3d.hint.pin")
        XCTAssertEqual(missingState.accessibilityIdentifier, "objects.badge3d.unknown")
        XCTAssertEqual(missingState.messageKey, "—")
    }

    func testNoncanonicalRarityDoesNotBecomeZeroOrAClampedGuess() {
        for raw in ["", "-1", "9", "01", "+2", "2 ", "nope"] {
            let state = ObjectBadge3DPreviewCoordinator.state(
                route: "/badge?name=Synthetic&rarity=\(raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)",
                scopeMatches: true, reducedMotion: false, settled: true)
            guard case .unknown(let content) = state else { return XCTFail("\(raw) \(state)") }
            XCTAssertEqual(content.rarityText, "—", raw)
            XCTAssertNotEqual(content.rarityText, "0", raw)
            XCTAssertNotEqual(content.rarityText, "4", raw)
            XCTAssertNil(content.rarityKey, raw)
        }
    }

    func testReadyRouteKeepsTheExistingQueryContractAndHidesAMesh() {
        let state = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.readyRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        guard case .ready(let content) = state else { return XCTFail() }
        XCTAssertEqual(content.name, "Synthetic badge")
        XCTAssertEqual(content.subtitle, "Example")
        XCTAssertEqual(content.style, "enamel")
        XCTAssertEqual(content.glyph, "DEFAULT")
        XCTAssertEqual(content.image, "https://fixtures.invalid/badge.png")
        XCTAssertEqual(content.rarityText, "2")
        XCTAssertEqual(content.rarityKey, "objects.rarity.2")
        XCTAssertEqual(content.hintKey, "objects.badge3d.hint.drag")
        XCTAssertEqual(content.staticPreviewKey, "objects.staticPreview")
        XCTAssertEqual(content.styleKey, "objects.enamel")
        XCTAssertNil(content.titleKey)
        XCTAssertFalse(content.showsMesh)
        XCTAssertEqual(state.accessibilityIdentifier, "objects.badge3d.ready")
        XCTAssertEqual(state.messageKey, "objects.staticPreview")
        XCTAssertEqual(ObjectBadge3DPreviewContent.rarityAccessibilityIdentifier, "objects.badge3d.rarity")
        XCTAssertEqual(ObjectBadge3DPreviewContent.staticPreviewAccessibilityIdentifier, "objects.badge3d.staticPreview")
    }

    func testUnsafeImageIsDroppedAndReducedMotionUsesTheStaticHint() {
        guard case .ready(let content) = ObjectBadge3DPreviewCoordinator.state(
            route: "/badge?name=Synthetic&style=glow&rarity=1&img=javascript%3Aalert",
            scopeMatches: true, reducedMotion: true, settled: true) else { return XCTFail() }
        XCTAssertTrue(content.image.isEmpty)
        XCTAssertEqual(content.hintKey, "objects.badge3d.hint.reduced")
        XCTAssertEqual(content.styleKey, "objects.glow")
        XCTAssertTrue(content.reducedMotion)
        XCTAssertFalse(content.showsMesh)
        guard case .ready(let glow) = ObjectBadge3DPreviewCoordinator.state(
            route: "/badge?name=Synthetic&style=glow&rarity=1",
            scopeMatches: true, reducedMotion: false, settled: true) else { return XCTFail() }
        XCTAssertNil(glow.hintKey)
        XCTAssertFalse(glow.showsMesh)
    }

    func testSessionMismatchAndMalformedLinksAreErrorsWithoutANumber() {
        let session = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.readyRoute,
            scopeMatches: false, reducedMotion: false, settled: true)
        XCTAssertEqual(session, .error(.sessionChanged))
        XCTAssertEqual(session.messageKey, "objects.sessionChanged")
        XCTAssertEqual(session.accessibilityIdentifier, "objects.badge3d.error.session")
        XCTAssertEqual(session.rarityText, "—")
        XCTAssertNotEqual(session.rarityText, "2")
        XCTAssertNotEqual(session.rarityText, "0")

        let malformed = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.malformedRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        XCTAssertEqual(malformed, .error(.malformed))
        XCTAssertEqual(malformed.messageKey, "nativeNav.error.title")
        XCTAssertEqual(malformed.rarityText, "—")
    }

    func testGlyphQueryStaysOffTheLiveRouteAndInAppParametersStillCarryIt() {
        let hidden = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.glyphRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        XCTAssertEqual(hidden, .error(.malformed))
        XCTAssertEqual(hidden.rarityText, "—")
        XCTAssertNotEqual(hidden.rarityText, "0")

        let parameters = ObjectBadgeDetailParameters(
            query: ["name": "Synthetic", "style": "pin", "glyph": "Star", "rarity": "1"], fallbackName: "")
        guard case .ready(let content) = ObjectBadge3DPreviewCoordinator.state(
            intent: .badge(parameters), rarityQuery: "1", scopeMatches: true, reducedMotion: false, settled: true)
        else { return XCTFail() }
        XCTAssertEqual(content.glyph, "Star")
        XCTAssertEqual(content.hintKey, "objects.badge3d.hint.pin")
        XCTAssertFalse(content.showsMesh)
    }

    func testAnotherIntentStaysHidden() {
        let state = ObjectBadge3DPreviewCoordinator.state(
            route: ObjectBadge3DPreviewFixtureData.nonBadgeRoute,
            scopeMatches: true, reducedMotion: false, settled: true)
        XCTAssertEqual(state, .empty)
        XCTAssertEqual(state.rarityText, "—")
        XCTAssertNotEqual(state.accessibilityIdentifier, "objects.badge3d.ready")
    }

    func testFallbackClockUsesRecordedDurationsAndUnknownElapsedIsTheEmDash() {
        let hint = RoamTabFullFeatureParityDescriptor.badge3DFallbackHintMs
        let flat = RoamTabFullFeatureParityDescriptor.badge3DAutoFallbackMs
        XCTAssertEqual(hint, 3_000)
        XCTAssertEqual(flat, 6_000)
        XCTAssertNil(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: nil, reducedMotion: false))
        XCTAssertNil(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: -1, reducedMotion: true))
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.elapsedText(nil), "—")
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.elapsedText(-1), "—")
        XCTAssertNotEqual(ObjectBadge3DPreviewCoordinator.elapsedText(nil), "0")
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.elapsedText(0), "0")
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: 0, reducedMotion: false), .preparing)
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: hint - 1, reducedMotion: false), .preparing)
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: hint, reducedMotion: false), .hint)
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: flat - 1, reducedMotion: false), .hint)
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: flat, reducedMotion: false), .flat)
        XCTAssertEqual(ObjectBadge3DPreviewCoordinator.fallbackPhase(elapsedMs: 0, reducedMotion: true), .flat)
    }

    func testSubtitleOnlyIsUnknownAndUsesTheDetailTitle() {
        guard case .unknown(let content) = ObjectBadge3DPreviewCoordinator.state(
            route: "/badge?sub=Example", scopeMatches: true, reducedMotion: true, settled: true) else { return XCTFail() }
        XCTAssertEqual(content.subtitle, "Example")
        XCTAssertEqual(content.titleKey, "profile.badges.detail")
        XCTAssertEqual(content.rarityText, "—")
        XCTAssertEqual(content.hintKey, "objects.badge3d.hint.reduced")
        XCTAssertFalse(content.showsMesh)
    }
}
#endif
