import SwiftUI

// Fills `mpParity.videoBounty` on the existing `MPParityBindings` (`App/MPParityKit.swift`).
// Accrual amounts are display text. This file does not send payout, withdraw, redeem, or wallet calls.

extension MPParityBindings {
    /// Author video bounty. The closure keeps one model for the session, so an unconfirmed write keeps its request id.
    @MainActor func fillingVideoBounty(session: AppSession) -> MPParityBindings {
        var copy = self
        copy.videoBounty = { [weak session] in VideoBountySessionHold.model(session: session) }
        return copy
    }
}

@MainActor private enum VideoBountySessionHold {
    private static var models: [ObjectIdentifier: VideoBountySessionModel] = [:]

    static func model(session: AppSession?) -> VideoBountySessionModel {
        models = models.filter { $0.value.session != nil }
        guard let session else { return VideoBountySessionModel(session: nil) }
        let key = ObjectIdentifier(session)
        if let existing = models[key], existing.session != nil { return existing }
        let created = VideoBountySessionModel(session: session)
        models[key] = created
        return created
    }
}

@MainActor @Observable final class VideoBountySessionModel: VideoBountyBinding {
    private(set) var state = VideoBountyState()
    /// Server campaign list only. Empty stays empty. The ops-link key is never inserted here.
    private(set) var campaigns: MPLoad<[VideoBountyCampaign]> = .loading

    fileprivate weak var session: AppSession?
    private let store: JourneyMemoryRequestStore
    private var appealIDs: [String] = []
    private var cancelIDs: [String] = []
    private var generation = 0

    init(session: AppSession?, store: JourneyMemoryRequestStore = JourneyMemoryRequestStore()) {
        self.session = session
        self.store = store
    }

    func load() {
        generation += 1
        let generation = generation
        state.signedOut = false
        state.submissions = .loading
        state.accruals = .loading
        campaigns = .loading
        Task { await reload(generation) }
    }

    func submit(campaignKey: String, topicID: String, platform: VideoBountyPlatform?, sourceURL: String, originGroupKey: String) {
        guard !state.submitting else { return }
        let locked = store.read(VideoBountyRequestKey.submit) != nil
        if !locked {
            if platform == nil {
                state.fieldError = (field: .platform, text: VideoBountyCopy.platform)
                return
            }
            if sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.fieldError = (field: .sourceURL, text: VideoBountyCopy.url)
                return
            }
        }
        state.fieldError = nil
        state.submitError = nil
        state.submitting = true
        let platformRaw = platform?.rawValue ?? ""
        Task {
            defer { state.submitting = false }
            guard let source = source(), let token = token() else {
                state.submitError = VideoBountyCopy.pendingSubmit
                return
            }
            do {
                let envelope = try await source.submit(campaignKey: campaignKey, topicID: topicID, platform: platformRaw,
                                                       sourceURL: sourceURL, originGroupKey: originGroupKey, token: token)
                note(envelope, pending: VideoBountyCopy.pendingSubmit)
                if envelope.ok {
                    state.submitRevision += 1
                    load()
                }
            } catch VideoBountyRefusal.invalidRequest {
                state.submitError = VideoBountyCopy.incomplete
            } catch {
                state.submitError = VideoBountyCopy.pendingSubmit
            }
        }
    }

    func appeal(submissionID: String, note: String) {
        guard !state.submitting else { return }
        state.submitting = true
        if !appealIDs.contains(submissionID) { appealIDs.append(submissionID) }
        Task {
            defer { state.submitting = false }
            guard let source = source(), let token = token() else {
                state.submitError = VideoBountyCopy.pending
                return
            }
            do {
                let envelope = try await source.appeal(submissionID: submissionID, note: note, token: token)
                if envelope.confirmed { appealIDs.removeAll { $0 == submissionID } }
                self.note(envelope, pending: VideoBountyCopy.pending)
                if envelope.ok { load() }
            } catch VideoBountyRefusal.invalidRequest {
                if store.read(VideoBountyRequestKey.appeal(submissionID)) == nil {
                    appealIDs.removeAll { $0 == submissionID }
                }
                state.submitError = VideoBountyCopy.incomplete
            } catch {
                state.submitError = VideoBountyCopy.pending
            }
        }
    }

    func cancel(submissionID: String) {
        guard !state.submitting else { return }
        state.submitting = true
        if !cancelIDs.contains(submissionID) { cancelIDs.append(submissionID) }
        Task {
            defer { state.submitting = false }
            guard let source = source(), let token = token() else {
                state.submitError = VideoBountyCopy.pending
                return
            }
            do {
                let envelope = try await source.cancel(submissionID: submissionID, token: token)
                if envelope.confirmed { cancelIDs.removeAll { $0 == submissionID } }
                note(envelope, pending: VideoBountyCopy.pending)
                if envelope.ok { load() }
            } catch VideoBountyRefusal.invalidRequest {
                if store.read(VideoBountyRequestKey.cancel(submissionID)) == nil {
                    cancelIDs.removeAll { $0 == submissionID }
                }
                state.submitError = VideoBountyCopy.incomplete
            } catch {
                state.submitError = VideoBountyCopy.pending
            }
        }
    }

    private func reload(_ generation: Int) async {
        guard let source = source(), let token = token() else {
            guard generation == self.generation else { return }
            state.signedOut = source() != nil   // PC-D-7-1: configured but no token → sign-in gate
            state.submissions = .failed(nil)
            state.accruals = .failed(nil)
            campaigns = .failed(nil)
            return
        }
        async let submissionEnvelope = source.submissions(token: token)
        async let accrualEnvelope = source.accruals(token: token)
        async let campaignEnvelope = source.campaigns(token: token)
        let submissions = try? await submissionEnvelope
        let accruals = try? await accrualEnvelope
        let campaignList = try? await campaignEnvelope
        guard generation == self.generation else { return }
        state.submissions = Self.submissions(submissions)
        state.accruals = Self.accruals(accruals)
        campaigns = Self.campaigns(campaignList)
        await settleLocked(source: source, token: token, generation: generation)
    }

    /// Re-post each saved request id. A confirmed success refreshes the lists. It does not mint a new id.
    private func settleLocked(source: VideoBountySource, token: String, generation: Int) async {
        var refresh = false
        if store.read(VideoBountyRequestKey.submit) != nil {
            if await reread({ try await source.rereadSubmit(token: token) }, pending: VideoBountyCopy.pendingSubmit) { refresh = true }
        }
        var finished: [String] = []
        for id in appealIDs where store.read(VideoBountyRequestKey.appeal(id)) != nil {
            if await reread({ try await source.rereadAppeal(submissionID: id, token: token) }, pending: VideoBountyCopy.pending) {
                refresh = true
            }
            if store.read(VideoBountyRequestKey.appeal(id)) == nil { finished.append(id) }
        }
        for id in cancelIDs where store.read(VideoBountyRequestKey.cancel(id)) != nil {
            if await reread({ try await source.rereadCancel(submissionID: id, token: token) }, pending: VideoBountyCopy.pending) {
                refresh = true
            }
            if store.read(VideoBountyRequestKey.cancel(id)) == nil { finished.append(id) }
        }
        appealIDs.removeAll { finished.contains($0) }
        cancelIDs.removeAll { finished.contains($0) }
        guard refresh, generation == self.generation else { return }
        async let submissionEnvelope = source.submissions(token: token)
        async let accrualEnvelope = source.accruals(token: token)
        async let campaignEnvelope = source.campaigns(token: token)
        let submissions = try? await submissionEnvelope
        let accruals = try? await accrualEnvelope
        let campaignList = try? await campaignEnvelope
        guard generation == self.generation else { return }
        state.submissions = Self.submissions(submissions)
        state.accruals = Self.accruals(accruals)
        campaigns = Self.campaigns(campaignList)
    }

    private func reread(_ call: () async throws -> VideoBountyEnvelope, pending: String) async -> Bool {
        do {
            let envelope = try await call()
            note(envelope, pending: pending)
            return envelope.ok
        } catch {
            state.submitError = pending
            return false
        }
    }

    private func note(_ envelope: VideoBountyEnvelope, pending: String) {
        if !envelope.confirmed {
            state.submitError = pending
            return
        }
        guard envelope.ok else {
            state.submitError = VideoBountyCopy.reason(code: envelope.reasonCode, message: envelope.message)
            return
        }
        state.submitError = nil
    }

    private func source() -> VideoBountySource? {
        guard let session, let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return VideoBountySource(configuration: configuration, transport: session.composition.makeTransport(), store: store)
    }

    private func token() -> String? {
        guard let token = session?.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return token
    }

    private static func submissions(_ envelope: VideoBountyEnvelope?) -> MPLoad<[VideoBountySubmissionRow]> {
        guard let envelope, envelope.ok, let facts = VideoBountySource.submissions(in: envelope) else { return .failed(nil) }
        return .ready(facts.map(row))
    }

    private static func accruals(_ envelope: VideoBountyEnvelope?) -> MPLoad<[VideoBountyAccrualRow]> {
        guard let envelope, envelope.ok, let facts = VideoBountySource.accruals(in: envelope) else { return .failed(nil) }
        return .ready(facts.map { VideoBountyAccrualRow(id: $0.id, amountText: $0.amountText, views: $0.views, groupViews: $0.groupViews) })
    }

    private static func campaigns(_ envelope: VideoBountyEnvelope?) -> MPLoad<[VideoBountyCampaign]> {
        guard let envelope, envelope.ok, let rows = VideoBountySource.campaigns(in: envelope) else { return .failed(nil) }
        return .ready(rows)
    }

    private static func row(_ fact: VideoBountySubmissionFact) -> VideoBountySubmissionRow {
        VideoBountySubmissionRow(id: fact.id, platform: fact.platform.flatMap(VideoBountyPlatform.init(rawValue:)),
                                 sourceURL: fact.sourceURL, status: VideoBountyStatus(rawValue: fact.statusLabel) ?? .unknown,
                                 reviewNote: fact.reviewNote, windowEndText: fact.windowEndText,
                                 canAppeal: fact.canAppeal, canCancel: fact.canCancel)
    }
}

enum VideoBountyCopy {
    private static var locale: Locale { .current }
    static var platform: String { appLocalized("mp.vb.form.platform", locale: locale) }
    static var url: String { appLocalized("mp.vb.form.urlMissing", locale: locale) }
    static var pendingSubmit: String { appLocalized("mp.vb.reason.pendingSubmit", locale: locale) }
    static var pending: String { appLocalized("mp.vb.reason.pending", locale: locale) }
    static var incomplete: String { appLocalized("mp.vb.reason.incomplete", locale: locale) }

    static func reason(code: String?, message: String?) -> String {
        switch code {
        case "VIDEO_ALREADY_SUBMITTED": return appLocalized("mp.vb.reason.alreadySubmitted", locale: locale)
        case "PLATFORM_MISMATCH": return appLocalized("mp.vb.reason.platformMismatch", locale: locale)
        case "LINK_PLATFORM_UNSUPPORTED": return appLocalized("mp.vb.reason.platformUnsupported", locale: locale)
        case "LINK_VIDEO_ID_MISSING": return appLocalized("mp.vb.reason.videoIdMissing", locale: locale)
        case "LINK_SCHEME_NOT_ALLOWED", "LINK_USERINFO_NOT_ALLOWED": return appLocalized("mp.vb.reason.httpsOnly", locale: locale)
        case "TOPIC_NOT_FOUND": return appLocalized("mp.vb.reason.topicMissing", locale: locale)
        case "CAMPAIGN_NOT_ACTIVE": return appLocalized("mp.vb.reason.campaignClosed", locale: locale)
        case "CANCEL_NOT_ALLOWED": return appLocalized("mp.vb.reason.cancelDenied", locale: locale)
        default:
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return message }
            return incomplete
        }
    }
}
