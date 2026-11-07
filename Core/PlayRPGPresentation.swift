import Foundation

// MARK: - Play / RPG presentation logic (pure, testable)
// Backs the dice roller sheet, character sheet editing, challenge-POI submit checklist and the
// "not yet available" write states. Nothing in this file performs a network write.

// MARK: Write availability

/// Play/RPG surfaces whose writes are rejected by the city-node transport in this build.
public enum PlayWriteSurface: String, CaseIterable, Equatable, Sendable {
    case challengeSubmit
    case storyJoin
    case storyAnswer
    case characterSheetSave
    case storyRuleSave
}

/// Honest availability of a write. `isAvailable` stays false until an approved write contract exists;
/// UI must then show `title`/`message` instead of a success state.
public struct PlayWriteAvailability: Equatable, Sendable {
    public let surface: PlayWriteSurface
    public let isAvailable: Bool
    public let title: String
    public let message: String

    public static func current(for surface: PlayWriteSurface) -> PlayWriteAvailability {
        let title = W8Text.t("暂未开放", "Not available yet")
        let message: String
        switch surface {
        case .challengeSubmit:
            message = W8Text.t(
                "挑战结果暂时无法在 App 内提交。你的拍照和答案只保留在本机，不会被发送。",
                "Challenge results can't be submitted from the app yet. Your photo and answer stay on this device and are not sent.")
        case .storyJoin:
            message = W8Text.t(
                "暂时无法在此申请加入，请在城瘾小程序或俱乐部页面中操作。",
                "Joining isn't available here yet. Use the club page instead.")
        case .storyAnswer:
            message = W8Text.t(
                "答案暂时无法在此提交。你的草稿只保留在本机。",
                "Answers can't be submitted from here yet. Your draft stays on this device.")
        case .characterSheetSave:
            message = W8Text.t(
                "角色卡修改暂时无法保存到服务器。以下调整只是本机预览。",
                "Character sheet changes can't be saved to the server yet. Adjustments below are a local preview only.")
        case .storyRuleSave:
            message = W8Text.t(
                "剧情规则暂时无法在此发布，仅保存在本章草稿中。",
                "Story rules can't be published from here yet and are kept in this chapter's draft only.")
        }
        return PlayWriteAvailability(surface: surface, isAvailable: false, title: title, message: message)
    }
}

// MARK: Challenge POI checklist

public struct ChallengePOIChecklistItem: Equatable, Identifiable, Sendable {
    public enum Kind: String, Equatable, Sendable { case arrival, photo, answer }
    public var id: String { kind.rawValue }
    public let kind: Kind
    public let title: String
    public let detail: String
    public let isDone: Bool
}

public enum ChallengePOIChecklist {
    /// Items that apply to the node, in the order the player does them.
    public static func items(
        node: ChallengePOINode,
        withinRange: Bool,
        distanceMeters: Int?,
        photoConfirmed: Bool,
        answerProvided: Bool
    ) -> [ChallengePOIChecklistItem] {
        var result: [ChallengePOIChecklistItem] = []
        if node.latitude != nil && node.longitude != nil {
            let detail: String
            if withinRange {
                detail = W8Text.t("你在挑战范围内", "You are within range")
            } else if let distanceMeters {
                detail = W8Text.t("距离约 \(distanceMeters) 米，请走近后再试", "About \(distanceMeters) m away. Move closer.")
            } else {
                detail = W8Text.t("需要定位确认到达", "Location is needed to confirm arrival")
            }
            result.append(ChallengePOIChecklistItem(
                kind: .arrival, title: W8Text.t("到达地标", "Arrive at the landmark"),
                detail: detail, isDone: withinRange))
        }
        if node.photoRequired {
            result.append(ChallengePOIChecklistItem(
                kind: .photo, title: W8Text.t("现场拍照打卡", "On-site photo"),
                detail: photoConfirmed ? W8Text.t("照片已确认", "Photo confirmed") : W8Text.t("尚未确认照片", "Photo not confirmed yet"),
                isDone: photoConfirmed))
        }
        if !node.question.isEmpty || !node.options.isEmpty {
            result.append(ChallengePOIChecklistItem(
                kind: .answer, title: W8Text.t("回答问题", "Answer the question"),
                detail: answerProvided ? W8Text.t("已选择答案", "Answer ready") : W8Text.t("尚未作答", "Not answered yet"),
                isDone: answerProvided))
        }
        return result
    }

    public static func hasAnswerInput(node: ChallengePOINode, selectedOptionIndex: Int?, textAnswer: String) -> Bool {
        if !node.options.isEmpty {
            guard let selectedOptionIndex else { return false }
            return node.options.indices.contains(selectedOptionIndex)
        }
        if !node.question.isEmpty {
            return !textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    public static func isReady(_ items: [ChallengePOIChecklistItem]) -> Bool {
        items.allSatisfy(\.isDone)
    }

    /// Fraction of applicable steps done, 0...1 (1 when nothing applies).
    public static func progress(_ items: [ChallengePOIChecklistItem]) -> Double {
        guard !items.isEmpty else { return 1 }
        return Double(items.filter(\.isDone).count) / Double(items.count)
    }
}

// MARK: Character sheet draft (local editing)

public struct CharacterSheetChange: Equatable, Identifiable, Sendable {
    public var id: String { stateKey }
    public let stateKey: String
    public let label: String
    public let from: Int
    public let to: Int
}

/// Local, clamped editing buffer for character attributes. It never writes anywhere; the host decides
/// what to do with `changes` (today: show `PlayWriteAvailability.current(for: .characterSheetSave)`).
public struct CharacterSheetDraft: Equatable, Sendable {
    private struct Entry: Equatable, Sendable {
        let label: String
        let original: Int
        var value: Int
        let min: Int
        let max: Int
    }

    private var entries: [String: Entry]
    private let order: [String]

    public init(attributes: [CharacterCardAttribute]) {
        var map: [String: Entry] = [:]
        var keys: [String] = []
        for attribute in attributes where map[attribute.stateKey] == nil {
            let lower = Swift.min(attribute.min, attribute.max)
            let upper = Swift.max(attribute.min, attribute.max)
            let clamped = Swift.max(lower, Swift.min(upper, attribute.value))
            map[attribute.stateKey] = Entry(label: attribute.label, original: clamped, value: clamped, min: lower, max: upper)
            keys.append(attribute.stateKey)
        }
        self.entries = map
        self.order = keys
    }

    public func value(for stateKey: String) -> Int? { entries[stateKey]?.value }

    public func canIncrement(_ stateKey: String) -> Bool {
        guard let entry = entries[stateKey] else { return false }
        return entry.value < entry.max
    }

    public func canDecrement(_ stateKey: String) -> Bool {
        guard let entry = entries[stateKey] else { return false }
        return entry.value > entry.min
    }

    /// Moves the value by `delta`, clamped to the attribute's range. Unknown keys are ignored.
    public mutating func adjust(_ stateKey: String, by delta: Int) {
        guard var entry = entries[stateKey] else { return }
        entry.value = Swift.max(entry.min, Swift.min(entry.max, entry.value + delta))
        entries[stateKey] = entry
    }

    public mutating func reset() {
        for key in order {
            if var entry = entries[key] {
                entry.value = entry.original
                entries[key] = entry
            }
        }
    }

    public var changes: [CharacterSheetChange] {
        order.compactMap { key in
            guard let entry = entries[key], entry.value != entry.original else { return nil }
            return CharacterSheetChange(stateKey: key, label: entry.label, from: entry.original, to: entry.value)
        }
    }

    public var isDirty: Bool { !changes.isEmpty }
}

// MARK: Dice roller session (practice rolls)

public struct DiceRollerHistoryEntry: Equatable, Identifiable, Sendable {
    public let id: Int
    public let kept: Int
    public let total: Int
    public let dc: Int
    public let success: Bool
    public let nat: String
}

/// Deterministic practice roller. Practice rolls are never sent to a server or recorded on a character.
public struct DiceRollerSession: Equatable, Sendable {
    public static let historyLimit = 8

    private var rng: DiceSeededRNG
    private var counter = 0
    public private(set) var receipt: DiceJourneyCheckReceiptView?
    public private(set) var history: [DiceRollerHistoryEntry] = []

    public init(seed: UInt64) {
        self.rng = DiceSeededRNG(seed: seed)
    }

    public mutating func roll(
        mode: DiceCheckEngine.RollMode,
        tier: String,
        skillValue: Int,
        bargain: Int = 0
    ) {
        let input = DiceCheckEngine.CheckInput(
            tier: tier, rollMode: mode,
            skillLabel: W8Text.t("练习", "Practice"),
            skillValue: skillValue, bargain: bargain)
        let result = DiceCheckEngine.evaluate(input: input, rng: &rng)
        receipt = result
        counter += 1
        let entry = DiceRollerHistoryEntry(
            id: counter, kept: result.kept ?? 0, total: result.total ?? 0,
            dc: result.dc ?? 0, success: result.success == true, nat: result.nat)
        history.insert(entry, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
    }

    public mutating func clear() {
        receipt = nil
        history = []
    }

    /// Short VoiceOver announcement for the latest roll.
    public var announcement: String {
        guard let receipt, let kept = receipt.kept, let total = receipt.total, let dc = receipt.dc else {
            return W8Text.t("D20 待掷", "D20 ready to roll")
        }
        let outcome = receipt.success == true ? W8Text.t("通过", "passed") : W8Text.t("未通过", "failed")
        return W8Text.t("D20 点数 \(kept)，总计 \(total)，难度 \(dc)，\(outcome)",
                        "D20 shows \(kept), total \(total) against DC \(dc), \(outcome)")
    }
}
