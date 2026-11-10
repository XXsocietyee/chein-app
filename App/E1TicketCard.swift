import SwiftUI

/// Wallet ticket: art band with the title on a scrim, info rows, a perforation with side notches and a stub
/// ("show at venue" state). The stub never draws a fake code: the real pass is verified by venue staff.
struct E1TicketCard: View {
    let ticket: TicketWalletTicket
    var fulfillmentNotice: String?
    var expiryText: String?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private let radius = CYRadius.xl

    var body: some View {
        VStack(spacing: 0) {
            top
            perforation
            stub
        }
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(CYColor.borderSubtle, lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                E1CoverArt(seed: ticket.title ?? "ticket", symbol: "ticket", debugLabel: false)
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                if !typeSize.isAccessibilitySize {
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .font(CYTypography.pageTitle).foregroundStyle(.white)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .padding(CYSpacing.lg)
                        .accessibilityIdentifier("ticketWallet.detail.title")
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 90 : 190)
            .overlay(alignment: .topLeading) {
                TicketWalletStatusBadge(status: ticket.status).padding(CYSpacing.md)
            }
            .clipped()
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if typeSize.isAccessibilitySize {
                    TicketWalletTitle(title: ticket.title, untitledKey: ticket.untitledKey)
                        .font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ticketWallet.detail.title")
                }
                if let date = ticket.participateDate, !date.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.participateDate", value: date, systemImage: "calendar")
                }
                if let place = ticket.addressName, !place.isEmpty {
                    QuestifyMetadataLine(label: "ticketWallet.place", value: place, systemImage: "mappin.and.ellipse")
                }
                if let expiryText, !expiryText.isEmpty {
                    Text(verbatim: expiryText).font(CYTypography.caption).foregroundStyle(CYColor.warningText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
        }
    }

    private var perforation: some View {
        ZStack {
            Line().stroke(CYColor.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [6, 5])).frame(height: 1).padding(.horizontal, 18)
            HStack {
                Circle().fill(CYColor.bgPage).frame(width: 22, height: 22).offset(x: -11)
                Spacer()
                Circle().fill(CYColor.bgPage).frame(width: 22, height: 22).offset(x: 11)
            }
        }
        .frame(height: 22).accessibilityHidden(true)
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
    }

    @ViewBuilder private var stub: some View {
        VStack(spacing: CYSpacing.sm) {
            switch ticket.status {
            case .ready, .pending:
                Image(systemName: "qrcode").font(.system(size: typeSize.isAccessibilitySize ? 44 : 72, weight: .light))
                    .foregroundStyle(.black).padding(CYSpacing.md)
                    .background(.white, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: c.t("到场出示", "Show at the venue")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: c.t("现场工作人员会为你核验，无需截图。", "Venue staff will check it for you. No screenshot needed."))
                    .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            case .verified:
                Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(CYColor.successText)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion).accessibilityHidden(true)
                Text(verbatim: c.t("已核验入场", "Checked in")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            case .cancelled, .expired, .unknown:
                Image(systemName: ticket.status == .unknown ? "questionmark.circle" : "ticket").font(.system(size: 36)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                Text(verbatim: ticket.status == .cancelled ? c.t("此票已取消", "This ticket was cancelled") : ticket.status == .expired ? c.t("此票已过期", "This ticket has expired") : c.t("暂时无法确认票的状态", "Ticket status unavailable"))
                    .font(CYTypography.cardTitle).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
            if let number = ticket.registrationNumber, !number.isEmpty {
                Text(verbatim: number).font(CYTypography.caption.monospaced()).foregroundStyle(CYColor.textTertiary)
                    .textSelection(.enabled)
            }
            if let fulfillmentNotice {
                Text(verbatim: fulfillmentNotice).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, CYSpacing.sm)
    }
}
