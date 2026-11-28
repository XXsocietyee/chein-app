#if DEBUG
import SwiftUI

/// `e5b-stamp` (mp-roam r3, ADA 11-28): the real roam "stamp collected" moment, not the generic `CYCelebrationMoment`.
/// MP `subpackageRoam/citystamp` ③ 换票: the slip left by the last visitor, torn and scratched open, with
/// 保存到相册 and 收下，出发. Same stamp (id 902) and art as the `e2-stamp-album` tile, so the two shots agree.
/// Synthetic data only; no session, network, camera or write path.
@MainActor struct RoamStampCollectedFixture: View {
    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    private let openedAt = Date()
    private var place: String { Self.tt("Old street", "老街") }
    private var receipt: RoamStampExchangeReceipt? {
        let caption = Self.tt("Old street neon", "老街霓虹")
        let json = #"{"exchanged":true,"stamp":{"id":902,"picUrl":"","caption":"\#(caption)","checkState":1,"createTime":"2026-01-02T12:00:00"}}"#
        return try? JSONDecoder().decode(RoamStampExchangeReceipt.self, from: Data(json.utf8))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 4) { Text(verbatim: RoamStampSlip.dateLabel(openedAt) + " ·"); Text(verbatim: place) }
                        .cyText(.meta).foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                    if let receipt {
                        RoamStampSlipView(slip: RoamStampSlip(receipt), place: Text(verbatim: place), openedAt: openedAt,
                                          revealedAtStart: true, sampleArt: MPAsset.BannerCover.cityCamera)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(Text(LocalizedStringKey(RoamStampSlip.titleKey(kind: "sticker"))))
            .navigationBarTitleDisplayMode(.inline)
        }
        .cyDomainScreen(.player)
    }
}
#endif
