import Foundation

/// Port of mini-program `pages/template/index` list-state rules (pure value logic, no network).
public enum TemplateBrowserPort {
    /// Cover image is shown only for a plain https URL; anything else (nil, blank, http, credentials)
    /// renders the mini-program's "封面暂不可用" placeholder instead of a broken box.
    public static func coverURL(_ raw: String?) -> URL? { RoamStampSlipPhotoPort.displayURL(raw) }

    /// `.wxml`: the "正在同步最新内容…" line shows only while a refresh runs over already-loaded rows;
    /// the first load uses the skeleton/spinner instead.
    public static func showsSyncingLine(isLoading: Bool, hasLoadedRows: Bool) -> Bool { isLoading && hasLoadedRows }

    /// `.wxml`: the "其他模板 / 不筛掉，继续显示" hint belongs to the tail list only.
    public static func showsOtherTemplatesHint(otherCount: Int) -> Bool { otherCount > 0 }
}

/// Pages/template/index shelf counts. Unknown is an em dash. A literal 0 stays "0".
public enum TemplateIndexCount: Equatable, Sendable {
    public static let unknownDisplay = "—"
    case unknown
    case known(Int)

    public var text: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .known(let value): return String(value)
        }
    }

    /// Nil and negative stay unknown. Zero is a known zero.
    public init(nonnegative value: Int?) {
        guard let value, value >= 0 else { self = .unknown; return }
        self = .known(value)
    }
}

public enum TemplateIndexHomeTotalUpdate: Equatable, Sendable {
    case notRead
    case read(Int?)
}

public struct TemplateIndexTopicFacts: Equatable, Sendable {
    public let id: Int
    public let chapterText: String
    public let stopsText: String
    public let secondsText: String
    public let chapterAccessibilityIdentifier: String
}

public struct TemplateIndexPlayFacts: Equatable, Sendable {
    public let id: Int
    public let useText: String
    public let playersText: String
    public let useAccessibilityIdentifier: String
}

/// Loading, empty, error, and ready for the publish / template-library tab.
/// A refresh keeps the last known counts. The first failure does not invent 0.
public struct TemplateIndexPageState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case loading
        case empty
        case error
        case ready

        public var localizationKey: String {
            switch self {
            case .loading: return "pages.template.index.loading"
            case .empty: return "pages.template.index.empty"
            case .error: return "pages.template.index.error"
            case .ready: return "pages.template.index.ready"
            }
        }

        public var accessibilityIdentifier: String {
            switch self {
            case .loading: return "pages.template.index.loading"
            case .empty: return "pages.template.index.empty"
            case .error: return "pages.template.index.error"
            case .ready: return "pages.template.index.ready"
            }
        }
    }

    public var phase: Phase
    public var showsError: Bool
    public var showsSyncing: Bool
    public var showsHomeError: Bool
    public var rowCount: TemplateIndexCount
    public var homeTotal: TemplateIndexCount

    public var rowCountText: String { rowCount.text }
    public var homeTotalText: String { homeTotal.text }
    public static let rowCountAccessibilityIdentifier = "pages.template.index.rowCount"
    public static let homeTotalAccessibilityIdentifier = "pages.template.index.homeTotal"
    public static let unknownAccessibilityIdentifier = "pages.template.index.unknown"

    public static let initial = TemplateIndexPageState(
        phase: .loading,
        showsError: false,
        showsSyncing: false,
        showsHomeError: false,
        rowCount: .unknown,
        homeTotal: .unknown
    )
}

public enum TemplateIndexPageModel {
    public static func beginLoad(_ state: TemplateIndexPageState) -> TemplateIndexPageState {
        var next = state
        next.showsError = false
        next.showsHomeError = false
        if case .unknown = state.rowCount {
            next.phase = .loading
            next.showsSyncing = false
        } else {
            next.showsSyncing = true
        }
        return next
    }

    public static func succeed(loadedRows: Int, homeTotal: TemplateIndexHomeTotalUpdate, showsHomeError: Bool, state: TemplateIndexPageState) -> TemplateIndexPageState {
        var next = state
        next.showsError = false
        next.showsSyncing = false
        next.showsHomeError = showsHomeError
        next.phase = loadedRows == 0 ? .empty : .ready
        next.rowCount = .known(loadedRows)
        switch homeTotal {
        case .notRead:
            break
        case .read(let value):
            next.homeTotal = TemplateIndexCount(nonnegative: value)
        }
        return next
    }

    public static func fail(_ state: TemplateIndexPageState) -> TemplateIndexPageState {
        var next = state
        next.showsSyncing = false
        next.showsError = true
        if case .unknown = state.rowCount {
            next.phase = .error
            next.rowCount = .unknown
        }
        return next
    }

    public static func topicFacts(_ item: DiscoveryTopicTemplate) -> TemplateIndexTopicFacts {
        let chapter: TemplateIndexCount = item.chapterCountIncluded && item.chapterCount >= 0
            ? .known(item.chapterCount)
            : .unknown
        return TemplateIndexTopicFacts(
            id: item.id,
            chapterText: chapter.text,
            stopsText: TemplateIndexCount(nonnegative: item.locationCount).text,
            secondsText: TemplateIndexCount(nonnegative: item.totalTime).text,
            chapterAccessibilityIdentifier: "pages.template.index.chapter.\(item.id)"
        )
    }

    public static func playFacts(_ item: DiscoveryPlayTemplate) -> TemplateIndexPlayFacts {
        TemplateIndexPlayFacts(
            id: item.id,
            useText: TemplateIndexCount(nonnegative: item.useNum).text,
            playersText: item.playersText ?? TemplateIndexCount.unknownDisplay,
            useAccessibilityIdentifier: "pages.template.index.use.\(item.id)"
        )
    }
}

/// Reads the template tab through the existing DiscoveryService catalog methods.
/// The copy-to-draft write stays hidden. A missing publish capability stays hidden.
@MainActor
public final class TemplateIndexPageCoordinator {
    public private(set) var state: TemplateIndexPageState
    public private(set) var topicFacts: [TemplateIndexTopicFacts]
    public private(set) var playFacts: [TemplateIndexPlayFacts]
    public let showsMerchantChoice = false
    public let paymentEnabled = false
    public let payoutEnabled = false
    public let withdrawalEnabled = false
    public let virtualGoodsEnabled = false
    public let topicTemplateUseHidden = true
    public let publishActionsHidden: Bool
    public let publishQuotaText: String
    private let service: DiscoveryService
    private var ticket = UUID()
    private var shelfKey = ""

    public init(service: DiscoveryService, publishCapability: PublishingCapability?, scope: TemplateTabScope = .consumer) {
        self.service = service
        let hidden = publishCapability == nil || scope.isStaffReadOnly
        self.publishActionsHidden = hidden
        self.publishQuotaText = hidden
            ? TemplateIndexCount.unknownDisplay
            : TemplateIndexCount(nonnegative: publishCapability?.remaining).text
        self.state = .initial
        self.topicFacts = []
        self.playFacts = []
    }

    public func loadTopicsShelf() async {
        let current = begin("topics")
        async let topicsTask = service.topicTemplates()
        async let homeTask = service.templateHome()
        let topics: Result<[DiscoveryTopicTemplate], Error>
        do { topics = .success(try await topicsTask) } catch { topics = .failure(error) }
        let home: Result<DiscoveryTemplateHome, Error>
        do { home = .success(try await homeTask) } catch { home = .failure(error) }
        guard ticket == current else { return }
        switch topics {
        case .success(let rows):
            let update: TemplateIndexHomeTotalUpdate
            var homeError = false
            switch home {
            case .success(let value):
                update = .read(value.total)
            case .failure:
                update = .notRead
                homeError = true
            }
            state = TemplateIndexPageModel.succeed(loadedRows: rows.count, homeTotal: update, showsHomeError: homeError, state: state)
            topicFacts = rows.map(TemplateIndexPageModel.topicFacts)
        case .failure(let error):
            if error is CancellationError { return }
            state = TemplateIndexPageModel.fail(state)
            switch home {
            case .success(let value):
                state.homeTotal = TemplateIndexCount(nonnegative: value.total)
            case .failure(let homeError):
                if !(homeError is CancellationError) {
                    state.showsHomeError = true
                }
            }
        }
    }

    public func loadGames(keyword: String, pack: DiscoveryPackType?) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = !trimmed.isEmpty || pack != nil
        let key = filtered ? "games:\(trimmed):\(pack.map { String($0.rawValue) } ?? "")" : "games"
        let current = begin(key)
        if filtered {
            do {
                let rows = try await service.playTemplates(keyword: trimmed, packType: pack)
                guard ticket == current else { return }
                state = TemplateIndexPageModel.succeed(loadedRows: rows.count, homeTotal: .notRead, showsHomeError: false, state: state)
                playFacts = rows.map(TemplateIndexPageModel.playFacts)
            } catch is CancellationError {
                return
            } catch {
                guard ticket == current else { return }
                state = TemplateIndexPageModel.fail(state)
            }
        } else {
            do {
                let home = try await service.templateHome()
                guard ticket == current else { return }
                let visible = home.banner.count + home.latest.count + home.recommended.count + home.mustPlay.count + home.hot.count
                let rows = home.isEmpty ? 0 : visible
                state = TemplateIndexPageModel.succeed(loadedRows: rows, homeTotal: .read(home.total), showsHomeError: false, state: state)
                playFacts = (home.banner + home.latest + home.recommended + home.mustPlay + home.hot).map(TemplateIndexPageModel.playFacts)
            } catch is CancellationError {
                return
            } catch {
                guard ticket == current else { return }
                state = TemplateIndexPageModel.fail(state)
            }
        }
    }

    private func begin(_ shelf: String) -> UUID {
        if shelfKey != shelf {
            shelfKey = shelf
            state = .initial
            topicFacts = []
            playFacts = []
        }
        ticket = UUID()
        state = TemplateIndexPageModel.beginLoad(state)
        return ticket
    }
}

#if DEBUG
/// Synthetic JSON for the template tab. No transport, host, or credential.
public enum TemplateIndexFixtureData {
    public static let topicMissingCounts = #"{"id":801,"name":"Sample route"}"#
    public static let topicNullCounts = #"{"id":801,"name":"Sample route","chapterCount":null,"locationCount":null,"totalTime":null}"#
    public static let topicKnownZero = #"{"id":802,"name":"Known zero","chapterCount":0,"locationCount":0,"totalTime":0}"#
    public static let topicKnown = #"{"id":803,"name":"Known","chapterCount":2,"locationCount":4,"totalTime":90}"#
    public static let topicNegativeChapter = #"{"id":804,"name":"Bad chapter","chapterCount":-1}"#
    public static let homeMissingTotal = "{}"
    public static let homeKnownZeroTotal = #"{"total":0}"#
    public static let homeKnownTotal = #"{"total":2,"recommendList":[{"id":701,"title":"Sample play"}]}"#
    public static let homeNegativeTotal = #"{"total":-3,"recommendList":[{"id":701,"title":"Sample play"}]}"#
    public static let playMissingUse = #"{"id":701,"title":"Sample play"}"#
    public static let playKnownZeroUse = #"{"id":702,"title":"Used none","useNum":0,"players":"--"}"#
    public static let playKnownUse = #"{"id":703,"title":"Used","useNum":3,"players":"2-4"}"#
}
#endif
