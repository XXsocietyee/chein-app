import SwiftUI

/// Host-owned capabilities. These only hide UI; the existing service still authorizes every request.
enum InvoiceLaunchUIAction: Hashable { case apply, saveTitle, deleteTitle, cancel }

/// A write the server refused (proven rollback) or left unconfirmed. The page keeps what it shows and states the
/// result in place, as the mini-program's `cy-inline-error` / toast do (X5, FIN-11-2, FIN-13-2, FIN-14-1, FIN-15-3).
struct InvoiceLaunchWriteNotice: Equatable {
    enum Kind: Equatable { case rejected, unknown, tooMany }
    let action: InvoiceLaunchUIAction
    let kind: Kind
    let code: String?
    /// Source `ORDER_CHANGED` (invoice-apply/index.js:7): the selection is stale, pick again.
    static let orderChangedCodes: Set<String> = ["INVOICE_ORDER_NOT_ELIGIBLE", "INVOICE_ORDER_ALREADY_INVOICED", "INVOICE_STATE_CONFLICT"]
    /// InvoiceLaunchUI key of the first line.
    var titleKey: String {
        switch (action, kind) {
        case (_, .tooMany): return "write.maxOrders"
        case (.apply, .unknown): return "write.apply.unknown"
        case (.apply, _): return "write.apply.failed"
        case (.saveTitle, .unknown): return "write.save.unknown"
        case (.saveTitle, _): return "write.save.failed"
        case (.deleteTitle, .unknown): return "write.delete.unknown"
        case (.deleteTitle, _): return "write.delete.failed"
        case (.cancel, .unknown): return "write.cancel.unknown"
        case (.cancel, _): return "write.cancel.failed"
        }
    }
    /// InvoiceLaunchUI key of the second line, when the code is one the source explains.
    var detailKey: String? {
        switch kind {
        case .tooMany: return nil
        case .unknown:
            switch action {
            case .apply: return "write.apply.unknown.sub"
            case .saveTitle: return "write.save.unknown.sub"
            case .deleteTitle, .cancel: return nil
            }
        case .rejected:
            guard let code else { return nil }
            if Self.orderChangedCodes.contains(code) { return "write.orderChanged" }
            switch code {
            case "INVOICE_TAX_NO_INVALID": return "taxInvalid"
            case "INVOICE_TITLE_LIMIT": return "write.titleLimit"
            case "INVOICE_TITLE_NOT_FOUND": return "write.titleNotFound"
            case "INVOICE_TITLE_NAME_INVALID", "INVOICE_TITLE_TYPE_INVALID", "INVOICE_ARGUMENT_INVALID": return "notSaved"
            case "INVOICE_FEATURE_OFF": return "unavailable"
            default: return nil
            }
        }
    }
    /// Apply rejections offer 重新选择 (source `reselect`); other writes offer nothing (the page is still there).
    var offersReselect: Bool { action == .apply && kind != .unknown }
}

@MainActor final class InvoiceLaunchPresentation: ObservableObject {
    let coordinator: InvoiceLaunchCoordinator
    private let isCurrent: () -> Bool
    private let permits: (InvoiceLaunchUIAction) -> Bool
    @Published private(set) var overview: InvoiceLaunchOverview?
    @Published private(set) var detail: InvoiceLaunchApplication?
    @Published private(set) var busy = false
    @Published private(set) var issue: String?
    @Published private(set) var unresolved = false
    /// Inline result of the last refused or unconfirmed write. The overview stays on screen (X5).
    @Published private(set) var writeNotice: InvoiceLaunchWriteNotice?
    /// A manual 查询结果 that still found nothing: source 暂未查到这次申请 · 再查一次 (FIN-11-4).
    @Published private(set) var recheckMissed = false
    @Published private(set) var identityRevision = UUID()
    private var generation: UUID { identityRevision }
    private var detailIntent = UUID()
    private var idleWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    private func wakeIdleWaiters() {
        let waiters = Array(idleWaiters.values)
        idleWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }
    private func finishOperation() {
        busy = false
        wakeIdleWaiters()
    }
    private func waitForDetailTurn(visit: UUID, intent: UUID) async {
        while busy && generation == visit && detailIntent == intent && !Task.isCancelled {
            let id = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    if Task.isCancelled { continuation.resume() }
                    else { idleWaiters[id] = continuation }
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.idleWaiters.removeValue(forKey: id)?.resume()
                }
            }
        }
    }

    init(coordinator: InvoiceLaunchCoordinator, isCurrent: @escaping () -> Bool,
         permits: @escaping (InvoiceLaunchUIAction) -> Bool = { _ in false }) {
        self.coordinator = coordinator; self.isCurrent = isCurrent; self.permits = permits
    }

    func allows(_ action: InvoiceLaunchUIAction) -> Bool {
        isCurrent() && permits(action) && overview != nil && !busy && !unresolved && issue == nil
    }

    /// The host calls this for account, realm, epoch, role or grant changes; it never clears the journal.
    func invalidate() {
        identityRevision = UUID(); detailIntent = UUID()
        wakeIdleWaiters()
        overview = nil; detail = nil; issue = nil; unresolved = false; writeNotice = nil; recheckMissed = false
        // An outstanding request retains serialization until its own defer runs.
    }

    func dismissWriteNotice() { writeNotice = nil }

    /// `manual` is the 查询结果 tap: a recovery that still cannot find the original shows 暂未查到这次申请.
    func refresh(manual: Bool = false) async {
        guard !busy else { return }
        guard isCurrent() else { invalidate(); issue = "session"; return }
        let visit = generation
        busy = true; issue = nil
        if writeNotice?.kind != .unknown { writeNotice = nil }
        defer { finishOperation() }
        do {
            // Recover before admitting another intent. Recovery is read-only and never resends a write.
            if try coordinator.store.load() != nil {
                do { _ = try await coordinator.recover(); recheckMissed = false; writeNotice = nil }
                catch {
                    guard accept(visit) else { return }
                    // A proven original-request miss keeps 暂未查到. A transport failure stays the unknown copy.
                    recheckMissed = manual && (error as? InvoiceLaunchIssue) == .notFound
                }
            } else { recheckMissed = false }
            let result = try await coordinator.overview()
            guard accept(visit) else { return }
            overview = result; unresolved = result.pending != nil
            if !unresolved, writeNotice?.kind == .unknown { writeNotice = nil }
        } catch { fail(error, visit: visit) }
    }

    func loadDetail(_ id: Int64) async {
        guard !Task.isCancelled else { return }
        guard isCurrent() else { invalidate(); issue = "session"; return }
        let visit = generation, intent = UUID()
        detailIntent = intent; detail = nil
        // A newer navigation retires queued reads but never overlaps an active operation.
        wakeIdleWaiters()
        await waitForDetailTurn(visit: visit, intent: intent)
        guard detailIntent == intent, generation == visit, !Task.isCancelled else { return }
        guard accept(visit) else { return }
        busy = true; issue = nil
        defer { finishOperation() }
        do {
            let result = try await coordinator.service.detail(id: id)
            guard detailIntent == intent, accept(visit) else { return }
            detail = result
        } catch {
            guard detailIntent == intent else { return }
            fail(error, visit: visit)
        }
    }

    func apply(titleID: Int64, orderIDs: [Int64]) async -> Bool {
        await perform(.apply) {
            let command = try InvoiceLaunchApply(titleId: titleID, orderIds: orderIDs)
            _ = try await self.coordinator.apply(command)
        }
    }
    func save(_ draft: InvoiceLaunchTitleDraft) async -> Bool {
        await perform(.saveTitle) { _ = try await self.coordinator.saveTitle(draft) }
    }
    func delete(_ id: Int64) async -> Bool {
        await perform(.deleteTitle) { try await self.coordinator.deleteTitle(id: id) }
    }
    func cancel(_ id: Int64) async -> Bool {
        await perform(.cancel) { _ = try await self.coordinator.cancel(id: id) }
    }

    private func perform(_ action: InvoiceLaunchUIAction, operation: () async throws -> Void) async -> Bool {
        guard allows(action) else { return false }
        let visit = generation
        busy = true; issue = nil; writeNotice = nil
        defer { finishOperation() }
        do {
            // The coordinator persists the original request before sending. No UI retry creates a second intent.
            try await operation()
            guard accept(visit) else { return false }
            detail = nil
            do {
                let result = try await coordinator.overview()
                guard accept(visit) else { return false }
                overview = result; unresolved = result.pending != nil
            } catch { fail(error, visit: visit) }
            // The mutation was confirmed even if refreshing the list subsequently failed.
            return generation == visit && isCurrent()
        } catch { await failWrite(error, action: action, visit: visit); return false }
    }

    /// A refused or unconfirmed write keeps the page: last overview stays, the list is re-read in place, and the
    /// result is stated inline. Session, switch and storage failures still take the page-level path.
    private func failWrite(_ error: Error, action: InvoiceLaunchUIAction, visit: UUID) async {
        guard accept(visit) else { return }
        let kind: InvoiceLaunchWriteNotice.Kind
        var code: String?
        switch error as? InvoiceLaunchIssue {
        case .rejected(let value)?:
            code = value; kind = value == "INVOICE_ORDERS_TOO_MANY" ? .tooMany : .rejected
        case .invalid?: kind = .rejected
        case .outcomeUnknown?, .pendingConflict?, .originalReadUnavailable?, .notFound?: kind = .unknown
        default: fail(error, visit: visit); return
        }
        guard overview != nil else { fail(error, visit: visit); return }
        writeNotice = InvoiceLaunchWriteNotice(action: action, kind: kind, code: code)
        unresolved = kind == .unknown || journalPending()
        // Source reloads eligible orders after a refused apply; a failed re-read keeps the last list.
        if let result = try? await coordinator.overview(), accept(visit) {
            overview = result; unresolved = unresolved || result.pending != nil
        }
    }
    private func journalPending() -> Bool {
        do { return try coordinator.store.load() != nil } catch { return true }
    }

    private func accept(_ visit: UUID) -> Bool {
        guard generation == visit, isCurrent() else {
            if generation == visit { invalidate(); issue = "session" }
            return false
        }
        // Cancellation belongs to this view task, not to the retained account
        // presentation. Discard its result without retiring a newer queued detail.
        return !Task.isCancelled
    }
    private func fail(_ error: Error, visit: UUID) {
        guard accept(visit) else { return }
        // A plain read failure keeps the last list on screen with an inline retry (X5); anything else clears it.
        let shown = overview
        overview = nil; detail = nil
        do { unresolved = try coordinator.store.load() != nil }
        catch { unresolved = true }
        switch error as? InvoiceLaunchIssue {
        case .staleSession, .unauthorized: invalidate(); issue = "session"
        case .disabled: issue = "unavailable"
        case .outcomeUnknown, .originalReadUnavailable, .pendingConflict, .notFound: unresolved = true; issue = "unknown"
        case .storageUnavailable: unresolved = true; issue = "storage"
        case .invalid, .rejected: issue = "notSaved"
        default: issue = "loadFailed"; overview = shown
        }
    }
}

func invoiceText(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "InvoiceLaunchUI") }
func invoiceAmount(_ value: Decimal, locale: Locale) -> String {
    let formatter = NumberFormatter(); formatter.locale = locale; formatter.numberStyle = .decimal
    // Owner decision 9: the shared money rule (`MoneyDisplay`, two decimals).
    formatter.minimumFractionDigits = MoneyDisplay.minimumFractionDigits(); formatter.maximumFractionDigits = MoneyDisplay.maximumFractionDigits
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—"
}
/// Known money stays the two-place formatter, including 0.00. A non-finite amount is the page-model em dash.
func invoiceLaunchDisplayedAmount(_ value: Decimal, locale: Locale) -> String {
    let amount = InvoiceLaunchApplyAmount.from(value)
    if amount.literal == nil { return amount.displayText }
    return invoiceAmount(value, locale: locale)
}
/// Source base.js `timeText`: 「10月27日 10:30」. A server wall-clock string keeps its clock; unparseable text is shown as is.
func invoiceTime(_ time: InvoiceLaunchTime?, locale: Locale) -> String {
    let date: Date
    switch time {
    case .text(let value):
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX")
        var parsed: Date?
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm"] where parsed == nil {
            parser.dateFormat = format
            parsed = parser.date(from: String(trimmed.prefix(format.replacingOccurrences(of: "'", with: "").count)))
        }
        guard let parsed else { return trimmed }
        date = parsed
    case .epochMilliseconds(let value):
        date = Date(timeIntervalSince1970: Double(value) / 1000)
    case nil: return "—"
    }
    let formatter = DateFormatter(); formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate("MMMdHHmm")
    return formatter.string(from: date)
}
/// Source base.js `titleLine`: 单位/个人 · 部分税号 · 默认.
func invoiceTitleLine(_ title: InvoiceLaunchTitle) -> String {
    let type = title.titleType == "COMPANY" || title.titleType == "PERSONAL" ? invoiceString(title.titleType) : ""
    return [type, title.taxNoMasked ?? "", title.isDefault ? invoiceString("defaultShort") : ""]
        .filter { !$0.isEmpty }.joined(separator: " · ")
}

@MainActor struct InvoiceLaunchStateSection: View {
    @ObservedObject var model: InvoiceLaunchPresentation
    var retry: (() async -> Void)? = nil
    /// Source signed-out state title per page (登录后查看发票 / 登录后申请开票 / 登录后管理发票抬头).
    var sessionTitle: LocalizedStringKey = "u9cde.invoice.login.view"
    /// Source 微信登录 CTA. Nil hides the button (the host has no sign-in entry here).
    var onSignIn: (() -> Void)? = nil
    /// Page-level load-failure title (source 发票记录加载失败 / 发票申请加载失败 / 开票信息加载失败 / 发票抬头加载失败).
    var loadFailedKey: String = "loadFailed"
    var body: some View {
        if model.unresolved {
            Section {
                // Source cy-inline-error: 上次的开票申请结果未确认 · 确认前请勿重复提交 · 查询结果,
                // and after a miss 暂未查到这次申请 · 请稍后再查，或联系客服 · 再查一次 (FIN-11-4, FIN-11-6).
                // R7-MEM-14-1: an unconfirmed title save reads 上次保存结果未确认 · 确认前请勿修改抬头 (MP invoice-titles).
                let savingTitle = model.overview?.pending?.kind == .saveTitle
                // MP invoice-titles: a missed title recheck reads 暂未查到这次保存 and keeps 确认前请勿修改抬头 · 查询结果.
                let key = savingTitle
                    ? (model.recheckMissed ? "titleSave.notFound" : "titleSave.unknown")
                    : (model.recheckMissed ? "notFound" : "unknown")
                let subKey = savingTitle ? "titleSave.unknown.sub" : key + ".sub"
                VStack(alignment: .leading, spacing: 4) {
                    Label { invoiceText(key) } icon: { Image(systemName: "clock.badge.questionmark").foregroundStyle(.orange) }
                        .font(.body)
                    invoiceText(subKey)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine).accessibilityIdentifier("invoice.pending")
                Button { Task { await model.refresh(manual: true) } } label: {
                    Text(model.recheckMissed && !savingTitle ? "recheck" : "checkResult", tableName: "InvoiceLaunchUI")
                }
                    .disabled(model.busy).accessibilityIdentifier("invoice.recover")
            }
        }
        if model.issue == "session" {
            // Source cy-empty kind="no-permission": lock icon, the page's 登录后… title and 微信登录 (FIN-11-7).
            ContentUnavailableView {
                Label { Text(sessionTitle) } icon: { Image(systemName: "lock") }
            } description: { invoiceText("session") } actions: {
                if let onSignIn {
                    Button(action: onSignIn) { Text("auth.wechat.signIn") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("invoice.signIn")
                }
            }
                .accessibilityIdentifier("invoice.signedOut")
        } else if model.issue == "unavailable" {
            // Source 发票功能暂未开放 has no retry: a retry cannot turn the switch on (FIN-11-7).
            ContentUnavailableView {
                Label { invoiceText("unavailable") } icon: { Image(systemName: "lock") }
            }
                .accessibilityIdentifier("invoice.unavailable")
        } else if model.issue == "loadFailed", model.overview != nil {
            // The last list stays; the failed refresh is stated in place with a retry (X5).
            Section {
                Label { Text(verbatim: invoiceString(loadFailedKey)) } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                Button("cy.state.offline.retry") { Task { if let retry { await retry() } else { await model.refresh() } } }
            }
        } else if let issue = model.issue {
            ContentUnavailableView {
                Label { invoiceText(issue == "loadFailed" ? loadFailedKey : issue) } icon: { Image(systemName: "exclamationmark.circle") }
            } actions: {
                Button { Task { if let retry { await retry() } else { await model.refresh() } } } label: { Text("retry", tableName: "InvoiceLaunchUI") }
                    .buttonStyle(.bordered).controlSize(.large)
                    .disabled(model.busy)
            }
        } else if model.busy && model.overview == nil {
            Section {
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(invoiceText("loading"))
            }
        }
    }
}

/// In-place result of a refused or unconfirmed write (source `cy-inline-error` in the footer / toast). The page keeps its content.
@MainActor struct InvoiceLaunchWriteNoticeView: View {
    let notice: InvoiceLaunchWriteNotice
    var onReselect: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label { invoiceText(notice.titleKey) } icon: {
                Image(systemName: notice.kind == .unknown ? "clock.badge.questionmark" : "exclamationmark.circle.fill")
                    .foregroundStyle(notice.kind == .unknown ? Color.secondary : Color.red)
            }
            .font(.body)
            if let detail = notice.detailKey {
                invoiceText(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if notice.offersReselect, let onReselect {
                Button(action: onReselect) { Text("reselect", tableName: "InvoiceLaunchUI") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("invoice.reselect")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("invoice.writeNotice")
    }
}

/// Pure list rules for 我的发票 (subpackageMember/invoice). No I/O and no money math.
enum InvoiceLaunchHistoryRules {
    /// Filter chips in source order: 全部 / 处理中 / 已开具 / 已驳回 / 已撤回.
    static let filterKeys = ["all", "SUBMITTED", "ISSUED", "REJECTED", "CANCELLED"]

    static func rows(_ applications: [InvoiceLaunchApplication], filter: String) -> [InvoiceLaunchApplication] {
        guard filter != "all" else { return applications }
        return applications.filter { $0.status.filterKey == filter }
    }

    /// Source shows 撤回申请 on SUBMITTED rows only; the service still authorizes the request.
    static func canWithdraw(_ status: InvoiceLaunchStatus) -> Bool { status == .submitted }

    /// Localization key for the empty state: no applications at all vs. an empty filter.
    static func emptyKey(total: Int, filter: String) -> String {
        total == 0 || filter == "all" ? "empty" : "emptyFiltered"
    }
}

/// Confirm-then-act state for the row-level withdraw. A success notice exists only
/// after the injected service reported success; failure never produces one.
struct InvoiceLaunchWithdrawFlow: Equatable {
    private(set) var confirming: Int64?
    private(set) var succeeded: Int64?

    mutating func ask(_ id: Int64) { confirming = id; succeeded = nil }
    mutating func cancelAsk() { confirming = nil }
    /// Returns the id to send, or nil when nothing is awaiting confirmation.
    mutating func confirm() -> Int64? {
        defer { confirming = nil }
        return confirming
    }
    mutating func finish(id: Int64, success: Bool) { succeeded = success ? id : nil }
    mutating func dismissNotice() { succeeded = nil }
}

/// Resolved label for chips (status keys live in the InvoiceLaunchUI table).
/// Follows the in-app language choice like `MerchantOpsCopy` (FIN-11 copy is shown as verbatim titles and chips, so a
/// plain `String(localized:)` read the system language: "My invoices" under a 中文 app).
func invoiceString(_ key: String) -> String {
    if let active = AppLanguageRuntime.active, active != .system,
       let path = Bundle.main.path(forResource: active.rawValue, ofType: "lproj"), let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: nil, table: "InvoiceLaunchUI")
    }
    return String(localized: String.LocalizationValue(key), table: "InvoiceLaunchUI")
}
extension InvoiceLaunchStatus {
    var chipTone: CYStatusTone {
        switch playerState { case .issued: return .success; case .rejected: return .danger; case .paused: return .warning
        case .cancelled: return .neutral; case .issuing: return .info }
    }
    /// Native r2: the tint of the status symbol (a `Label` replaces the chip).
    var chipTint: Color {
        switch playerState { case .issued: return .green; case .rejected: return .red; case .paused: return .orange
        case .cancelled: return .secondary; case .issuing: return .blue }
    }
    var chipSymbol: String {
        switch playerState { case .issued: return "checkmark.circle"; case .rejected: return "xmark.circle"; case .paused: return "pause.circle"
        case .cancelled: return "arrow.uturn.backward.circle"; case .issuing: return "clock" }
    }
}
