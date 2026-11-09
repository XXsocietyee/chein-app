import Foundation

/// club/create + club/edit parity helpers (pure logic; the SwiftUI screen only renders the result).
public enum ClubOperationsPort {
    /// Field limits copied from the mini-program inputs (maxlength) and mirrored by `ClubOperationsDraft.validate`.
    public static let limits: [String: Int] = ["name": 30, "city": 20, "description": 200, "keywords": 60, "style": 30]

    public static func limit(for field: String) -> Int? { limits[field] }

    /// `N / 200` style counter value; never negative and counted in Characters like the validator.
    public static func counter(_ text: String, field: String) -> (used: Int, limit: Int)? {
        guard let limit = limits[field] else { return nil }
        return (text.count, limit)
    }

    public static func isOverLimit(_ text: String, field: String) -> Bool {
        guard let c = counter(text, field: field) else { return false }
        return c.used > c.limit
    }

    /// First wizard step (1 type, 3 name, 4 city) whose required value is blank, mirroring the mini
    /// `submit()` pre-check; `nil` when the three required inputs are present.
    public static func missingCreateStep(clubType: String, name: String, city: String) -> Int? {
        func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if blank(clubType) { return 1 }
        if blank(name) { return 3 }
        if blank(city) { return 4 }
        return nil
    }

    /// Localization key (see port-1-new-strings.md) for the hint shown for a missing step.
    public static func missingStepHintKey(_ step: Int) -> String? {
        switch step {
        case 1: return "club.ops.create.needType"
        case 3: return "club.ops.create.needName"
        case 4: return "club.ops.create.needCity"
        default: return nil
        }
    }
}

/// Read model for `pages/club/create/index`. It classifies facts the operations
/// service and coordinator already return. It does not add a route, mark a route
/// live, or upload media. Creation stays behind `ClubCreationGate`. The player-first
/// entry never offers the form.
public enum ClubCreatePagePhase: Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

public enum ClubCreateOwnedRead: Equatable, Sendable {
    /// `owned` was present. Callers still reject non-positive and duplicate IDs.
    case list([Int])
    /// The payload omitted `owned`. The count is withheld, not zero.
    case withheld
    /// The array was present but an ID was missing, non-integral, non-positive, or repeated.
    case unknownIDs
    case malformed
}

public enum ClubCreatePageCopy {
    public static let loading = "club.ops.checking"
    public static let empty = "club.ops.create.empty"
    public static let error = "club.ops.readFailed"
    public static let unknownCount = "club.ops.create.unknownCount"
    public static let currentRecords = "club.ops.create.currentRecords"
}

public enum ClubCreatePageAccessibility {
    public static let loading = "club.ops.create.state.loading"
    public static let empty = "club.ops.create.state.empty"
    public static let error = "club.ops.create.state.error"
    public static let unknown = "club.ops.create.state.unknown"
    public static let openCreate = "club.ops.openCreate"
    public static let currentRecords = "club.ops.create.currentRecordCount"
}

public struct ClubCreatePageModel: Equatable, Sendable {
    public static let unknownMark = "—"
    /// Welcome / player-first entry does not list club creation.
    public static let showsOnPlayerFirstEntry = false
    /// Logo and cover upload have no reviewed route on this page, so they stay hidden.
    public static let mediaUploadVisible = false

    public let phase: ClubCreatePagePhase
    /// Known counts, including an explicit empty list (`"0"`). Unknown, loading, and error stay an em dash.
    public let recordCountText: String
    public let offersForm: Bool
    public let showsHostApplication: Bool
    /// True only when the form is offered and the existing creation gate is open.
    public let liveSubmitEnabled: Bool

    public static func usesExistingCreateCommand() -> Bool {
        ClubOperationsCommand.create(ClubOperationsDraft()).path == "api/club/create"
    }

    public static func parseOwned(_ data: Data) -> ClubCreateOwnedRead {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any] else { return .malformed }
        guard payload.keys.contains("owned") else { return .withheld }
        guard let rows = payload["owned"] as? [Any] else { return .malformed }
        var ids: [Int] = []
        for row in rows {
            guard let object = row as? [String: Any], let raw = object["id"], let id = exactInt(raw), id > 0 else { return .unknownIDs }
            ids.append(id)
        }
        guard Set(ids).count == ids.count else { return .unknownIDs }
        return .list(ids)
    }

    public static func interpret(
        signedIn: Bool,
        configured: Bool,
        loading: Bool,
        gate: ClubCreationGate,
        snapshot: ClubOperationsSnapshot?,
        readback: ClubOperationsReadback,
        onPlayerFirstEntry: Bool
    ) -> ClubCreatePageModel {
        func hidden(_ phase: ClubCreatePagePhase, count: String) -> ClubCreatePageModel {
            .init(phase: phase, recordCountText: count, offersForm: false, showsHostApplication: false, liveSubmitEnabled: false)
        }
        if !signedIn || !configured { return hidden(.error, count: unknownMark) }
        if loading { return hidden(.loading, count: unknownMark) }
        let current: ClubOperationsSnapshot?
        switch readback {
        case .loading:
            return hidden(.loading, count: unknownMark)
        case .unavailable:
            return hidden(.error, count: unknownMark)
        case .received(let value):
            guard value.target == .create else { return hidden(.error, count: unknownMark) }
            current = value
        case .idle:
            current = snapshot?.target == .create ? snapshot : nil
        }
        guard let current else { return hidden(.unknown, count: unknownMark) }
        let ids = current.ownedClubIDs
        let phase: ClubCreatePagePhase
        let count: String
        if ids.isEmpty {
            phase = .empty
            count = "0"
        } else if ids.allSatisfy({ $0 > 0 }), Set(ids).count == ids.count {
            phase = .ready
            count = String(ids.count)
        } else {
            return hidden(.unknown, count: unknownMark)
        }
        let playerEntry = onPlayerFirstEntry || showsOnPlayerFirstEntry
        let offersForm = !playerEntry && current.canCreate
        let showsHostApplication = !playerEntry && !current.accountRole.isEmpty && current.accountRole != "club"
        return .init(
            phase: phase,
            recordCountText: count,
            offersForm: offersForm,
            showsHostApplication: showsHostApplication,
            liveSubmitEnabled: offersForm && gate.isCreationAllowed
        )
    }

    public static func interpret(owned: ClubCreateOwnedRead, accountRole: String, gate: ClubCreationGate, onPlayerFirstEntry: Bool) -> ClubCreatePageModel {
        switch owned {
        case .malformed:
            return interpret(signedIn: true, configured: true, loading: false, gate: gate, snapshot: nil, readback: .unavailable, onPlayerFirstEntry: onPlayerFirstEntry)
        case .withheld, .unknownIDs:
            return interpret(signedIn: true, configured: true, loading: false, gate: gate, snapshot: nil, readback: .idle, onPlayerFirstEntry: onPlayerFirstEntry)
        case .list(let ids):
            return interpret(
                signedIn: true,
                configured: true,
                loading: false,
                gate: gate,
                snapshot: .init(target: .create, accountRole: accountRole, ownedClubIDs: ids),
                readback: .idle,
                onPlayerFirstEntry: onPlayerFirstEntry
            )
        }
    }

    private static func exactInt(_ value: Any) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let raw = number.doubleValue
        guard raw.isFinite, raw <= 9_007_199_254_740_991, raw >= -9_007_199_254_740_991 else { return nil }
        let int = Int(raw)
        guard Double(int) == raw else { return nil }
        return int
    }
}
