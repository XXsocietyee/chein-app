import Foundation

/// P040 selects a single real home-data pool before taking three examples; it never mixes or seeds drafts.
public struct TemplateAuthoringIntroExamples: Equatable {
    public enum Pool: String, Equatable { case recommended, hot, latest }
    public struct SysCategory: Codable, Equatable, Sendable {
        public let categoryName: String?
        public init(categoryName: String? = nil) { self.categoryName = categoryName }
    }
    private struct CategoryEnvelope: Decodable {
        struct Item: Decodable { let sysCategoryList: [SysCategory]? }
        let recommendList: [Item]?
        let hotList: [Item]?
        let latestList: [Item]?
    }
    public static let maximum = 3
    public static let defaultCategoryName = "节点玩法"
    public let pool: Pool
    public let rows: [DiscoveryPlayTemplate]
    public let categoryNames: [String]
    public init(home: DiscoveryTemplateHome, categoryNames: [String]? = nil) {
        let source: [DiscoveryPlayTemplate]
        if !home.recommended.isEmpty { pool = .recommended; source = home.recommended }
        else if !home.hot.isEmpty { pool = .hot; source = home.hot }
        else { pool = .latest; source = home.latest }
        let selected = Array(source.prefix(Self.maximum))
        rows = selected
        self.categoryNames = (0..<selected.count).map { index in
            Self.normalizedCategoryName(categoryNames?.indices.contains(index) == true ? categoryNames?[index] : nil)
        }
    }
    public init(homeData: Data) throws {
        let home = try JSONDecoder().decode(DiscoveryTemplateHome.self, from: homeData)
        let selectedPool: Pool = !home.recommended.isEmpty ? .recommended : (!home.hot.isEmpty ? .hot : .latest)
        let decodedCategories = Self.decodeCategoryNames(from: homeData, pool: selectedPool)
        self.init(home: home, categoryNames: decodedCategories)
    }
    public func categoryName(at index: Int) -> String {
        categoryNames.indices.contains(index) ? categoryNames[index] : Self.defaultCategoryName
    }
    public static func categoryName(from sysCategoryList: [SysCategory]?) -> String {
        normalizedCategoryName(sysCategoryList?.first?.categoryName)
    }
    public static func normalizedCategoryName(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultCategoryName : trimmed
    }
    public static func decodeCategoryNames(from homeData: Data, pool: Pool) -> [String] {
        guard let envelope = try? JSONDecoder().decode(CategoryEnvelope.self, from: homeData) else { return [] }
        let items: [CategoryEnvelope.Item]
        switch pool {
        case .recommended: items = envelope.recommendList ?? []
        case .hot: items = envelope.hotList ?? []
        case .latest: items = envelope.latestList ?? []
        }
        return items.prefix(maximum).map { categoryName(from: $0.sysCategoryList) }
    }
}

/// A count from the existing template home document.
/// Missing, null, boolean, text (including UNKNOWN), and non-integers stay unknown.
/// Unknown is an em dash. A server 0 stays 0.
public enum TemplateAuthoringIntroCountState: Equatable {
    case unknown
    case value(Int)
    public static let unknownText = "—"
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }
    public var text: String {
        switch self {
        case .unknown: return Self.unknownText
        case .value(let number): return String(number)
        }
    }
    public static func parse(_ raw: Any?) -> TemplateAuthoringIntroCountState {
        guard let raw, !(raw is NSNull) else { return .unknown }
        guard let number = raw as? NSNumber else { return .unknown }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return .unknown }
        let double = number.doubleValue
        guard double.isFinite, abs(double) <= 9_007_199_254_740_991 else { return .unknown }
        let integer = Int(double)
        guard Double(integer) == double else { return .unknown }
        return .value(integer)
    }
}

public struct TemplateAuthoringIntroCardFact: Equatable {
    public let id: Int
    public let title: String
    public let categoryName: String
    public let useCount: TemplateAuthoringIntroCountState
    public let duration: TemplateAuthoringIntroCountState
    public init(id: Int, title: String, categoryName: String, useCount: TemplateAuthoringIntroCountState, duration: TemplateAuthoringIntroCountState) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.useCount = useCount
        self.duration = duration
    }
}

/// Loading, empty, error, and unknown-count states for the intro examples.
/// Pool choice stays in `TemplateAuthoringIntroExamples`. No sample rows are invented.
public struct TemplateAuthoringIntroReadModel: Equatable {
    public enum Phase: Equatable { case loading, empty, error, ready }
    public let phase: Phase
    public let examples: TemplateAuthoringIntroExamples?
    public let cards: [TemplateAuthoringIntroCardFact]
    public let total: TemplateAuthoringIntroCountState
    public static let loading = TemplateAuthoringIntroReadModel(phase: .loading, examples: nil, cards: [], total: .unknown)
    public static let errored = TemplateAuthoringIntroReadModel(phase: .error, examples: nil, cards: [], total: .unknown)

    public init(phase: Phase, examples: TemplateAuthoringIntroExamples?, cards: [TemplateAuthoringIntroCardFact], total: TemplateAuthoringIntroCountState) {
        self.phase = phase
        self.examples = examples
        self.cards = cards
        self.total = total
    }

    /// Decoded home from the existing `DiscoveryService.templateHome` read.
    /// Nil counts are unknown. This path does not see a raw UNKNOWN token; that token never becomes 0.
    public init(home: DiscoveryTemplateHome) {
        let examples = TemplateAuthoringIntroExamples(home: home)
        let total = home.total.map { TemplateAuthoringIntroCountState.value($0) } ?? .unknown
        if examples.rows.isEmpty {
            self.init(phase: .empty, examples: examples, cards: [], total: total)
            return
        }
        let cards = examples.rows.enumerated().map { index, row in
            TemplateAuthoringIntroCardFact(
                id: row.id,
                title: row.title,
                categoryName: examples.categoryName(at: index),
                useCount: row.useNum.map { TemplateAuthoringIntroCountState.value($0) } ?? .unknown,
                duration: row.duration.map { TemplateAuthoringIntroCountState.value($0) } ?? .unknown)
        }
        self.init(phase: .ready, examples: examples, cards: cards, total: total)
    }

    /// Same home object `DiscoveryService.templateHome` already decodes. Not a new route.
    public static func make(homeData: Data) -> TemplateAuthoringIntroReadModel? {
        guard let root = try? JSONSerialization.jsonObject(with: homeData) as? [String: Any] else { return nil }
        let examples: TemplateAuthoringIntroExamples
        if let decoded = try? TemplateAuthoringIntroExamples(homeData: homeData) {
            examples = decoded
        } else if let normalized = try? JSONSerialization.data(withJSONObject: normalizeUnknownCounts(root)),
                  let decoded = try? TemplateAuthoringIntroExamples(homeData: normalized) {
            examples = decoded
        } else {
            return nil
        }
        let total = TemplateAuthoringIntroCountState.parse(root["total"])
        if examples.rows.isEmpty {
            return TemplateAuthoringIntroReadModel(phase: .empty, examples: examples, cards: [], total: total)
        }
        guard let raw = rawPoolRows(root, pool: examples.pool), raw.count == examples.rows.count else { return nil }
        var cards: [TemplateAuthoringIntroCardFact] = []
        for index in examples.rows.indices {
            let row = examples.rows[index]
            let source = raw[index]
            guard TemplateAuthoringIntroCountState.parse(source["id"]) == .value(row.id) else { return nil }
            cards.append(TemplateAuthoringIntroCardFact(
                id: row.id,
                title: row.title,
                categoryName: examples.categoryName(at: index),
                useCount: TemplateAuthoringIntroCountState.parse(source["useNum"]),
                duration: TemplateAuthoringIntroCountState.parse(source["duration"])))
        }
        return TemplateAuthoringIntroReadModel(phase: .ready, examples: examples, cards: cards, total: total)
    }

    private static func rawPoolRows(_ root: [String: Any], pool: TemplateAuthoringIntroExamples.Pool) -> [[String: Any]]? {
        let key: String
        switch pool {
        case .recommended: key = "recommendList"
        case .hot: key = "hotList"
        case .latest: key = "latestList"
        }
        guard let list = root[key] as? [Any] else { return nil }
        var rows: [[String: Any]] = []
        for item in list {
            guard let row = item as? [String: Any] else { return nil }
            rows.append(row)
            if rows.count == TemplateAuthoringIntroExamples.maximum { break }
        }
        return rows
    }

    /// Lets the existing decoder accept a row whose count is not an integer, then the original token stays unknown.
    private static func normalizeUnknownCounts(_ root: [String: Any]) -> [String: Any] {
        var copy = root
        if copy.keys.contains("total"), TemplateAuthoringIntroCountState.parse(copy["total"]).literal == nil {
            copy["total"] = NSNull()
        }
        for key in ["recommendList", "hotList", "latestList"] {
            guard let list = copy[key] as? [Any] else { continue }
            var rebuilt: [Any] = []
            for item in list {
                guard var row = item as? [String: Any] else {
                    rebuilt.append(item)
                    continue
                }
                for field in ["useNum", "duration"] {
                    if row.keys.contains(field), TemplateAuthoringIntroCountState.parse(row[field]).literal == nil {
                        row[field] = NSNull()
                    }
                }
                rebuilt.append(row)
            }
            copy[key] = rebuilt
        }
        return copy
    }
}

/// Calls the existing template-home read. A failed read stays an error and does not invent examples.
@MainActor public final class TemplateAuthoringIntroCoordinator {
    private enum Source {
        case service(@MainActor () async throws -> DiscoveryTemplateHome)
        case document(@MainActor () async throws -> Data)
    }
    public private(set) var model = TemplateAuthoringIntroReadModel.loading
    private let source: Source
    private var task: Task<Void, Never>?
    private var ticket = UUID()

    public init(templateHome: @escaping @MainActor () async throws -> DiscoveryTemplateHome) {
        source = .service(templateHome)
    }
    public init(homeData: @escaping @MainActor () async throws -> Data) {
        source = .document(homeData)
    }

    @discardableResult public func load() -> Task<Void, Never>? {
        guard task == nil else { return nil }
        let generation = UUID()
        ticket = generation
        if model.phase != .ready { model = .loading }
        let created = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.ticket == generation { self.task = nil } }
            guard self.ticket == generation, !Task.isCancelled else { return }
            let next: TemplateAuthoringIntroReadModel?
            do {
                switch self.source {
                case .service(let templateHome):
                    next = TemplateAuthoringIntroReadModel(home: try await templateHome())
                case .document(let homeData):
                    next = TemplateAuthoringIntroReadModel.make(homeData: try await homeData())
                }
            } catch {
                next = nil
            }
            guard self.ticket == generation, !Task.isCancelled else { return }
            if let next {
                self.model = next
            } else if self.model.phase != .ready {
                self.model = .errored
            }
        }
        task = created
        return created
    }

    public func cancel() {
        ticket = UUID()
        task?.cancel()
        task = nil
    }
}
