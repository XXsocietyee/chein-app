import XCTest
@testable import Questify

/// K13: every player service on the Release composition is on, off by design, or was off by mistake.
/// China and the shipped US storefront both call `reviewedDeployment` on the pinned China backend.
/// A literal US-market deployment is not that path and stays dormant.
@MainActor final class ReleasePlayerServiceAuditTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"
    private static let releaseReads: Set<ReviewedAppDeployment.ReadGrant> = [
        .homeAndSearch, .manualMap, .publicMapLayers, .publicTopicTemplateCatalogAndDetail,
        .officialPublicEventCatalogAndDetail, .playNodesAndRouteState
    ]

    private enum Kind { case on, offByDesign, wasOffByMistake }
    private struct Row {
        let service: String
        let kind: Kind
        let isOn: (AppCompositionRoot, RuntimeDependencyContext) -> Bool

        init(service: String, kind: Kind, isOn: @escaping (AppCompositionRoot, RuntimeDependencyContext) -> Bool) {
            self.service = service
            self.kind = kind
            self.isOn = isOn
        }

        init(service: String, kind: Kind, isOn: @escaping (AppCompositionRoot) -> Bool) {
            self.init(service: service, kind: kind, isOn: { root, _ in isOn(root) })
        }
    }

    private func pinnedBuild() -> RegionalLaunchConfiguration.BuildMetadata {
        .init(market: RegionalMarket.china.rawValue, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
              bundleIdentifier: bundle, realm: realm)
    }

    /// The release path: `reviewedDeployment` with the reads `shippedComposition` passes in.
    private func releaseRoot() throws -> (ReviewedAppDeployment, AppCompositionRoot) {
        let build = pinnedBuild()
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(
            build: build, reads: Self.releaseReads, contentDetails: .activityAndTopic)
        let root = RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build, makeTransport: { QuietTransport() })
        return (deployment, root)
    }

    private func playerContext(_ composition: AppCompositionRoot, market: RegionalMarket) throws -> RuntimeDependencyContext {
        let reviewed = try XCTUnwrap(composition.reviewed)
        let base = try XCTUnwrap(reviewed.regional.apiConfiguration?.baseURL)
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: reviewed.storageScope.service, token: "player-token")
        return RuntimeDependencyContext(market: market, baseURL: base, role: "player", session: session)
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: "\(#filePath)")
        url.deleteLastPathComponent(); url.deleteLastPathComponent(); url.deleteLastPathComponent()
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }

    private func deps(_ root: AppCompositionRoot, _ context: RuntimeDependencyContext) -> NativeRuntimeDependencies {
        root.sessionDependencies(context)
    }

    func testReleaseCompositionEnumeratesPlayerServicesForChinaAndTheUnitedStates() throws {
        let (cnDeployment, cn) = try releaseRoot()
        let (usDeployment, us) = try releaseRoot()
        XCTAssertEqual(cnDeployment.regional.market, .china)
        XCTAssertEqual(usDeployment.regional.market, .china)
        XCTAssertTrue(cnDeployment.productionGatesEnabled)
        XCTAssertTrue(cnDeployment.playerWritesEnabled)
        XCTAssertEqual(cnDeployment.reads, Self.releaseReads)
        let shippedUS = RegionalLaunchConfiguration.shippedComposition(
            build: .init(market: "US", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { QuietTransport() })
        XCTAssertEqual(shippedUS.reviewed?.regional.market, usDeployment.regional.market)
        XCTAssertEqual(shippedUS.reviewed?.reads, usDeployment.reads)
        let cnContext = try playerContext(cn, market: .china)
        let usContext = try playerContext(us, market: .china)
        let merchantReleaseOn = try merchantCenterIsOnInReleaseSource()
        var on = 0, designed = 0, fixed = 0
        for row in catalog(merchantReleaseOn: merchantReleaseOn) {
            let cnOn = row.isOn(cn, cnContext)
            let usOn = row.isOn(us, usContext)
            XCTAssertEqual(cnOn, usOn, row.service)
            XCTAssertEqual(cnOn, row.kind != .offByDesign, row.service)
            switch row.kind {
            case .on: on += 1
            case .offByDesign: designed += 1
            case .wasOffByMistake: fixed += 1
            }
        }
        // City board is on for a China player only when QuestifyCityGameRegion is set (Debug gaps-a-test).
        // Release leaves the region empty, so the same row stays off by design there.
        let cityBoardOn = ReviewedProductionGateLeases.cityGameRegion != nil
        XCTAssertEqual(on, 54 + (cityBoardOn ? 1 : 0))
        XCTAssertEqual(designed, 26 - (cityBoardOn ? 1 : 0))
        XCTAssertEqual(fixed, 10)
    }

    func testWeeklyPointsPublicInfoAndGuideAreIssuedAndStable() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let weekly = try XCTUnwrap(root.profileWeeklyPointsReadApproval(context))
        XCTAssertTrue(weekly === root.profileWeeklyPointsReadApproval(context))
        XCTAssertTrue(weekly.endpoints.paths.contains(ProfileWeeklyPointsReadRoute.path))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ProfileWeeklyPointsReadRoute.path))
        let info = try XCTUnwrap(root.profilePublicInfoReadAccess(context))
        XCTAssertTrue(info === root.profilePublicInfoReadAccess(context))
        XCTAssertTrue(info.endpoints.paths.contains(ProfilePublicInfoReadRoute.path))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ProfilePublicInfoReadRoute.path))
        let guide = try XCTUnwrap(root.profileGuideReadAccess(context))
        XCTAssertTrue(guide === root.profileGuideReadAccess(context))
        XCTAssertEqual(guide.endpoints.paths, ProfileGuideReadRoute.paths)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ProfileGuideReadRoute.listPath))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + ProfileGuideReadRoute.detailPath))
        let injected = try ProfileWeeklyPointsReadApproval(context: context, expiresAt: Date().addingTimeInterval(600))
        let overridden = try overriddenRoot(profileWeeklyPointsReadApproval: { candidate in candidate == context ? injected : nil })
        XCTAssertTrue(overridden.profileWeeklyPointsReadApproval(context) === injected)
    }

    func testMemberRoleInfoIsIssuedForThePlayer() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let approval = try XCTUnwrap(root.memberRoleInfoReadApproval(context))
        XCTAssertTrue(approval === root.memberRoleInfoReadApproval(context))
        XCTAssertTrue(approval.matches(context))
        XCTAssertTrue(approval.endpoints.paths.contains(MemberRoleInfoReadRoute.path))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + MemberRoleInfoReadRoute.path))
    }

    func testOwnMediaListIsOnAndStatusStaysOff() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let approval = try XCTUnwrap(root.ownMediaReadApproval(context))
        XCTAssertFalse(approval.allowsStatus)
        XCTAssertTrue(approval === root.ownMediaReadApproval(context))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + OwnMediaReadRoute.path))
    }

    func testManualMapAndPublicLayersFollowTheReadGrant() throws {
        let (_, shipped) = try releaseRoot()
        let context = try playerContext(shipped, market: .china)
        let manual = try XCTUnwrap(shipped.manualMapReadApproval(context))
        let layers = try XCTUnwrap(shipped.mapPublicLayerReadApproval(context))
        XCTAssertEqual(manual.revision, shipped.manualMapReadApproval(context)?.revision)
        XCTAssertEqual(layers.revision, shipped.mapPublicLayerReadApproval(context)?.revision)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/map/nearby"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/roam/pois"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city/nodes"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/map/public-layers"))
        let build = pinnedBuild()
        let defaults = try RegionalLaunchConfiguration.reviewedDeployment(build: build)
        XCTAssertFalse(defaults.reads.contains(.manualMap))
        XCTAssertTrue(defaults.reads.contains(.publicMapLayers))
        let narrow = RegionalLaunchConfiguration.makeComposition(reviewed: defaults, build: build, makeTransport: { QuietTransport() })
        let narrowContext = try playerContext(narrow, market: .china)
        XCTAssertNil(narrow.manualMapReadApproval(narrowContext))
        XCTAssertNotNil(narrow.mapPublicLayerReadApproval(narrowContext))
    }

    func testSocialReaderObjectCardsAndMessageImagesAreOn() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let approval = try XCTUnwrap(root.sessionDependencies(context).socialReaderApproval)
        let again = try XCTUnwrap(root.sessionDependencies(context).socialReaderApproval)
        XCTAssertEqual(approval.endpoints, again.endpoints)
        XCTAssertTrue(approval.objectCards)
        XCTAssertTrue(approval.messageImages)
        XCTAssertFalse(approval.imageOrigins.isEmpty)
        XCTAssertTrue(approval.endpoints.paths.contains("api/object-card/list"))
        XCTAssertTrue(approval.endpoints.paths.contains("api/im/messages"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/object-card/list"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/messages"))
        let factory = SocialReaderProductionFactory(
            configuration: try APIConfiguration(baseURL: context.baseURL), approval: approval, current: { context })
        XCTAssertNotNil(factory.objectCards())
        XCTAssertNotNil(factory.messageMedia())
    }

    func testPlaySensorsAreOnWithoutChangingTheDeviceContract() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let config = try XCTUnwrap(root.sessionDependencies(context).configuration)
        XCTAssertEqual(config.devices, ReviewedProductionGateLeases.playDevices)
        XCTAssertEqual(config.sensors, ReviewedProductionGateLeases.playSensors)
        XCTAssertEqual(config.sensors, [.acceleration, .soundPeak, .heading])
        XCTAssertTrue(config.endpoints.paths.contains("api/play/sensor-result"))
        let again = try XCTUnwrap(root.sessionDependencies(context).configuration)
        XCTAssertEqual(again.sensors, config.sensors)
        XCTAssertEqual(again.playReadApprovalID, config.playReadApprovalID)
    }

    func testOwnerDraftListAndRestoreAreOnAndSaveDeleteStayOff() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let approval = try XCTUnwrap(root.ownerDraftReadApproval(context))
        XCTAssertEqual(approval.grant.routes, [.list, .restore])
        XCTAssertEqual(approval.grant.scope, .personal)
        XCTAssertFalse(approval.grant.routes.contains(.save))
        XCTAssertFalse(approval.grant.routes.contains(.delete))
        XCTAssertTrue(approval.matches(context))
        XCTAssertEqual(root.ownerDraftReadApproval(context)?.grant.expiresAt, approval.grant.expiresAt)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/content-draft/list"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/content-draft/restore"))
    }

    func testProductionGatesOffLeavesTheNewReadsNil() throws {
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: [.china: [ReviewedMarketLaunch.chinaProductionBaseURL]], verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: bundle, realm: "gates-off", reads: Self.releaseReads)
        XCTAssertFalse(deployment.productionGatesEnabled)
        let root = AppCompositionRoot(deployment: .reviewed(deployment), makeTransport: { QuietTransport() })
        let context = try playerContext(root, market: .china)
        XCTAssertNil(root.profileWeeklyPointsReadApproval(context))
        XCTAssertNil(root.profilePublicInfoReadAccess(context))
        XCTAssertNil(root.profileGuideReadAccess(context))
        XCTAssertNil(root.memberRoleInfoReadApproval(context))
        XCTAssertNil(root.ownMediaReadApproval(context))
        XCTAssertNil(root.manualMapReadApproval(context))
        XCTAssertNil(root.mapPublicLayerReadApproval(context))
        XCTAssertNil(root.ownerDraftReadApproval(context))
        XCTAssertNil(root.sessionDependencies(context).socialReaderApproval)
        XCTAssertNil(root.sessionDependencies(context).configuration)
    }

    func testLiteralUnitedStatesMarketDeploymentDoesNotIssueChinaPlayerLeases() throws {
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "US", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle, realm: realm)
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build, reads: Self.releaseReads, contentDetails: .activityAndTopic)
        XCTAssertEqual(deployment.regional.market, .unitedStates)
        XCTAssertTrue(deployment.productionGatesEnabled)
        let root = RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build, makeTransport: { QuietTransport() })
        let reviewed = try XCTUnwrap(root.reviewed)
        XCTAssertEqual(reviewed.regional.market, .unitedStates)
        let context = try playerContext(root, market: .unitedStates)
        XCTAssertNil(root.playerWriteGrant(context))
        XCTAssertNil(root.profileWeeklyPointsReadApproval(context))
        XCTAssertNil(root.memberRoleInfoReadApproval(context))
        XCTAssertNil(root.ownMediaReadApproval(context))
        XCTAssertNil(root.manualMapReadApproval(context))
        XCTAssertNil(root.mapPublicLayerReadApproval(context))
        XCTAssertNil(root.ownerDraftReadApproval(context))
        let runtime = root.sessionDependencies(context)
        XCTAssertNil(runtime.configuration)
        XCTAssertNil(runtime.socialReaderApproval)
        XCTAssertNil(runtime.clubGovernanceApproval)
    }

    func testMerchantMoneySecurityAndAccountDeletionStayOff() throws {
        let (deployment, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let runtime = root.sessionDependencies(context)
        XCTAssertNil(deployment.accountDeregistrationOriginalSource)
        XCTAssertNil(deployment.privateHome)
        XCTAssertNotEqual(deployment.regional.availability(of: .usernamePassword), .available)
        XCTAssertNil(root.merchantOperationsWriteApproval(context))
        XCTAssertNil(root.couponReadApproval(context))
        XCTAssertNil(root.couponWriteApproval(context))
        let order = try XCTUnwrap(runtime.orderLifecycleConfiguration)
        XCTAssertTrue(order.approvals.isEmpty)
        XCTAssertFalse(order.externalCheckoutApproved)
        XCTAssertTrue(order.devicePaymentApproved)
        XCTAssertNil(runtime.selfPlayPayment)
        XCTAssertNil(runtime.bankDocument)
        XCTAssertNil(runtime.signupDocument)
        XCTAssertNil(runtime.nativePlatform)
        XCTAssertNil(runtime.walkingNavigation)
        XCTAssertNil(runtime.journeyNarrativeImageReader)
        XCTAssertFalse(runtime.configuration?.journeyReads ?? true)
        XCTAssertFalse(runtime.configuration?.nearbyLocation ?? true)
        XCTAssertNil(root.projectTopicImageUploadApproval(context))
        XCTAssertNil(root.workshopPaidInstallApproval(context))
        XCTAssertNil(root.bundleApprovals.read(context))
        XCTAssertNil(root.makeSession().personalLocationShareScope)
        XCTAssertFalse(PlayerLaunch.merchantCenterEnabled && (try merchantCenterIsOnInReleaseSource()))
    }

    func testMerchantCenterStaysFalseOutsideDebug() throws {
        let source = try source("Core/PlayerLaunch.swift")
        XCTAssertTrue(source.contains("#else\n    public static let merchantCenterEnabled = false\n    #endif"))
    }

    /// The combined-r7 tip after this branch (sensor skip, play contact, team-command recovery, AI chat clear)
    /// did not add a new composition switch. Each rides a grant the census already marks on.
    func testCombinedR7PlayerAdditionsRideExistingGrants() throws {
        let (_, root) = try releaseRoot()
        let context = try playerContext(root, market: .china)
        let grant = try XCTUnwrap(root.playerWriteGrant(context))
        XCTAssertTrue(grant.play.paths.contains("api/play/contact"), "play contact row")
        XCTAssertEqual(root.sessionDependencies(context).configuration?.sensors, ReviewedProductionGateLeases.playSensors, "sensor skip")
        XCTAssertNotNil(root.nearbyTeamReadApproval(context), "team command recovery")
        XCTAssertNotNil(root.nearbyTeamWriteApproval(context), "team command recovery")
        XCTAssertTrue(root.releaseAINPCEnabled(context), "AI chat clear")
        let deletion = try XCTUnwrap(ReviewedProductionGateLeases.npcChatLogDeletionApproval(context))
        XCTAssertTrue(deletion.paths.contains("api/ai/npc/chat/data/delete"))
    }

    private func merchantCenterIsOnInReleaseSource() throws -> Bool {
        let text = try source("Core/PlayerLaunch.swift")
        return !text.contains("#else\n    public static let merchantCenterEnabled = false\n    #endif")
    }

    private func overriddenRoot(profileWeeklyPointsReadApproval: @escaping @MainActor (RuntimeDependencyContext) -> ProfileWeeklyPointsReadApproval?) throws -> AppCompositionRoot {
        let build = pinnedBuild()
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build, reads: Self.releaseReads, contentDetails: .activityAndTopic)
        return AppCompositionRoot(deployment: .reviewed(deployment), makeTransport: { QuietTransport() },
            profileWeeklyPointsReadApproval: profileWeeklyPointsReadApproval)
    }

    private func catalog(merchantReleaseOn: Bool) -> [Row] {
        let on = Kind.on, off = Kind.offByDesign, fixed = Kind.wasOffByMistake
        return [
            Row(service: "Play configuration", kind: on) { root, context in
                guard let config = root.sessionDependencies(context).configuration else { return false }
                return config.devices == ReviewedProductionGateLeases.playDevices
                    && config.play.isSuperset(of: [.mediaUpload, .preference, .tags]) && !config.artworkHosts.isEmpty
            },
            Row(service: "Player write grant", kind: on) { $0.playerWriteGrant($1) != nil },
            Row(service: "Club governance", kind: on) { $0.sessionDependencies($1).clubGovernanceApproval != nil },
            Row(service: "Official player actions", kind: on) { $0.sessionDependencies($1).officialActionApproval != nil },
            Row(service: "Contextual review", kind: on) { $0.sessionDependencies($1).contextualReviewApproval != nil },
            Row(service: "Player coupon QR", kind: on) { $0.sessionDependencies($1).couponCodeApproval != nil },
            Row(service: "Order device-payment flag", kind: on) { $0.sessionDependencies($1).orderLifecycleConfiguration?.devicePaymentApproved == true },
            Row(service: "Non-cash rewards", kind: on) { $0.sessionDependencies($1).nonCashRewardApproved },
            Row(service: "Club community read", kind: on) { $0.clubCommunityReadApproval($1) != nil },
            Row(service: "Club post image upload", kind: on) { $0.clubPostImageUploadApproval($1, 3) != nil },
            Row(service: "Club badges", kind: on) { $0.clubBadgeManagementApproval($1) != nil },
            Row(service: "Club role assignment", kind: on) { $0.clubRoleAssignmentApproval($1) != nil },
            Row(service: "Club welcome note", kind: on) { $0.clubWelcomeNoteWriteApproval($1) != nil },
            Row(service: "Club public roster", kind: on) { $0.clubPublicRosterApproval($1) != nil },
            Row(service: "Club public topics", kind: on) { root, context in
                let topics = ClubPublicTopicsContext(identity: .init(accountID: 7, epoch: 1), viewerRevision: 1, role: "player",
                    baseURL: context.baseURL, namespace: context.session.namespace)
                return root.clubPublicTopicsApproval(topics, 3) != nil
            },
            Row(service: "Template shelf", kind: on) { $0.templateShelfReadApproval($1) != nil },
            Row(service: "Template authoring", kind: on) { $0.templateAuthoringOriginalReadApproval($1) != nil },
            Row(service: "Story image upload", kind: on) { $0.projectStoryImageUploadApproval($1) != nil },
            Row(service: "Story audio upload", kind: on) { $0.projectStoryAudioUploadApproval($1) != nil },
            Row(service: "Node image upload", kind: on) { $0.projectNodeImageUploadApproval($1) != nil },
            Row(service: "Owned topic cover", kind: on) { $0.ownedTopicCoverApproval($1) != nil },
            Row(service: "Roam nearby events", kind: on) { $0.roamNearbyEventsReadAccess($1) != nil },
            Row(service: "Roam nearby players", kind: on) { $0.roamNearbyPlayersReadAccess($1) != nil },
            Row(service: "Roam entry nearby", kind: on) { $0.roamEntryNearbyReadAccess($1) != nil },
            Row(service: "Received stamps", kind: on) { $0.roamReceivedStampReadAccess($1) != nil },
            Row(service: "Roam album", kind: on) { $0.roamAlbumMetadataReadAccess($1) != nil },
            Row(service: "Roam tiles", kind: on) { $0.roamTileMemoryReadAccess($1) != nil },
            Row(service: "Roam session fact", kind: on) { $0.roamSessionFactReadAccess($1) != nil },
            Row(service: "Passport tools", kind: on) { $0.roamPassportToolsReadAccess($1) != nil },
            Row(service: "Passport history", kind: on) { $0.roamPassportHistoryReadAccess($1) != nil },
            Row(service: "Roam live", kind: on) { $0.roamLiveApproval($1) != nil },
            Row(service: "Roam private tools write", kind: on) { $0.roamPrivateToolsWriteAccess($1) != nil },
            Row(service: "Wallet history", kind: on) { $0.walletHistoryReadApproval($1) != nil },
            Row(service: "Messaging history", kind: on) { $0.messagingHistoryReadApproval($1) != nil },
            Row(service: "Owned orders", kind: on) { $0.ownedOrderReadApproval($1) != nil },
            Row(service: "Favorites", kind: on) { $0.profileFavoritesReadAccess($1) != nil },
            Row(service: "Favorite topic", kind: on) { $0.profileFavoriteTopicReadAccess($1) != nil },
            Row(service: "Invite history", kind: on) { $0.profileInviteHistoryReadAccess($1) != nil },
            Row(service: "Growth reads", kind: on) { $0.growthNormalReadApproval($1) != nil },
            Row(service: "Team read", kind: on) { $0.teamReadApproval($1) != nil },
            Row(service: "Explore completion", kind: on) { $0.exploreCompletionReadApproval($1) != nil },
            Row(service: "Invoice reads", kind: on) { $0.invoiceLaunchReadApproval($1) != nil },
            Row(service: "Nearby team read", kind: on) { $0.nearbyTeamReadApproval($1) != nil },
            Row(service: "Nearby team write", kind: on) { $0.nearbyTeamWriteApproval($1) != nil },
            Row(service: "Topic unlike", kind: on) { $0.topicUnlikeApproval($1) != nil },
            Row(service: "Profile participant", kind: on) { $0.profileParticipantAccess($1) != nil },
            Row(service: "City voucher and ticket codes", kind: on) { $0.verificationCodeApproval($1) != nil },
            Row(service: "Owned coupons", kind: on) { $0.profileOwnedCouponReadAccess($1) != nil },
            Row(service: "Social member follow and chat issuer", kind: on) { root, _ in
                guard let reviewed = root.reviewed else { return false }
                return AppSession.releaseIssuesSocialMemberActions(reviewed)
            },
            Row(service: "Business runtime", kind: on) { $0.sessionDependencies($1).businessConfiguration != nil },
            Row(service: "Shop NPC text", kind: on) { root, context in
                let runtime = root.sessionDependencies(context)
                return runtime.shopNPCGrants.textAllowed && runtime.configuration?.shopNPCWrites == true
            },
            Row(service: "Activity editing", kind: on) { MPFirstSocialApprovals.activityEditing($0)($1).read != nil },
            Row(service: "Merchant business writes", kind: on) { $0.sessionDependencies($1).merchantBusinessApproval != nil },
            Row(service: "Merchant engagement writes", kind: on) { $0.sessionDependencies($1).merchantEngagementApproval != nil },
            Row(service: "Weekly points", kind: fixed) { $0.profileWeeklyPointsReadApproval($1) != nil },
            Row(service: "Public profile", kind: fixed) { $0.profilePublicInfoReadAccess($1) != nil },
            Row(service: "Guide", kind: fixed) { $0.profileGuideReadAccess($1) != nil },
            Row(service: "Member role info", kind: fixed) { $0.memberRoleInfoReadApproval($1) != nil },
            Row(service: "Own media list", kind: fixed) { $0.ownMediaReadApproval($1) != nil },
            Row(service: "Manual map", kind: fixed) { $0.manualMapReadApproval($1) != nil },
            Row(service: "Public map layers", kind: fixed) { $0.mapPublicLayerReadApproval($1) != nil },
            Row(service: "Social reader", kind: fixed) { $0.sessionDependencies($1).socialReaderApproval?.objectCards == true },
            Row(service: "Play kit sensors", kind: fixed) { root, context in
                root.sessionDependencies(context).configuration?.sensors == ReviewedProductionGateLeases.playSensors
            },
            Row(service: "Owner draft list and restore", kind: fixed) { root, context in
                root.ownerDraftReadApproval(context)?.grant.routes == [.list, .restore]
            },
            Row(service: "Merchant center in Release", kind: off) { _, _ in merchantReleaseOn },
            Row(service: "Merchant operations for a player", kind: off) { $0.merchantOperationsWriteApproval($1) != nil },
            Row(service: "Merchant coupon management for a player", kind: off) { root, context in
                root.couponReadApproval(context) != nil || root.couponWriteApproval(context) != nil
            },
            Row(service: "Order payment approvals", kind: off) { root, context in
                root.sessionDependencies(context).orderLifecycleConfiguration?.approvals.isEmpty == false
            },
            Row(service: "External checkout", kind: off) { $0.sessionDependencies($1).orderLifecycleConfiguration?.externalCheckoutApproved == true },
            Row(service: "Self-play payment", kind: off) { $0.sessionDependencies($1).selfPlayPayment != nil },
            Row(service: "Bank withdrawal document", kind: off) { $0.sessionDependencies($1).bankDocument != nil },
            Row(service: "Signup payment document", kind: off) { $0.sessionDependencies($1).signupDocument != nil },
            Row(service: "Workshop paid install", kind: off) { $0.workshopPaidInstallApproval($1) != nil },
            Row(service: "Workshop purchased packages", kind: off) { root, context in
                root.workshopPurchasedReadApproval(context) != nil && !ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host)
            },
            Row(service: "Bundle approvals", kind: off) { $0.bundleApprovals.read($1) != nil },
            Row(service: "Account deletion source", kind: off) { $0.reviewed?.accountDeregistrationOriginalSource != nil },
            Row(service: "Password login", kind: off) { $0.reviewed?.regional.availability(of: .usernamePassword) == .available },
            Row(service: "Journey reads", kind: off) { $0.sessionDependencies($1).configuration?.journeyReads == true },
            Row(service: "Journey narrative images", kind: off) { $0.sessionDependencies($1).journeyNarrativeImageReader != nil },
            Row(service: "Native platform acceptance", kind: off) { $0.sessionDependencies($1).nativePlatform != nil },
            Row(service: "Walking navigation", kind: off) { $0.sessionDependencies($1).walkingNavigation != nil },
            Row(service: "Personal location share", kind: off) { $0.makeSession().personalLocationShareScope != nil },
            Row(service: "Project topic image", kind: off) { $0.projectTopicImageUploadApproval($1) != nil },
            Row(service: "Nearby merchant location", kind: off) { $0.sessionDependencies($1).configuration?.nearbyLocation == true },
            Row(service: "Private home", kind: off) { $0.reviewed?.privateHome != nil },
            Row(service: "Owner refund beyond the money switch", kind: off) { root, context in
                let runtime = root.sessionDependencies(context)
                return runtime.ownerRefundApproval != nil && !ReleaseMoneyWriteSwitch.isEnabled(.refund)
            },
            Row(service: "City board", kind: ReviewedProductionGateLeases.cityGameRegion == nil ? off : on) { $0.cityPlayerReadApproval($1) != nil },
            Row(service: "Own media status writes", kind: off) { $0.ownMediaReadApproval($1)?.allowsStatus == true },
            Row(service: "Owner draft save and delete", kind: off) { root, context in
                let routes = root.ownerDraftReadApproval(context)?.grant.routes ?? []
                return routes.contains(.save) || routes.contains(.delete)
            },
            Row(service: "Shop NPC reply playback", kind: off) { $0.sessionDependencies($1).shopNPCGrants.playback },
        ]
    }
}

private final class QuietTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { (Data(), 200) }
}
