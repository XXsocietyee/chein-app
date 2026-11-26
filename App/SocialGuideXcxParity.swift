import SwiftUI

/// Mini-program `subpackageA/pages/infomation` copy: hero line, per-mode tag and description.
extension SocialGuideMode {
    var xcxTagKey: LocalizedStringKey { switch self { case .classic: return "guideXcx.classicTag"; case .free: return "guideXcx.freeTag"; case .roam: return "guideXcx.roamTag" } }
    var xcxDetailKey: LocalizedStringKey { switch self { case .classic: return "guideXcx.classicDetail"; case .free: return "guideXcx.freeDetail"; case .roam: return "guideXcx.roamDetail" } }
}

struct SocialGuideXcxHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("guideXcx.heroLead").font(.title2.weight(.bold))
            Text("guideXcx.heroDetail").foregroundStyle(.secondary)
            Text("guideXcx.heroEmphasis").font(.footnote).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("social.guide.hero")
            .themeDomain(.player)
    }
}

/// Mini-program `gl-mode` card as a native row: mode icon and name, with 去看看 as the trailing accessory.
struct SocialGuideXcxModeRow: View {
    let mode: SocialGuideMode
    var onOpen: ((SocialGuideDestination) -> Void)?
    @State private var tap = 0
    var body: some View {
        let row = HStack {
            Label {
                Text(mode.titleKey)
            } icon: {
                Image(systemName: mode.icon).accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            if onOpen != nil {
                Spacer(minLength: 8)
                Text("guideXcx.go")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        if let onOpen {
            Button { tap += 1; onOpen(mode.destination) } label: { row }
                .cyHaptic(.selection, trigger: tap)
                .accessibilityIdentifier("social.guide.\(mode.rawValue)")
                .themeDomain(.player)
        } else {
            row.themeDomain(.player)
        }
    }
}
