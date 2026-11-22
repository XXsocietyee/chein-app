import SwiftUI

/// Recovery remains reachable without the generic current-run snapshot. No submit/retry action.
@MainActor struct CityOrientationOriginalRecoveryView: View {
    @Bindable var model: CityOrientationOriginalRecoveryHost
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader("cityOriginalRecovery.title")
            status
            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
            if model.canAcknowledge {
                CYPillButton("cityOriginalRecovery.acknowledge", systemImage: "checkmark.seal") { try? model.acknowledge() }
                    .accessibilityLabel(Text("cityOriginalRecovery.acknowledge"))
            }
            if model.current && model.phase != .loading && model.phase != .settled {
                CYPillButton(
                    "cityOriginalRecovery.read",
                    style: model.canAcknowledge ? .secondary : .primary,
                    systemImage: "arrow.clockwise"
                ) { Task { await model.load() } }
                .accessibilityLabel(Text("cityOriginalRecovery.read"))
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.md)
        .privacySensitive()
        .accessibilityIdentifier("cityOriginalRecovery")
        .task { await model.load() }
        .onDisappear { model.invalidate() }
    }

    @ViewBuilder private var status: some View {
        if let receipt = model.visibleReceipt {
            CYNoteBanner(
                text: Text(LocalizedStringKey(receipt.succeeded ? "cityOriginalRecovery.applied" : "cityOriginalRecovery.failed")),
                symbol: receipt.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill",
                tone: receipt.succeeded ? .success : .danger
            )
            Text(verbatim: shown(receipt.message))
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            switch model.phase {
            case .loading:
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("cityOriginalRecovery.loading")
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CYSkeleton().accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            case .approvalRequired:
                CYNoteBanner(text: Text("cityOriginalRecovery.approval"), symbol: "lock.fill", tone: .warning)
            case .unknown:
                CYNoteBanner(text: Text("cityOriginalRecovery.unknown"), symbol: "questionmark.circle", tone: .warning)
            case .unavailable:
                CYNoteBanner(text: Text("cityOriginalRecovery.storage"), symbol: "externaldrive.badge.exclamationmark", tone: .danger)
            case .settled:
                CYNoteBanner(text: Text("cityOriginalRecovery.settled"), symbol: "checkmark.circle.fill", tone: .success)
            default:
                CYNoteBanner(text: Text("cityOriginalRecovery.unavailable"), symbol: "clock.badge.questionmark", tone: .neutral)
            }
        }
    }

    /// A missing server line is unknown. A real message is shown unchanged.
    private func shown(_ message: String?) -> String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
}
