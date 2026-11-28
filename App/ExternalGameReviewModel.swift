import Foundation
import Security
#if canImport(QuestifyCore)
import QuestifyCore
#endif

@available(macOS 14.0, *)
@MainActor @Observable final class ExternalGameReviewModel {
    let store: ExternalGameStore
    private let requestStore = JourneyMemoryRequestStore()
    var catalog: [ExternalGameCatalogFact] = []
    var catalogFailed = false
    var submissions: [ExternalGameSubmissionFact] = []
    var submissionsFailed = false
    var removedByKillSwitch: [String] = []
    var notice = ""
    var unconfirmedRequestID: String?
    var workshop = WorkshopModuleImportGate()
    var reportOutcome = ""
    var monetizationByGame: [String: ExternalGameMonetizationFact] = [:]
    var creatorSummary: ExternalGameCreatorSummary?
    var lastResultOutcome: ExternalGameResultOutcome?

    init(store: ExternalGameStore) {
        self.store = store
    }

    func reload(session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else {
            catalogFailed = true
            submissionsFailed = true
            return
        }
        adoptKey(await client.signingKey(token: token), host: session?.baseURL.host)
        switch await client.catalog(token: token) {
        case .loaded(let rows):
            catalog = rows
            catalogFailed = false
            if let removed = try? store.removeUnpublished(approvedGameIDs: Set(rows.map(\.gameID))) {
                removedByKillSwitch = removed
            }
        case .failed:
            catalogFailed = true
        }
        if let rows = await client.submissions(token: token) {
            submissions = rows
            submissionsFailed = false
        } else {
            submissionsFailed = true
        }
    }

    func install(gameID: String, session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else {
            notice = Self.unavailable
            return
        }
        adoptKey(await client.signingKey(token: token), host: session?.baseURL.host)
        guard let data = await client.downloadApproved(gameID: gameID, token: token) else {
            notice = Self.downloadFailed
            return
        }
        do {
            let file = URL(fileURLWithPath: gameID + ".questify-game.json")
            _ = try store.prepareImport(archiveData: data, source: .file(file))
            notice = ""
        } catch {
            notice = error.localizedDescription
        }
    }

    func submit(archive: Data, session: ExternalGameSessionBridge?) async {
        guard !ExternalGameReviewClient.workshopBinaryIsNotThisAPI(archive) else {
            notice = Self.workshopBinary
            return
        }
        guard let client = client(session), let token = session?.token else {
            notice = Self.unavailable
            return
        }
        apply(await client.submit(archive: archive, token: token))
        await reload(session: session)
    }

    func resubmit(submissionID: String, archive: Data, session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else {
            notice = Self.unavailable
            return
        }
        apply(await client.resubmit(submissionID: submissionID, archive: archive, token: token))
        await reload(session: session)
    }

    func cancel(submissionID: String, session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else {
            notice = Self.unavailable
            return
        }
        apply(await client.cancel(submissionID: submissionID, token: token))
        await reload(session: session)
    }

    func report(_ draft: ExternalGameReportDraft, session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else {
            reportOutcome = Self.unavailable
            return
        }
        switch await client.report(draft, token: token) {
        case .confirmed(let reportID, _, _):
            unconfirmedRequestID = nil
            reportOutcome = reportID
        case .refused(let message, let requestID):
            unconfirmedRequestID = nil
            reportOutcome = message.isEmpty ? "—" : message
            if !requestID.isEmpty { reportOutcome += " " + requestID }
        case .unknown(let requestID):
            unconfirmedRequestID = requestID
            reportOutcome = "—"
        }
    }

    func apply(_ outcome: ExternalGameWriteOutcome) {
        switch outcome {
        case .confirmed(let fact, let requestID):
            unconfirmedRequestID = nil
            noteWorkshop(requestID: requestID, status: fact.status?.rawValue)
            notice = ""
        case .refused(let message, let requestID):
            unconfirmedRequestID = nil
            notice = message.isEmpty ? "—" : message
            if !requestID.isEmpty { try? workshop.beginExternalGameReview(requestID: requestID) }
        case .unknown(let requestID):
            unconfirmedRequestID = requestID.isEmpty ? nil : requestID
            notice = ""
            if !requestID.isEmpty { try? workshop.beginExternalGameReview(requestID: requestID) }
        }
    }

    var workshopStatusText: String {
        workshop.externalGameServerStatus ?? "—"
    }

    private func noteWorkshop(requestID: String, status: String?) {
        guard !requestID.isEmpty else { return }
        try? workshop.beginExternalGameReview(requestID: requestID)
        guard let status else { return }
        _ = workshop.applyExternalGameServerStatus(status, requestID: requestID)
    }

    private func adoptKey(_ key: ExternalGameSigningKeyFact?, host: String?) {
        guard let key, key.configured, key.algorithm == "Ed25519", let raw = key.publicKeyRaw, raw.count == 32,
              let pinned = Self.pin(raw, host: host) else { return }
        store.adoptVerificationKey(pinned)
    }

    /// Owner 2026-11-13: the server's Ed25519 key is pinned per environment (API host) on first use. A different key
    /// for the same host is refused, so packages keep verifying against the pinned key only. No host, no key.
    /// Production pinning (default UserDefaults.standard) is anchored in Keychain (WhenUnlockedThisDeviceOnly).
    static func pin(_ raw: Data, host: String?, defaults: UserDefaults = .standard) -> Data? {
        guard let host = host?.lowercased(), !host.isEmpty, raw.count == 32 else { return nil }
        if defaults === UserDefaults.standard {
            return pinKeychain(raw, host: host)
        }
        let name = "externalGame.signingKey.pinned." + host
        if let stored = defaults.string(forKey: name).flatMap({ Data(base64Encoded: $0) }) {
            return stored == raw ? stored : nil
        }
        defaults.set(raw.base64EncodedString(), forKey: name)
        return raw
    }

    private static func pinKeychain(_ raw: Data, host: String) -> Data? {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "questify.externalGame.signingKey.v1",
            kSecAttrAccount as String: host,
            kSecAttrSynchronizable as String: false,
        ]
        var readQuery = baseQuery
        readQuery[kSecReturnAttributes as String] = true
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
        if status == errSecSuccess,
           let attrs = result as? [String: Any],
           let stored = attrs[kSecValueData as String] as? Data,
           stored.count == 32 {
            guard KeychainItemProtection.isDeviceOnlyUnlocked(attrs) else {
                SecItemDelete(baseQuery as CFDictionary)
                return nil
            }
            return stored == raw ? stored : nil
        }
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = raw
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else { return nil }
            return raw
        }
        return nil
    }

    private func client(_ session: ExternalGameSessionBridge?) -> ExternalGameReviewClient? {
        guard let session, let configuration = try? APIConfiguration(baseURL: session.baseURL) else { return nil }
        return ExternalGameReviewClient(configuration: configuration, transport: session.transport, store: requestStore)
    }

    private static var unavailable: String {
        W8Text.t("没有可用的接口，请求没有发出。", "No API is available, so the request was not sent.")
    }
    private static var downloadFailed: String {
        W8Text.t("没有下载到已签名的游戏包。", "The signed package was not downloaded.")
    }
    private static var workshopBinary: String {
        W8Text.t("工坊二进制包不会提交。请提交单个 HTML 游戏包。", "A workshop binary is not submitted. Submit a single HTML game package.")
    }

    func loadMonetization(gameID: String, session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else { return }
        if let fact = await client.monetizationConfig(gameID: gameID, token: token) {
            monetizationByGame[gameID] = fact
        }
    }

    func loadCreatorSummary(session: ExternalGameSessionBridge?) async {
        guard let client = client(session), let token = session?.token else { return }
        creatorSummary = await client.creatorSummary(token: token)
    }

    func saveMonetization(
        gameID: String,
        pricingMode: String,
        priceFen: Int,
        trafficRewardMode: String,
        channelFeeBearer: Int = 0,
        session: ExternalGameSessionBridge?
    ) async -> Bool {
        guard let client = client(session), let token = session?.token else { notice = Self.unavailable; return false }
        if let saved = await client.saveMonetizationConfig(
            gameID: gameID,
            pricingMode: pricingMode,
            priceFen: priceFen,
            trafficRewardMode: trafficRewardMode,
            channelFeeBearer: channelFeeBearer,
            token: token
        ) {
            monetizationByGame[gameID] = saved
            notice = W8Text.t("变现配置已提交审核（状态：\(saved.reviewStatus)）。", "Monetization config submitted (\(saved.reviewStatus)).")
            await loadCreatorSummary(session: session)
            return true
        }
        notice = W8Text.t("变现配置保存失败。", "Failed to save monetization config.")
        return false
    }

    func purchaseGame(gameID: String, session: ExternalGameSessionBridge?) async -> Bool {
        guard let session, let client = client(session) else { notice = Self.unavailable; return false }
        guard ReviewedAreaSwitch.moneyPayments(apiHost: session.baseURL.host),
              !ReleaseMoneyWriteSwitch.blocks(ExternalGameReviewPaths.orders) else {
            notice = W8Text.t("当前环境未开启付费购买。", "Paid purchases are disabled in this build or environment.")
            return false
        }
        if let order = await client.purchaseGame(gameID: gameID, token: session.token) {
            await loadMonetization(gameID: gameID, session: session)
            notice = W8Text.t("购买成功（订单 \(order.orderNo)），已解锁下载与游玩。", "Purchased (\(order.orderNo)). Download & play unlocked.")
            return true
        }
        notice = W8Text.t("购买未完成，请稍后确认。", "Purchase could not be completed.")
        return false
    }

    func bindNode(nodeID: Int, gameID: String, minScore: Int = 0, requirePass: Bool = true, session: ExternalGameSessionBridge?) async -> Bool {
        guard let client = client(session), let token = session?.token else { notice = Self.unavailable; return false }
        let ok = await client.bindNode(nodeID: nodeID, gameID: gameID, minScore: minScore, requirePass: requirePass, token: token)
        notice = ok
            ? W8Text.t("节点已绑定外部游戏 \(gameID)。", "Bound external game \(gameID) to node.")
            : W8Text.t("节点绑定失败。", "Failed to bind external game.")
        return ok
    }

    func startPlaySession(gameID: String, nodeID: Int? = nil, topicID: Int? = nil, activityID: Int? = nil, session: ExternalGameSessionBridge?) async -> ExternalGameSessionTicket? {
        guard let client = client(session), let token = session?.token else { return nil }
        return await client.startSession(gameID: gameID, nodeID: nodeID, topicID: topicID, activityID: activityID, token: token)
    }

    func submitSignedResult(ticket: ExternalGameSessionTicket, passed: Bool, score: Int?, durationMs: Int64, digest: String? = nil, session: ExternalGameSessionBridge?) async -> ExternalGameResultOutcome? {
        guard let client = client(session), let token = session?.token else { return nil }
        let outcome = await client.submitSignedResult(ticket: ticket, passed: passed, score: score, durationMs: durationMs, digest: digest, token: token)
        lastResultOutcome = outcome
        return outcome
    }
}
