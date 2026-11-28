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
        NavigationStack {
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    summary
                    tile.opacity(checkedIn ? 0.6 : 1)
                    if checkedIn {
                        Label { Text(verbatim: c.t("已入场，玩得开心", "You're in. Have fun.")) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(CYColor.successText) }
                            .font(.headline)
                            .transition(.opacity)
                            .accessibilityIdentifier("ticketWallet.present.checkedIn")
                    }
                    Text(verbatim: c.t("亮度已调高，方便扫码。关闭后恢复。", "Brightness is raised for scanning and restored when you close."))
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("ticketWallet.present.brightnessNote")
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Label("action.close", systemImage: "xmark")
                    }
                    .accessibilityLabel(Text("action.close"))
                    .accessibilityIdentifier("ticketWallet.present.close")
                }
            }
        }
        .cyBrightnessBoost(true)
        .privacySensitive()
        .onAppear { appeared = true }
        .onChange(of: ticket.status) { old, new in
            // The venue scanned this pass while it is on screen: the code tile steps back and the check-in line appears.
            guard new == .verified, old != .verified else { return }
            glowTick += 1
            withAnimation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion)) { checkedIn = true }
        }
        .cyHaptic(.impactMedium, trigger: appeared)
        .accessibilityIdentifier("ticketWallet.present")
        .cyDomainScreen(.player)
    }

    private var summary: some View {
        VStack {
            TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                .font(.title2.bold()).foregroundStyle(.primary)
                .multilineTextAlignment(.center).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            HStack {
                if let date = ticket.participateDate, !date.isEmpty {
                    Label { Text(verbatim: LocaleDisplay.civil(date, locale: locale)) } icon: { Image(systemName: "calendar") }
                }
                if let place = ticket.addressName, !place.isEmpty {
                    Label { Text(verbatim: place).lineLimit(2) } icon: { Image(systemName: "mappin.and.ellipse") }
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var tile: some View {
        if let codeFactory, ticket.status == .ready {
            VerificationCodeView(model: codeFactory(.init(kind: .ticket, id: ticket.id)))
                .frame(maxWidth: .infinity)
        } else {
            staffTile
        }
    }

    /// Honest fallback: the registration number in large type, so staff can read or key it. No code is drawn.
    private var staffTile: some View {
        VStack {
            if let number = ticket.registrationNumber, !number.isEmpty {
                Text(verbatim: number)
                    .font(typeSize.isAccessibilitySize ? .title2 : .largeTitle).monospaced()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5).lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)
                    .accessibilityLabel(Text(verbatim: c.t("票号", "Ticket number")))
                    .accessibilityValue(Text(verbatim: number))
                    .accessibilityIdentifier("ticketWallet.present.number")
            } else {
                Image(systemName: "ticket")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical)
                    .accessibilityHidden(true)
            }
            Text(verbatim: c.t("到场出示", "Show at the venue")).font(.headline).foregroundStyle(.primary)
            Text(verbatim: c.t("现场工作人员会为你核验，无需截图。", "Venue staff will check it for you. No screenshot needed."))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("ticketWallet.present.staffTile")
    }
}
