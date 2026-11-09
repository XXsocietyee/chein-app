import SwiftUI

/// Mini-program `subpackageA/pages/infomation` copy: hero line, per-mode tag and description.
extension SocialGuideMode {
    var xcxTagKey: LocalizedStringKey { switch self { case .classic: return "guideXcx.classicTag"; case .free: return "guideXcx.freeTag"; case .roam: return "guideXcx.roamTag" } }
    var xcxDetailKey: LocalizedStringKey { switch self { case .classic: return "guideXcx.classicDetail"; case .free: return "guideXcx.freeDetail"; case .roam: return "guideXcx.roamDetail" } }
}

struct SocialGuideXcxHero: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYHeroHeader("guideXcx.heroLead", subtitle: "guideXcx.heroDetail")
            Text("guideXcx.heroEmphasis").font(CYTypography.label).foregroundStyle(palette.textSecondary)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("social.guide.hero")
            .themeDomain(.player)
    }
}

/// Source mode card: icon, name, tag pill, description and the small "去看看" action.
struct SocialGuideXcxModeRow: View {
    let mode: SocialGuideMode
    var onOpen: ((SocialGuideDestination) -> Void)?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(mode.titleKey, meta: mode.xcxDetailKey, trailing: .none, card: true) {
                CYRowIcon(systemImage: mode.icon)
            }
            CYStatusChip(mode.xcxTagKey)
            if let onOpen {
                CYPillButton("guideXcx.go", style: .secondary, fullWidth: false) { onOpen(mode.destination) }
                    .accessibilityIdentifier("social.guide.\(mode.rawValue)")
            }
        }.padding(.vertical, CYSpacing.xs).themeDomain(.player)
    }
}
