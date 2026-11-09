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

/// Image-led mode card: generated cover art (tonal gradient + oversized symbol, decorative, no data),
/// title, tag chip, description and a single "go" pill, all over a bottom scrim.
struct SocialGuideXcxModeRow: View {
    let mode: SocialGuideMode
    var onOpen: ((SocialGuideDestination) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tap = 0
    private var tones: [Color] {
        switch mode {
        case .classic: return [Color(red: 0.10, green: 0.16, blue: 0.30), Color(red: 0.16, green: 0.36, blue: 0.42)]
        case .free: return [Color(red: 0.30, green: 0.16, blue: 0.14), Color(red: 0.46, green: 0.30, blue: 0.16)]
        case .roam: return [Color(red: 0.09, green: 0.22, blue: 0.20), Color(red: 0.14, green: 0.18, blue: 0.34)]
        }
    }
    var body: some View {
        let card = ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: tones, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: mode.icon).font(.system(size: 150, weight: .thin))
                .foregroundStyle(.white.opacity(0.10)).rotationEffect(.degrees(-12))
                .offset(x: 90, y: -40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                CYStatusChip(mode.xcxTagKey)
                Text(mode.titleKey).font(.title2.weight(.semibold)).foregroundStyle(.white)
                Text(mode.xcxDetailKey).font(CYTypography.meta).foregroundStyle(.white.opacity(0.78)).lineLimit(3)
                if onOpen != nil {
                    Label("guideXcx.go", systemImage: "arrow.right").font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black).padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                        .background(Capsule().fill(.white)).padding(.top, CYSpacing.xs)
                }
            }
            .padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
        }
        .frame(minHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        if let onOpen {
            Button { tap += 1; onOpen(mode.destination) } label: { card }
                .buttonStyle(GuideCardPressStyle(reduceMotion: reduceMotion))
                .sensoryFeedback(.selection, trigger: tap)
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
