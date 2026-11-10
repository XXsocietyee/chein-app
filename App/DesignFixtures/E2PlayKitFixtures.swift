#if DEBUG
import SwiftUI

/// DEBUG-only host for the real `PlayKitScreen` forms: a static synthetic transport serves one node state, so the
/// play-kit cards, choice rows and fields are shot as shipped. Never writes (every action is rejected).
@MainActor private final class E2PlayKitTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        if request.url?.path.hasSuffix("/action") == true { throw PlayExperienceError.invalidAction }
        func opt(_ id: String, _ label: String) -> PlayWireValue { .object(["id": .string(id), "label": .string(label)]) }
        let qa: PlayWireValue = .object(["title": .string("断桥的名字从哪里来？"), "mode": .string("PICK"), "maxAttempts": .int(3), "attempts": .int(0), "remainingAttempts": .int(3),
            "options": .array([opt("a", "雪后初晴时桥面残雪未消"), opt("b", "桥因战乱被拦腰折断"), opt("c", "桥下常年没有水流")])])
        let profile: PlayWireValue = .object(["title": .string("给这趟旅程留个名片"), "avatar": .object(["enabled": .bool(false)]),
            "questions": .array([
                .object(["key": .string("mood"), "label": .string("今天的心情"), "kind": .string("pick"), "options": .array([.object(["key": .string("calm"), "label": .string("安静")]), .object(["key": .string("bold"), "label": .string("想多走走")])])]),
                .object(["key": .string("word"), "label": .string("用一句话形容西湖"), "kind": .string("text"), "maxLength": .int(40)]),
                .object(["key": .string("pace"), "label": .string("你的步调"), "kind": .string("text"), "maxLength": .int(20)])])])
        let note: PlayWireValue = .object(["title": .string("留一句话给下一位旅人"), "maxLength": .int(80), "presets": .array([.string("湖边的风很舒服"), .string("推荐傍晚来")]),
            "previous": .array([.object(["text": .string("桥头的桂花糕值得排队。"), "at": .number(1_792_382_400_000)])])])
        let photo: PlayWireValue = .object(["title": .string("拍下今天的断桥"), "shotNote": .string("让桥身和水面同时入镜"), "tries": .int(1), "maxTries": .int(3)])
        let state: PlayWireValue = .object(["sessionId": .int(1), "activityId": .int(41), "topicId": .int(71), "nodeId": .int(701), "version": .int(1), "status": .string("RUNNING"), "readyForBase": .bool(false),
            "playKit": .object(["qa": qa, "profile": profile, "note": note, "photoCheck": photo])])
        return (try JSONEncoder().encode(PlayWireValue.object(["code": .int(200), "data": state])), 200)
    }
}

@MainActor struct E2PlayKitHost: View {
    let kind: PlayKitScreenKind
    @State private var model: PlayAdvancedCoordinator
    init(kind: PlayKitScreenKind) {
        self.kind = kind
        let session = try! PlayExperienceSession(accountID: 1, epoch: 1, namespace: "synthetic-e2", token: "synthetic-token")
        let service = PlayExperienceService(configuration: try! APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: E2PlayKitTransport(), enabled: [.reads, .advanced])
        _model = State(initialValue: PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: { session }))
    }
    var body: some View {
        NavigationStack { PlayKitScreen(model: model, kind: kind) }.task { await model.start() }
    }
}
#endif
