import SwiftUI

/// Concrete observer so the POI card redraws when the place read or the review write changes.
struct RoamPlaceExtrasLive: View {
    @Bindable var binding: RoamPlaceExtrasProduction

    var body: some View {
        if let extras = binding.extras {
            RoamPlaceExtrasSection(extras: extras, onPublish: { binding.publishReview(stars: $0, text: $1) }, onRetryReviews: { binding.load() })
        }
    }
}

/// Official place facts and reviews for one roam POI card.
/// City-node reads go through the existing search-map and roam readers (`api/city/nodes/{id}`).
/// Merchant facts go through `RoamReading.roamMerchantDetail` (`api/merchant/public-detail`).
/// Reviews list through `RoamPlaceCommentClient`. Publish sends `PlayerContentMPContract.commentAdd` (owner type 4).
/// The local attempt still keeps one request id; that id is not a field on the mini-program add body.
/// No payment, quote, or price is sent. `routeMarkedLive` stays false on the comment client.
@MainActor @Observable final class RoamPlaceExtrasProduction: RoamPlaceExtrasBinding {
    let poiID: Int
    private let session: AppSession
    private(set) var extras: RoamPlaceExtras?
    private var attempt = RoamPlaceReviewAttempt.idle
    private var loadGeneration = 0
    private var writeGeneration = 0
    private var locallyReviewed = false

    init(poiID: Int, session: AppSession) {
        self.poiID = poiID
        self.session = session
        if let accountID = session.account?.id {
            attempt = RoamPlaceReviewLockStore.read(accountID: accountID, poiID: poiID)
        }
    }

    func load() {
        loadGeneration += 1
        let generation = loadGeneration
        let write = writeGeneration
        Task { await performLoad(generation: generation, write: write) }
    }

    func publishReview(stars: Int, text: String) {
        guard var current = extras, !current.reviewBusy else { return }
        let (next, decision) = attempt.begin(stars: stars, text: text, makeRequestID: { UUID().uuidString })
        attempt = next
        persistAttempt()
        guard case .send(let requestID, let sentStars, let sentText) = decision else {
            if attempt.locked {
                current.reviewError = copy("评价结果未确认，请用同一条评价再试。", "This review was not confirmed. Send the same review again.")
                extras = current
            }
            return
        }
        current.reviewBusy = true
        current.reviewError = nil
        extras = current
        writeGeneration += 1
        let write = writeGeneration
        Task { await performPublish(requestID: requestID, stars: sentStars, text: sentText, write: write) }
    }

    private func performLoad(generation: Int, write: Int) async {
        guard let credential = liveCredential() else {
            apply(node: nil, map: nil, merchant: nil, reviews: nil, generation: generation, write: write)
            return
        }
        let node: RoamNodeDetail?
        let map: SearchMapCityNode?
        do { node = try await session.roamReader.roamNodeDetail(id: poiID) }
        catch {
            node = nil
            noteUnauthorized(error, credential: credential)
        }
        guard still(credential), generation == loadGeneration, write == writeGeneration else { return }
        do { map = try await session.searchMapReader.cityNode(id: poiID) }
        catch {
            map = nil
            noteUnauthorized(error, credential: credential)
        }
        guard still(credential), generation == loadGeneration, write == writeGeneration else { return }
        let merchantID = (node?.merchantId ?? map?.merchantID).flatMap { $0 > 0 ? $0 : nil }
        var merchant: RoamMerchantDetail?
        if let merchantID {
            do { merchant = try await session.roamReader.roamMerchantDetail(id: merchantID) }
            catch {
                merchant = nil
                noteUnauthorized(error, credential: credential)
            }
        }
        guard still(credential), generation == loadGeneration, write == writeGeneration else { return }
        let reviews = await comments(credential)
        guard still(credential), generation == loadGeneration, write == writeGeneration else { return }
        apply(node: node, map: map, merchant: merchant, reviews: reviews, generation: generation, write: write)
    }

    private func performPublish(requestID: String, stars: Int, text: String, write: Int) async {
        guard let credential = liveCredential(), let configuration = session.regionalConfiguration?.apiConfiguration,
              session.regionalConfiguration?.showsRoute("/" + RoamPlaceCommentClient.addPath) == true else {
            finishPublish(.notSent, message: nil, write: write)
            return
        }
        let outcome = await publishComment(configuration: configuration, stars: stars, text: text, requestID: requestID, token: credential.token)
        if case .unknown = outcome {
            attempt = attempt.resolve(.unknown)
            RoamPlaceReviewLockStore.write(accountID: credential.accountID, poiID: poiID, attempt)
        }
        if case .unauthorized = outcome {
            attempt = attempt.resolve(.unknown)
            RoamPlaceReviewLockStore.write(accountID: credential.accountID, poiID: poiID, attempt)
            session.expireIfMatching(error: APIError.unauthorized, stamp: credential.stamp, credential: credential.token)
        }
        guard still(credential), write == writeGeneration else { return }
        switch outcome {
        case .published:
            locallyReviewed = true
            finishPublish(.published, message: nil, write: write)
            load()
        case .rejected(let message):
            finishPublish(.rejected, message: message, write: write)
        case .notSent:
            finishPublish(.notSent, message: nil, write: write)
        case .unknown, .unauthorized:
            finishPublish(.unknown, message: nil, write: write)
        }
    }

    /// Mini-program `api/comment/add`. The local request id stays on the attempt and is not put on this body.
    private func publishComment(configuration: APIConfiguration, stars: Int, text: String, requestID: String, token: String) async -> RoamPlaceCommentClient.PublishOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard poiID > 0, (1...5).contains(stars), !trimmed.isEmpty, trimmed.utf16.count <= 200,
              RoamPlaceCommentClient.acceptableRequestID(requestID), AuthRequestBuilder.isValidToken(token) else { return .notSent }
        let drafted: URLRequest
        do {
            drafted = try PlayerContentMPContract.commentAdd(
                baseURL: configuration.baseURL, ownerType: RoamPlaceCommentClient.ownerType, ownerID: poiID,
                rating: stars, contents: trimmed, replyID: 0, images: "")
        } catch { return .notSent }
        let request: URLRequest
        do { request = try PlayerContentMPAppWire.rehome(drafted, onto: configuration.baseURL, token: token, stripContentType: false) }
        catch { return .notSent }
        let data: Data
        let status: Int
        do { (data, status) = try await session.runtimeHTTPTransport.send(request) }
        catch { return .unknown }
        if status == 401 { return .unauthorized }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = Self.commentCode(root["code"]) else { return .unknown }
        if code == 401 { return .unauthorized }
        if code == 200 { return .published }
        let message = (root["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .rejected(message?.isEmpty == false ? message : nil)
    }

    private static func commentCode(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private func finishPublish(_ outcome: RoamPlaceReviewAttempt.Outcome, message: String?, write: Int) {
        guard write == writeGeneration, var current = extras else { return }
        attempt = attempt.resolve(outcome)
        persistAttempt()
        current.reviewBusy = false
        current.reviewed = current.reviewed || locallyReviewed
        switch outcome {
        case .published:
            current.reviewError = nil
            current.reviewed = true
        case .rejected:
            current.reviewError = message ?? copy("评价未提交，请重试。", "The review was not published. Try again.")
        case .notSent:
            current.reviewError = copy("评价没有发出。", "The review was not sent.")
        case .unknown:
            current.reviewError = copy("评价结果未确认，请用同一条评价再试。", "This review was not confirmed. Send the same review again.")
        }
        extras = current
    }

    private struct Credential: Equatable {
        let accountID: Int
        let stamp: UInt64
        let token: String
    }

    private func liveCredential() -> Credential? {
        guard let accountID = session.account?.id, accountID > 0,
              let token = session.token, !token.isEmpty else { return nil }
        return Credential(accountID: accountID, stamp: session.sessionRevision, token: token)
    }

    private func still(_ credential: Credential) -> Bool {
        session.account?.id == credential.accountID && session.sessionRevision == credential.stamp && session.token == credential.token
    }

    private func comments(_ credential: Credential) async -> RoamPlaceCommentClient.ListOutcome {
        guard let configuration = session.regionalConfiguration?.apiConfiguration,
              session.regionalConfiguration?.showsRoute("/" + RoamPlaceCommentClient.listPath) == true else { return .unavailable }
        let client = RoamPlaceCommentClient(configuration: configuration, transport: session.runtimeHTTPTransport)
        let outcome = await client.list(poiID: poiID, token: credential.token)
        if case .unauthorized = outcome {
            session.expireIfMatching(error: APIError.unauthorized, stamp: credential.stamp, credential: credential.token)
        }
        return outcome
    }

    private func noteUnauthorized(_ error: Error, credential: Credential) {
        guard still(credential), error as? APIError == .unauthorized else { return }
        session.expireIfMatching(error: error, stamp: credential.stamp, credential: credential.token)
    }

    private func apply(node: RoamNodeDetail?, map: SearchMapCityNode?, merchant: RoamMerchantDetail?, reviews: RoamPlaceCommentClient.ListOutcome?, generation: Int, write: Int) {
        guard generation == loadGeneration, write == writeGeneration else { return }
        let accountID = session.account?.id
        let rows: [RoamPlaceCommentClient.Row]
        let loaded: Bool
        switch reviews {
        case .loaded(let value): rows = value; loaded = true
        default: rows = []; loaded = false
        }
        if loaded, let accountID, rows.contains(where: { $0.memberID == accountID }) {
            locallyReviewed = true
            if attempt.locked {
                attempt = .idle
                persistAttempt()
            }
        }
        let title = nonempty(node?.templateTitle) ?? nonempty(map?.templateTitle)
        var steps: [String] = []
        if node?.validationMethod == 3 || map?.validationMethod == 3 {
            steps.append(copy("观察答题", "Answer from what you see"))
        }
        let game: RoamPlaceGame? = (node != nil || title != nil || !steps.isEmpty)
            ? RoamPlaceGame(title: title, detail: nil, steps: steps, completed: node?.completed == true)
            : nil
        var rowsOut: [RoamPlaceInfoRow] = []
        if let tags = nonempty(node?.tags) ?? nonempty(map?.tags) {
            rowsOut.append(RoamPlaceInfoRow(key: copy("类型", "Type"), value: tags))
        }
        if let address = nonempty(node?.merchantAddress) ?? nonempty(merchant?.merchant.address) {
            rowsOut.append(RoamPlaceInfoRow(key: copy("地址", "Address"), value: address))
        }
        if let hours = nonempty(merchant?.merchant.businessTime) {
            rowsOut.append(RoamPlaceInfoRow(key: copy("营业时间", "Hours"), value: hours))
        }
        if let status = merchant?.merchant.businessStatus {
            let value: String
            switch status {
            case 1: value = copy("营业中", "Open")
            case 0: value = copy("已打烊", "Closed")
            default: value = RoamFinishAddress.unknown
            }
            rowsOut.append(RoamPlaceInfoRow(key: copy("营业状态", "Status"), value: value))
        }
        let categories = merchant?.merchant.categories.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
        if !categories.isEmpty {
            rowsOut.append(RoamPlaceInfoRow(key: copy("品类", "Categories"), value: categories.joined(separator: " · ")))
        }
        let reviewRows = rows.map {
            RoamPlaceReview(id: $0.id, name: $0.name, timeText: $0.timeText, stars: $0.stars, text: $0.text)
        }
        var next = RoamPlaceExtras(
            placeName: nonempty(node?.name) ?? nonempty(map?.name) ?? RoamFinishAddress.unknown,
            game: game,
            infoRows: rowsOut,
            quotes: RoamPlaceSources.quotes(node?.quotesJSON), // ROAM-r11-8

            reviews: reviewRows,
            reviewsLoaded: loaded,
            reviewed: locallyReviewed || (accountID != nil && rows.contains { $0.memberID == accountID }),
            photoCredit: RoamPlaceSources.credit(node?.photoCreditRaw)
        )
        next.sources = RoamCityGuideCatalog.sourcesFor(tags: node?.tags)
        next.reviewsFailed = reviews == .unavailable
        if attempt.locked {
            next.reviewError = copy("评价结果未确认，请用同一条评价再试。", "This review was not confirmed. Send the same review again.")
        }
        extras = next
    }

    private func persistAttempt() {
        guard let accountID = session.account?.id else { return }
        RoamPlaceReviewLockStore.write(accountID: accountID, poiID: poiID, attempt)
    }

    private func copy(_ zh: String, _ en: String) -> String {
        AppLanguage.interfaceIsChinese(.autoupdatingCurrent) ? zh : en
    }

    private func nonempty(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}
