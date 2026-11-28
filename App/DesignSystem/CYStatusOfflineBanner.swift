import SwiftUI

/// Mini-program `cy-offline-banner` parity component built with `CY*` tokens.
/// Displays offline connectivity notice, optional last cache timestamp, optional retry connection
/// action, optional queued non-money write summary, and serious/danger tone support.
public struct CYStatusOfflineBanner: View {
    public let messageKey: String
    public let detailKey: String?
    public let cachedAt: Date?
    public let stillOffline: Bool
    public let serious: Bool
    public let actionTitleKey: String
    public let isRetrying: Bool
    public let onRetry: (() -> Void)?

    public init(
        messageKey: String = "cy.state.offline.banner.title",
        detailKey: String? = nil,
        cachedAt: Date? = nil,
        stillOffline: Bool = false,
        serious: Bool = false,
        actionTitleKey: String = "cy.state.offline.banner.retry",
        isRetrying: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.messageKey = messageKey
        self.detailKey = detailKey
        self.cachedAt = cachedAt
        self.stillOffline = stillOffline
        self.serious = serious
        self.actionTitleKey = actionTitleKey
        self.isRetrying = isRetrying
        self.onRetry = onRetry
    }

    @Environment(\.cyPalette) private var palette

    private var foregroundTone: Color {
        serious ? palette.danger : palette.warning
    }

    private var backgroundTone: Color {
        serious ? palette.dangerSoft : palette.warningSoft
    }

    private var borderTone: Color {
        serious ? palette.danger.opacity(0.32) : palette.warning.opacity(0.28)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(CYTypography.bodyMedium)
                    .foregroundStyle(foregroundTone)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(messageKey))
                    .cyText(.meta, weight: .semibold)
                    .foregroundStyle(foregroundTone)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: CYSpacing.xs)
                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text(LocalizedStringKey(actionTitleKey))
                            .cyText(.caption, weight: .semibold)
                    }
                    .buttonStyle(.bordered)
                    .tint(foregroundTone)
                    .disabled(isRetrying)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("cy.offlineBanner.retry")
                    .accessibilityLabel(Text(LocalizedStringKey(actionTitleKey)))
                    .accessibilityValue(spokenCache)
                    .accessibilityHint(Text(LocalizedStringKey(stillOffline ? "cy.state.offline.banner.stillOffline" : messageKey)))
                }
            }
            if let cachedAt {
                HStack(spacing: CYSpacing.xxs) {
                    Text(LocalizedStringKey("cy.state.offline.banner.cachedAt"))
                    Text(cachedAt, format: .dateTime.hour().minute())
                }
                .cyText(.caption)
                .foregroundStyle(palette.textSecondary)
                .accessibilityIdentifier("cy.offlineBanner.cachedAt")
            }
            if let detailKey {
                Text(LocalizedStringKey(detailKey))
                    .cyText(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cy.offlineBanner.detail")
            }
            if stillOffline {
                Text(LocalizedStringKey("cy.state.offline.banner.stillOffline"))
                    .cyText(.caption)
                    .foregroundStyle(foregroundTone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cy.offlineBanner.stillOffline")
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTone, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .stroke(borderTone, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(LocalizedStringKey("cy.state.offline.accessibility.label")))
        .accessibilityValue(spokenCache)
        .accessibilityHint(Text(LocalizedStringKey(stillOffline ? "cy.state.offline.banner.stillOffline" : messageKey)))
        .accessibilityIdentifier("cy.offlineBanner")
    }

    /// A missing cache time is unknown. A shown clock stays the time already on the banner.
    private var spokenCache: Text {
        if let cachedAt {
            return Text(cachedAt, format: .dateTime.hour().minute())
        }
        return Text(verbatim: "—")
    }
}

/// User-visible per-screen sync state for an opted-in non-money backend-idempotent write.
enum CYOfflineWriteScreenStatus: Equatable, Sendable {
    case none
    case queued(count: Int)
    case syncing(count: Int)
    case synced
    case waitingConfirmation(count: Int)
    case rejected(count: Int)
    case moneyExcluded
}

/// Reusable `CY*` status card embedded on screens that opt non-money idempotent writes into `OfflineIdempotentWriteQueue`.
struct CYOfflineWriteStatusBanner: View {
    let status: CYOfflineWriteScreenStatus
    let isOnline: Bool
    var accessibilityID: String = "cy.offlineWrite.status"
    var onSyncNow: (() -> Void)? = nil
    var onDismissSynced: (() -> Void)? = nil

    @Environment(\.cyPalette) private var palette

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .queued(let count):
            card(tone: .warning, border: palette.warning.opacity(0.35), fill: palette.warningSoft.opacity(0.55)) {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip("cy.state.offline.write.chip.queued", tone: .warning, systemImage: "icloud.slash")
                    Spacer(minLength: CYSpacing.xs)
                    if isOnline, let onSyncNow {
                        Button("cy.state.offline.queue.syncNow", action: onSyncNow)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityIdentifier("\(accessibilityID).syncNow")
                    }
                }
                Text(count > 1
                     ? LocalizedStringKey("cy.state.offline.write.willSendCount \(count)")
                     : LocalizedStringKey("cy.state.offline.write.willSendWhenOnline"))
                    .cyText(.caption)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        case .syncing(let count):
            card(tone: .info, border: palette.borderSubtle, fill: palette.bgElevated) {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip("cy.state.offline.write.chip.syncing", tone: .info, systemImage: "arrow.triangle.2.circlepath")
                    ProgressView()
                        .controlSize(.small)
                    Spacer(minLength: CYSpacing.xs)
                    Text(verbatim: "\(count)")
                        .cyText(.caption, monospacedDigit: true)
                        .foregroundStyle(palette.textSecondary)
                }
                Text("cy.state.offline.queue.syncing")
                    .cyText(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        case .synced:
            card(tone: .success, border: palette.success.opacity(0.35), fill: palette.successSoft.opacity(0.5)) {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip("cy.state.offline.write.chip.synced", tone: .success, systemImage: "checkmark.circle.fill")
                    Spacer(minLength: CYSpacing.xs)
                    if let onDismissSynced {
                        Button("cy.state.offline.write.dismiss", action: onDismissSynced)
                            .cyText(.caption)
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("\(accessibilityID).dismiss")
                    }
                }
                Text("cy.state.offline.write.synced")
                    .cyText(.caption)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        case .waitingConfirmation(let count):
            card(tone: .warning, border: palette.danger.opacity(0.35), fill: palette.dangerSoft.opacity(0.45)) {
                CYStatusChip("cy.state.offline.write.chip.locked", tone: .warning, systemImage: "lock.fill")
                Text("cy.state.offline.queue.lockedUnknown \(count)")
                    .cyText(.caption)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        case .rejected:
            card(tone: .danger, border: palette.danger.opacity(0.35), fill: palette.dangerSoft.opacity(0.45)) {
                CYStatusChip("cy.state.offline.write.chip.rejected", tone: .danger, systemImage: "xmark.octagon.fill")
                Text("cy.state.offline.write.rejected")
                    .cyText(.caption)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        case .moneyExcluded:
            card(tone: .danger, border: palette.danger.opacity(0.35), fill: palette.dangerSoft.opacity(0.45)) {
                CYStatusChip("cy.state.offline.write.chip.excluded", tone: .danger, systemImage: "lock.shield.fill")
                Text("cy.state.offline.queue.moneyNoAutoReplay")
                    .cyText(.caption)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(accessibilityID).message")
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(
        tone: CYStatusTone,
        border: Color,
        fill: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            content()
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
    }
}
