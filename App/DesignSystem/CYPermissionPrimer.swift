import SwiftUI

// CYPermissionPrimer: the card shown before the system location prompt on the first GO, and the denied-state card with
// Open Settings (roam-fog-engine §1d). Presentation only: it never asks the OS for anything; the host decides, using
// `RoamLocationPrimerStep`. DRAFT COPY: the strings below await owner confirmation (docs/roam-fog/location-permission-copy.md).

// MARK: - Content

struct CYPermissionPrimerContent: Equatable {
    var glyph: String
    var title: String
    var body: String
    var points: [String]
    var primaryTitle: String
    var secondaryTitle: String

    var allStrings: [String] { [title, body, primaryTitle, secondaryTitle] + points }

    /// Before the system prompt. The body is the owner-pending usage sentence, so the card and the OS prompt say one thing.
    static func locationPriming(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "location.fill",
            title: c("Light up where you walk", "点亮你走过的地方"),
            body: c("Chengyin uses your location while the app is open to light up the places you walk and show what is nearby. It never runs in the background.",
                    "城瘾仅在你使用时获取位置，用来点亮你走过的地方并显示附近内容，不会在后台定位。"),
            points: [
                c("Only while the app is open", "仅在使用 App 时"),
                c("Never in the background", "不会在后台定位"),
                c("You can turn it off anytime in Settings", "随时可在设置里关闭"),
            ],
            primaryTitle: c("Continue", "继续"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    /// After the OS said no. Roam keeps working from a chosen search area, so the card says what is lost, not a dead end.
    static func locationDenied(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "location.slash",
            title: c("Location is off", "定位已关闭"),
            body: c("Turn it on in Settings to light up the places you walk. You can still look around a place you pick.",
                    "在设置里打开定位，才能点亮你走过的地方。你仍然可以浏览自己选的地点。"),
            points: [],
            primaryTitle: c("Open Settings", "打开设置"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func content(for step: RoamLocationPrimerStep, locale: Locale) -> CYPermissionPrimerContent {
        switch step {
        case .priming: .locationPriming(locale: locale)
        case .denied: .locationDenied(locale: locale)
        }
    }
}

// MARK: - View

struct CYPermissionPrimer: View {
    let step: RoamLocationPrimerStep
    let content: CYPermissionPrimerContent
    var onPrimary: () -> Void
    var onSecondary: () -> Void
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .title2) private var glyphSize: CGFloat = 36

    init(step: RoamLocationPrimerStep, locale: Locale, onPrimary: @escaping () -> Void, onSecondary: @escaping () -> Void) {
        self.step = step
        self.content = .content(for: step, locale: locale)
        self.onPrimary = onPrimary; self.onSecondary = onSecondary
    }

    private var identifierKind: String { step == .priming ? "priming" : "denied" }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Image(systemName: content.glyph)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
            Text(verbatim: content.title)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: content.body)
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !content.points.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(content.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            Image(systemName: "checkmark").font(CYTypography.meta).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                            Text(verbatim: point).font(CYTypography.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            VStack(spacing: CYSpacing.xs) {
                CYPillButton(verbatim: content.primaryTitle, style: .primary, fullWidth: true, action: onPrimary)
                    .accessibilityIdentifier("cy.permission.\(identifierKind).primary")
                CYPillButton(verbatim: content.secondaryTitle, style: .tertiary, fullWidth: true, action: onSecondary)
                    .accessibilityIdentifier("cy.permission.\(identifierKind).secondary")
            }
            .padding(.top, CYSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.xl)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cy.permission.\(identifierKind)")
    }
}

extension CYPermissionPrimer {
    /// The denied card's primary action: the app's own Settings page. Hosts pass `@Environment(\.openURL)`.
    static func openSettings(using openURL: OpenURLAction) {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

#Preview("Permission · priming") {
    CYPermissionPrimer(step: .priming, locale: Locale(identifier: "en"), onPrimary: {}, onSecondary: {})
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("Permission · denied zh") {
    CYPermissionPrimer(step: .denied, locale: Locale(identifier: "zh-Hans"), onPrimary: {}, onSecondary: {})
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
