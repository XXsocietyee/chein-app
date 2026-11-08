import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// Source subpackageP3/pages/badge-3d/index.js + index.wxml (styles, glyph, hints, reduced motion).
final class ObjectBadgeTurntableTests: XCTestCase {
    func testRouteParametersAcceptPinStyleAndGlyphLikeTheMiniProgram() {
        XCTAssertEqual(ObjectBadgeDetailParameters(query: ["style": "pin", "glyph": "Star"], fallbackName: "").style, "pin")
        XCTAssertEqual(ObjectBadgeDetailParameters(query: ["style": "pin", "glyph": "Star"], fallbackName: "").glyph, "Star")
        for bad in ["", "St4r", "has space", String(repeating: "a", count: 25), "星"] {
            XCTAssertEqual(ObjectBadgeDetailParameters(query: ["glyph": bad], fallbackName: "").glyph, "DEFAULT", bad)
        }
        XCTAssertEqual(ObjectBadgeDetailParameters(query: ["style": "other"], fallbackName: "").style, "enamel")
        XCTAssertEqual(ObjectBadgeDetailParameters(query: ["style": "glow"], fallbackName: "").style, "glow")
    }

    func testDragRotatesAndCommitsOnEnd() {
        var table = ObjectBadgeTurntable(style: "enamel", reducedMotion: false)
        table.drag(translationWidth: 100)
        XCTAssertEqual(table.angle, 50, accuracy: 0.0001)
        table.endDrag()
        XCTAssertEqual(table.angle, 50, accuracy: 0.0001); XCTAssertEqual(table.liveTranslation, 0)
        table.drag(translationWidth: -40)
        XCTAssertEqual(table.angle, 30, accuracy: 0.0001)
        table.drag(translationWidth: .nan)
        XCTAssertEqual(table.angle, 30, accuracy: 0.0001, "a non-finite drag is ignored")
    }

    func testTapSpinsOnlyPinBadges() {
        var pin = ObjectBadgeTurntable(style: "pin", reducedMotion: false)
        pin.tap(); XCTAssertEqual(pin.angle, 360, accuracy: 0.0001)
        var enamel = ObjectBadgeTurntable(style: "enamel", reducedMotion: false)
        enamel.tap(); XCTAssertEqual(enamel.angle, 0)
    }

    func testReducedMotionAndGlowStayStaticWithSourceHints() {
        var reduced = ObjectBadgeTurntable(style: "pin", reducedMotion: true)
        reduced.drag(translationWidth: 300); reduced.tap()
        XCTAssertEqual(reduced.angle, 0); XCTAssertEqual(reduced.hintKey, "objects.badge3d.hint.reduced")
        var glow = ObjectBadgeTurntable(style: "glow", reducedMotion: false)
        glow.drag(translationWidth: 300)
        XCTAssertEqual(glow.angle, 0); XCTAssertNil(glow.hintKey)
        XCTAssertEqual(ObjectBadgeTurntable(style: "pin", reducedMotion: false).hintKey, "objects.badge3d.hint.pin")
        XCTAssertEqual(ObjectBadgeTurntable(style: "enamel", reducedMotion: false).hintKey, "objects.badge3d.hint.drag")
    }
}
#endif
