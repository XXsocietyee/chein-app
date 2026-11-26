import SwiftUI

/// One working screen for each club and merchant-club path. A withheld call stays an em dash.
struct ClubGapBoardView: View {
    let client: ClubGapClient
    let token: String?
    let apiHost: String?
    let chinese: Bool
    @State private var replies: [String: ClubGapReply] = [:]

    var body: some View {
        List(ClubGapSurface.all) { surface in
            ClubGapSurfaceRow(surface: surface, chinese: chinese, reply: replies[surface.path],
                              merchantReply: replies[ClubGapPaths.merchantCooperationWrite],
                              send: submit)
        }
        .cyDomainScreen(.player)
    }

    private var payoutOpen: Bool { ReviewedAreaSwitch.payout(apiHost: apiHost) }
    private var merchantOpen: Bool { ReviewedAreaSwitch.merchantWrites(apiHost: apiHost) }

    private func submit(_ call: ClubGapCall) {
        let payout = payoutOpen
        let merchant = merchantOpen
        Task { @MainActor in
            let reply = await client.perform(call, token: token, allowsPayout: payout, allowsMerchantWrite: merchant)
            replies[call.path] = reply
        }
    }
}

private struct ClubGapSurfaceRow: View {
    let surface: ClubGapSurface
    let chinese: Bool
    let reply: ClubGapReply?
    let merchantReply: ClubGapReply?
    let send: (ClubGapCall) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: surface.title(chinese: chinese))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: surface.method + " /" + surface.path)
                .font(.footnote)
                .foregroundStyle(CYColor.textSecondary)
            CurA11yDashText(shown: ClubGapSurfaceRow.line(reply), color: CYColor.textSecondary)
                .accessibilityHint(Text("curA11y.club.result.hint", tableName: "CurA11y"))
            CurA11yTextButton(
                title: Text(verbatim: chinese ? "发送" : "Send"),
                hint: Text("curA11y.club.send.hint", tableName: "CurA11y"),
                action: { send(surface.call()) }
            )
            if surface.path == ClubGapPaths.coop {
                ClubGapMerchantRow(chinese: chinese, reply: merchantReply, send: send)
            }
        }
    }

    static func line(_ reply: ClubGapReply?) -> String {
        guard let reply, reply.sent else { return ClubGapReply.unknown }
        if reply.succeeded { return reply.message }
        if let errorCode = reply.errorCode, !errorCode.isEmpty { return errorCode }
        return reply.message
    }
}

private struct ClubGapMerchantRow: View {
    let chinese: Bool
    let reply: ClubGapReply?
    let send: (ClubGapCall) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: chinese ? "商家合作邀请" : "Merchant cooperation invite")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            CurA11yDashText(shown: ClubGapSurfaceRow.line(reply), color: CYColor.textSecondary)
                .accessibilityHint(Text("curA11y.club.result.hint", tableName: "CurA11y"))
            CurA11yTextButton(
                title: Text(verbatim: chinese ? "邀请" : "Invite"),
                hint: Text("curA11y.club.invite.hint", tableName: "CurA11y"),
                action: { send(ClubGapSurface.merchantInvite(topicID: 2, recipientID: 9)) }
            )
        }
    }
}
