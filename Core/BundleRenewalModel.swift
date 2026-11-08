import Foundation
import Observation

/// Unmounted. Holds one bundle order's renewal intent. Latest intent wins (by server record id).
/// An unknown write outcome keeps the pending command (same idempotency key) in memory; it is never
/// re-keyed. NOTE: the pending command is memory-only in this slice (no durable store; see iwp-8b-report).
@MainActor @Observable public final class BundleRenewalModel {
    public enum Phase: Equatable { case idle, loaded, unavailable, failed, outcomeUnknown }

    public let registrationID: FreeExploreLaunchID
    private let service: any BundleRenewalServing
    private let makeKey: () -> String
    private var retired = false
    private var latestValue: BundleRenewalRecord?
    private var pending: BundleRenewalCommand?
    public private(set) var phase: Phase = .idle
    public private(set) var busy = false
    public private(set) var failure: FreeExploreLaunchFailure?

    public init(registrationID: FreeExploreLaunchID, service: any BundleRenewalServing,
                makeKey: @escaping () -> String = { UUID().uuidString }) {
        self.registrationID = registrationID; self.service = service; self.makeKey = makeKey
    }

    public var current: Bool { !retired && service.isCurrent }
    public var latest: BundleRenewalRecord? { current ? latestValue : nil }
    public var canSubmit: Bool { current && !busy && pending == nil && phase != .unavailable && service.permitsWrites }
    public var canRetry: Bool { current && !busy && pending != nil && service.permitsWrites }
    public var canRecover: Bool { current && !busy && pending != nil }
    public func retire() { retired = true }

    public func load() async {
        guard current, !busy else { return }
        busy = true; defer { busy = false }
        do {
            let record = try await service.latestIntent(registrationID: registrationID)
            guard current else { return }
            if let record { guard record.registrationId == registrationID else { fail(.malformed); return }; adopt(record) }
            failure = nil; if phase != .outcomeUnknown { phase = .loaded }
        } catch { readFailure(error) }
    }

    public func submit(intent: BundleRenewalIntent, note: String?) async {
        guard canSubmit else { return }
        let command: BundleRenewalCommand
        do { command = try BundleRenewalCommand(registrationId: registrationID, intent: intent, note: note, idempotencyKey: makeKey()) }
        catch { fail(.invalid); return }
        pending = command
        await send(command)
    }

    /// Resends the SAME command (same key). Never builds a new one.
    public func retry() async {
        guard canRetry, let command = pending else { return }
        await send(command)
    }

    /// Reads the latest intent; the pending command is resolved only if the server echoes its key.
    /// A read that does not show the key proves nothing, so the state stays unknown.
    public func recover() async {
        guard canRecover, let command = pending else { return }
        busy = true; defer { busy = false }
        do {
            let record = try await service.latestIntent(registrationID: registrationID)
            guard current else { return }
            if let record, record.registrationId == registrationID, record.idempotencyKey == command.idempotencyKey {
                adopt(record); pending = nil; failure = nil; phase = .loaded
            }
        } catch { readFailure(error) }
    }

    private func send(_ command: BundleRenewalCommand) async {
        busy = true; defer { busy = false }
        do {
            let record = try await service.submitIntent(command)
            guard current else { return }
            guard record.registrationId == registrationID, record.intent == command.intent.rawValue else {
                phase = .outcomeUnknown; failure = .outcomeUnknown; return
            }
            adopt(record); pending = nil; failure = nil; phase = .loaded
        } catch let error as FreeExploreLaunchFailure {
            switch error {
            case .disabled: pending = nil; failure = error; phase = .unavailable
            case .invalid, .staleSession, .busy, .response: pending = nil; fail(error)
            default: phase = .outcomeUnknown; failure = .outcomeUnknown
            }
        } catch let error as APIError where error == .unauthorized {
            pending = nil; fail(.staleSession)
        } catch {
            phase = .outcomeUnknown; failure = .outcomeUnknown
        }
    }

    /// Latest wins: a record older than the one already held (lower server id) never replaces it.
    private func adopt(_ record: BundleRenewalRecord) {
        if let held = latestValue, record.id.value < held.id.value { return }
        latestValue = record
    }

    private func fail(_ error: FreeExploreLaunchFailure) { failure = error; phase = pending == nil ? .failed : .outcomeUnknown }

    private func readFailure(_ error: Error) {
        guard current else { return }
        if let error = error as? FreeExploreLaunchFailure {
            if error == .disabled { failure = error; phase = .unavailable } else { fail(error) }
        } else if let error = error as? APIError, error == .unauthorized {
            fail(.staleSession)
        } else {
            fail(.malformed)
        }
    }
}
