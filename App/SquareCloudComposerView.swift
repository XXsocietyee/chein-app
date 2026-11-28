import SwiftUI

/// `cy/post-compose` and `cy/post-drafts` on one sheet. Drafts and activity lists are pushes, not a second sheet.
@MainActor struct SquareCloudComposerView: View {
    let coordinator: SocialActionCoordinator
    var offline = false
    var prefill = ""
    var nickname: String?
    var clubID: String? = nil
    var canAnnounce = false
    var allowsImages = false
    var allowsLocation = false
    var joinedHosted: () async -> SquareCloudRead<SquareComposeActivityOption> = { .permission }
    var completed: () async -> SquareCloudRead<SquareCompletedActivity> = { .permission }
    var editingPost: SquarePost? = nil
    var onClose: () -> Void
    @Environment(\.locale) private var locale
    @State private var path: [SquareCloudComposerRoute] = []
    @State private var contents = ""
    @State private var address = ""
    @State private var selectedActivity: SquareComposeActivityOption?
    @State private var asAnnouncement = false
    @State private var notice: String?
    @State private var lock = SquareComposeLock()
    @State private var review: SocialActionReview?
    @State private var preparing = false
    @State private var openedMember: String?
    @State private var drafts: [SquareCloudDraftRow] = []
    @State private var draftsLoading = false
    @State private var undo: SquareCloudDraftUndo?

    private var editing: Bool { editingPost != nil }
    private var memberID: String? {
        guard let id = coordinator.identity.accountID, id > 0 else { return nil }
        return String(id)
    }
    private var screenTitle: String {
        switch path.last {
        case .drafts: return copy("草稿", "Drafts")
        case .activities: return copy("选择活动", "Choose an activity")
        case .completed: return copy("选择已完成的活动", "Choose a cleared activity")
        case .review: return copy("确认发布", "Confirm publish")
        case nil: return editing ? copy("编辑帖文", "Edit post") : copy("新建帖文", "New post")
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationTitle(Text(verbatim: screenTitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbar { toolbar }
                .navigationDestination(for: SquareCloudComposerRoute.self) { route in
                    destination(route)
                        .navigationTitle(Text(verbatim: screenTitle))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.visible, for: .navigationBar)
                }
        }
        .onAppear(perform: open)
        .onChange(of: coordinator.identity) { _, _ in identityChanged() }
        .onDisappear {
            persist()
            if lock.phase != .sending && lock.phase != .unknown { releaseReview() }
        }
        .cyHaptic(.success, trigger: lock.phase, where: Self.becameReceipt)
        .cyHaptic(.warning, trigger: lock.phase, where: Self.becameRejected)
        .accessibilityIdentifier("square.cloud.composer")
        .cyDomainScreen(.player)
    }

    /// Haptics follow the server-confirmed send result only (sending / unknown → receipt or rejected), never a restore.
    private static func becameReceipt(_ old: SquareComposeLock.Phase, _ new: SquareComposeLock.Phase) -> Bool {
        new == .receipt && (old == .sending || old == .unknown)
    }
    private static func becameRejected(_ old: SquareComposeLock.Phase, _ new: SquareComposeLock.Phase) -> Bool {
        new == .rejected && (old == .sending || old == .unknown)
    }

    private var showsEditor: Bool {
        memberID != nil && !(offline || coordinator.availability == .syntheticOnly) && coordinator.availability == .approved
    }

    @ViewBuilder private var root: some View {
        if memberID == nil {
            status(copy("登录后才能发帖", "Sign in to publish"), copy("这一页不会替你发出去", "This screen will not send a post for you"), symbol: "person.crop.circle.badge.questionmark").accessibilityIdentifier("square.cloud.permission")
        } else if offline || coordinator.availability == .syntheticOnly {
            status(copy("你离线了", "You're offline"), copy("离线示例不会提交广场帖", "The offline example does not submit a square post"), symbol: "wifi.slash").accessibilityIdentifier("square.cloud.offline")
        } else if coordinator.availability != .approved {
            status(copy("当前账号未开放广场发布", "Square publishing is not open for this account"), copy("没有可用的发布通道", "No publish channel is available"), symbol: "lock").accessibilityIdentifier("square.cloud.permission")
        } else {
            editor
        }
    }

    private var editor: some View {
        Form {
            Section {
                TextField(text: $contents, prompt: Text(verbatim: copy("有什么新鲜好玩的分享吗？", "Share something new?")), axis: .vertical) {
                    Text(verbatim: copy("帖文内容", "Post text"))
                }
                .lineLimit(6, reservesSpace: true)
                .disabled(lock.locksComposer)
                .accessibilityIdentifier("square.cloud.text")
            } header: {
                Label { Text(verbatim: displayName) } icon: { Image(systemName: "person.crop.circle.fill") }
                    .accessibilityIdentifier("square.cloud.author")
            } footer: {
                Text(verbatim: "\(contents.count)/\(SquareComposeRules.maxLength)")
                    .monospacedDigit().accessibilityLabel(Text("a11y.value.characters \(Int(contents.count)) \(Int(SquareComposeRules.maxLength))"))
                    .accessibilityIdentifier("square.cloud.count")
            }
            if let text = notice {
                Section {
                    Label { Text(verbatim: text) } icon: { Image(systemName: "info.circle") }
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("square.cloud.notice")
                }
            }
            previews
            tools
        }
        .onChange(of: contents) { _, value in
            if value.count > SquareComposeRules.maxLength { contents = SquareComposeRules.clip(value) }
        }
    }

    @ViewBuilder private var previews: some View {
        if !address.isEmpty || selectedActivity != nil {
            Section {
                if !address.isEmpty {
                    chip(address, "mappin") { address = "" }.accessibilityIdentifier("square.cloud.address")
                }
                if let activity = selectedActivity {
                    chip(activity.name, "flag") { selectedActivity = nil }.accessibilityIdentifier("square.cloud.activityChip")
                }
            }
        }
    }

    private func chip(_ title: String, _ symbol: String, clear: @escaping () -> Void) -> some View {
        HStack {
            Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
            Spacer(minLength: 0)
            Button(action: clear) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle()) }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: copy("清除", "Clear")))
        }
    }

    private var tools: some View {
        Section {
            if !editing && allowsImages {
                tool("photo", copy("添加图片", "Add photo")) {
                    notice = copy("图片这一版不会随帖子提交", "Photos are not sent with the post in this version")
                }
                .accessibilityIdentifier("square.cloud.tool.photo")
            }
            if !editing && allowsLocation && clubID == nil {
                tool("mappin", copy("添加地点", "Add place")) {
                    notice = copy("地点这一版还不能提交", "A place cannot be submitted in this version")
                }
                .accessibilityIdentifier("square.cloud.tool.place")
            }
            if !editing && clubID == nil {
                tool("flag", copy("选择活动", "Choose activity")) { path.append(.activities) }.accessibilityIdentifier("square.cloud.tool.activity")
            }
            if !editing && clubID != nil {
                tool("point.topleft.down.to.point.bottomright.curvepath", copy("带上一次游玩记录", "Attach a play record")) {
                    notice = copy("游玩记录由俱乐部页选择", "The club page picks the play record")
                }
                .accessibilityIdentifier("square.cloud.tool.play")
            }
            if canAnnounce && clubID != nil && !editing {
                Toggle(isOn: $asAnnouncement) {
                    Text(verbatim: copy("作为公告发布", "Post as an announcement"))
                }
                .accessibilityIdentifier("square.cloud.announce")
            }
        }
    }

    private func tool(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(verbatim: label) } icon: { Image(systemName: symbol) }
        }
    }

    /// Mail-style send: the primary action sits in the navigation bar, the counter in the text section footer.
    @ViewBuilder private var submitAction: some View {
        if lock.phase == .unknown {
            Button(action: confirmResult) { Text(verbatim: copy("确认结果", "Check result")) }
                .accessibilityIdentifier("square.cloud.confirmResult")
        } else if lock.phase == .receipt {
            Button(action: onClose) { Text(verbatim: copy("关闭", "Close")) }
                .accessibilityIdentifier("square.cloud.receiptClose")
        } else {
            Button(action: beginPublish) {
                Text(verbatim: editing ? copy("保存", "Save") : copy("发布", "Publish"))
            }
            .disabled(!canSubmit || lock.phase == .sending || preparing)
            .accessibilityIdentifier("square.cloud.publish")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: cancel) {
                Text(verbatim: path.isEmpty ? copy("取消", "Cancel") : copy("关闭", "Close"))
            }
            .accessibilityLabel(Text(verbatim: path.isEmpty ? copy("取消并关闭", "Cancel and close") : copy("关闭", "Close")))
            .accessibilityIdentifier("square.cloud.cancel")
        }
        if !editing && path.isEmpty && memberID != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button { openDrafts() } label: { Image(systemName: "doc.text") }
                    .accessibilityLabel(Text(verbatim: copy("草稿箱", "Drafts")))
                    .accessibilityIdentifier("square.cloud.drafts")
            }
        }
        if showsEditor && path.isEmpty {
            ToolbarItem(placement: .confirmationAction) { submitAction }
        }
    }

    @ViewBuilder private func destination(_ route: SquareCloudComposerRoute) -> some View {
        switch route {
        case .drafts: draftsPage
        case .activities:
            SquareCloudJoinedActivityList(load: joinedHosted, onSelect: { item in
                selectedActivity = item
                path.removeAll()
            }, onCompleted: { path.append(.completed) }, onClose: { if !path.isEmpty { path.removeLast() } })
        case .completed:
            SquareCloudCompletedActivityPicker(load: completed, onSelect: { item, _ in
                selectedActivity = SquareComposeActivityOption(activityID: item.activityID, name: item.name, sourceLabel: copy("已通关", "Cleared"))
                notice = copy("没有路线预览图，只记下活动名字。这一版还不能把活动写进帖子。", "No route preview was made. Only the name is kept, and this version still cannot save the activity on the post.")
                path.removeAll()
            }, onClose: { if !path.isEmpty { path.removeLast() } })
        case .review: reviewPage
        }
    }

    private var draftsPage: some View {
        List {
            if draftsLoading {
                ProgressView { Text(verbatim: copy("正在读取草稿", "Loading drafts")) }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("square.cloud.drafts.loading")
            } else if drafts.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: copy("还没有草稿", "No drafts yet")).accessibilityIdentifier("square.cloud.drafts.empty")
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                } description: {
                    Text(verbatim: copy("写到一半退出时会自动存成草稿，回到这里就能接着写。", "Leaving mid-write keeps a draft. Come back and continue."))
                }
            } else {
                Section {
                    ForEach(drafts) { row in
                        Button { pick(row) } label: {
                            VStack(alignment: .leading) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(verbatim: row.nickname).font(.headline).foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    Text(verbatim: row.date).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(verbatim: row.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .accessibilityLabel(Text(verbatim: copy("继续编辑这条草稿", "Continue this draft")))
                        .accessibilityIdentifier("square.cloud.draft.row")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(row) } label: {
                                Label { Text(verbatim: copy("删除这条草稿", "Delete this draft")) } icon: { Image(systemName: "trash") }
                            }
                            .accessibilityIdentifier("square.cloud.draft.delete")
                        }
                        .contextMenu {
                            Button(role: .destructive) { delete(row) } label: {
                                Label { Text(verbatim: copy("删除这条草稿", "Delete this draft")) } icon: { Image(systemName: "trash") }
                            }
                        }
                    }
                } footer: {
                    Text(verbatim: copy("只有 \(drafts.count) 条草稿", "Only \(drafts.count) drafts"))
                        .accessibilityIdentifier("square.cloud.drafts.count")
                }
            }
            if let pending = undo {
                Section {
                    HStack {
                        Text(verbatim: copy("草稿已删除", "Draft deleted"))
                        Spacer(minLength: 0)
                        Button { restore(pending) } label: { Text(verbatim: copy("撤销", "Undo")) }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("square.cloud.draft.undo")
                    }
                    .accessibilityIdentifier("square.cloud.draft.undoBar")
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("square.cloud.drafts.page")
    }

    private var reviewPage: some View {
        Form {
            Section {
                Text(verbatim: contents).textSelection(.enabled)
            } footer: {
                if let activity = selectedActivity {
                    Text(verbatim: copy("活动「\(activity.name)」不会写入这次提交", "Activity “\(activity.name)” is not part of this submit"))
                }
            }
            Section {
                if lock.phase == .unknown {
                    Text(verbatim: copy("结果还没核对。请求号 \(lock.requestID ?? SquareCountDisplay.unknownMark)", "The result is still unchecked. Request \(lock.requestID ?? SquareCountDisplay.unknownMark)"))
                        .accessibilityIdentifier("square.cloud.unknown")
                    Button(action: confirmResult) { Text(verbatim: copy("确认结果", "Check result")) }
                        .accessibilityIdentifier("square.cloud.confirmResult")
                } else if lock.phase == .receipt {
                    Text(verbatim: copy("已收到提交回执。刷新广场核对。这张回执不是新帖子的编号。", "A submit receipt arrived. Refresh the square to check it. The receipt is not a new post id."))
                        .accessibilityIdentifier("square.cloud.receipt")
                    Button(action: onClose) { Text(verbatim: copy("关闭", "Close")) }
                        .accessibilityIdentifier("square.cloud.receiptClose")
                } else if lock.phase == .rejected {
                    Label { Text(verbatim: copy("没有发出去", "It was not sent")) } icon: { Image(systemName: "exclamationmark.triangle") }
                        .accessibilityIdentifier("square.cloud.rejected")
                } else if preparing || lock.phase == .sending {
                    ProgressView { Text(verbatim: copy("正在提交", "Submitting")) }
                        .accessibilityIdentifier("square.cloud.submitting")
                } else {
                    Button { Task { await submit() } } label: {
                        Text(verbatim: editing ? copy("保存", "Save") : copy("发布", "Publish"))
                    }
                    .disabled(review == nil)
                    .accessibilityIdentifier("square.cloud.reviewPublish")
                }
            } footer: {
                if let text = notice { Text(verbatim: text) }
            }
        }
        .task { await prepareReview() }
        .accessibilityIdentifier("square.cloud.review")
    }

    private var displayName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? copy("城瘾玩家", "Chein player") : trimmed
    }

    private var canSubmit: Bool {
        SquareComposeRules.submittable(text: contents, pictureCount: 0, club: clubID != nil, editing: editing)
    }

    private func status(_ title: String, _ detail: String, symbol: String) -> some View {
        ContentUnavailableView {
            Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
        } description: {
            Text(verbatim: detail)
        }
    }

    private func open() {
        openedMember = memberID
        if let editingPost { contents = editingPost.contents ?? ""; return }
        if let memberID, let pending = SquareCloudDraftDisk.pending(memberID: memberID), pending.phase == .unknown || pending.phase == .sending {
            lock = SquareComposeLock(requestID: pending.requestID, phase: .unknown)
        }
        guard lock.phase != .unknown else { restoreDraft(); return }
        if !prefill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { contents = SquareComposeRules.clip(prefill); return }
        restoreDraft()
    }

    private func restoreDraft() {
        guard let memberID, let topic = SquareComposeRules.topicID(memberID: memberID, clubID: clubID) else { return }
        if case .ready(let text) = SquareComposeDraftRules.load(SquareCloudDraftDisk.load(topicID: topic), memberID: memberID) {
            contents = SquareComposeRules.clip(text)
        }
    }

    private func identityChanged() {
        guard openedMember != memberID else { return }
        if lock.phase != .sending && lock.phase != .unknown { releaseReview() }
        persist()
        notice = copy("登录身份已变化，请重新打开编辑器", "The signed-in account changed. Open the editor again.")
        onClose()
    }

    private func cancel() {
        if path.isEmpty { releaseReview(); persist(); onClose() } else { path.removeLast() }
    }

    private func releaseReview() {
        if let review { coordinator.cancel(review) }
    }

    private func beginPublish() {
        notice = nil
        let text = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SquareComposeRules.submittable(text: text, pictureCount: 0, club: clubID != nil, editing: editing) else {
            notice = clubID == nil ? copy("请输入内容", "Write something first") : copy("说点什么，或加张图", "Write something, or add a photo")
            return
        }
        if clubID != nil {
            notice = copy("俱乐部帖走俱乐部的确认页", "Club posts use the club confirm screen")
            return
        }
        if selectedActivity != nil {
            notice = copy("活动关联这一版发不出去。清掉活动后再发正文。", "This version cannot attach an activity. Clear it, then publish the text.")
            return
        }
        if lock.phase == .unknown || coordinator.state(target: editingTarget).locksForm {
            lock.phase = .unknown
            notice = copy("上次结果还没核对，不能再发一条。", "The last result is still unchecked, so nothing new is sent.")
            return
        }
        path.append(.review)
    }

    private var editingTarget: SocialActionTarget {
        if let editingPost { return .post(editingPost.id) }
        return .newPost
    }

    private func prepareReview() async {
        guard review == nil, !preparing, lock.phase != .unknown, lock.phase != .receipt else { return }
        let identity = coordinator.identity
        preparing = true
        defer { preparing = false }
        let command: SocialActionCommand
        if editing { command = .editPost(text: contents) }
        else {
            requestIfNeeded()
            command = .createPost(text: contents, requestID: lock.requestID ?? UUID().uuidString)
        }
        do {
            let value = try await coordinator.prepare(command, target: editingTarget, ownerID: UUID(), expectedIdentity: identity)
            guard coordinator.identity == identity else { coordinator.cancel(value); return }
            review = value
        } catch {
            notice = copy("还不能提交", "It cannot be submitted yet")
            review = nil
        }
    }

    private func requestIfNeeded() {
        if lock.requestID == nil { lock = SquareComposeLock(requestID: UUID().uuidString, phase: .idle) }
    }

    private func submit() async {
        guard let review, !lock.locksComposer else { return }
        let identity = coordinator.identity
        if !editing { requestIfNeeded() }
        lock.phase = .sending
        if let memberID, let id = lock.requestID { SquareCloudDraftDisk.savePending(memberID: memberID, requestID: id, phase: .sending) }
        await coordinator.confirm(review)
        guard coordinator.identity == identity else { lock.phase = .unknown; storePending(); return }
        switch coordinator.state(target: editingTarget) {
        case .acknowledged:
            lock.phase = .receipt
            if let memberID { SquareCloudDraftDisk.clearPending(memberID: memberID) }
            clearDraft()
        case .rejected, .notSent:
            lock = SquareComposeLock(requestID: UUID().uuidString, phase: .rejected)
            self.review = nil
            if let memberID { SquareCloudDraftDisk.clearPending(memberID: memberID) }
            notice = copy("没有发出去", "It was not sent")
        default:
            lock.phase = .unknown
            storePending()
            notice = copy("结果未知，先核对这一次，不要重发。", "The result is unknown. Check this one. Do not send it again.")
        }
    }

    private func confirmResult() {
        let observed: SquareComposeLock.Phase
        switch coordinator.state(target: editingTarget) {
        case .acknowledged: observed = .receipt
        case .rejected, .notSent: observed = .rejected
        case .outcomeUnknown, .submitting: observed = .unknown
        default: observed = .idle
        }
        let saved = lock.requestID ?? SquareCloudDraftDisk.pending(memberID: memberID ?? "")?.requestID
        lock = SquareComposeLock(requestID: saved, phase: .unknown).confirmResult(currentRequestID: saved, observed: observed)
        if lock.phase == .receipt {
            if let memberID { SquareCloudDraftDisk.clearPending(memberID: memberID) }
            clearDraft()
        } else if lock.phase == .unknown {
            notice = copy("核对后仍未知。请求号 \(saved ?? SquareCountDisplay.unknownMark)", "Still unknown after the check. Request \(saved ?? SquareCountDisplay.unknownMark)")
        }
    }

    private func storePending() {
        guard let memberID, let id = lock.requestID else { return }
        SquareCloudDraftDisk.savePending(memberID: memberID, requestID: id, phase: .unknown)
    }

    private func openDrafts() {
        draftsLoading = true
        path.append(.drafts)
        drafts = readDrafts()
        draftsLoading = false
    }

    private func readDrafts() -> [SquareCloudDraftRow] {
        guard let memberID, let topic = SquareComposeRules.topicID(memberID: memberID, clubID: clubID),
              case .ready(let text) = SquareComposeDraftRules.load(SquareCloudDraftDisk.load(topicID: topic), memberID: memberID) else { return [] }
        let saved = SquareCloudDraftDisk.load(topicID: topic)?.savedAt ?? Date()
        return [SquareCloudDraftRow(key: topic, nickname: displayName, date: SquareComposeRules.chinaMonthDay(saved), summary: text)]
    }

    private func pick(_ row: SquareCloudDraftRow) {
        guard let memberID, case .ready(let text) = SquareComposeDraftRules.load(SquareCloudDraftDisk.load(topicID: row.key), memberID: memberID) else {
            notice = copy("这条草稿无法打开了", "This draft cannot be opened")
            drafts = readDrafts()
            return
        }
        contents = SquareComposeRules.clip(text)
        path.removeAll()
    }

    private func delete(_ row: SquareCloudDraftRow) {
        drafts.removeAll { $0.key == row.key }
        undo?.task.cancel()
        let task = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            commitDelete(row)
        }
        undo = SquareCloudDraftUndo(row: row, task: task)
    }

    private func restore(_ pending: SquareCloudDraftUndo) {
        pending.task.cancel()
        undo = nil
        drafts = readDrafts()
    }

    private func commitDelete(_ row: SquareCloudDraftRow) {
        guard let memberID else { return }
        let removed = SquareCloudDraftDisk.remove(topicID: row.key, memberID: memberID)
        let left = readDrafts()
        if !removed || left.contains(where: { $0.key == row.key }) {
            drafts = left
            notice = copy("删除失败，请重试", "The delete did not stick. Try again")
        } else {
            drafts = left
        }
        undo = nil
    }

    private func persist() {
        guard lock.phase != .receipt, !editing, let memberID, let topic = SquareComposeRules.topicID(memberID: memberID, clubID: clubID) else { return }
        let text = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        SquareCloudDraftDisk.save(topicID: topic, memberID: memberID, contents: contents)
    }

    private func clearDraft() {
        guard let memberID, let topic = SquareComposeRules.topicID(memberID: memberID, clubID: clubID) else { return }
        _ = SquareCloudDraftDisk.remove(topicID: topic, memberID: memberID)
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

enum SquareCloudComposerRoute: Hashable { case drafts, activities, completed, review }

struct SquareCloudDraftRow: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let nickname: String
    let date: String
    let summary: String
}

struct SquareCloudDraftUndo {
    let row: SquareCloudDraftRow
    let task: Task<Void, Never>
}

enum SquareCloudDraftDisk {
    private struct Envelope: Codable {
        var memberID: String
        var savedAt: Date
        var contents: String
    }
    private struct Pending: Codable {
        var requestID: String
        var phase: String
    }

    private static func storageDirectory() -> URL? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return root.appendingPathComponent("SquareCloudDrafts-v1", isDirectory: true)
    }

    private static func fileURL(for key: String) -> URL? {
        guard let dir = storageDirectory() else { return nil }
        let hex = key.utf8.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(hex + ".json", isDirectory: false)
    }

    private static func writeProtected(_ data: Data, key: String) {
        guard let url = fileURL(for: key), let dir = storageDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var protectedDir = dir
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? protectedDir.setResourceValues(values)
        #if os(iOS)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try? data.write(to: url, options: .atomic)
        #endif
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func readProtected(key: String) -> Data? {
        UserDefaults.standard.removeObject(forKey: key)
        guard let url = fileURL(for: key), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func removeProtected(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        guard let url = fileURL(for: key), FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func load(topicID: String) -> SquareComposeDraftEnvelope? {
        guard let data = readProtected(key: draftKey(topicID)),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        return SquareComposeDraftEnvelope(memberID: envelope.memberID, savedAt: envelope.savedAt, contents: envelope.contents)
    }

    static func save(topicID: String, memberID: String, contents: String) {
        let envelope = Envelope(memberID: memberID, savedAt: Date(), contents: contents)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        writeProtected(data, key: draftKey(topicID))
    }

    /// True only when a following read no longer returns this member's draft.
    static func remove(topicID: String, memberID: String) -> Bool {
        removeProtected(key: draftKey(topicID))
        guard let left = load(topicID: topicID) else { return true }
        return left.memberID != memberID
    }

    static func savePending(memberID: String, requestID: String, phase: SquareComposeLock.Phase) {
        let name: String
        switch phase {
        case .unknown: name = "unknown"
        case .sending: name = "sending"
        case .receipt: name = "receipt"
        case .rejected: name = "rejected"
        case .idle: name = "idle"
        }
        guard let data = try? JSONEncoder().encode(Pending(requestID: requestID, phase: name)) else { return }
        writeProtected(data, key: pendingKey(memberID))
    }

    static func pending(memberID: String) -> (requestID: String, phase: SquareComposeLock.Phase)? {
        guard let data = readProtected(key: pendingKey(memberID)),
              let pending = try? JSONDecoder().decode(Pending.self, from: data) else { return nil }
        let phase: SquareComposeLock.Phase
        switch pending.phase {
        case "unknown": phase = .unknown
        case "sending": phase = .sending
        case "receipt": phase = .receipt
        case "rejected": phase = .rejected
        default: phase = .idle
        }
        return (pending.requestID, phase)
    }

    static func clearPending(memberID: String) {
        removeProtected(key: pendingKey(memberID))
    }

    private static func draftKey(_ topicID: String) -> String { "pro_editor_draft_topic_" + topicID }
    private static func pendingKey(_ memberID: String) -> String { "square_compose_lock_" + memberID }
}
