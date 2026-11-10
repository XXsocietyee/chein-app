import SwiftUI

enum CYStatusTone { case neutral, success, warning, danger, info }

/// Small capsule status label (order state, ticket state). Colour is never the only signal: pass text.
struct CYStatusChip: View {
    private let text: LocalizedStringKey
    private let verbatim: String?
    private let tone: CYStatusTone
    private let systemImage: String?
    private var forcesSingleLine = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ text: LocalizedStringKey, tone: CYStatusTone = .neutral, systemImage: String? = nil) {
        self.text = text
        self.verbatim = nil
        self.tone = tone
        self.systemImage = systemImage
    }

    /// Server status text. Blank text renders as an em dash.
    init(verbatim text: String, tone: CYStatusTone = .neutral, systemImage: String? = nil) {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = ""
        self.verbatim = shown.isEmpty ? "—" : shown
        self.tone = tone
        self.systemImage = systemImage
    }

    /// One short status word (Locked / Unlocked): never wraps or hyphenates, shrinks a little instead, at any text size.
    func singleLine() -> CYStatusChip { var copy = self; copy.forcesSingleLine = true; return copy }

    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            Group {
                if let verbatim { Text(verbatim: verbatim) } else { Text(text) }
            }.font(CYTypography.caption)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs + 1)
        .background(Capsule(style: .continuous).fill(background))
        // Accessibility sizes may wrap to a second line instead of truncating a status word.
        .lineLimit(forcesSingleLine ? 1 : (typeSize.isAccessibilitySize ? 3 : 1))
        .minimumScaleFactor(forcesSingleLine ? 0.7 : 1)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return palette.textSecondary
        case .success: return palette.success
        case .warning: return palette.warning
        case .danger: return palette.danger
        case .info: return palette.info
        }
    }
    private var background: Color {
        switch tone {
        case .neutral: return palette.actionSecondaryBg
        case .success: return palette.successSoft
        case .warning: return palette.warningSoft
        case .danger: return palette.dangerSoft
        case .info: return palette.infoSoft
        }
    }
}

private struct CYStatusChipPreviewBody: View {
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            CYStatusChip("Pending")
            CYStatusChip("Paid", tone: .success, systemImage: "checkmark")
            CYStatusChip("Expiring", tone: .warning)
            CYStatusChip("Refunded", tone: .danger)
            CYStatusChip("New", tone: .info)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}
#Preview("Chip · player dark") { CYStatusChipPreviewBody().themeDomain(.player) }
#Preview("Chip · merchant light") { CYStatusChipPreviewBody().themeDomain(.merchant) }
