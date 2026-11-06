import Foundation
import Observation

/// Owns one screen's reads and selection. Covering it with the selected profile cancels
/// list work, but does not revoke the profile's target or manufacture a new action owner.
@MainActor @Observable public final class ProfileFollowListFlow {
    private let reader: (any ProfileFollowListReading)?
    public private(set) var kind: ProfileFollowListKind = .following
    public private(set) var rows: [ProfileFollowListMember] = []
    public private(set) var nextCursor: Int?
    public private(set) var loadedPageCount = 0
    public private(set) var hasLoaded = false
    public private(set) var loading = false
    public private(set) var error: Error?
    public private(set) var selection: ProfileFollowListSelection?
    public private(set) var returnAnchorMemberID: Int?
    private var pendingReturnMemberID: Int?
    private enum ReadPlan {
        case refresh(pages: Int)
        case more(cursor: Int)
    }
    private var failedPlan: ReadPlan?
    private var visible = false
    private var foreground = false
    private var retired = false
    private var generation = UUID()
    private var task: Task<Void, Never>?
    public init(reader: (any ProfileFollowListReading)?) { self.reader = reader }
    public var isCurrent: Bool { !retired && reader?.isCurrent == true }
    public var isConfigured: Bool { isCurrent && reader?.isConfigured == true }
    public var hasMore: Bool { nextCursor != nil }
    public var canRetry: Bool { failedPlan != nil && !loading && isConfigured }
    public var visibleRows: [ProfileFollowListMember] { isConfigured && foreground ? rows : [] }
    @discardableResult public func appear(foreground: Bool) -> Task<Void, Never>? {
        guard !retired else { return nil }
        visible = true; self.foreground = foreground
        cancelRead()
        // Rebuild the visited depth using fresh cursors, not a stale tail or optimistic toggles.
        return start(plan: refreshPlan)
    }
    public func suspend() { visible = false; cancelRead() }
    public func setForeground(_ value: Bool) {
        guard foreground != value else { return }
        foreground = value; cancelRead()
        if visible && value { start(plan: refreshPlan) }
    }
    public func retire() {
        retired = true; visible = false; foreground = false; cancelRead()
        selection = nil; rows = []; nextCursor = nil; loadedPageCount = 0
        pendingReturnMemberID = nil; returnAnchorMemberID = nil
        hasLoaded = false; error = nil; failedPlan = nil
    }
    public func selectKind(_ value: ProfileFollowListKind) {
        guard visible, foreground, isConfigured, selection == nil, kind != value else { return }
        cancelRead(); kind = value; rows = []; nextCursor = nil; loadedPageCount = 0
        pendingReturnMemberID = nil; returnAnchorMemberID = nil
        hasLoaded = false; error = nil; failedPlan = nil
        start(plan: refreshPlan)
    }
    public func refresh() async {
        guard visible, foreground, isConfigured, selection == nil else { return }
        cancelRead()
        await start(plan: refreshPlan)?.value
    }
    @discardableResult public func more() -> Task<Void, Never>? {
        guard error == nil, hasLoaded, let nextCursor else { return nil }
        return start(plan: .more(cursor: nextCursor))
    }
    @discardableResult public func retry() -> Task<Void, Never>? {
        guard let plan = failedPlan else { return nil }; return start(plan: plan)
    }
    private var refreshPlan: ReadPlan { .refresh(pages: max(1, loadedPageCount)) }
    private func cancelRead() { generation = UUID(); task?.cancel(); task = nil; loading = false }
    @discardableResult private func start(plan: ReadPlan) -> Task<Void, Never>? {
        guard visible, foreground, isConfigured, selection == nil, !loading, let reader else { return nil }
        let reset: Bool, requestedPages: Int, firstCursor: Int
        switch plan {
        case .refresh(let pages): reset = true; requestedPages = pages; firstCursor = 0
        case .more(let cursor):
            guard hasLoaded, nextCursor == cursor else { return nil }
            reset = false; requestedPages = 1; firstCursor = cursor
        }
        let capturedKind = kind, capturedIdentity = reader.identity, run = UUID()
        generation = run; loading = true; error = nil; failedPlan = nil
        if reset { rows = []; nextCursor = nil; hasLoaded = false }
        let next = Task { @MainActor [weak self] in
            guard let self else { return }
            @MainActor func current() -> Bool {
                !Task.isCancelled && self.generation == run && self.visible && self.foreground &&
                self.kind == capturedKind && self.selection == nil && self.isConfigured &&
                reader.identity == capturedIdentity
            }
            defer { if self.generation == run { self.loading = false; self.task = nil } }
            do {
                guard current() else { return }
                guard let owner = capturedIdentity.accountID else { throw APIError.unauthorized }
                var collected = reset ? [] : self.rows
                var cursor = firstCursor, completedPages = 0
                var freshNextCursor: Int? = nil
                for _ in 0..<requestedPages {
                    guard current() else { return }
                    let page = try await reader.page(kind: capturedKind, cursor: cursor)
                    guard current() else { return }
                    try page.validate(owner: owner, kind: capturedKind, cursor: cursor)
                    let existing = Set(collected.map(\.id))
                    guard page.rows.allSatisfy({ !existing.contains($0.id) }) else { throw APIError.malformedResponse }
                    collected += page.rows; completedPages += 1; freshNextCursor = page.nextCursor
                    guard let next = page.nextCursor else { break }
                    cursor = next
                }
                guard current() else { return }
                // Publish the rebuilt window once. A failed later page never exposes a partial rebuild.
                self.rows = collected; self.nextCursor = freshNextCursor; self.hasLoaded = true
                self.loadedPageCount = reset ? completedPages : self.loadedPageCount + completedPages
                if reset, let anchor = self.pendingReturnMemberID {
                    // The selected member may have disappeared. Restore to its next surviving
                    // neighbour, or the last row, without extending the visited page window.
                    self.returnAnchorMemberID = collected.first(where: { $0.id >= anchor })?.id ?? collected.last?.id
                    self.pendingReturnMemberID = nil
                }
            } catch {
                guard current() else { return }
                self.error = error
                if Self.isDenial(error) {
                    self.rows = []; self.nextCursor = nil; self.hasLoaded = false; self.loadedPageCount = 0
                }
                self.failedPlan = Self.isDenial(error) ? .refresh(pages: 1) : plan
            }
        }
        task = next; return next
    }
    private static func isDenial(_ error: Error) -> Bool {
        switch error {
        case APIError.unauthorized, APIError.notConfigured, APIError.httpStatus(403), APIError.businessCode(403): return true
        default: return false
        }
    }
    @discardableResult public func open(_ member: ProfileFollowListMember) -> ProfileFollowListSelection? {
        guard visible, foreground, isConfigured, !loading, error == nil, selection == nil,
              rows.contains(member), let reader else { return nil }
        let selected = ProfileFollowListSelection(memberID: member.id, scope: reader.scope)
        selection = selected; pendingReturnMemberID = member.id; returnAnchorMemberID = nil
        cancelRead(); return selected
    }
    public func owns(_ selected: ProfileFollowListSelection) -> Bool {
        isConfigured && selection == selected && reader?.scope == selected.scope
    }
    public func close(_ id: UUID) {
        guard selection?.id == id else { return }
        selection = nil
        if visible && foreground { cancelRead(); start(plan: refreshPlan) }
    }
    public func didRestoreReturnAnchor(_ memberID: Int) {
        guard returnAnchorMemberID == memberID else { return }
        returnAnchorMemberID = nil
    }
    public func memberReader(for selected: ProfileFollowListSelection) -> ProfilePublicInfoReader? {
        guard owns(selected), let reader else { return nil }
        return reader.makePublicProfileReader(memberID: selected.memberID, isCurrent: { [weak self] in self?.owns(selected) == true })
    }
}
