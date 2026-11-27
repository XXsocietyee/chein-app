import SwiftUI

/// The pass in the ticket holder: art band with the title on a scrim, a status chip, info rows, a
/// perforated tear line with side notches (real cut-outs) and a stub. Press and hold to tilt it, tap for a foil
/// sheen. The stub never draws a fake code: the real pass is issued by `TicketPassPresentView` when the host
/// supplies a verification code factory, otherwise venue staff verify the ticket.
struct E1TicketCard: View {
    let ticket: TicketWalletTicket
    var fulfillmentNotice: String?
    var expiryText: String?
    /// Tilt and tap sheen. Off when the card is a still inside another control.
    var interactive = true
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = 64
    @State private var sheen = 0
    @State private var autoSheen = 0
    @State private var topHeight: CGFloat = 0
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private let radius = CYRadius.xl
    private let tearBand: CGFloat = 22
    private var state: CYPassState { CYPassState(ticket.status) }
    private var shape: CYTicketPassShape {
        CYTicketPassShape(notchY: topHeight > 0 ? topHeight + tearBand / 2 : -1, radius: radius, notch: 11, perforation: 3, perforationGap: 7)
    }

    var body: some View {
        VStack(spacing: 0) {
            top.background(GeometryReader { Color.clear.preference(key: E1TicketTopHeightKey.self, value: $0.size.height) })
            Color.clear.frame(height: tearBand).accessibilityHidden(true)
            stub
        }
        .onPreferenceChange(E1TicketTopHeightKey.self) { topHeight = $0 }
        // native-a r3: the pass sits on the system secondary background (Light/Dark by the system); no drawn gloss
        // line and no custom double drop shadow. The notch cut-outs and foil edge stay (P20: a pass, not a receipt).
        .background(.background.secondary)
        .cyFoilSheen(trigger: sheen + autoSheen)
        .clipShape(shape, style: FillStyle(eoFill: true))
        .cyPassFoilEdge(shape, active: ticket.status == .ready)
        .opacity(state.isRetired ? 0.74 : 1)
        .modifier(E1TicketTilt(enabled: interactive))
        .onTapGesture { if interactive { sheen += 1 } }
        .cyHaptic(.selection, trigger: sheen)
        .task {
            // The foil catches the light once when a live pass shows up (the lantern-gold hue stop travels across).
            guard interactive, ticket.status == .ready else { return }
            try? await Task.sleep(for: .milliseconds(500))
            autoSheen += 1
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(interactive ? Text(verbatim: c.t("轻点看光泽，长按拖动倾斜", "Tap for a shine, hold and drag to tilt")) : Text(verbatim: ""))
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                E1CoverArt(seed: ticket.title ?? "ticket", symbol: "ticket", debugLabel: false, symbolPoint: nil)
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                if !typeSize.isAccessibilitySize {
                    // Status chip top-right, exactly like the My pass card; the title keeps the bottom scrim.
                    VStack(spacing: 0) {
                        HStack(spacing: 0) { Spacer(minLength: 0); statusChip }
                        Spacer(minLength: 0)
                    }.padding(CYSpacing.lg)
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .cyText(.pageTitle).foregroundStyle(.white)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .padding(CYSpacing.lg)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("ticketWallet.detail.title")
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 96 : 196)
            .clipped()
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if typeSize.isAccessibilitySize {
                    statusChip
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("ticketWallet.detail.title")
                }
                if let date = ticket.participateDate, !date.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.participateDate", value: date, systemImage: "calendar")
                }
                if let place = ticket.addressName, !place.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.place", value: place, systemImage: "mappin.and.ellipse")
                }
                if let expiryText, !expiryText.isEmpty {
                    Text(verbatim: expiryText).cyText(.caption).foregroundStyle(CYColor.warningText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
        }
    }

    private var statusChip: some View {
        CYPassStatusChip(state: state, text: LocalizedStringKey("ticketWallet.status." + ticket.status.rawValue), identifier: "ticketWallet.detail.status")
    }

    @ViewBuilder private var stub: some View {
        VStack(spacing: CYSpacing.sm) {
            switch ticket.status {
            case .ready, .pending:
                Image(systemName: "qrcode").resizable().scaledToFit()
                    .frame(width: glyph, height: glyph)
                    .foregroundStyle(.black).padding(CYSpacing.md)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: ticket.status == .ready ? c.t("到场出示", "Show at the venue") : c.t("支付后可出示", "Available after payment"))
                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: ticket.status == .ready
                     ? c.t("现场工作人员会为你核验，无需截图。", "Venue staff will check it for you. No screenshot needed.")
                     : c.t("完成支付后，这张票就可以出示了。", "Once paid, this pass is ready to present."))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            case .verified:
                Group {
                    let seal = Image(systemName: "checkmark.seal.fill").resizable().scaledToFit()
                        .frame(width: glyph * 0.7, height: glyph * 0.7)
                        .foregroundStyle(CYColor.successText)
                    if #available(iOS 18.0, *) {
                        seal.symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                    } else {
                        seal
                    }
                }
                .accessibilityHidden(true)
                Text(verbatim: c.t("已核验入场", "Checked in")).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            case .cancelled, .expired, .unknown:
                Image(systemName: ticket.status == .unknown ? "questionmark.circle" : "ticket").resizable().scaledToFit()
                    .frame(width: glyph * 0.55, height: glyph * 0.55)
                    .foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                Text(verbatim: ticket.status == .cancelled ? c.t("此票已取消", "This ticket was cancelled") : ticket.status == .expired ? c.t("此票已过期", "This ticket has expired") : c.t("暂时无法确认票的状态", "Ticket status unavailable"))
                    .cyText(.cardTitle).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
            if let number = ticket.registrationNumber, !number.isEmpty {
                Text(verbatim: number).cyText(.caption).monospaced().foregroundStyle(CYColor.textTertiary)
                    .textSelection(.enabled)
            }
            if let fulfillmentNotice {
                Text(verbatim: fulfillmentNotice).cyText(.caption).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, CYSpacing.xs)
    }
}

private struct E1TicketTopHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Tilt only for the interactive card; a still (inside a NavigationLink) keeps the parent's gestures.
private struct E1TicketTilt: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.cyPassTilt() } else { content }
    }
}

extension CYPassState {
    /// Wallet status to ribbon state. Verified means the pass was used at the venue.
    init(_ status: TicketWalletStatus) {
        switch status {
        case .ready: self = .valid
        case .pending: self = .pending
        case .verified: self = .used
        case .expired: self = .expired
        case .cancelled: self = .cancelled
        case .unknown: self = .unknown
        }
    }
}
