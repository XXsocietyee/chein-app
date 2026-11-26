import SwiftUI

/// Mini-program row / badge artwork (`MPAsset.*`) at a Dynamic-Type-scaled glyph size.
/// The asset catalog decides tinting: template imagesets take the foreground style
/// (`SettingsTileLabelStyle`, `CYRowIcon` colours); full-colour ones (e.g. `iconFlagBlue`) keep their MP colours.
/// Decorative: the row title is the spoken label.
struct AccountPublishMPGlyph: View {
    let image: Image
    @ScaledMetric private var side: CGFloat

    init(_ image: Image, side: CGFloat = 18) {
        self.image = image
        _side = ScaledMetric(wrappedValue: side, relativeTo: .body)
    }

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// Mini-program artwork as a plain list-row icon (native r2: no tile chrome; the system `Label` draws the row).
struct AccountPublishMPRowIcon: View {
    let image: Image
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 22
    init(_ image: Image) { self.image = image }
    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .foregroundStyle(.tint)
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// MP member level badge (`subpackageMember/images/group{2…5}.png`, profile index.wxml:65-68). Levels without art return nil.
enum AccountPublishLevelBadge {
    static func image(levelID: Int?) -> Image? {
        switch levelID {
        case 2: return MPAsset.BadgeMedal.group2
        case 3: return MPAsset.BadgeMedal.group3
        case 4: return MPAsset.BadgeMedal.group4
        case 5: return MPAsset.BadgeMedal.group5
        default: return nil
        }
    }
}
