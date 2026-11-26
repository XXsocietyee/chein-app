import SwiftUI

/// S04 presentation only. All state, identity, journal and navigation ownership stays with callers.
/// Screens give their title to the navigation bar; this modifier never clears it. List/Form draw their own grouped background.
private struct NativeChannelScreenPresentation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .cyText(.body)
            .environment(\.defaultMinListRowHeight, CYSpacing.minTouchTarget)
            .navigationBarTitleDisplayMode(.inline)
            .transaction { transaction in
                // Kit press springs stay inside the components. Anything else degrades to a cross-fade.
                if reduceMotion, transaction.animation != nil {
                    transaction.animation = CYMotion.reduced
                }
            }
    }
}

/// System prominent button. One primary per screen.
private struct NativeChannelPrimaryAction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}

/// Inline state text as a plain row label: secondary SF Symbol beside the text, no card.
private struct NativeChannelInlineNotice: ViewModifier {
    let systemImage: String

    func body(content: Content) -> some View {
        Label {
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func nativeChannelScreen() -> some View { modifier(NativeChannelScreenPresentation()) }
    func nativeChannelPrimaryAction() -> some View { modifier(NativeChannelPrimaryAction()) }
    func nativeChannelNotice(systemImage: String) -> some View { modifier(NativeChannelInlineNotice(systemImage: systemImage)) }
}

/// Section title for keys that live in a string table. `CYSectionHeader` reads the default catalog only.
struct NativeChannelSectionTitle: View {
    let key: String
    var tableName: String = "NativeChannelProgress"

    var body: some View {
        Text(LocalizedStringKey(key), tableName: tableName)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Wide generated cover for a hero illustration. Height follows width, not a fixed text line.
struct NativeChannelCoverBanner: View {
    let seed: String
    var symbol: String? = nil

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 7.0, contentMode: .fit)
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum NativeChannelProgressCopy {
    static func text(_ key: String) -> String {
        String(localized: LocalizedStringResource(
            String.LocalizationValue(stringLiteral: key),
            table: "NativeChannelProgress"
        ))
    }
}
