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
    @State private var glowTick = 0
    @State private var checkedIn = false
    @QuestifyReduceMotion private var reduceMotion
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        ZStack(alignment: .top) {
            // Ink ground, not pure black: the edge glow and the code tile read against it.
            CYNight.ink0.ignoresSafeArea()
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    summary
                    tile.opacity(checkedIn ? 0.6 : 1)
                    if checkedIn {
                        Label { Text(verbatim: c.t("已入场，玩得开心", "You're in. Have fun.")) } icon: { Image(systemName: "checkmark.circle.fill") }
                            .cyText(.cardTitle).foregroundStyle(CYNight.verify)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            .accessibilityIdentifier("ticketWallet.present.checkedIn")
                    }
                    Text(verbatim: c.t("亮度已调高，方便扫码。关闭后恢复。", "Brightness is raised for scanning and restored when you close."))
                        .cyText(.meta).foregroundStyle(CYColor.textTertiary)
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
        .onChange(of: ticket.status) { old, new in
            // The venue scanned this pass while it is on screen: the display edge lights green once (full-screen
            // cover, so it hugs the corners) and the code tile steps back.
            guard new == .verified, old != .verified else { return }
            glowTick += 1
            withAnimation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion)) { checkedIn = true }
        }
        .cyEdgeGlow(trigger: glowTick)
        .cyHaptic(.impactMedium, trigger: appeared)
        .accessibilityIdentifier("ticketWallet.present")
        .cyDomainScreen(.player)
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .cyText(.label)
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
                .cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.center).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: CYSpacing.sm) {
                if let date = ticket.participateDate, !date.isEmpty {
                    Label { Text(verbatim: date) } icon: { Image(systemName: "calendar") }
                }
                if let place = ticket.addressName, !place.isEmpty {
                    Label { Text(verbatim: place).lineLimit(2) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
            }
            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
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
                    .cyText(typeSize.isAccessibilitySize ? .sectionTitle : .display).monospaced()
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.5).lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.xxl)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: c.t("票号", "Ticket number")))
                    .accessibilityValue(Text(verbatim: number))
                    .accessibilityIdentifier("ticketWallet.present.number")
            } else {
                Image(systemName: "ticket")
                    .cyText(.display)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.xxl)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text(verbatim: c.t("到场出示", "Show at the venue")).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: c.t("现场工作人员会为你核验，无需截图。", "Venue staff will check it for you. No screenshot needed."))
                .cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("ticketWallet.present.staffTile")
    }
}
