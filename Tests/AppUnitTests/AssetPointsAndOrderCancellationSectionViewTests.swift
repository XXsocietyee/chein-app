import XCTest
import SwiftUI
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

extension AssetPointsAndOrderCancellationSnapshot {
    static let defaultConservationSnapshot = AssetPointsAndOrderCancellationSnapshot(
        ownerScope: "member-i04-baseline",
        authoritativeBalancePoints: 1280,
        rows: [
            AssetPointsCancellationRow(
                id: "ord-cancel-101",
                orderNumber: "CY202610200101",
                deductedPoints: 200,
                refundedPointsFromAuthority: 200,
                state: .conservedByAuthority,
                note: "订单取消后经服务端流水回读确认 200 积分原路退回，本地不自造余额"
            ),
            AssetPointsCancellationRow(
                id: "ord-cancel-102",
                orderNumber: "CY202610200102",
                deductedPoints: 150,
                refundedPointsFromAuthority: nil,
                state: .awaitingServerReadback,
                note: "取消请求已受理，积分余额与退回明细等待服务端权威回读 (I04)"
            )
        ]
    )
}

@MainActor
final class AssetPointsAndOrderCancellationSectionViewTests: XCTestCase {
    func testEmptyDefaultSnapshotHasZeroHardcodedOrders() {
        let view = AssetPointsAndOrderCancellationSectionView()
        XCTAssertEqual(view.snapshot, .empty)
        XCTAssertNil(view.snapshot.authoritativeBalancePoints)
        XCTAssertTrue(view.snapshot.rows.isEmpty)
        XCTAssertEqual(view.snapshot.balanceDisplayText, "—（待服务端权威回读）")
    }

    func testSnapshotBuildsFromRealProfileOrders() throws {
        let raw = Data(#"[{"id":501,"registrationNo":"ORD-501","pointUsed":200,"pointsReturned":200},{"id":502,"registrationNo":"ORD-502","pointUsed":150}]"#.utf8)
        let orders = try JSONDecoder().decode([ProfileOrder].self, from: raw)
        let snapshot = AssetPointsAndOrderCancellationSnapshot(
            ownerScope: "member-real-orders",
            authoritativeBalancePoints: 600,
            orders: orders
        )
        XCTAssertEqual(snapshot.rows.map(\.orderNumber), ["ORD-501", "ORD-502"])
        XCTAssertEqual(snapshot.conservedCount, 1)
        XCTAssertEqual(snapshot.pendingReadbackCount, 1)
        XCTAssertEqual(snapshot.discrepancyCount, 0)
    }

    func testDefaultConservationSnapshotShowsAuthoritativeBalanceAndConservedRows() {
        let snapshot = AssetPointsAndOrderCancellationSnapshot.defaultConservationSnapshot
        XCTAssertTrue(snapshot.isConservationCompliant)
        XCTAssertEqual(snapshot.authoritativeBalancePoints, 1280)
        XCTAssertEqual(snapshot.conservedCount, 1)
        XCTAssertEqual(snapshot.pendingReadbackCount, 1)
        XCTAssertEqual(snapshot.discrepancyCount, 0)
        XCTAssertEqual(snapshot.summaryText, "守恒确认 1 · 待回读 1 · 异常 0")

        let view = AssetPointsAndOrderCancellationSectionView(snapshot: snapshot)
        _ = view.body
        XCTAssertEqual(view.snapshot, snapshot)
    }

    func testUnconfirmedBalanceAndDiscrepancyRowAreSurfacedExplicitly() {
        let rows: [AssetPointsCancellationRow] = [
            AssetPointsCancellationRow(
                id: "ord-cancel-201",
                orderNumber: "CY202610200201",
                deductedPoints: 300,
                refundedPointsFromAuthority: 100,
                state: .discrepancyDetected,
                note: "退回积分与扣减积分不一致，需人工复核"
            )
        ]
        let snapshot = AssetPointsAndOrderCancellationSnapshot(
            ownerScope: "member-i04-check",
            authoritativeBalancePoints: nil,
            rows: rows
        )
        XCTAssertFalse(snapshot.isConservationCompliant)
        XCTAssertEqual(snapshot.balanceDisplayText, "—（待服务端权威回读）")
        XCTAssertEqual(snapshot.discrepancyCount, 1)
        XCTAssertEqual(rows.first?.badgeText, "MISMATCH")
        XCTAssertEqual(rows.first?.deltaSummaryText, "扣减 -300 · 权威退回 +100")

        let view = AssetPointsAndOrderCancellationSectionView(snapshot: snapshot)
        _ = view.body
        XCTAssertEqual(view.snapshot.summaryText, "守恒确认 0 · 待回读 0 · 异常 1")
    }
}

@MainActor
final class G1ProductionGatesEndToEndTests: XCTestCase {
    private static let placeholderBaseURL = "https://api.example.com"
    private static let placeholderBundleIdentifier = "com.questify.ios"

    private func makeReviewedSession(wire: G1TestWire, vault: G1TestVault) throws -> (AppCompositionRoot, AppSession, UserDefaults) {
        let suite = "g1-gates-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(
            market: "CN",
            baseURL: Self.placeholderBaseURL,
            bundleIdentifier: Self.placeholderBundleIdentifier,
            realm: "g1-test-" + UUID().uuidString.lowercased()
        )
        let composition = RegionalLaunchConfiguration.reviewedComposition(
            build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }),
            makeTransport: { wire }
        )
        return (composition, composition.makeSession(), defaults)
    }

    func testUnconfiguredDefaultKeepsAllProductionGatesClosed() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let suite = "g1-unconfigured-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let unconfigured = RegionalLaunchConfiguration.makeComposition(
            reviewed: nil,
            build: .init(market: "CN", baseURL: Self.placeholderBaseURL, bundleIdentifier: Self.placeholderBundleIdentifier, realm: "g1-unconfigured"),
            storage: .init(defaults: defaults, tokenStore: { _ in vault }),
            makeTransport: { wire }
        )
        let session = unconfigured.makeSession()
        XCTAssertFalse(session.isConfigured)
        XCTAssertFalse(session.canUsePassword)
        XCTAssertFalse(session.authChannels.isConfigured)
        XCTAssertFalse(session.authChannels.appleConfigurationVerified)
        XCTAssertNil(session.accountComplianceCoordinator)
        XCTAssertFalse(session.walletHistoryReader.isConfigured)
        XCTAssertFalse(session.ownedOrderReader.isConfigured)
        XCTAssertFalse(session.profileFavoritesReader.isConfigured)
        XCTAssertFalse(session.profileOwnedCouponReader.isConfigured)
        let privacyResolution = try await session.legalReader.document(type: .privacyPolicy, market: .china)
        XCTAssertEqual(privacyResolution, .missing(.pendingSourceText))
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testGate1InAppAccountDeletionEndToEndAndErrorRetryThroughReviewedComposition() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let (_, session, _) = try makeReviewedSession(wire: wire, vault: vault)

        await session.authChannels.sendSMSCode(phone: "13800138000")
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(session.account?.id, 7)

        let coordinator = try XCTUnwrap(session.accountComplianceCoordinator)
        let safetyDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AccountComplianceSafety", isDirectory: true)
        if let safetyDir { try? FileManager.default.removeItem(at: safetyDir) }
        addTeardownBlock { if let safetyDir { try? FileManager.default.removeItem(at: safetyDir) } }

        await coordinator.load()
        XCTAssertEqual(coordinator.state.step, .notice)
        XCTAssertEqual(coordinator.state.status?.status, "NORMAL")

        await coordinator.precheckAndAgree(documentRead: true, explicitAgreement: true)
        XCTAssertEqual(coordinator.state.step, .verify)
        XCTAssertNil(coordinator.state.error)

        // Error state: SMS send fails -> stays on verify, surfaces error, blocks review transition
        wire.failNextSMS = true
        await coordinator.sendSMS(phone: "13800138000", explicitlyRequested: true)
        XCTAssertFalse(coordinator.state.smsSent)
        XCTAssertNotNil(coordinator.state.error)
        coordinator.prepareReview(code: "123456")
        XCTAssertEqual(coordinator.state.step, .verify)

        // Retry state: SMS send succeeds -> transitions to review -> apply -> confirmation + sign-out
        wire.failNextSMS = false
        await coordinator.sendSMS(phone: "13800138000", explicitlyRequested: true)
        XCTAssertTrue(coordinator.state.smsSent)
        XCTAssertNil(coordinator.state.error)

        coordinator.prepareReview(code: "123456")
        XCTAssertEqual(coordinator.state.step, .review)

        await coordinator.apply(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.step, .freshLogin)
        XCTAssertEqual(coordinator.state.status?.status, "PENDING")
        XCTAssertNil(session.account)
        XCTAssertNil(vault.value)
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/user/deregister/apply" })
    }

    func testGate2LegalCatalogAndConsentWithdrawalEndToEndThroughReviewedComposition() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let (composition, session, defaults) = try makeReviewedSession(wire: wire, vault: vault)

        // 1. All 3 legal documents resolve with real bilingual sections under reviewed deployment
        for docType in [SettingsLegalType.userAgreement, .privacyPolicy, .cancellationNotice] {
            let resolution = try await session.legalReader.document(type: docType, market: .china)
            guard case .sourceDocument(let doc) = resolution else {
                XCTFail("Expected sourceDocument for \(docType), got \(resolution)")
                return
            }
            XCTAssertFalse(doc.sections.isEmpty)
            XCTAssertFalse(doc.version.isEmpty)
        }

        // 2. App-level usage consent grant and withdrawal on device
        let policy = UsageConsentPolicy(storage: UserDefaultsUsageConsentStorage(defaults: defaults))
        try policy.agree(agreementChecked: true)
        XCTAssertTrue(policy.granted)
        policy.decline()
        XCTAssertFalse(policy.granted)

        // 3. Roam location consent withdrawal + Merchant marketing consent withdrawal
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(session.account?.id, 7)

        let safetyDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AccountComplianceSafety", isDirectory: true)
        if let safetyDir { try? FileManager.default.removeItem(at: safetyDir) }
        addTeardownBlock { if let safetyDir { try? FileManager.default.removeItem(at: safetyDir) } }

        let coordinator = try XCTUnwrap(session.accountComplianceCoordinator)
        wire.latestConsentDocType = "privacy_policy"
        wire.latestConsentScene = "roam_location"
        wire.latestConsentEvent = "REVOKE"
        await coordinator.revokeRoam(explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.roamCleanup, .complete)

        await coordinator.loadMarketing()
        XCTAssertTrue(coordinator.state.marketingLoaded)
        let row = try XCTUnwrap(coordinator.state.marketing.first)
        XCTAssertTrue(row.inAppOptedIn)
        let review = try XCTUnwrap(coordinator.reviewMarketing(row, channel: .inApp, optedIn: false))
        await coordinator.setMarketing(review, explicitlyConfirmed: true)
        XCTAssertEqual(coordinator.state.marketing.first?.inAppOptedIn, false)

        // Usage consent read approval is also available under reviewed deployment unless explicitly revoked
        let context = try XCTUnwrap(session.currentRuntimeDependencyContext)
        XCTAssertNotNil(composition.selectedUsageConsentReadApproval(context))
        composition.usageConsentReadSelection.revoke()
        XCTAssertNil(composition.selectedUsageConsentReadApproval(context))
    }

    func testGate3AppleAndSMSSignInEnabledAndRolelessUserInfoFallbackWorksWhilePasswordStaysDisabled() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let (_, session, _) = try makeReviewedSession(wire: wire, vault: vault)

        XCTAssertFalse(session.canUsePassword, "Password login must remain disabled")
        XCTAssertTrue(session.authChannels.isConfigured)
        XCTAssertTrue(session.authChannels.appleConfigurationVerified)

        // Apple Sign-In end to end
        let attempt = try XCTUnwrap(session.authChannels.beginAppleAuthorization())
        await session.authChannels.completeAppleAuthorization(attempt, identityToken: "apple.identity.jwt.token")
        XCTAssertEqual(session.account?.id, 7)
        XCTAssertEqual(vault.value, "synthetic-apple-7")
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/login/apple" })

        // Sign out and sign in via SMS when /api/userInfo omits role (master userInfoView whitelist)
        let snapshot = try XCTUnwrap(session.signOutConfirmation(accountID: 7))
        let signedOut = await session.logout(matching: snapshot)
        XCTAssertTrue(signedOut)
        XCTAssertNil(session.account)

        wire.omitRoleInUserInfo = true
        await session.authChannels.sendSMSCode(phone: "13800138000")
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(session.account?.id, 7)
        XCTAssertEqual(session.account?.role, "player")
        XCTAssertEqual(vault.value, "synthetic-7")
    }

    func testGate4WalletHistoryAndOverviewReadsOpenWhileBankWithdrawalAndVirtualGoodsStayOff() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let (_, session, _) = try makeReviewedSession(wire: wire, vault: vault)
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")

        XCTAssertTrue(session.walletHistoryReader.isConfigured)
        let stages = try await session.walletHistoryReader.read { try await $0.stages(token: $1) }
        XCTAssertEqual(stages.withdrawable.value, Decimal(string: "88.5"))
        let balance = try await session.walletHistoryReader.read { try await $0.ledger(.balance, token: $1) }
        XCTAssertEqual(balance.rows.first?.id, 61)
        let points = try await session.walletHistoryReader.read { try await $0.ledger(.assetPoints, token: $1) }
        XCTAssertEqual(points.rows.first?.id, 61)
        let withdrawals = try await session.walletHistoryReader.read { try await $0.withdrawals(token: $1) }
        XCTAssertEqual(withdrawals.rows.first?.id, 71)

        // Bank withdrawal and virtual goods remain strictly flagged off
        XCTAssertNil(session.makeBankWithdrawalContext())
    }

    func testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition() async throws {
        let wire = G1TestWire()
        let vault = G1TestVault()
        let (composition, session, _) = try makeReviewedSession(wire: wire, vault: vault)
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")

        // 1. Orders read + cancellation lifecycle
        let orderDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OrderLifecycle", isDirectory: true)
        if let orderDir { try? FileManager.default.removeItem(at: orderDir) }
        addTeardownBlock { if let orderDir { try? FileManager.default.removeItem(at: orderDir) } }

        XCTAssertTrue(session.ownedOrderReader.isConfigured)
        let orders = try await session.ownedOrderReader.profileOrders()
        XCTAssertEqual(orders.map(\.id), [41])
        let detail = try await session.ownedOrderReader.profileOrder(id: 41)
        XCTAssertEqual(detail.id, 41)

        await session.orderLifecycleCoordinator.load(id: 41)
        session.orderLifecycleCoordinator.prepare(.cancel, orderID: 41)
        XCTAssertTrue(session.orderLifecycleCoordinator.canDispatch)
        let review = try XCTUnwrap(session.orderLifecycleCoordinator.review)
        await session.orderLifecycleCoordinator.confirm(reviewID: review.id)
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/registration/cancel" })

        // 2. Participant addresses read + write (create/update + delete)
        let participants = try await session.participantReader.profileParticipants()
        XCTAssertEqual(participants.map(\.id), [9])
        let writerIdentity = try XCTUnwrap(session.participantWriter.identity)
        var draft = ParticipantFormDraft()
        draft.fullName = "张三"
        draft.mobilePhone = "13800138000"
        try await session.participantWriter.perform(.save(draft), expectedIdentity: writerIdentity)
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/user/address/action" })
        try await session.participantWriter.perform(.delete(id: 9), expectedIdentity: writerIdentity)
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/user/address/delete" })

        // 3. Favorites read + detail + topic unlike + post bookmark removal
        XCTAssertTrue(session.profileFavoritesReader.isConfigured)
        let favPosts = try await session.profileFavoritesReader.favoritePosts(pageNumber: 1, pageSize: 20)
        XCTAssertEqual(favPosts.rows.map(\.id), [301])
        let favTopics = try await session.profileFavoritesReader.favoriteTopics(pageNumber: 1, pageSize: 20)
        XCTAssertEqual(favTopics.rows.map(\.id), [88])

        let unlikeController = try XCTUnwrap(session.makeTopicUnlikeController())
        XCTAssertTrue(unlikeController.isAvailable)
        let unlikeID = try XCTUnwrap(unlikeController.request(topicID: 88))
        await unlikeController.confirm(unlikeID)
        XCTAssertEqual(unlikeController.phase, .removed(topicID: 88))

        let favScope = session.profileFavoritesReader.scope
        let removalController = try XCTUnwrap(session.makeProfileFavoriteRemovalController(scope: favScope))
        XCTAssertTrue(removalController.isAvailable(postID: 301, collectionScope: favScope))

        // 4. Owned coupons + coupon QR/status
        XCTAssertTrue(session.profileOwnedCouponReader.isConfigured)
        let coupons = try await session.profileOwnedCouponReader.ownedCoupons(keyword: nil)
        XCTAssertEqual(coupons.map(\.id), [31])

        let codeCoordinator = session.makeCouponCodeCoordinator(historyID: 31)
        XCTAssertTrue(codeCoordinator.enabled)
        await codeCoordinator.confirmPresentation()
        XCTAssertNotNil(codeCoordinator.receipt)
        XCTAssertTrue(wire.requests.contains { $0.url?.path == "/api/coupon/qr-token" })

        // 5. Merchant coupon management lease when signed in as merchant
        wire.role = "merchant"
        let logoutSnapshot = try XCTUnwrap(session.signOutConfirmation(accountID: 7))
        _ = await session.logout(matching: logoutSnapshot)
        await session.authChannels.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(session.account?.effectiveRole, "merchant")
        let merchantContext = try XCTUnwrap(session.currentRuntimeDependencyContext)
        XCTAssertNotNil(composition.couponReadApproval(merchantContext))
        XCTAssertNotNil(composition.couponWriteApproval(merchantContext))

        // 6. G2 hook & IM/club safety approvals open under reviewed composition
        XCTAssertTrue(session.messagingReader.isConfigured)
        XCTAssertTrue(session.imSafetyWriter.permits(.hide(conversationID: 10)))
        XCTAssertTrue(session.imSafetyWriter.permits(.report(conversationID: 10, messageID: 20)))
        XCTAssertTrue(session.imSafetyWriter.permits(.block(conversationID: 10, targetMemberID: 30)))
        XCTAssertTrue(session.imSafetyWriter.permits(.unblock(conversationID: 10, targetMemberID: 30)))
    }
}

private final class G1TestVault: AppTokenStorage {
    var value: String?
    func read() throws -> String? { value }
    func write(_ token: String) throws { value = token }
    func clear() throws { value = nil }
}

private final class G1TestWire: HTTPTransport {
    var requests: [URLRequest] = []
    var account = 7
    var role = "player"
    var omitRoleInUserInfo = false
    var failNextSMS = false
    var latestConsentDocType = "account_cancellation_notice"
    var latestConsentScene = "account_cancel"
    var latestConsentEvent = "AGREE"
    private var marketingOptedIn = true
    private var marketingRecordedRequests: Set<String> = []
    private var topicLiked = true

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/sms/send") {
            if failNextSMS {
                return (Data(#"{"code":500,"msg":"sms_failed"}"#.utf8), 200)
            }
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/login/phone") {
            return (Data("{\"code\":200,\"token\":\"synthetic-\(account)\",\"data\":{\"id\":\(account),\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/login/apple") {
            return (Data("{\"code\":200,\"token\":\"synthetic-apple-\(account)\",\"data\":{\"id\":\(account),\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/userInfo") {
            if omitRoleInUserInfo {
                return (Data("{\"code\":200,\"appUser\":{\"userId\":\(account),\"nickName\":\"G1 Tester\",\"userType\":1}}".utf8), 200)
            }
            return (Data("{\"code\":200,\"appUser\":{\"userId\":\(account),\"nickName\":\"G1 Tester\",\"role\":\"\(role)\"}}".utf8), 200)
        }
        if path.hasSuffix("/api/logout") {
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/status") {
            return (Data(#"{"code":200,"data":{"status":"NORMAL"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/precheck") {
            return (Data(#"{"code":200,"data":{"status":"ELIGIBLE","verificationMethod":"SMS"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/compliance/consents") && !path.hasSuffix("/latest") {
            if let body = request.httpBody,
               let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                latestConsentDocType = (obj["docType"] as? String) ?? latestConsentDocType
                latestConsentScene = (obj["scene"] as? String) ?? latestConsentScene
                latestConsentEvent = (obj["eventType"] as? String) ?? latestConsentEvent
            }
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/compliance/consents/latest") {
            let json = """
            {"code":200,"data":{"docType":"\(latestConsentDocType)","scene":"\(latestConsentScene)","eventType":"\(latestConsentEvent)","docVersion":"v1"}}
            """
            return (Data(json.utf8), 200)
        }
        if path.hasSuffix("/api/user/deregister/apply") {
            return (Data(#"{"code":200,"data":{"status":"PENDING","executeAfter":"2026-11-22 12:00:00"}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/merchant/crm/marketing-consents/result") || path.hasSuffix("/api/compliance/marketing-consents/result") {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let reqID = query.first(where: { $0.name == "requestId" })?.value ?? ""
            let channel = query.first(where: { $0.name == "channel" })?.value ?? "IN_APP"
            if marketingRecordedRequests.contains(reqID) {
                let eventType = marketingOptedIn ? "OPT_IN" : "OPT_OUT"
                let json = """
                {"code":200,"data":{"receiptVersion":1,"actorId":\(account),"merchantRowId":10,"merchantOwnerMemberId":20,"channel":"\(channel)","requestId":"\(reqID)","outcome":"RECORDED","consentId":101,"eventType":"\(eventType)","recordedAt":1762500000}}
                """
                return (Data(json.utf8), 200)
            }
            let json = """
            {"code":200,"data":{"receiptVersion":1,"actorId":\(account),"merchantRowId":10,"merchantOwnerMemberId":20,"channel":"\(channel)","requestId":"\(reqID)","outcome":"NOT_OBSERVED"}}
            """
            return (Data(json.utf8), 200)
        }
        if path.hasSuffix("/api/merchant/crm/marketing-consents") || path.hasSuffix("/api/compliance/marketing-consents") {
            if request.httpMethod == "POST",
               let body = request.httpBody,
               let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let reqID = obj["requestId"] as? String,
               let optedIn = obj["optedIn"] as? Bool {
                marketingOptedIn = optedIn
                marketingRecordedRequests.insert(reqID)
                return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
            }
            let json = """
            {"code":200,"data":[{"merchantRowId":10,"merchantOwnerMemberId":20,"merchantName":"测试商户","inAppOptedIn":\(marketingOptedIn),"couponOptedIn":false}]}
            """
            return (Data(json.utf8), 200)
        }
        if path.hasSuffix("/api/wallet/stages") {
            return (Data(#"{"code":200,"data":{"pendingSettlement":12,"disputed":0,"withdrawable":88.5,"complaintPeriod":[]}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/balance/list") || path.hasSuffix("/api/points/list") {
            return (Data(#"{"code":200,"data":[{"id":61,"memberId":7,"changeAmount":10.5,"createTime":"2026-10-01 10:00:00"}]}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/balance/list") {
            return (Data(#"{"code":200,"data":{"rows":[{"id":61,"changeBalance":12}],"total":1}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/withdrawal/list") {
            return (Data(#"{"code":200,"data":[{"id":71,"amount":20.0,"status":1,"createTime":"2026-10-02 10:00:00"}]}"#.utf8), 200)
        }
        if path.hasSuffix("/api/registration/list") {
            return (Data(#"{"code":200,"data":{"rows":[{"id":41,"memberId":7,"ownerType":2,"ownerId":100,"cmsActivity":{"id":100,"name":"测试活动","memberId":99},"registrationStatus":1,"paymentStatus":1,"verificationStatus":0,"payableAmount":12.0}],"total":1}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/registration/info") {
            return (Data(#"{"code":200,"data":{"id":41,"memberId":7,"ownerType":2,"ownerId":100,"cmsActivity":{"id":100,"name":"测试活动","memberId":99},"registrationStatus":1,"paymentStatus":1,"verificationStatus":0,"payableAmount":12.0}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/registration/cancel") {
            return (Data(#"{"code":200,"msg":"ok","data":{"registrationId":41,"cancellationStatus":"CANCELLED","cashRefundStatus":"NOT_NEEDED","pointsRefundStatus":"NOT_NEEDED","pointsUsed":0,"pointsReturned":0}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/address/list") {
            return (Data(#"{"code":200,"data":{"rows":[{"id":9,"fullName":"张三","mobilePhone":"13800138000","isDefault":1}]}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/address/action") {
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/user/address/delete") {
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/creativesquare/list") {
            return (Data(#"{"code":200,"data":{"rows":[{"id":301,"title":"收藏帖子","memberId":12}]}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/topic/like_list") {
            if topicLiked {
                return (Data(#"{"code":200,"data":{"rows":[{"id":88,"name":"收藏主题","memberId":12}]}}"#.utf8), 200)
            }
            return (Data(#"{"code":200,"data":{"rows":[]}}"#.utf8), 200)
        }
        if path.hasSuffix("/api/topic/like") {
            topicLiked = false
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        if path.hasSuffix("/api/coupon/myrecvlist") {
            return (Data(#"{"code":200,"data":[{"id":31,"memberId":7,"couponId":5,"couponName":"满减券","useStatus":0}]}"#.utf8), 200)
        }
        if path.hasSuffix("/api/coupon/qr-token") {
            return (Data(#"{"code":200,"data":{"expiresIn":60,"useStatus":0,"couponName":"满减券","token":"QR-TOKEN-31"}}"#.utf8), 200)
        }
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}
