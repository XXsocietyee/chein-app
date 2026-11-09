import SwiftUI

enum CYStatusTone { case neutral, success, warning, danger, info }

/// Small capsule status label (order state, ticket state). Colour is never the only signal: pass text.
struct CYStatusChip: View {
    private let text: LocalizedStringKey
    private let tone: CYStatusTone
    private let systemImage: String?

    @Environment(\.cyPalette) private var palette

    init(_ text: LocalizedStringKey, tone: CYStatusTone = .neutral, systemImage: String? = nil) {
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            if let systemImage { Image(systemName: systemImage).font(.caption2.weight(.bold)) }
            Text(text).font(CYTypography.caption)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs + 1)
        .background(Capsule(style: .continuous).fill(background))
        .lineLimit(1)
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
