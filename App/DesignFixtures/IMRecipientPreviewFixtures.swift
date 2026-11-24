#if DEBUG
import SwiftUI

/// DEBUG conversation preview. `--design-fixture im-preview` issues the six GETs.
/// `--design-fixture im-preview-refused` keeps a lease for conversation 11 and a message in 22.
enum IMRecipientPreviewFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "im-preview":
            return host(messageConversationID: 11, leaseConversationID: 11)
        case "im-preview-refused":
            return host(messageConversationID: 22, leaseConversationID: 11)
        default:
            return nil
        }
    }

    @MainActor private static func host(messageConversationID: Int, leaseConversationID: Int64) -> AnyView? {
        guard let message = decodedMessage(conversationID: messageConversationID) else { return nil }
        guard let viewer = viewer() else { return nil }
        let now = Date(timeIntervalSince1970: 1_763_000_000)
        var leases: [IMPreviewTemplateLease] = []
        for template in IMPreviewRouteTemplates.all {
            guard let lease = IMPreviewTemplateLease(
                template: template, viewer: viewer, conversationID: leaseConversationID, expiresAt: now.addingTimeInterval(3600)
            ) else { return nil }
            leases.append(lease)
        }
        let input = IMRecipientPreviewInput(phase: .ready, leases: leases, now: now)
        return AnyView(IMRecipientPreviewFixtureScreen(message: message, input: input))
    }

    private static func decodedMessage(conversationID: Int) -> MessagingMessage? {
        let json = #"{"id":42,"conversationId":\#(conversationID),"senderId":8,"status":0,"msgType":1,"content":"Fixture preview","createTime":"12:00"}"#
        return try? JSONDecoder().decode(MessagingMessage.self, from: Data(json.utf8))
    }

    private static func viewer() -> RuntimeDependencyContext? {
        guard let base = URL(string: "https://fixture.example") else { return nil }
        guard let session = try? PlayExperienceSession(accountID: 7, epoch: 1, namespace: "tests", token: "synthetic-token", role: "player") else { return nil }
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }
}

private struct IMRecipientPreviewFixtureScreen: View {
    let message: MessagingMessage
    let input: IMRecipientPreviewInput

    var body: some View {
        NavigationStack {
            List {
                IMRecipientPreviewRow(message: message, input: input)
                    .listRowBackground(CYColor.bgElevated)
                    .frame(minHeight: CurA11y.hit, alignment: .leading)
            }
            .navigationTitle(Text("im.preview.section", tableName: "IMRecipientPreview")).navigationBarTitleDisplayMode(.inline)
            .accessibilityLabel(Text("im.preview.section", tableName: "IMRecipientPreview"))
            .accessibilityHint(Text("curA11y.imPreview.hint", tableName: "CurA11y"))
            .accessibilityAddTraits(.isHeader)
        }
    }
}
#endif
