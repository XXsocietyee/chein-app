import Foundation

// Design hand-off r1 · review/full-config.md (CF-10 … CF-78).
// Pure, testable rules behind the creator Editor kit (App/EditorKit*.swift).
// No wire field, endpoint or persisted format changes here: these are display
// and local-editing rules only.

/// Section 3.3: every editor sheet opens at its smallest detent that shows its content.
public enum EditorSheetDetent: Equatable, Hashable, Sendable {
    /// `.height(content)`, capped at `EditorSheetDetentPlan.fitCap` of the screen.
    case fit
    case height(Double)
    case fraction(Double)
    case medium
    case large
}

/// The sheet families of section 3.3, with their detents (opening detent first).
public enum EditorSheetFamily: String, CaseIterable, Sendable {
    // C1
    case topicMode, imageLayout, branchTask, insertVariable, node, chapter, topicDetail
    case textName, textDescription, textStory, playableHours, dateTime, ticket
    case storyPreview, publishConfirm, publishResult, publishEntry, rewardPicker, collaborator
    // C2
    case gameplayPicker, toolPicker, listTool, singleTool, scanReply, effects, pickOne, saveResult
    // C3
    case activityTime, activityType, myTemplates, originalDraft, allCategories, nodePreview
    case importExternalGame, confirmImport, successResult

    public var detents: [EditorSheetDetent] {
        switch self {
        case .topicMode, .imageLayout, .playableHours, .dateTime, .publishConfirm, .publishResult, .publishEntry,
             .toolPicker, .singleTool, .pickOne, .saveResult, .activityTime, .nodePreview, .successResult:
            return [.fit]
        case .branchTask, .chapter, .ticket, .rewardPicker, .collaborator, .listTool, .effects, .myTemplates,
             .allCategories, .importExternalGame:
            return [.medium, .large]
        case .insertVariable, .scanReply, .activityType, .originalDraft:
            return [.fit, .large]
        case .node, .gameplayPicker:
            return [.fraction(0.62), .large]
        case .topicDetail, .storyPreview, .confirmImport:
            return [.large]
        case .textName:
            return [.height(200)]
        case .textDescription:
            return [.medium]
        case .textStory:
            return [.large]
        }
    }

    /// The grabber is shown on every resizable sheet and hidden on a single-detent sheet.
    public var isResizable: Bool { detents.count > 1 }
    public var openingDetent: EditorSheetDetent { detents[0] }
}

public enum EditorSheetDetentPlan {
    /// `fit` is capped at 62% of the screen height.
    public static let fitCap = 0.62
    /// Height for `.fit`: measured content plus pinned header chrome, capped at 62%.
    public static func fitHeight(content: Double, chrome: Double, screen: Double) -> Double {
        let natural = max(0, content) + max(0, chrome)
        guard screen > 0 else { return natural }
        return min(natural, screen * fitCap)
    }
    /// The inner scroll view is locked until the sheet is at its largest detent.
    public static func scrollEnabled(current: EditorSheetDetent, family: EditorSheetFamily) -> Bool {
        guard let last = family.detents.last else { return true }
        return current == last
    }
}

/// Section 3.2 values, kept as numbers so the SwiftUI side and tests read the same source.
public enum EditorMotionSpec {
    public static let detentResponse = 0.38
    public static let detentDamping = 0.86
    public static let presentSeconds = 0.35
    public static let dismissSeconds = 0.28
    public static let fieldFadeSeconds = 0.18
    public static let fieldFadeDelay = 0.06
    public static let reduceMotionCrossFade = 0.20
    public static let pressScale = 0.97
    public static let pressSeconds = 0.08
    public static let revealSeconds = 0.22
    public static let collapseSeconds = 0.18
    public static let pushSeconds = 0.35
    public static let toastSeconds = 2.0
    // CF-60 reorder
    public static let liftScale = 1.03
    public static let liftSeconds = 0.14
    public static let moveResponse = 0.32
    public static let moveDamping = 0.82
    public static let dropResponse = 0.28
    public static let dropDamping = 0.78
    public static let autoScrollEdge = 60.0
}

/// Section 2 / CF-33: list item actions, in order. Delete is destructive and last.
public enum EditorRowAction: String, CaseIterable, Sendable {
    case moveUp, moveDown, duplicate, delete
    public var isDestructive: Bool { self == .delete }
}

/// CF-33 / CF-60: one reorder rule used by drag (`onMove`), the "⋯" menu and VoiceOver actions.
public enum EditorReorder {
    public static func move<T>(_ items: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().filter { items.indices.contains($0) }
        guard !moving.isEmpty else { return }
        let picked = moving.map { items[$0] }
        let clamped = min(max(0, destination), items.count)
        let before = moving.filter { $0 < clamped }.count
        for index in moving.reversed() { items.remove(at: index) }
        items.insert(contentsOf: picked, at: clamped - before)
    }
    public static func canMoveUp(index: Int, count: Int) -> Bool { index > 0 && index < count }
    public static func canMoveDown(index: Int, count: Int) -> Bool { index >= 0 && index < count - 1 }
    /// Destination for `move(fromOffsets:toOffset:)` when a row moves one step.
    public static func destination(for action: EditorRowAction, index: Int, count: Int) -> Int? {
        switch action {
        case .moveUp: return canMoveUp(index: index, count: count) ? index - 1 : nil
        case .moveDown: return canMoveDown(index: index, count: count) ? index + 2 : nil
        case .duplicate, .delete: return nil
        }
    }
    public static func apply<T>(_ action: EditorRowAction, at index: Int, in items: inout [T]) -> Bool {
        guard let destination = destination(for: action, index: index, count: items.count) else { return false }
        move(&items, fromOffsets: IndexSet(integer: index), toOffset: destination)
        return true
    }
}

/// CF-47: 次数上限 is a number with a 不限次数 switch, never a magic 0.
public enum EditorAttemptLimit: Equatable, Sendable {
    case unlimited
    case limited(Int)

    public static let range = 1...10
    /// Legacy storage uses 0 (or nothing) for "unlimited".
    public init(legacy value: Int?) {
        if let value, value > 0 { self = .limited(value) } else { self = .unlimited }
    }
    public var legacyValue: Int {
        switch self {
        case .unlimited: return 0
        case .limited(let value): return value
        }
    }
    public var isUnlimited: Bool { self == .unlimited }
    /// Turning 不限次数 off restores a sensible small limit.
    public func settingUnlimited(_ unlimited: Bool, fallback: Int = 3) -> EditorAttemptLimit {
        if unlimited { return .unlimited }
        if case .limited = self { return self }
        return .limited(EditorNumber.clamp(fallback, to: Self.range))
    }
}

/// CF-47 / CF-48: numbers with a unit suffix; 积分 is the only currency.
public enum EditorUnit: String, CaseIterable, Sendable {
    case seconds, times, steps, degrees, points, items, percent
    /// Key in the EditorKit table (`editorKit.unit.*`).
    public var key: String { "editorKit.unit." + rawValue }
}

public enum EditorNumber {
    public static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int { min(max(value, range.lowerBound), range.upperBound) }
    /// CF-47: milliseconds are shown in seconds with one decimal (`0.3 秒`).
    public static func secondsText(milliseconds: Int) -> String {
        let tenths = (Double(milliseconds) / 100).rounded()
        return String(format: "%.1f", tenths / 10)
    }
    /// Inverse of `secondsText`; nil for text that is not a non-negative number.
    public static func milliseconds(secondsText text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0, value.isFinite else { return nil }
        return Int((value * 1000).rounded())
    }
    /// Range hints appear only as the error text (CF-47), so the check returns whether to show it.
    public static func isOutOfRange(_ value: Int?, _ range: ClosedRange<Int>) -> Bool {
        guard let value else { return false }
        return !range.contains(value)
    }
}

/// Rule: show unknown values as '—'.
public enum EditorUnknown {
    public static let dash = "—"
    public static func display(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return dash }
        return value
    }
    public static func display(_ value: Int?) -> String { value.map(String.init) ?? dash }
}

/// CF-28: live counter `12/30`, red at the limit.
public struct EditorCounter: Equatable, Sendable {
    public let count: Int
    public let limit: Int
    public init(text: String, limit: Int) { count = text.count; self.limit = limit }
    public var isAtLimit: Bool { limit > 0 && count >= limit }
    public var text: String { "\(count)/\(limit)" }
    public static func clamp(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit))
    }
}

/// CF-22: four save states, icon plus two characters; colour only on failure.
public enum EditorSaveState: String, CaseIterable, Sendable {
    case saved, syncing, unsaved, failed
    public var key: String { "editorKit.save." + rawValue }
    public var symbol: String {
        switch self {
        case .saved: return "checkmark"
        case .syncing: return "arrow.up"
        case .unsaved: return "exclamationmark"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    public var usesErrorColour: Bool { self == .failed }
}

/// CF-03: review status shown as a tag, never as the raw server code.
public enum EditorReviewStatus: Equatable, Sendable {
    case pending, rejected, approved, draft, unknown
    public init(raw: String?) {
        switch raw?.trimmingCharacters(in: .whitespaces).uppercased() {
        case "PENDING", "REVIEWING", "IN_REVIEW", "SUBMITTED": self = .pending
        case "REJECTED", "DENIED", "FAILED": self = .rejected
        case "APPROVED", "PASSED", "PUBLISHED": self = .approved
        case "DRAFT": self = .draft
        default: self = .unknown
        }
    }
    public var key: String {
        switch self {
        case .pending: return "editorKit.review.pending"
        case .rejected: return "editorKit.review.rejected"
        case .approved: return "editorKit.review.approved"
        case .draft: return "editorKit.review.draft"
        case .unknown: return "editorKit.review.unknown"
        }
    }
    public var symbol: String {
        switch self {
        case .pending: return "clock"
        case .rejected: return "xmark.circle"
        case .approved: return "checkmark.circle"
        case .draft: return "pencil"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// CF-44: the gameplay editor's sticky section bar, in page order. mp-r3-publish: MP temp/index.wxml:1213 puts the
/// gameplay first, then the rules, then the cover / template info, then the optional reward, story and tools
/// (玩法 · 规则 · 信息 · 奖励 · 反馈 · 工具).
public enum EditorOutlineSection: String, CaseIterable, Identifiable, Sendable {
    case gameplay, rules, info, reward, feedback, tools
    public var id: String { rawValue }
    public var key: String { "editorKit.outline." + rawValue }
    /// Anchor id used with `ScrollViewReader.scrollTo`.
    public var anchor: String { "editor-outline-" + rawValue }
}

public enum EditorOutlineItemState: String, Equatable, Sendable { case normal, current, error, done }

public struct EditorOutline: Equatable, Sendable {
    public var current: EditorOutlineSection
    public var errors: Set<EditorOutlineSection>
    public var done: Set<EditorOutlineSection>
    public init(current: EditorOutlineSection = .info, errors: Set<EditorOutlineSection> = [], done: Set<EditorOutlineSection> = []) {
        self.current = current; self.errors = errors; self.done = done
    }
    public func state(_ section: EditorOutlineSection) -> EditorOutlineItemState {
        if errors.contains(section) { return .error }
        if section == current { return .current }
        if done.contains(section) { return .done }
        return .normal
    }
    /// CF-17: the primary stays enabled; tapping it jumps to the first section with an error.
    public var firstError: EditorOutlineSection? { EditorOutlineSection.allCases.first { errors.contains($0) } }

    /// Maps an existing validation key (e.g. `templateAuthor.validation.descriptionLength`) to a section.
    public static func section(forIssue key: String) -> EditorOutlineSection {
        let lower = key.lowercased()
        if lower.contains("rule") { return .rules }
        if lower.contains("reward") || lower.contains("medal") || lower.hasSuffix(".xp") || lower.contains(".xp.") { return .reward }
        if lower.contains("feedback") || lower.contains("story") { return .feedback }
        if lower.contains("tool") || lower.contains("module") { return .tools }
        if lower.contains("game") || lower.contains("finish") || lower.contains("question") || lower.contains("option")
            || lower.contains("method") || lower.contains("compass") || lower.contains("shout") || lower.contains("timer") { return .gameplay }
        return .info
    }
    public static func errors(forIssues keys: [String]) -> Set<EditorOutlineSection> { Set(keys.map(section(forIssue:))) }
}

/// CF-58: three-segment step bar; a segment is tappable once visited.
public struct EditorStepProgress: Equatable, Sendable {
    public let count: Int
    public private(set) var current: Int
    public private(set) var furthestVisited: Int
    public init(count: Int, current: Int = 0) {
        self.count = max(1, count)
        let start = min(max(0, current), max(1, count) - 1)
        self.current = start; furthestVisited = start
    }
    public func canSelect(_ index: Int) -> Bool { index >= 0 && index < count && index <= furthestVisited }
    public func isFilled(_ index: Int) -> Bool { index <= current }
    @discardableResult public mutating func select(_ index: Int) -> Bool {
        guard canSelect(index) else { return false }
        current = index; return true
    }
    @discardableResult public mutating func advance() -> Bool {
        guard current + 1 < count else { return false }
        current += 1; furthestVisited = max(furthestVisited, current); return true
    }
    @discardableResult public mutating func back() -> Bool {
        guard current > 0 else { return false }
        current -= 1; return true
    }
}

/// CF-38: the 创作页 ticket card summary (`2 种票 · 39 积分起`, or `还没设置`).
public struct EditorTicketSummary: Equatable, Sendable {
    public let kinds: Int
    /// Lowest known price in 积分; nil when no price is known.
    public let lowestPoints: Int?
    public init(prices: [Int?]) {
        kinds = prices.count
        lowestPoints = prices.compactMap { $0 }.filter { $0 >= 0 }.min()
    }
    public var isEmpty: Bool { kinds == 0 }
}

/// HIG Modality / CF-12: never a sheet on a sheet; deeper editors push inside the one sheet.
public enum EditorPresentationRule {
    public enum Mode: Equatable, Sendable { case sheet, push }
    /// `sheetDepth` is the number of sheets already on screen.
    public static func mode(sheetDepth: Int) -> Mode { sheetDepth >= 1 ? .push : .sheet }
}

/// CF-55 / section 6 Q-D: D20 难度 keeps the owner's dropdown.
public enum EditorChoiceControl: Equatable, Sendable {
    case segmented, popUp, tiles
    /// Section 2 single-choice rule, with the owner override for D20 difficulty.
    public static func forChoices(count: Int, longestLabel: Int, isVisual: Bool, ownerDropdown: Bool = false) -> EditorChoiceControl {
        if ownerDropdown { return .popUp }
        if isVisual { return .tiles }
        if count <= 3 && longestLabel <= 6 { return .segmented }
        return .popUp
    }
}
