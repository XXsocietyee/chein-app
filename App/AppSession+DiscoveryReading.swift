import Foundation

/// Merchant and club catalog reads, plus play-continuation persistence.
// Views never own credentials; every completion is bound to the captured session.
extension AppSession: MerchantReading {
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

extension AppSession {
    var currentHomeContinuationOwnerScope: HomeContinuationOwnerScope? {
        guard isSignedIn, let account else { return nil }
        return HomeContinuationOwnerScope(
            accountID: account.id,
            sessionRevision: sessionRevision,
            journeyScope: playerJourneyReader.scope
        )
    }

    func noteAccountPersistence(_ next: Account?) {
        let nextID = (next?.id).flatMap { $0 > 0 ? $0 : nil }
        let transition = AccountPersistenceTransition.classify(
            rememberedAccountID: rememberedPersistenceAccountID, nextAccountID: nextID)
        if let nextID { rememberedPersistenceAccountID = nextID }
        guard let transition, let namespace = storageScope?.service else { return }
        _ = AccountScopedPersistence.apply(transition, namespace: namespace, defaults: sessionDefaults)
    }

    static func playContinuationDefaultsKeys(
        namespace: String,
        accountID: Int,
        role: String
    ) -> (scopesKey: String, titlesKey: String)? {
        guard !namespace.isEmpty, accountID > 0,
              let parsedRole = PlayRecoveryAccountRole(rawValue: role),
              let keys = AccountScopedPersistence.legacyKeys(namespace: namespace, accountID: accountID, role: parsedRole.rawValue) else { return nil }
        return (keys.scopes, keys.titles)
    }

    private func playContinuationDefaultsKeys() -> (scopesKey: String, titlesKey: String)? {
        guard let storageScope, let account else { return nil }
        return Self.playContinuationDefaultsKeys(
            namespace: storageScope.service,
            accountID: account.id,
            role: account.effectiveRole
        )
    }

    private static func encodeContinuationScopeToken(_ scope: PlaySessionScope) -> String {
        switch scope {
        case .activity(let id): return "activity:\(id)"
        case .topic(let id): return "topic:\(id)"
        }
    }

    static func decodeContinuationScopeToken(_ token: String) -> PlaySessionScope? {
        let parts = token.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let id = Int(parts[1]), id > 0 else { return nil }
        switch parts[0] {
        case "activity": return .activity(id)
        case "topic": return .topic(id)
        default: return nil
        }
    }

    func matchesContinuationSession(_ expected: PlayExperienceSession, viewerRevision: UInt64) -> Bool {
        guard !authenticatedSessionIsCommitting,
              isSignedIn,
              let currentStorage = storageScope,
              let currentAccount = account,
              let currentToken = token,
              currentStorage.service == expected.namespace,
              currentAccount.id == expected.accountID,
              gate.currentStamp == expected.epoch,
              currentToken == expected.token,
              currentAccount.effectiveRole == expected.role,
              compositionViewerRevision == viewerRevision else {
            return false
        }
        return true
    }

    func persistPlayContinuationScope(
        _ scope: PlaySessionScope,
        title: String? = nil,
        expectedSession: PlayExperienceSession,
        expectedViewerRevision: UInt64
    ) {
        guard scope.isValid,
              matchesContinuationSession(expectedSession, viewerRevision: expectedViewerRevision),
              let keys = Self.playContinuationDefaultsKeys(
                  namespace: expectedSession.namespace,
                  accountID: expectedSession.accountID,
                  role: expectedSession.role
              ) else { return }
        let token = Self.encodeContinuationScopeToken(scope)
        var existing = sessionDefaults.stringArray(forKey: keys.scopesKey) ?? []
        if !existing.contains(token) {
            existing.append(token)
            sessionDefaults.set(existing, forKey: keys.scopesKey)
        }
        if let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            var titles = (sessionDefaults.dictionary(forKey: keys.titlesKey) as? [String: String]) ?? [:]
            titles[token] = trimmed
            sessionDefaults.set(titles, forKey: keys.titlesKey)
        }
        _ = AccountScopedPersistence.recordContinuation(
            namespace: expectedSession.namespace, accountID: expectedSession.accountID,
            role: expectedSession.role, defaults: sessionDefaults)
    }

    func registerPlayContinuationScope(_ scope: PlaySessionScope, title: String? = nil) {
        guard !authenticatedSessionIsCommitting,
              let storageScope,
              let account,
              let token,
              let role = PlayRecoveryAccountRole(rawValue: account.effectiveRole),
              let playSession = try? PlayExperienceSession(
                  accountID: account.id,
                  epoch: gate.currentStamp,
                  namespace: storageScope.service,
                  token: token,
                  role: role.rawValue
              ) else { return }
        persistPlayContinuationScope(
            scope,
            title: title,
            expectedSession: playSession,
            expectedViewerRevision: compositionViewerRevision
        )
    }
}
