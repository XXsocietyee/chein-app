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
        serious ? palette.danger : palette.warningText
    }

    private var backgroundTone: Color {
        serious ? palette.dangerBg : palette.warningBg
    }

    private var borderTone: Color {
        serious ? palette.danger.opacity(0.32) : palette.warning.opacity(0.28)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(CYTypography.bodyBold)
                    .foregroundStyle(foregroundTone)
                Text(LocalizedStringKey(messageKey))
                    .font(CYTypography.meta.weight(.semibold))
                    .foregroundStyle(foregroundTone)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: CYSpacing.xs)
                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text(LocalizedStringKey(actionTitleKey))
                            .font(CYTypography.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(foregroundTone)
                    .disabled(isRetrying)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("cy.offlineBanner.retry")
                }
            }
            if let cachedAt {
                HStack(spacing: CYSpacing.xxs) {
                    Text(LocalizedStringKey("cy.state.offline.banner.cachedAt"))
                    Text(cachedAt, format: .dateTime.hour().minute())
                }
                .font(CYTypography.caption)
                .foregroundStyle(palette.textSecondary)
                .accessibilityIdentifier("cy.offlineBanner.cachedAt")
            }
            if let detailKey {
                Text(LocalizedStringKey(detailKey))
                    .font(CYTypography.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cy.offlineBanner.detail")
            }
            if stillOffline {
                Text(LocalizedStringKey("cy.state.offline.banner.stillOffline"))
                    .font(CYTypography.caption)
                    .foregroundStyle(foregroundTone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cy.offlineBanner.stillOffline")
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTone, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                .stroke(borderTone, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(LocalizedStringKey("cy.state.offline.accessibility.label")))
        .accessibilityIdentifier("cy.offlineBanner")
    }
}
