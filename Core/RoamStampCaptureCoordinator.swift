import Foundation

/// Exact uploaded picture, reviewed caption and idempotency key are immutable create inputs.
/// Secure storage is required, scoped by namespace/deployment/account (not transient login epoch).
/// No card, credential, raw photo or location is persisted here.
public struct RoamStampPending: Codable, Equatable {
    public let pictureURL: URL
    public let caption: String
    public let idempotencyKey: String
    public init(pictureURL: URL, caption: String = "", idempotencyKey: String) throws {
        guard pictureURL.scheme == "https", pictureURL.host != nil, pictureURL.user == nil, pictureURL.password == nil,
              pictureURL.fragment == nil, !pictureURL.path.isEmpty, pictureURL.path != "/",
              RoamExperienceMath.validCaption(caption),
              (1...128).contains(idempotencyKey.utf8.count),
              idempotencyKey.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw RetainedImageFailure.invalid }
        self.pictureURL = pictureURL; self.caption = caption; self.idempotencyKey = idempotencyKey
    }
    private enum CodingKeys: String, CodingKey { case pictureURL, caption, idempotencyKey }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // v1 records made before caption authoring used an empty create caption. Only an
        // absent key migrates; explicit null, wrong types and overlong text fail closed.
        let caption = values.contains(.caption) ? try values.decode(String.self, forKey: .caption) : ""
        try self.init(pictureURL: values.decode(URL.self, forKey: .pictureURL), caption: caption,
                      idempotencyKey: values.decode(String.self, forKey: .idempotencyKey))
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.pictureURL == rhs.pictureURL && lhs.idempotencyKey == rhs.idempotencyKey &&
            lhs.caption.utf8.elementsEqual(rhs.caption.utf8)
    }
}
@MainActor public protocol RoamStampPendingStorage {
    func load(scope: RetainedImageScope) throws -> RoamStampPending?
    func save(_ pending: RoamStampPending, scope: RetainedImageScope) throws
    func clear(_ pending: RoamStampPending, scope: RetainedImageScope) throws
}
@MainActor public struct StoredRoamStampPending: RoamStampPendingStorage {
    private let read: (String) throws -> Data?
    private let write: (Data, String) throws -> Void
    public init(read: @escaping (String) throws -> Data?, write: @escaping (Data, String) throws -> Void) { self.read = read; self.write = write }
    private func key(_ scope: RetainedImageScope) throws -> String {
        guard scope.destination == .stamp, let namespace = scope.namespace, !namespace.isEmpty else { throw RetainedImageFailure.invalid }
        return "stamp-create.v1." + Data([namespace, scope.realm, String(scope.accountID)].map { "\($0.utf8.count):\($0)" }.joined().utf8).base64EncodedString()
    }
    public func load(scope: RetainedImageScope) throws -> RoamStampPending? {
        guard let data = try read(key(scope)), data != Data("null".utf8) else { return nil }
        guard data.count <= 16384, let record = try? JSONDecoder().decode(RoamStampPending.self, from: data) else { throw ImageUploadJournalFailure.corrupt }
        return try RoamStampPending(pictureURL: record.pictureURL, caption: record.caption, idempotencyKey: record.idempotencyKey)
    }
    public func save(_ pending: RoamStampPending, scope: RetainedImageScope) throws {
        if let existing = try load(scope: scope), existing != pending { throw ImageUploadJournalFailure.locked }
        let data = try JSONEncoder().encode(pending), name = try key(scope)
        try write(data, name); guard try read(name) == data else { throw ImageUploadJournalFailure.unavailable }
    }
    public func clear(_ pending: RoamStampPending, scope: RetainedImageScope) throws {
        guard try load(scope: scope) == pending else { throw ImageUploadJournalFailure.locked }
        let name = try key(scope), data = Data("null".utf8)
        try write(data, name); guard try read(name) == data else { throw ImageUploadJournalFailure.unavailable }
    }
}
@MainActor public final class RoamStampCaptureCoordinator {
    public enum Phase: Equatable { case ready, review, uploading, awaitingCreate, creating, unknown, created(Int), unavailable, failed }
    public private(set) var phase: Phase = .ready
    public private(set) var selection: RetainedSelectedImage?
    public private(set) var pending: RoamStampPending?
    public private(set) var caption = ""
    public let scope: RetainedImageScope
    public let uploads: RetainedImageUploadCoordinator
    private let executor: any RoamMediaMutationExecuting
    private let storage: any RoamStampPendingStorage
    private var generation = 0
    public var changed: (() -> Void)?
    public init(scope: RetainedImageScope, uploads: RetainedImageUploadCoordinator,
                executor: any RoamMediaMutationExecuting, storage: any RoamStampPendingStorage) {
        self.scope = scope; self.uploads = uploads; self.executor = executor; self.storage = storage
        do { pending = try storage.load(scope: scope); if let pending { caption = pending.caption; phase = .unknown } }
        catch { phase = .unavailable }
        if uploads.locked && pending == nil { phase = .unknown }
    }
    public var canCapture: Bool { pending == nil && !uploads.locked && [.ready, .review, .failed].contains(phase) }
    public var canEditCaption: Bool { pending == nil && !uploads.locked && [.ready, .review, .failed].contains(phase) }
    public var canUpload: Bool { phase == .review && RoamExperienceMath.validCaption(caption) && uploads.uploader.isConfigured && uploads.uploader.scope == scope }
    public var canCreate: Bool { pending != nil && phase != .creating && executor.enabled && executor.scope == scope }
    /// Local authoring only. Keep over-limit text visible for correction, never truncate it
    /// mid-composition or dispatch an invalid caption. Upload freezes the reviewed value.
    public func updateCaption(_ value: String) {
        guard canEditCaption else { return }; caption = value; changed?()
    }
    public func captured(_ image: RetainedSelectedImage) {
        guard canCapture else { return }; selection = image; phase = .review; changed?()
    }
    public func retake() { guard canCapture else { return }; selection = nil; phase = .ready; changed?() }
    public func upload() async {
        guard canUpload, let selection else { return }
        let reviewedCaption = caption
        uploads.prepare(selection, scope: scope)
        guard case .reviewing(let review) = uploads.state else { phase = .unknown; changed?(); return }
        let ticket = generation; phase = .uploading; changed?()
        await uploads.confirm(review)
        guard ticket == generation, !Task.isCancelled else { return }
        guard case .uploaded(let proof) = uploads.state else { phase = uploads.locked ? .unknown : .failed; changed?(); return }
        do {
            let record = try RoamStampPending(pictureURL: proof.url, caption: reviewedCaption, idempotencyKey: "stamp-" + proof.id.uuidString)
            // Persist the exact create command before allowing a single create dispatch.
            guard uploads.applyLocally(proof, consume: { proof in
                guard proof.scope == self.scope else { return false }
                do { try self.storage.save(record, scope: self.scope); return true } catch { return false }
            }) else { phase = .unknown; changed?(); return }
            pending = record; phase = .awaitingCreate; changed?()
        } catch { phase = .unknown; changed?() }
    }
    /// An explicit retry reuses the original URL/key, never uploads again or changes the key.
    public func create() async {
        guard canCreate, let pending else { return }
        let ticket = generation; phase = .creating; changed?()
        do {
            try storage.save(pending, scope: scope)
            let data = try await executor.execute(.createStamp(pictureURL: pending.pictureURL.absoluteString, caption: pending.caption, idempotencyKey: pending.idempotencyKey))
            guard ticket == generation, executor.scope == scope, !Task.isCancelled else { return }
            let receipt = try RoamMutationReceiptDecoder.value(RoamStampCreatedReceipt.self, from: data)
            try storage.clear(pending, scope: scope)
            self.pending = nil; selection = nil; phase = .created(receipt.id)
        } catch let error as RetainedImageFailure {
            if ticket == generation {
                if case .rejected = error {
                    do { try storage.clear(pending, scope: scope); self.pending = nil; phase = .failed }
                    catch { phase = .unknown }
                } else { phase = .unknown }
            }
        } catch { if ticket == generation { phase = .unknown } }
        changed?()
    }
    public func cancel() {
        generation += 1; uploads.clear(); selection = nil
        caption = pending?.caption ?? ""
        if pending != nil || uploads.locked || phase == .creating { phase = .unknown }
        else if phase != .unavailable { phase = .ready }
        changed?()
    }
}

/// Page projection for the stamp camera. It does not register a route, mark a route live,
/// upload a photo, or create or exchange a stamp. A missing write stays hidden.
/// Unknown text is an em dash (U+2014). A missing number is never shown as 0.
public enum StampCameraCapturePhase: String, Equatable, Sendable {
    case ready, review, uploading, awaitingCreate, creating, unknown, created, unavailable, failed
}

public enum StampCameraPagePhase: String, Equatable, Sendable {
    case loading, empty, error, unknown, ready
}

public struct StampCameraPageValue: Equatable, Sendable {
    public let phase: StampCameraPagePhase
    public let text: String
    public let reason: String
}

public enum StampCameraPageFact: Equatable, Sendable {
    case loading
    case empty
    case error(String)
    case unknown
    /// A present integer, including a measured zero. This is not a numeric string.
    case count(Int)
}

public enum StampCameraPageReady {
    public static let unknownMark = "\u{2014}"
    public static let registersRoute = false
    public static let marksRouteLive = false
    public static let showsMerchantChoice = false
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false

    public static var createPath: String {
        RoamExperienceMutation.createStamp(pictureURL: "", caption: "", idempotencyKey: "").path
    }
    public static var exchangePath: String {
        RoamExperienceMutation.exchangeStamp(givenStampID: 1).path
    }
    public static var listPath: String { RoamAlbumMetadataReadRoute.path }

    public static func project(_ fact: StampCameraPageFact) -> StampCameraPageValue {
        switch fact {
        case .loading:
            return make(.loading, "", "loading")
        case .empty:
            return make(.empty, unknownMark, "empty")
        case .unknown:
            return make(.unknown, unknownMark, "unknown")
        case .error(let token):
            return errorValue(token)
        case .count(let number):
            guard number >= 0 else { return make(.unknown, unknownMark, "unknown") }
            return make(.ready, String(number), "ready.count")
        }
    }

    /// Loading wins over a stale failure. A confirmed empty album stays empty.
    /// A missing total, a negative total, or a zero that is not an empty list stays unknown.
    public static func albumTotal(loading: Bool, failure: String? = nil, confirmedTotal: Int? = nil, listIsEmpty: Bool = false) -> StampCameraPageValue {
        if loading { return project(.loading) }
        if let failure { return project(.error(failure)) }
        guard let confirmedTotal, confirmedTotal >= 0 else { return project(.unknown) }
        if confirmedTotal == 0 { return listIsEmpty ? project(.empty) : project(.unknown) }
        return project(.count(confirmedTotal))
    }

    /// A missing, zero, or negative created id is unknown. The receipt contract already rejects non-positive ids.
    public static func createdIdentifier(loading: Bool, failure: String? = nil, id: Int? = nil) -> StampCameraPageValue {
        if loading { return project(.loading) }
        if let failure { return project(.error(failure)) }
        guard let id, id > 0 else { return project(.unknown) }
        return project(.count(id))
    }

    /// A missing caption is unknown. A present caption, including an empty one, keeps its measured UTF-16 length.
    public static func captionUnits(_ caption: String?) -> StampCameraPageValue {
        guard let caption else { return project(.unknown) }
        if caption.utf16.count > 30 { return project(.error("limit")) }
        return project(.count(caption.utf16.count))
    }

    public static func screen(phase: StampCameraCapturePhase, hasSelection: Bool) -> StampCameraPageValue {
        switch phase {
        case .uploading, .creating:
            return project(.loading)
        case .failed:
            return project(.error("failed"))
        case .unknown, .unavailable:
            return project(.unknown)
        case .ready:
            return hasSelection ? make(.ready, "", "ready") : project(.empty)
        case .review, .awaitingCreate, .created:
            return make(.ready, "", "ready")
        }
    }

    public static func screen(coordinatorPhase: RoamStampCaptureCoordinator.Phase, hasSelection: Bool) -> StampCameraPageValue {
        let mapped: StampCameraCapturePhase
        switch coordinatorPhase {
        case .ready: mapped = .ready
        case .review: mapped = .review
        case .uploading: mapped = .uploading
        case .awaitingCreate: mapped = .awaitingCreate
        case .creating: mapped = .creating
        case .unknown: mapped = .unknown
        case .created: mapped = .created
        case .unavailable: mapped = .unavailable
        case .failed: mapped = .failed
        }
        return screen(phase: mapped, hasSelection: hasSelection)
    }

    private static func make(_ phase: StampCameraPagePhase, _ text: String, _ reason: String) -> StampCameraPageValue {
        StampCameraPageValue(phase: phase, text: text, reason: reason)
    }

    private static func errorValue(_ token: String) -> StampCameraPageValue {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("UNKNOWN") == .orderedSame
            || trimmed == unknownMark || isNumericToken(trimmed) {
            return make(.unknown, unknownMark, "unknown")
        }
        return make(.error, trimmed, "error")
    }

    private static func isNumericToken(_ text: String) -> Bool {
        text.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil
    }
}

/// Existing create, exchange, and list contracts. A false capability hides its path.
/// This value does not register a route and does not mark a route live.
public struct StampCameraPageContract: Equatable, Sendable {
    public let showsCreate: Bool
    public let showsExchange: Bool
    public let createPath: String?
    public let exchangePath: String?
    public let listPath: String?
    public let registersRoute: Bool
    public let marksRouteLive: Bool

    public init(hasAlbumReader: Bool) {
        showsCreate = RoamExperienceCapabilities.mediaUpload
        showsExchange = RoamExperienceCapabilities.stampExchange
        createPath = showsCreate ? StampCameraPageReady.createPath : nil
        exchangePath = showsExchange ? StampCameraPageReady.exchangePath : nil
        listPath = hasAlbumReader ? StampCameraPageReady.listPath : nil
        registersRoute = false
        marksRouteLive = false
    }
}

#if DEBUG
public enum StampCameraPageFixtureData {
    public static let unknownMark = StampCameraPageReady.unknownMark
    public static let loading = StampCameraPageReady.albumTotal(loading: true, failure: "stale", confirmedTotal: 0, listIsEmpty: true)
    public static let empty = StampCameraPageReady.albumTotal(loading: false, confirmedTotal: 0, listIsEmpty: true)
    public static let unknown = StampCameraPageReady.albumTotal(loading: false, confirmedTotal: nil)
    public static let failed = StampCameraPageReady.albumTotal(loading: false, failure: "unavailable")
    public static let createdUnknown = StampCameraPageReady.createdIdentifier(loading: false, id: 0)
    public static let hiddenContract = StampCameraPageContract(hasAlbumReader: false)
    public static let readContract = StampCameraPageContract(hasAlbumReader: true)
}
#endif
