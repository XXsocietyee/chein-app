import Foundation

// MARK: - Bundle transfer model (IWP-8c; T-15 / EP-BND-24). Wires nothing, gates OFF.
// The backend endpoint does not exist yet, so everything here talks to the injected `BundleTransferServing`
// protocol whose default is `BundleTransferUnavailableClient`. No data is ever invented.
// Rules encoded here:
//  * The one-time code lives in memory only (`BundleTransferOneTimeCode`, redacted in every description,
//    not Codable). It is never persisted, never logged, and is discarded when the sender leaves the screen.
//  * Eligibility, impact text and offered channels come from the server preview. No unit counting here.
//  * Claim failures for wrong / expired / used / mismatched codes collapse into ONE state.
//  * Unknown outcome = read back with the SAME idempotency key; the pending record holds no code and no phone.
//  * Refund quote for the payer is whatever the server answers; this layer never hides or computes it.

public enum BundleTransferChannel: String, Codable, Equatable {
    case inApp = "IN_APP"
    case sms = "SMS"
}

/// Business codes from `bundle-backend-spec.md` B-24.
public enum BundleTransferBusinessCode {
    public static let codeInvalid = "BUNDLE_TRANSFER_CODE_INVALID"
    public static let phoneMismatch = "BUNDLE_TRANSFER_PHONE_MISMATCH"
    public static let selfTransfer = "BUNDLE_TRANSFER_SELF"
    public static let notEligible = "BUNDLE_TRANSFER_NOT_ELIGIBLE"
    public static let duplicatePending = "BUNDLE_TRANSFER_DUPLICATE_PENDING"
    public static let loginRequired = "LOGIN_REQUIRED"
}

/// Plain-text one-time code. Deliberately not Codable / Equatable; every textual rendering is redacted.
public struct BundleTransferOneTimeCode: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let value: String
    public init(_ value: String) throws {
        guard (1...64).contains(value.utf8.count), value.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7f }) else {
            throw FreeExploreLaunchFailure.invalid
        }
        self.value = value
    }
    /// The only way to read the code: for on-screen display or the request body.
    public func reveal() -> String { value }
    public var description: String { "BundleTransferOneTimeCode(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public enum BundleTransferState: Equatable {
    case pending, claimed, expired, revoked
    case unknown(String)
    public init(raw: String) {
        switch raw {
        case "PENDING": self = .pending
        case "CLAIMED": self = .claimed
        case "EXPIRED": self = .expired
        case "REVOKED": self = .revoked
        default: self = .unknown(raw)
        }
    }
}

/// What a screen can show. `.sent` is only the moment right after creation, while the code is on screen.
public enum BundleTransferDisplayState: Equatable {
    case sent, pending, claimed, expired, revoked, unknown
    public init(_ state: BundleTransferState, justCreated: Bool) {
        switch state {
        case .pending: self = justCreated ? .sent : .pending
        case .claimed: self = .claimed
        case .expired: self = .expired
        case .revoked: self = .revoked
        case .unknown: self = .unknown
        }
    }
}

/// A transfer as the server describes it. Never carries the code.
public struct BundleTransferRecord: Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID?
    public let state: BundleTransferState
    public let expiresAt: BundleTimestamp?
    public init(id: FreeExploreLaunchID, registrationId: FreeExploreLaunchID?,
                state: BundleTransferState, expiresAt: BundleTimestamp?) {
        self.id = id; self.registrationId = registrationId; self.state = state; self.expiresAt = expiresAt
    }
}

/// Server answer to "what happens if I transfer this order". Shape is NOT verified against a backend
/// (B-24 lists no preview route yet); decoded defensively and all fields are display-only.
public struct BundleTransferPreview: Decodable, Equatable {
    public let registrationId: FreeExploreLaunchID
    public let eligible: Bool
    public let ineligibleCode: String?
    public let channels: [String]?
    public let impact: [String]?
    public var offersSMS: Bool { channels?.contains(BundleTransferChannel.sms.rawValue) == true }
    public var impactLines: [String] { impact ?? [] }
}

public struct BundleTransferSendResult {
    public let record: BundleTransferRecord
    public let code: BundleTransferOneTimeCode
    public init(record: BundleTransferRecord, code: BundleTransferOneTimeCode) {
        self.record = record; self.code = code
    }
}

public struct BundleTransferClaimResult: Equatable {
    public let registrationId: FreeExploreLaunchID
    public init(registrationId: FreeExploreLaunchID) { self.registrationId = registrationId }
}

public struct BundleTransferReceipt: Equatable {
    public let idempotencyKey: String
    /// NOT_FOUND is never proof that nothing was written.
    public let transfer: BundleTransferRecord?
    public init(idempotencyKey: String, transfer: BundleTransferRecord?) {
        self.idempotencyKey = idempotencyKey; self.transfer = transfer
    }
}

private func bundleTransferKeyIsValid(_ key: String) -> Bool {
    (1...64).contains(key.utf8.count)
        && key.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }
}

/// `POST transfer` body: `{ registrationId, receiverPhone, channel, idempotencyKey }`.
public struct BundleTransferSendCommand: Encodable, Equatable {
    public let registrationId: FreeExploreLaunchID
    public let receiverPhone: String
    public let channel: BundleTransferChannel
    public let idempotencyKey: String
    public init(registrationId: FreeExploreLaunchID, receiverPhone: String,
                channel: BundleTransferChannel, idempotencyKey: String) throws {
        self.registrationId = registrationId; self.receiverPhone = receiverPhone
        self.channel = channel; self.idempotencyKey = idempotencyKey
        try validate()
    }
    func validate() throws {
        // E.164 or a mainland mobile number; the server remains the authority.
        guard receiverPhone.range(of: "^(\\+[1-9][0-9]{6,14}|1[3-9][0-9]{9})$", options: .regularExpression) != nil,
              bundleTransferKeyIsValid(idempotencyKey) else { throw FreeExploreLaunchFailure.invalid }
    }
    public func wireData() throws -> Data {
        try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// `POST transfer/claim` body: `{ code, idempotencyKey }`. Never persisted.
public struct BundleTransferClaimCommand {
    public let code: BundleTransferOneTimeCode
    public let idempotencyKey: String
    public init(code: BundleTransferOneTimeCode, idempotencyKey: String) throws {
        guard bundleTransferKeyIsValid(idempotencyKey) else { throw FreeExploreLaunchFailure.invalid }
        self.code = code; self.idempotencyKey = idempotencyKey
    }
    private struct Body: Encodable { let code: String; let idempotencyKey: String }
    public func wireData() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Body(code: code.reveal(), idempotencyKey: idempotencyKey))
    }
}

/// Injected boundary. The shipped default is `BundleTransferUnavailableClient`.
@MainActor public protocol BundleTransferServing: AnyObject {
    func preview(registrationID: FreeExploreLaunchID) async throws -> BundleTransferPreview
    func send(_ command: BundleTransferSendCommand) async throws -> BundleTransferSendResult
    func receipt(idempotencyKey: String) async throws -> BundleTransferReceipt
    func transfers(registrationID: FreeExploreLaunchID) async throws -> [BundleTransferRecord]
    func revoke(transferID: FreeExploreLaunchID) async throws -> BundleTransferRecord
    func claim(_ command: BundleTransferClaimCommand) async throws -> BundleTransferClaimResult
}

/// Backend EP-BND-24 does not exist: every call is `.disabled`. Never returns canned data.
@MainActor public final class BundleTransferUnavailableClient: BundleTransferServing {
    public init() {}
    public func preview(registrationID: FreeExploreLaunchID) async throws -> BundleTransferPreview { throw FreeExploreLaunchFailure.disabled }
    public func send(_ command: BundleTransferSendCommand) async throws -> BundleTransferSendResult { throw FreeExploreLaunchFailure.disabled }
    public func receipt(idempotencyKey: String) async throws -> BundleTransferReceipt { throw FreeExploreLaunchFailure.disabled }
    public func transfers(registrationID: FreeExploreLaunchID) async throws -> [BundleTransferRecord] { throw FreeExploreLaunchFailure.disabled }
    public func revoke(transferID: FreeExploreLaunchID) async throws -> BundleTransferRecord { throw FreeExploreLaunchFailure.disabled }
    public func claim(_ command: BundleTransferClaimCommand) async throws -> BundleTransferClaimResult { throw FreeExploreLaunchFailure.disabled }
}

// MARK: - Sender

public enum BundleTransferSendPhase: Equatable {
    case idle, loadingPreview
    /// Server said the bundle cannot be transferred (any used / reserved / held unit, refund hold, ...).
    case ineligible(code: String?)
    /// Server preview is on screen, waiting for the explicit confirmation.
    case ready(BundleTransferPreview)
    case sending
    /// Created; the one-time code is in `oneTimeCode` (memory only) until the sender leaves.
    case shown(BundleTransferRecord)
    /// Created but this device never saw the code (read back after an unknown outcome): sender may only revoke.
    case recovered(BundleTransferRecord)
    case revoked(BundleTransferRecord)
    case outcomeUnknown
    case failed(code: String?)
    case unavailable
}

@MainActor public final class BundleTransferSendModel: ObservableObject {
    @Published public private(set) var phase: BundleTransferSendPhase = .idle
    /// Memory only. Never written to storage, logs or snapshots.
    @Published public private(set) var oneTimeCode: BundleTransferOneTimeCode?
    private let service: any BundleTransferServing
    private let pending: BundleTransferPendingStore
    private let makeKey: () -> String
    private var registrationID: FreeExploreLaunchID?

    public init(service: any BundleTransferServing, pending: BundleTransferPendingStore,
                makeKey: @escaping () -> String = { "bt-" + UUID().uuidString }) {
        self.service = service; self.pending = pending; self.makeKey = makeKey
    }

    public var display: BundleTransferDisplayState? {
        switch phase {
        case .shown(let r): return BundleTransferDisplayState(r.state, justCreated: true)
        case .recovered(let r), .revoked(let r): return BundleTransferDisplayState(r.state, justCreated: false)
        default: return nil
        }
    }

    public func loadPreview(registrationID: FreeExploreLaunchID) async {
        switch phase { case .loadingPreview, .sending: return; default: break }
        self.registrationID = registrationID; phase = .loadingPreview
        do {
            let preview = try await service.preview(registrationID: registrationID)
            guard preview.registrationId == registrationID else { phase = .failed(code: nil); return }
            phase = preview.eligible ? .ready(preview) : .ineligible(code: preview.ineligibleCode)
        } catch { phase = Self.phase(for: error) }
    }

    /// Explicit confirmation. The command is persisted BEFORE dispatch.
    public func confirm(phone: String, channel: BundleTransferChannel) async {
        guard case .ready(let preview) = phase, let registrationID else { return }
        if channel == .sms, !preview.offersSMS { phase = .failed(code: nil); return }
        let key: String
        do {
            if let previous = try pending.load() {
                guard previous.kind == .send, previous.registrationId == registrationID, previous.channel == channel else {
                    phase = .failed(code: nil); return
                }
                key = previous.idempotencyKey
            } else { key = makeKey() }
            let command = try BundleTransferSendCommand(registrationId: registrationID, receiverPhone: phone,
                                                        channel: channel, idempotencyKey: key)
            try pending.save(.send(registrationId: registrationID, channel: channel, idempotencyKey: key))
            phase = .sending
            let result = try await service.send(command)
            oneTimeCode = result.code
            phase = .shown(result.record)
            try? pending.clear()
        } catch { phase = Self.phase(for: error) }
    }

    /// Read back by the SAME key after `.outcomeUnknown`. NOT_FOUND is not proof of "nothing happened".
    public func recover() async {
        guard let operation = try? pending.load(), operation.kind == .send else { return }
        do {
            let receipt = try await service.receipt(idempotencyKey: operation.idempotencyKey)
            if let record = receipt.transfer {
                phase = .recovered(record); try? pending.clear()
            } else { phase = .outcomeUnknown }
        } catch { phase = Self.phase(for: error) }
    }

    /// Sender may revoke while the server says PENDING; the server decides.
    public func revoke() async {
        let record: BundleTransferRecord
        switch phase {
        case .shown(let r), .recovered(let r): record = r
        default: return
        }
        do {
            let updated = try await service.revoke(transferID: record.id)
            oneTimeCode = nil
            phase = .revoked(updated)
        } catch { phase = Self.phase(for: error) }
    }

    /// Leaving the screen discards the code. The transfer itself stays PENDING on the server.
    public func leave() {
        oneTimeCode = nil
        if case .shown(let record) = phase { phase = .recovered(record) }
    }

    static func phase(for error: Error) -> BundleTransferSendPhase {
        guard let failure = error as? FreeExploreLaunchFailure else { return .failed(code: nil) }
        switch failure {
        case .disabled: return .unavailable
        case .outcomeUnknown: return .outcomeUnknown
        case .response(_, _, let code, _):
            return code == BundleTransferBusinessCode.notEligible ? .ineligible(code: code) : .failed(code: code)
        default: return .failed(code: nil)
        }
    }
}

// MARK: - Receiver

public enum BundleTransferClaimPhase: Equatable {
    case idle, claiming
    case claimed(FreeExploreLaunchID)
    /// ONE state for wrong / expired / used / mismatched code. No detail leaks.
    case codeNotAccepted
    case outcomeUnknown
    case failed(code: String?)
    case unavailable
}

@MainActor public final class BundleTransferClaimModel: ObservableObject {
    @Published public private(set) var phase: BundleTransferClaimPhase = .idle
    private let service: any BundleTransferServing
    private let pending: BundleTransferPendingStore
    private let makeKey: () -> String

    public init(service: any BundleTransferServing, pending: BundleTransferPendingStore,
                makeKey: @escaping () -> String = { "bc-" + UUID().uuidString }) {
        self.service = service; self.pending = pending; self.makeKey = makeKey
    }

    /// The code is typed by the user each time; only the idempotency key is persisted.
    public func claim(code: String) async {
        if case .claiming = phase { return }
        do {
            let key: String
            if let previous = try pending.load() {
                guard previous.kind == .claim else { phase = .failed(code: nil); return }
                key = previous.idempotencyKey
            } else { key = makeKey() }
            let command = try BundleTransferClaimCommand(code: BundleTransferOneTimeCode(code.trimmingCharacters(in: .whitespacesAndNewlines)),
                                                         idempotencyKey: key)
            try pending.save(.claim(idempotencyKey: key))
            phase = .claiming
            let result = try await service.claim(command)
            try? pending.clear()
            phase = .claimed(result.registrationId)
        } catch {
            phase = Self.phase(for: error)
            // A definite rejection releases the key; an unknown outcome or login loss keeps it.
            if phase == .codeNotAccepted { try? pending.clear() }
        }
    }

    static func phase(for error: Error) -> BundleTransferClaimPhase {
        guard let failure = error as? FreeExploreLaunchFailure else { return .failed(code: nil) }
        switch failure {
        case .disabled: return .unavailable
        case .outcomeUnknown: return .outcomeUnknown
        case .invalid: return .codeNotAccepted
        case .response(_, _, let code, _):
            switch code {
            case BundleTransferBusinessCode.codeInvalid, BundleTransferBusinessCode.phoneMismatch,
                 BundleTransferBusinessCode.selfTransfer: return .codeNotAccepted
            default: return .failed(code: code)
            }
        default: return .failed(code: nil)
        }
    }
}

// MARK: - Payer refund quote

public enum BundleTransferPayerQuoteState: Equatable {
    case idle
    case shown(FreeExploreLaunchRefundQuote)
    /// Server refused or failed: shown as the server's business code, never inferred locally.
    case unavailable(code: String?)
}

/// The payer keeps the refund right after a transfer (plan: 保留原付款人). Whether a quote exists is the
/// server's answer; this model forwards it unchanged and never consults transfer state.
@MainActor public final class BundleTransferPayerRefundQuoteModel: ObservableObject {
    @Published public private(set) var state: BundleTransferPayerQuoteState = .idle
    private let quote: (FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote
    public init(quote: @escaping (FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote) { self.quote = quote }
    public func load(registrationID: FreeExploreLaunchID) async {
        do { state = .shown(try await quote(registrationID)) }
        catch {
            if case FreeExploreLaunchFailure.response(_, _, let code, _) = error { state = .unavailable(code: code) }
            else { state = .unavailable(code: nil) }
        }
    }
}
