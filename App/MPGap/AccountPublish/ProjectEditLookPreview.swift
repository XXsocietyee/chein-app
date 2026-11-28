import SwiftUI

/// MP `publishkit/components/look-preview` (embedded, pinned at the top of the 画面风格 sheet): a sample chapter
/// screen (kick · title · story · option A) that follows the chosen style, palette and neon at once. The canvas
/// particles and per-character text effects are not drawn here; colours, corner radius and title type come from
/// `CYThemeLook`, the same tokens the play screens use.
struct ProjectEditLookPreview: View {
    let look: CYThemeLook

    var body: some View {
        let colors = look.colors
        let key = look.style.rawValue.lowercased()
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(LocalizedStringKey("mpPublish.look.preview.\(key).kick"))
                .font(.caption)
                .foregroundStyle(colors.a.swiftUIColor)
            Text(LocalizedStringKey("mpPublish.look.preview.\(key).title"))
                .font(.title2)
                .cyLookTitle()
            Text(LocalizedStringKey("mpPublish.look.preview.\(key).story"))
                .font(.body)
                .foregroundStyle(colors.ink.swiftUIColor)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Text(verbatim: "A")
                    .font(.headline)
                    .foregroundStyle(colors.a.swiftUIColor)
                Text(LocalizedStringKey("mpPublish.look.preview.\(key).option"))
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyLookCard(pop: true, padding: CYSpacing.md)
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyThemeLook(look)
        .background(colors.bg.swiftUIColor, in: RoundedRectangle(cornerRadius: look.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: look.cardRadius, style: .continuous).strokeBorder(colors.a.swiftUIColor.opacity(0.5), lineWidth: 1))
        .animation(.default, value: look)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("projectEdit.look.preview")
    }
}
