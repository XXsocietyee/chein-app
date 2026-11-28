import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Questify

/// Hosts the shared components K26 changed at AX-XXXL (`.accessibility5`) and checks they
/// stay inside the offered width and grow taller than the default size. This is a layout
/// measurement, not a screenshot. It does not run without UIKit.
@MainActor
final class DynamicTypeAX5SharedComponentsTests: XCTestCase {
    private let english = "Confirm and pay with Apple Pay along the old city wall"
    private let place = "North gate of the old city wall, past the lantern market"
    private let chinese = "这是一段用于验证超大字体换行的城市漫游活动标题，不应被裁成一个字。"

    func testSharedComponentsGrowAtAccessibilityXXXLWithoutHorizontalOverflow() {
        #if canImport(UIKit)
        assertGrows(width: 320) {
            CYPayButton(title: self.english, amount: "¥1,280.00", action: {})
        }
        assertGrows(width: 320) {
            CYHeroBanner(items: [
                CYHeroBannerItem(id: 1, imageURL: nil, accessibilityLabel: nil, title: Text(verbatim: self.english), subtitle: Text(verbatim: self.place)),
            ])
        }
        assertGrows(width: 320) {
            CYCarouselCaption(title: self.english, date: "Nov 28", place: self.place)
        }
        assertGrows(width: 280) {
            CYMapCallout(text: self.place)
        }
        assertGrows(width: 320) {
            CYRootSubtitle(verbatim: self.english)
        }
        assertGrows(width: 320) {
            CYMedalDeck(items: [CYMedalItem(id: "night", name: self.english, subtitle: self.place)])
        }
        assertGrows(width: 320) {
            CYRoamNearbyCard(item: CYRoamNearbyItem(id: "gate", title: self.english, meta: self.place, symbol: "mappin"))
        }
        assertGrows(width: 320) {
            CYResultToast(state: CYResultToastState(.done, self.chinese, actionTitle: "View"), onAction: {})
        }
        assertGrows(width: 320) {
            CYChapterEndCard(number: 2, title: self.english, stats: [
                CYStoryStat(key: "chapterFlip.stat.stops", value: "4"),
                CYStoryStat(key: "chapterFlip.stat.chapter", value: "2/6"),
                CYStoryStat(key: "medalScreen.stat.time", value: "18:00"),
            ], nextTitle: self.place, onContinue: {})
        }
        assertFits(StampSeal(size: 220, stamped: true), typeSize: .accessibility5, width: 320)
        assertFits(
            CYPassVerifiedFace(title: self.english, number: "A-1842", size: CGSize(width: 320, height: 480), notchY: 300, shape: CYTicketPassShape(notchY: 300)),
            typeSize: .accessibility5,
            width: 360
        )
        #endif
    }

    #if canImport(UIKit)
    private func assertGrows<V: View>(width: CGFloat, @ViewBuilder _ view: () -> V, file: StaticString = #filePath, line: UInt = #line) {
        let regular = measure(view(), typeSize: .large, width: max(width, 390))
        let ax = measure(view(), typeSize: .accessibility5, width: width)
        XCTAssertGreaterThan(ax.height, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(ax.width, width + 1, "Horizontal overflow at AX-XXXL", file: file, line: line)
        XCTAssertGreaterThan(ax.height, regular.height, "AX-XXXL should wrap instead of staying the default height", file: file, line: line)
    }

    private func assertFits<V: View>(_ view: V, typeSize: DynamicTypeSize, width: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let size = measure(view, typeSize: typeSize, width: width)
        XCTAssertGreaterThan(size.height, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(size.width, width + 1, file: file, line: line)
    }

    private func measure<V: View>(_ view: V, typeSize: DynamicTypeSize, width: CGFloat) -> CGSize {
        let hosted = view
            .environment(\.themeDomain, .player)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.locale, Locale(identifier: "en"))
            .frame(width: width)
        let controller = UIHostingController(rootView: hosted)
        return controller.sizeThatFits(in: CGSize(width: width, height: 8000))
    }
    #endif
}
