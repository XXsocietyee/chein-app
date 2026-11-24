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
            Text("guideXcx.heroEmphasis").cyText(.label).foregroundStyle(palette.textSecondary)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("social.guide.hero")
            .themeDomain(.player)
    }
}

/// Mini-program `gl-mode` card: icon disc and mode name on top, one 去看看 pill bottom-right.
struct SocialGuideXcxModeRow: View {
    let mode: SocialGuideMode
    var onOpen: ((SocialGuideDestination) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tap = 0
    var body: some View {
        let card = VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: mode.icon).font(.title3.weight(.medium)).foregroundStyle(CYColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(CYNight.ink2, in: Circle())
                    .overlay(Circle().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                    .accessibilityHidden(true)
                Text(mode.titleKey).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            }
            if onOpen != nil {
                HStack {
                    Spacer(minLength: 0)
                    Text("guideXcx.go").cyText(.label, weight: .semibold)
                        .foregroundStyle(CYNight.ink0).padding(.horizontal, CYSpacing.xxl).frame(minHeight: 44)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                }
            }
        }
        .padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
        .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(CYColor.borderSubtle, lineWidth: 1))
        .accessibilityElement(children: .combine)
        if let onOpen {
            Button { tap += 1; onOpen(mode.destination) } label: { card }
                .buttonStyle(GuideCardPressStyle(reduceMotion: reduceMotion))
                .cyHaptic(.selection, trigger: tap)
                .accessibilityIdentifier("social.guide.\(mode.rawValue)")
                .themeDomain(.player)
        } else {
            card.themeDomain(.player)
        }
    }
}

private struct GuideCardPressStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
