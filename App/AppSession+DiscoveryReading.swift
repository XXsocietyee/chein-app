import Foundation

/// Discovery, merchant, and club catalog reads. Kept out of `AppSession.swift` (size ratchet).
// Views never own credentials; every completion is bound to the captured session.
extension AppSession: DiscoveryReading, MerchantReading {
    private func readDiscovery<Value>(expiresSession: Bool = true,
        _ operation:(DiscoveryService,String?) async throws -> Value) async throws -> Value {
        guard let discoveryService else { throw APIError.notConfigured }
        let stamp=gate.currentStamp, credential=token, viewerRevision=compositionViewerRevision
        do {
            let value=try await operation(discoveryService,credential)
            try Task.checkCancellation()
            guard gate.isCurrent(stamp), credential == token,
                  viewerRevision == compositionViewerRevision else { throw CancellationError() }
            return value
        } catch {
            // Fence identity-only refreshes before unauthorized expiration, including ABA.
            guard gate.isCurrent(stamp), credential == token,
                  viewerRevision == compositionViewerRevision, !Task.isCancelled else { throw CancellationError() }
            if expiresSession { expireIfMatching(error:error,stamp:stamp,credential:credential) }
            throw error
        }
    }
    func discoveryBanners() async throws -> [DiscoveryBanner] { try await readDiscovery { try await $0.banners(token:$1) } }
    func discoveryCategories(type:Int?) async throws -> [DiscoveryCategory] { try await readDiscovery { try await $0.categories(type:type,token:$1) } }
    func templateMetadataDictionary(kind: TemplateMetadataKind) async throws -> [TemplateMetadataOption] {
        try await readDiscovery { try await $0.templateMetadataDictionary(kind: kind, token: $1) }
    }
    func templateMetadataDictionaryRequest(kind: TemplateMetadataKind) -> DiscoveryReadRequest<[TemplateMetadataOption]> {
        templateMetadataRequest { try await $0.templateMetadataDictionary(kind: kind, token: $1) }
    }
    func templateMetadataCategoriesRequest() -> DiscoveryReadRequest<[DiscoveryCategory]> {
        templateMetadataRequest { try await $0.categories(type: 4, token: $1) }
    }
    func projectMetadataCategoriesRequest() -> DiscoveryReadRequest<[DiscoveryCategory]> {
        templateMetadataRequest { try await $0.categories(type: 1, token: $1) }
    }
    // Only an accepted, still-present selector can expire its captured identity.
    private func templateMetadataRequest<Value>(
        _ operation: @escaping (DiscoveryService, String?) async throws -> Value
    ) -> DiscoveryReadRequest<Value> {
        let stamp = gate.currentStamp, credential = token, viewerRevision = compositionViewerRevision
        return DiscoveryReadRequest(read: { [weak self] in
            guard let self, self.gate.isCurrent(stamp), credential == self.token,
                  viewerRevision == self.compositionViewerRevision else { throw CancellationError() }
            return try await self.readDiscovery(expiresSession: false, operation)
        }, onUnauthorized: { [weak self] in
            guard let self, viewerRevision == self.compositionViewerRevision else { return }
            self.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: credential)
        })
    }
    func discoveryTemplateHome() async throws -> DiscoveryTemplateHome { try await readDiscovery { try await $0.templateHome(token:$1) } }
    func discoveryPlayTemplates(keyword:String,packType:DiscoveryPackType?) async throws -> [DiscoveryPlayTemplate] { try await readDiscovery { try await $0.playTemplates(keyword:keyword,packType:packType,token:$1) } }
    func publicTopicTemplateCoordinator(id: Int) -> PublicTopicTemplateCoordinator {
        makePublicTopicTemplateCoordinator(id: id) { [weak self] id in
            guard let self else { throw CancellationError() }
            // The coordinator expires only an accepted current-generation failure.
            return try await self.readPublicTopicTemplate(id: id, expiresSession: false)
        }
    }
    /// Shared owner construction permits offline lifecycle tests without granting an HTTP route.
    func makePublicTopicTemplateCoordinator(id: Int,
        read: @escaping @MainActor (Int) async throws -> PublicTopicTemplateDetail) -> PublicTopicTemplateCoordinator {
        publicTemplateDetails.synchronize(PublicTemplateViewerContext(
            accountID: account?.id, role: account?.effectiveRole,
            realm: regionalConfiguration?.apiConfiguration?.baseURL.absoluteString ?? "",
            revision: gate.currentStamp))
        let stamp = gate.currentStamp, credential = token, epoch = publicTemplateDetails.epoch
        return publicTemplateDetails.coordinator(id: id, onUnauthorized: { [weak self] in
            guard let self, self.publicTemplateDetails.epoch == epoch else { return }
            self.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: credential)
        }, read: read)
    }
    func discoveryTopicTemplateDetail(id: Int) async throws -> PublicTopicTemplateDetail {
        try await readPublicTopicTemplate(id: id, expiresSession: true)
    }
    private func readPublicTopicTemplate(id: Int, expiresSession: Bool) async throws -> PublicTopicTemplateDetail {
        guard let discoveryService else { throw APIError.notConfigured }
        let stamp = gate.currentStamp, credential = token, epoch = publicTemplateDetails.epoch
        func current() -> Bool {
            gate.isCurrent(stamp) && credential == token && epoch == publicTemplateDetails.epoch
        }
        do {
            let result = try await discoveryService.publicTopicTemplate(id: id, token: credential)
            try Task.checkCancellation()
            guard current() else { throw CancellationError() }
            return result
        } catch {
            // A revoked role's late 401 must not expire the new viewer context.
            guard current(), !Task.isCancelled else { throw CancellationError() }
            if expiresSession { expireIfMatching(error: error, stamp: stamp, credential: credential) }
            throw error
        }
    }
    func discoveryTopicTemplates() async throws -> [DiscoveryTopicTemplate] { try await readDiscovery { try await $0.topicTemplates(token:$1) } }
    func publicTopicTemplateCatalogRequest() -> DiscoveryReadRequest<[DiscoveryTopicTemplate]> {
        let stamp = gate.currentStamp, credential = token, viewerRevision = compositionViewerRevision
        return DiscoveryReadRequest(read: { [weak self] in
            guard let self, self.gate.isCurrent(stamp), credential == self.token,
                  viewerRevision == self.compositionViewerRevision else { throw CancellationError() }
            return try await self.readDiscovery(expiresSession: false) { try await $0.topicTemplates(token: $1) }
        }, onUnauthorized: { [weak self] in
            guard let self, viewerRevision == self.compositionViewerRevision else { return }
            self.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: credential)
        })
    }
    func discoveryPlayTemplate(id:Int) async throws -> DiscoveryPlayTemplate { try await readDiscovery { try await $0.playTemplate(id:id,token:$1) } }
    func discoveryPlayTemplateRead(id:Int) async throws -> DiscoveryPlayTemplateRead { try await readDiscovery { try await $0.playTemplateRead(id:id,token:$1) } }

    private func readMerchant<Value>(access:MerchantAccess?=nil, expectedDiscoveryScope: ClubDiscoveryScope? = nil,_ operation:(MerchantService,String) async throws -> Value) async throws -> Value {
        guard let merchantService else { throw APIError.notConfigured }
        guard account != nil, let credential=token else { throw APIError.unauthorized }
        let stamp=gate.currentStamp
        if let access {
            guard let record=merchantAccessRecord, record.stamp == stamp, record.access == access else { throw MerchantReadError.accessDenied }
        }
        do {
            let value=try await operation(merchantService,credential)
            try Task.checkCancellation()
            guard gate.isCurrent(stamp), credential == token,
                  expectedDiscoveryScope == nil || expectedDiscoveryScope == clubDiscoveryScope else { throw CancellationError() }
            return value
        } catch {
            guard expectedDiscoveryScope == nil || !Task.isCancelled else { throw CancellationError() }
            guard gate.isCurrent(stamp), credential == token,
                  expectedDiscoveryScope == nil || expectedDiscoveryScope == clubDiscoveryScope else { throw CancellationError() }
            expireIfMatching(error:error,stamp:stamp,credential:credential)
            throw error
        }
    }
    func merchantAccess() async throws -> MerchantAccess {
        merchantClubAccessRevision &+= 1
        merchantAccessRecord=nil
        let localityScope = clubDiscoveryScope
        let access=try await readMerchant(expectedDiscoveryScope: localityScope) { try await $0.access(token:$1) }
        guard clubDiscoveryScope == localityScope else { throw CancellationError() }
        merchantAccessRecord=(gate.currentStamp,access)
        merchantClubAccessRevision &+= 1
        return access
    }
    func merchantDashboard(access:MerchantAccess) async throws -> MerchantDashboard { try await readMerchant(access:access) { try await $0.dashboard(access:access,token:$1) } }
    func merchantTodo(access:MerchantAccess) async throws -> MerchantTodo { try await readMerchant(access:access) { try await $0.todo(access:access,token:$1) } }
    func merchantEvents(access:MerchantAccess) async throws -> [MerchantEvent] { try await readMerchant(access:access) { try await $0.events(access:access,token:$1) } }
    func merchantOrders(access:MerchantAccess,filter:MerchantOrderFilter) async throws -> [MerchantOrder] { try await readMerchant(access:access) { try await $0.orders(access:access,filter:filter,token:$1) } }
    func merchantProjects(access:MerchantAccess) async throws -> MerchantProjectPage { try await readMerchant(access:access) { try await $0.projects(access:access,token:$1) } }
    func merchantUpcomingRuns(access:MerchantAccess) async throws -> [MerchantUpcomingRun] {
        try await readMerchant(access:access) { try await $0.upcomingRuns(access:access, token:$1) }
    }
}

extension AppSession: ClubReading {
    var isClubConfigured: Bool { clubReader.isClubConfigured }
    var clubIdentity: ClubReadIdentity { clubReader.clubIdentity }
    var clubDiscoveryScope: ClubDiscoveryScope {
        let merchantID = merchantAccessRecord.flatMap { $0.stamp == gate.currentStamp ? $0.access.merchantID : nil }
        return .init(identity: clubIdentity, role: account?.effectiveRole,
                     viewerRevision: compositionViewerRevision, merchantID: merchantID,
                     merchantRevision: merchantClubAccessRevision)
    }
    func clubMerchantLocality() async throws -> MerchantClubLocality {
        let captured = clubDiscoveryScope, credential = token
        guard captured.isMerchantViewer, let credential else { throw APIError.unauthorized }
        guard let merchantOnboardingService else { throw APIError.notConfigured }
        try Task.checkCancellation()
        do {
            let result = try await merchantOnboardingService.clubLocality(token: credential)
            guard !Task.isCancelled, clubDiscoveryScope == captured, token == credential else { throw CancellationError() }
            guard captured.merchantID == nil || captured.merchantID == result.merchantID else { throw MerchantReadError.accessDenied }
            return result
        } catch {
            guard !Task.isCancelled, clubDiscoveryScope == captured, token == credential else { throw CancellationError() }
            // Locality is optional presentation. In particular a superseded request's 401
            // must not expire a live session; the per-view generation accepts only its own result.
            throw error
        }
    }
    func clubHome() async throws -> ClubHome { try await clubReader.clubHome() }
    func clubOwned() async throws -> [ClubRecord] { try await clubReader.clubOwned() }
    func clubDirectory(name:String?) async throws -> [ClubRecord] { try await clubReader.clubDirectory(name:name) }
    func clubDetail(id:Int) async throws -> ClubRecord { try await clubReader.clubDetail(id:id) }
    func clubMembers(id:Int) async throws -> ClubMemberDirectory { try await clubReader.clubMembers(id:id) }
}
