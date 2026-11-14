import SwiftUI

enum CYStatusTone { case neutral, success, warning, danger, info, rare }

/// Small capsule status badge (`--cy-comp-tag-h` 20pt, soft fill, zero outer border). Colour is never the only signal: pass text.
struct CYStatusChip: View {
    private let text: LocalizedStringKey
    private let verbatim: String?
    private let tone: CYStatusTone
    private let systemImage: String?
    private let isSelected: Bool
    private var forcesSingleLine = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ text: LocalizedStringKey, tone: CYStatusTone = .neutral, systemImage: String? = nil, isSelected: Bool = false) {
        self.text = text
        self.verbatim = nil
        self.tone = tone
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    /// Server status text. Blank text renders as an em dash.
    init(verbatim text: String, tone: CYStatusTone = .neutral, systemImage: String? = nil, isSelected: Bool = false) {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = ""
        self.verbatim = shown.isEmpty ? "—" : shown
        self.tone = tone
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    /// One short status word (Locked / Unlocked): never wraps or hyphenates, shrinks a little instead, at any text size.
    func singleLine() -> CYStatusChip { var copy = self; copy.forcesSingleLine = true; return copy }

    var body: some View {
        let shape = Capsule(style: .continuous)
        HStack(spacing: CYSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(CYTypography.caption.weight(.semibold))
            }
            Group {
                if let verbatim { Text(verbatim: verbatim) } else { Text(text) }
            }
            .font(CYTypography.micro.weight(.semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .frame(minHeight: 20)
        .background(shape.fill(background))
        .overlay {
            if isSelected {
                shape.strokeBorder(palette.borderStrong, lineWidth: 1)
            }
        }
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
        case .rare: return palette.rare
        }
    }
    private var background: Color {
        switch tone {
        case .neutral: return palette.actionSecondaryBg
        case .success: return palette.successSoft
        case .warning: return palette.warningSoft
        case .danger: return palette.dangerSoft
        case .info: return palette.infoSoft
        case .rare: return palette.rareSoft
        }
    }
}

/// 16pt tabular numeric count badge (unread/pending items; omits 0 unless `showsZero` is true).
struct CYCountBadge: View {
    let count: Int?
    var showsZero: Bool = false

    @Environment(\.cyPalette) private var palette

    var body: some View {
        if let label {
            Text(verbatim: label)
                .font(CYTypography.micro.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.actionDangerFg)
                .padding(.horizontal, 5)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule(style: .continuous).fill(palette.actionDangerBg))
                .accessibilityLabel(Text(verbatim: label))
        }
    }

    private var label: String? {
        guard let count else { return "—" }
        if count == 0 && !showsZero { return nil }
        return count > 99 ? "99+" : "\(count)"
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
            CYStatusChip("Rare", tone: .rare, systemImage: "star.fill")
            CYCountBadge(count: 12)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}
#Preview("Chip · player dark") { CYStatusChipPreviewBody().themeDomain(.player) }
#Preview("Chip · merchant light") { CYStatusChipPreviewBody().themeDomain(.merchant) }
