import SwiftUI

/// "Present" mode for one pass: black backdrop, screen at full brightness, the pass summary and the code tile.
/// With a verification code factory the tile is the real approval-gated `VerificationCodeView`; without one it
/// shows the registration number large for staff to read. Never a decorative or screenshot QR.
@MainActor struct TicketPassPresentView: View {
    let ticket: TicketWalletTicket
    let onClose: () -> Void
    @Environment(\.verificationCodeFactory) private var codeFactory
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var appeared = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    summary
                    tile
                    Text(verbatim: c.t("亮度已调高，方便扫码。关闭后恢复。", "Brightness is raised for scanning and restored when you close."))
                        .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("ticketWallet.present.brightnessNote")
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.top, 72)
                .padding(.bottom, CYSpacing.hero)
                .frame(maxWidth: .infinity)
            }
            closeBar
        }
        .preferredColorScheme(.dark)
        .cyBrightnessBoost(true)
        .privacySensitive()
        .onAppear { appeared = true }
        .cyHaptic(.impactMedium, trigger: appeared)
        .accessibilityIdentifier("ticketWallet.present")
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(CYTypography.label)
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                    .background(CYColor.actionSecondary, in: Circle())
            }
            .buttonStyle(.cyPressable)
            .accessibilityLabel(Text("action.close"))
            .accessibilityIdentifier("ticketWallet.present.close")
        }
        .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.md)
    }

    private var summary: some View {
        VStack(spacing: CYSpacing.xs) {
            TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                .font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.center).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: CYSpacing.sm) {
                if let date = ticket.participateDate, !date.isEmpty {
                    Label { Text(verbatim: date) } icon: { Image(systemName: "calendar") }
                }
                if let place = ticket.addressName, !place.isEmpty {
                    Label { Text(verbatim: place).lineLimit(1) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
            }
            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var tile: some View {
        if let codeFactory, ticket.status == .ready {
            VerificationCodeView(model: codeFactory(.init(kind: .ticket, id: ticket.id)))
                .frame(maxWidth: .infinity)
        } else {
            staffTile.cyCodeReveal()
        }
    }

    /// Honest fallback: the registration number in large type, so staff can read or key it. No code is drawn.
    private var staffTile: some View {
        VStack(spacing: CYSpacing.md) {
            if let number = ticket.registrationNumber, !number.isEmpty {
                Text(verbatim: number)
                    .font((typeSize.isAccessibilitySize ? CYTypography.sectionTitle : CYTypography.display).monospaced())
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.5).lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.xxl)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                    .textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: c.t("票号", "Ticket number")))
                    .accessibilityValue(Text(verbatim: number))
                    .accessibilityIdentifier("ticketWallet.present.number")
            } else {
                Image(systemName: "ticket")
                    .font(CYTypography.display)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.xxl)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text(verbatim: c.t("到场出示", "Show at the venue")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: c.t("现场工作人员会为你核验，无需截图。", "Venue staff will check it for you. No screenshot needed."))
                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("ticketWallet.present.staffTile")
    }
}
