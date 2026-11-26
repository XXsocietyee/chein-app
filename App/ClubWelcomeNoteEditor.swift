import SwiftUI

@MainActor struct ClubWelcomeNoteEntry: View {
    @Environment(\.locale) private var locale
    let club: ClubRecord
    let identity: ClubReadIdentity?
    let access: any ClubOperationsAccess
    let enabled: Bool
    var onConfirmed: ((ClubWelcomeNoteConfirmedReturn) -> Void)? = nil
    @State private var visit: ClubWelcomeNoteVisit?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Section(locale.pick("入会欢迎语", "Welcome message")) {
            Text(verbatim: club.welcomeNote.flatMap { $0.isEmpty ? nil : $0 } ?? locale.pick("尚未设置欢迎语", "No welcome message set yet"))
            Button(locale.pick("编辑入会欢迎语", "Edit welcome message")) {
                guard visit == nil, scenePhase == .active, enabled, club.isOwner,
                      let identity, identity.isSignedIn, access.identity == identity else { return }
                visit = ClubWelcomeNoteVisit(clubID: club.id, identity: identity, access: access)
            }
            .disabled(!enabled || !club.isOwner || identity == nil || access.identity != identity)
            .accessibilityIdentifier("club.welcome.edit")
        }
        .cySheet(item: Binding(get: { visit }, set: { next in
            if next == nil { visit?.retire() }; visit = next
        })) { opened in
            NavigationStack {
                ClubWelcomeNoteEditor(visit: opened, saved: { _ in
                    guard scenePhase == .active, enabled, club.isOwner, visit?.id == opened.id,
                          opened.matches(clubID: club.id, identity: identity, access: access) else { return }
                    // APPLIED is a historical acknowledgement, never a replacement current value.
                    if let result = ClubWelcomeNoteConfirmedReturn(visit: opened, access: access) { onConfirmed?(result) }
                })
            }.id(opened.id)
        }
        .onChange(of: identity) { _, _ in retire() }
        .onChange(of: club.id) { _, _ in retire() }
        .onChange(of: club.isOwner) { _, owner in if !owner { retire() } }
        .onChange(of: ObjectIdentifier(access)) { _, _ in retire() }
        .onChange(of: access.welcomeNoteRevision) { _, _ in retire() }
        .onChange(of: access.welcomeNote.map(ObjectIdentifier.init)) { _, _ in retire() }
        .onChange(of: enabled) { _, value in if !value { retire() } }
        .onChange(of: scenePhase) { _, value in if value != .active { retire() } }
        .onDisappear { retire() }
    }
    private func retire() { visit?.retire(); visit = nil }
}

@MainActor struct ClubWelcomeNoteEditor: View {
    @Environment(\.locale) private var locale
    @StateObject private var flow: ClubWelcomeNoteFlow
    @ObservedObject private var visit: ClubWelcomeNoteVisit
    let saved: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirming = false
    init(visit: ClubWelcomeNoteVisit, saved: @escaping (String) -> Void) {
        self.visit = visit
        _flow = StateObject(wrappedValue: ClubWelcomeNoteFlow(clubID: visit.clubID, identity: visit.identity, access: visit.access))
        self.saved = saved
    }
    var body: some View {
        Form {
            Section {
                TextEditor(text: $flow.draft).frame(minHeight: 150)
                    .disabled(!visit.isCurrent || !flow.ownerConfirmed || flow.state == .saving || flow.state == .unknown || flow.state == .revoked)
                    .accessibilityIdentifier("club.welcome.text")
            } footer: {
                // The limit hint and the count sit in the section footer, like Settings text fields.
                VStack(alignment: .leading, spacing: 4) {
                    Text(locale.pick("新成员首次加入后会看到这段话。仅主理人可以修改；可清空，最多 200 个 Unicode 码点。", "New members see this message after joining. Only the owner can edit it; it can be cleared. Up to 200 characters."))
                    Text("\(flow.count) / 200").monospacedDigit().foregroundStyle(flow.count > 200 ? .red : .secondary)
                }
            }
            Button(locale.pick("清空文本", "Clear text"), role: .destructive) { flow.draft = "" }
                .disabled(!visit.isCurrent || !flow.ownerConfirmed || flow.state == .saving || flow.state == .unknown || flow.state == .revoked)
            Button(locale.pick("保存", "Save")) { guard visit.isCurrent, scenePhase == .active else { return }; confirming = true }.disabled(!flow.canSave || !visit.isCurrent)
                .accessibilityIdentifier("club.welcome.save")
            switch flow.state {
            case .loading, .saving: ProgressView()
            case .saved(let note):
                Section(locale.pick("本次原请求已确认", "Request confirmed")) {
                    Text(locale.pick("这是本次提交的历史结果，当前欢迎语由管理页重新读取。", "This is the result of this submission. The current welcome message is re-read on the management page."))
                    Text(verbatim: note.isEmpty ? locale.pick("当时已清空欢迎语", "The welcome message was cleared") : locale.pick("当时保存：", "Saved: ") + note)
                }
            case .unknown:
                Text(locale.pick("本次结果仍未确认。新协议沿原请求回执恢复；旧请求没有原身份，继续保留 UNKNOWN。当前文本相同也不是这次保存的凭据，不会自动重发。", "The result is still unconfirmed. Newer requests recover through their original receipt; older requests have no original identity and stay UNKNOWN. Matching text is not proof of this save, and nothing is resent automatically."))
                if let current = flow.currentNote { Text(verbatim: current.isEmpty ? locale.pick("当前回读：欢迎语为空", "Current read-back: welcome message is empty") : locale.pick("当前回读：", "Current read-back: ") + current) }
            case .revoked: Text(locale.pick("认证或主理人权限已失效；已转发的原请求仍保留保护锁，不会据错误码自动重发。", "Your sign-in or owner permission is no longer valid. The forwarded request stays locked and is not resent automatically."))
            case .notSent: Text(locale.pick("本次未确认发送；请刷新原资料、检查权限后再保存。", "This request was not confirmed as sent. Refresh the club profile, check your permissions, then save again."))
            case .rejected: Text(locale.pick("原接口拒绝了这次修改，欢迎语未按本次草稿确认保存。", "The service rejected this change. The welcome message was not saved from this draft."))
            case .unavailable: Text(locale.pick("当前无法确认主理人身份或读取欢迎语。", "Can't confirm your owner status or read the welcome message right now."))
            case .ready: EmptyView()
            }
            if flow.state != .loading && flow.state != .saving {
                Button(locale.pick("回读原请求并刷新当前欢迎语", "Read back original request and refresh")) { Task { await flow.load() } }
                    .accessibilityIdentifier("club.welcome.readback")
            }
            if flow.recoveryUnavailable { Text(locale.pick("原请求回执暂不可读；身份记录未删除，未重发保存。可从俱乐部详情的本人原请求入口继续回读。", "The original receipt can't be read right now. The record is kept and nothing was resent. You can continue from your original requests in club details.")).font(.subheadline).foregroundStyle(.secondary) }
            if visit.isCurrent, !flow.originalResults.isEmpty {
                Section(locale.pick("本人原请求 · 历史事实", "Your original requests · History")) { ForEach(flow.originalResults) { ClubWelcomeNoteOriginalRow(value: $0) } }
            }
            if flow.ownerConfirmed && !flow.canSave && flow.state == .ready { Text(locale.pick("内容未变或此接口尚未单独批准写入。只读不会授权保存。", "The text is unchanged, or this endpoint isn't approved for writes yet. Read access does not authorize saving.")).font(.subheadline).foregroundStyle(.secondary) }
        }
        .navigationTitle(locale.pick("入会欢迎语", "Welcome message")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(locale.pick("关闭", "Close")) { retire(); dismiss() } } }
        .confirmationDialog(appLocalized("club.welcome.title", locale: locale), isPresented: $confirming, titleVisibility: .visible) {
            let clearing = flow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(appLocalized(clearing ? "club.welcome.clear" : "club.welcome.save", locale: locale), role: clearing ? .destructive : nil) {
                confirming = false
                guard visit.isCurrent, scenePhase == .active else { return }
                Task {
                    await flow.save()
                    guard visit.isCurrent, scenePhase == .active, !Task.isCancelled else { return }
                    if case .saved(let note) = flow.state { saved(note) }
                }
            }
            Button(appLocalized("club.welcome.keep", locale: locale), role: .cancel) { confirming = false }
        } message: {
            Text(verbatim: appLocalized(flow.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "club.welcome.clearBody" : "club.welcome.saveBody", locale: locale))
        }
        .task { guard visit.isCurrent, scenePhase == .active else { return }; await flow.load() }
        .onDisappear { retire() }
        .onChange(of: visit.isCurrent) { _, current in if !current { retire(); dismiss() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { retire(); dismiss() } }
    }
    private func retire() { confirming = false; visit.retire(); flow.close() }
}


/// Mounted outside the mutable detail/manage gates: losing club ownership must not
/// strand the same account's original request. It never grants settings visibility/write.
@MainActor struct ClubWelcomeNoteRecoveryEntry: View {
    @Environment(\.locale) private var locale
    let clubID: Int
    let identity: ClubReadIdentity
    let access: any ClubOperationsAccess
    var body: some View {
        if identity.isSignedIn, access.identity == identity, let service = access.welcomeNote, service.hasOriginalRequests(clubID: clubID, identity: identity) {
            NavigationLink {
                ClubWelcomeNoteOriginalHistoryView(clubID: clubID, identity: identity, access: access)
            } label: { Label(locale.pick("本人欢迎语原请求", "Your welcome message requests"), systemImage: "clock.arrow.circlepath") }
                .accessibilityIdentifier("club.welcome.original.entry")
        }
    }
}
@MainActor private struct ClubWelcomeNoteOriginalHistoryView: View {
    @Environment(\.locale) private var locale
    let clubID: Int
    let identity: ClubReadIdentity
    let access: any ClubOperationsAccess
    @StateObject private var visit: ClubWelcomeNoteVisit
    init(clubID: Int, identity: ClubReadIdentity, access: any ClubOperationsAccess) {
        self.clubID = clubID; self.identity = identity; self.access = access
        _visit = StateObject(wrappedValue: ClubWelcomeNoteVisit(clubID: clubID, identity: identity, access: access))
    }
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ClubWelcomeNoteOriginalHistory] = []
    @State private var loadedIdentity: ClubReadIdentity?
    @State private var message: String?
    @State private var busy = false
    @State private var active = false
    @State private var generation = UUID()
    var body: some View {
        Form {
            Section { Text(locale.pick("这里只回读本人提交时绑定的原请求，不读取当前主理人的设置，不重发保存。已保存文本属于当时的历史事实；当前欢迎语可能已被后续修改。", "This only reads back requests you submitted. It doesn't read the current owner settings or resend anything. Saved text is a historical fact; the current welcome message may have changed since.")) }
            if busy { ProgressView(locale.pick("正在回读原请求", "Reading back original requests…")) }
            if let message { Text(verbatim: message) }
            if active, phase == .active, visit.isCurrent, visit.service?.canRecover(identity: identity) == true, loadedIdentity == identity {
                ForEach(rows) { ClubWelcomeNoteOriginalRow(value: $0) }
            }
            Button(locale.pick("只回读原请求", "Read back original requests only")) { Task { await load() } }.disabled(busy || phase != .active || !visit.isCurrent)
                .accessibilityIdentifier("club.welcome.original.recover")
        }
        .navigationTitle(locale.pick("欢迎语原请求", "Welcome message requests")).navigationBarTitleDisplayMode(.inline)
        .task { guard visit.isCurrent else { return }; active = true; await load() }
        .onDisappear { retire() }
        .onChange(of: identity) { _, _ in retire(); dismiss() }
        .onChange(of: ObjectIdentifier(access)) { _, _ in retire(); dismiss() }
        .onChange(of: access.welcomeNoteRevision) { _, _ in retire(); dismiss() }
        .onChange(of: access.welcomeNote.map(ObjectIdentifier.init)) { _, _ in retire(); dismiss() }
        .onChange(of: phase) { _, value in if value != .active { retire(); dismiss() } }
        .cyDomainScreen(.player)
    }
    private func retire() { visit.retire(); active = false; generation = UUID(); rows = []; loadedIdentity = nil; message = nil; busy = false }
    private func load() async {
        guard active, phase == .active, !busy, visit.isCurrent, let service = visit.service else { return }
        generation = UUID(); let ticket = generation
        rows = []; loadedIdentity = nil; message = nil; busy = true
        defer { if generation == ticket { busy = false } }
        do {
            let result = try await service.recoverOriginal(clubID: clubID, identity: identity,
                viewCurrent: { visit.isCurrent && active && generation == ticket && phase == .active })
            guard visit.isCurrent, active, generation == ticket, phase == .active, service.canRecover(identity: identity), !Task.isCancelled else { return }
            rows = result; loadedIdentity = identity
            if result.isEmpty { message = locale.pick("没有带原请求身份的记录。旧请求不根据当前文本补造回执。", "No records with an original request identity. Older requests are not given receipts based on current text.") }
        } catch {
            guard active, generation == ticket, phase == .active else { return }
            rows = []; loadedIdentity = nil
            message = locale.pick("原回执暂不可读或读取授权已失效；记录仍保留。请重新登录或恢复独立回读授权后继续，不会自动重发。", "The original receipt can't be read, or read authorization expired. The record is kept. Sign in again or restore read access to continue; nothing is resent automatically.")
        }
    }
}
private struct ClubWelcomeNoteOriginalRow: View {
    @Environment(\.locale) private var locale
    let value: ClubWelcomeNoteOriginalHistory
    @Environment(\.themeDomain) private var domain
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Generated.length("--cy-space-1-5", in: domain)) {
            Text(verbatim: value.entry.requestID).cyText(.meta).textSelection(.enabled)
            if let receipt = value.receipt, receipt.state == "APPLIED", let note = receipt.welcomeNote {
                Text(locale.pick("已保存 · 原请求回执确认", "Saved · confirmed by original receipt"))
                Text(verbatim: note.isEmpty ? locale.pick("当时已清空欢迎语", "The welcome message was cleared") : locale.pick("当时保存：", "Saved: ") + note)
                if let audit = receipt.auditId { Text(verbatim: locale.pick("原审计编号 \(audit)", "Original audit ID \(audit)")).cyText(.meta) }
            } else if let receipt = value.receipt, receipt.state == "REJECTED" {
                Text(locale.pick("原请求已拒绝 · 未保留本次设置变更", "Original request rejected · change not kept"))
                if let message = receipt.message { Text(verbatim: message) }
                if let audit = receipt.auditId { Text(verbatim: locale.pick("原审计编号 \(audit)", "Original audit ID \(audit)")).cyText(.meta) }
            } else if value.entry.state == "NOT_SENT" {
                Text(locale.pick("未转发到网络；这条请求没有重发。", "Not sent to the network; this request was not resent."))
            } else {
                Text(locale.pick("UNKNOWN · 保留原身份；不以当前文本推断保存结果。", "UNKNOWN · original identity kept; the save result is not inferred from current text."))
            }
        }
        .accessibilityIdentifier("club.welcome.original." + value.entry.requestID)
    }
}
