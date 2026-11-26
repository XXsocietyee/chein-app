import SwiftUI

enum CYStatusTone { case neutral, success, warning, danger, info, rare }

/// Status word (native r2: secondary text or a tinted `Label`, no capsule). Colour is never the only signal: pass text.
struct CYStatusChip: View {
    private let text: LocalizedStringKey
    private let verbatim: String?
    private let tableName: String?
    private let tone: CYStatusTone
    private let systemImage: String?
    private let isSelected: Bool
    private var forcesSingleLine = false

    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ text: LocalizedStringKey, tone: CYStatusTone = .neutral, systemImage: String? = nil, isSelected: Bool = false, tableName: String? = nil) {
        self.text = text
        self.verbatim = nil
        self.tableName = tableName
        self.tone = tone
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    /// Server status text. Blank text renders as an em dash.
    init(verbatim text: String, tone: CYStatusTone = .neutral, systemImage: String? = nil, isSelected: Bool = false) {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = ""
        self.verbatim = shown.isEmpty ? "—" : shown
        self.tableName = nil
        self.tone = tone
        self.systemImage = systemImage
        self.isSelected = isSelected
    }

    /// One short status word (Locked / Unlocked): never wraps or hyphenates, shrinks a little instead, at any text size.
    func singleLine() -> CYStatusChip { var copy = self; copy.forcesSingleLine = true; return copy }

    /// Native r2: no capsule chrome. A `.footnote` `Label` (tinted SF Symbol when one is given) or plain text:
    /// `.secondary` for neutral, the matching system colour (green / orange / red / blue / purple) otherwise.
    var body: some View {
        Group {
            if let systemImage {
                Label {
                    textView
                } icon: {
                    Image(systemName: systemImage)
                }
            } else {
                textView
            }
        }
        .font(.footnote)
        .fontWeight(isSelected ? .semibold : nil)
        .foregroundStyle(Self.systemStyle(for: tone))
        .lineLimit(forcesSingleLine ? 1 : (typeSize.isAccessibilitySize ? 3 : 1))
        .minimumScaleFactor(forcesSingleLine ? 0.7 : 1)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var textView: some View {
        if let verbatim { Text(verbatim: verbatim) } else { Text(text, tableName: tableName) }
    }

    /// The system colour a tone renders in (native r2).
    static func systemStyle(for tone: CYStatusTone) -> AnyShapeStyle {
        switch tone {
        case .neutral: return AnyShapeStyle(.secondary)
        case .success: return AnyShapeStyle(Color.green)
        case .warning: return AnyShapeStyle(Color.orange)
        case .danger: return AnyShapeStyle(Color.red)
        case .info: return AnyShapeStyle(Color.blue)
        case .rare: return AnyShapeStyle(Color.purple)
        }
    }

    /// Token readback kept for existing token tests; the chip itself renders `systemStyle(for:)`.
    static func tokens(
        for tone: CYStatusTone,
        isSelected: Bool = false,
        in palette: CYDomainPalette
    ) -> (foreground: Color, background: Color, selectedBorder: Color?) {
        let fg: Color
        let bg: Color
        switch tone {
        case .neutral: fg = palette.textSecondary; bg = palette.actionSecondaryBg
        case .success: fg = palette.success; bg = palette.successSoft
        case .warning: fg = palette.warning; bg = palette.warningSoft
        case .danger: fg = palette.danger; bg = palette.dangerSoft
        case .info: fg = palette.info; bg = palette.infoSoft
        case .rare: fg = palette.rare; bg = palette.rareSoft
        }
        return (fg, bg, isSelected ? palette.borderStrong : nil)
    }
}

/// 16pt tabular numeric count badge (unread/pending items; omits 0 unless `showsZero` is true).
struct CYCountBadge: View {
    let count: Int?
    var showsZero: Bool = false

    var body: some View {
        if let label {
            // Native r2: the system badge look (white caption digits on system red).
            Text(verbatim: label)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 16, minHeight: 16)
                .background(Color.red, in: Capsule())
                .accessibilityLabel(Text(verbatim: label))
        }
    }

    private var label: String? {
        Self.formattedLabel(count: count, showsZero: showsZero)
    }

    static func formattedLabel(count: Int?, showsZero: Bool = false) -> String? {
        guard let count else { return "—" }
        if count == 0 && !showsZero { return nil }
        return count > 99 ? "99+" : "\(count)"
    }
}

private struct CYStatusChipPreviewBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip("Pending")
            CYStatusChip("Paid", tone: .success, systemImage: "checkmark")
            CYStatusChip("Refunded", tone: .danger)
            CYCountBadge(count: 12)
        }
        .padding()
    }
}
#Preview("Chip") { CYStatusChipPreviewBody() }
