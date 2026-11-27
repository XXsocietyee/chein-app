import MapKit
import SwiftUI

/// List and detail callbacks for the activity card. Nil hides that control.
@MainActor struct SquareCloudFeedContext {
    var viewerID: Int?
    var offline = false
    var onDoubleTapLike: ((SquarePost) -> Void)?
    var onFollow: ((SquarePost) -> Void)?
    var onRepost: ((SquarePost) -> Void)?
    var onReport: ((SquarePost) -> Void)?
    var onProfile: ((SquarePost) -> Void)?
    var onCopyLink: ((SquarePost) -> Void)?
    var onActions: ((SquarePost) -> Void)?
    var onEdit: ((SquarePost) -> Void)?
    var onBookmark: ((SquarePost) -> Void)?
    var onDelete: ((SquarePost) -> Void)?
    var bookmarked: (SquarePost) -> Bool = { _ in false }
}

private struct SquareCloudFeedContextKey: EnvironmentKey {
    static let defaultValue: SquareCloudFeedContext? = nil
}

extension EnvironmentValues {
    var squareCloudFeed: SquareCloudFeedContext? {
        get { self[SquareCloudFeedContextKey.self] }
        set { self[SquareCloudFeedContextKey.self] = newValue }
    }
}

enum SquareCloudRoutePhase: Equatable {
    case loading, ready, empty, failed, offline, permission
}

/// `components/route-map`. Orange line from real points on an Apple map. No points, no invented line.
struct SquareCloudRouteMap: View {
    var phase: SquareCloudRoutePhase
    var points: [SquareRoutePoint] = []
    var sourceText: String?
    var onRetry: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    @Environment(\.locale) private var locale

    private var line: [SquareRouteUnitPoint] { SquareRouteCanvas.unitPoints(points) }
    private var coordinates: [CLLocationCoordinate2D] {
        points
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter { CLLocationCoordinate2DIsValid($0) }
    }

    var body: some View {
        VStack(alignment: .leading) {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(verbatim: copy("正在读取路线", "Loading the route")))
                    .accessibilityIdentifier("square.cloud.route.loading")
            case .permission:
                state("没有路线读取权限", "No permission to read this route", symbol: "lock").accessibilityIdentifier("square.cloud.route.permission")
            case .offline:
                state("你离线了", "You're offline", symbol: "wifi.slash").accessibilityIdentifier("square.cloud.route.offline")
            case .failed:
                state("路线没能打开", "The route did not open", symbol: "exclamationmark.triangle").accessibilityIdentifier("square.cloud.route.failed")
                if let onRetry {
                    Button(action: onRetry) { Text(verbatim: copy("重试", "Retry")) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("square.cloud.route.retry")
                }
            case .empty:
                state("这条活动没有可画的轨迹", "This activity has no route to draw", symbol: "point.topleft.down.to.point.bottomright.curvepath").accessibilityIdentifier("square.cloud.route.empty")
            case .ready:
                if line.count >= 2, coordinates.count >= 2 {
                    Map(initialPosition: .automatic, interactionModes: []) {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.orange, lineWidth: 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .accessibilityLabel(Text(verbatim: copy("活动路线", "Activity route")))
                    .accessibilityIdentifier("square.cloud.route.map")
                    .accessibilityAction(named: Text(verbatim: copy("点赞", "Kudos"))) { onDoubleTap?() }
                    .onTapGesture(count: 2) { onDoubleTap?() }
                    if let sourceText, !sourceText.isEmpty {
                        Text(verbatim: sourceText).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("square.cloud.route.source")
                    }
                } else {
                    state("这条活动没有可画的轨迹", "This activity has no route to draw", symbol: "point.topleft.down.to.point.bottomright.curvepath").accessibilityIdentifier("square.cloud.route.empty")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.cloud.route")
    }

    private func state(_ zh: String, _ en: String, symbol: String) -> some View {
        Label { Text(verbatim: copy(zh, en)) } icon: { Image(systemName: symbol) }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

/// Activity stats, route, cleared banner, kudos, and one comment. Text posts do not use this view.
struct SquareCloudStravaBlock: View {
    let card: SquareStravaCard
    var title: String?
    var onDoubleTapLike: (() -> Void)?
    var onRepost: (() -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let name = card.name ?? title, !name.isEmpty {
                HStack {
                    Text(verbatim: name).font(.headline).foregroundStyle(.primary).lineLimit(2)
                    if card.cleared == true {
                        Image(systemName: "trophy.fill").foregroundStyle(.orange)
                            .accessibilityLabel(Text(verbatim: copy("已通关", "Cleared")))
                    }
                }
                .accessibilityIdentifier("square.cloud.activityTitle")
            }
            HStack(alignment: .top) {
                stat(copy("距离", "Distance"), LocaleDisplay.isChinese(locale) ? SquareStravaCard.distanceText(card.distanceKilometers) : (card.distanceKilometers.flatMap { LocaleDisplay.distance(kilometers: $0, locale: locale) } ?? SquareStravaCard.distanceText(card.distanceKilometers))).accessibilityIdentifier("square.cloud.stat.distance")
                stat(copy("完成节点", "Nodes done"), SquareStravaCard.nodeText(done: card.nodeDone, total: card.nodeTotal)).accessibilityIdentifier("square.cloud.stat.nodes")
                stat(copy("时长", "Duration"), SquareStravaCard.durationText(card.durationSeconds)).accessibilityIdentifier("square.cloud.stat.duration")
            }
            SquareCloudRouteMap(
                phase: card.route.count >= 2 ? .ready : (card.topicID == nil ? .empty : .empty),
                points: card.route,
                sourceText: card.routeSourceText,
                onDoubleTap: onDoubleTapLike)
            if card.cleared == true { clearedBanner }
            if onDoubleTapLike != nil {
                Text(verbatim: copy("双击路线点赞", "Double-tap the route to give kudos"))
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityAction(named: Text(verbatim: copy("点赞", "Kudos"))) { onDoubleTapLike?() }
                    .accessibilityIdentifier("square.cloud.doubleTap")
            }
            if !card.kudosAvatars.isEmpty || card.kudosText != nil { kudos }
            if card.commentAuthor != nil || card.commentBody != nil { inlineComment }
            if onRepost != nil { repostButton }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.cloud.strava")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.body.weight(.medium)).foregroundStyle(.primary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var clearedBanner: some View {
        Label { Text(verbatim: copy("已通关", "Cleared")) } icon: { Image(systemName: "trophy.fill").accessibilityHidden(true) }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("square.cloud.cleared")
    }

    private var kudos: some View {
        HStack {
            HStack(spacing: -6) {
                ForEach(Array(card.kudosAvatars.prefix(3).enumerated()), id: \.offset) { _, _ in
                    Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: card.kudosText ?? SquareCountDisplay.unknownMark)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.cloud.kudos")
    }

    private var inlineComment: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: card.commentAuthor ?? SquareCountDisplay.unknownMark).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            Text(verbatim: card.commentBody ?? SquareCountDisplay.unknownMark).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.cloud.comment")
    }

    private var repostButton: some View {
        Button { onRepost?() } label: {
            Label { Text(verbatim: copy("转发", "Repost")) } icon: { Image(systemName: "arrowshape.turn.up.right") }
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("square.cloud.repost")
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

/// `cy/post-actions` as a system action list. Edit and bookmark sit apart from delete and report; delete confirms
/// with a system confirmation dialog.
struct SquareCloudPostActions: View {
    var owner: Bool
    var bookmarkable: Bool
    var bookmarked: Bool
    var summary: String
    var onEdit: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReport: (() -> Void)?
    var onClose: () -> Void
    @Environment(\.locale) private var locale
    @State private var confirmingDelete = false

    private struct ActionItem: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        var isDanger = false
        let identifier: String
    }

    var body: some View {
        NavigationStack {
            List {
                let items = actionItems
                if items.isEmpty {
                    Text(verbatim: copy("没有可做的操作", "Nothing to do here"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("square.cloud.actions.empty")
                } else {
                    // MP `.pa-card` x2: 收藏 / 编辑 in the first group, 删除 / 举报 in the second.
                    let plain = items.filter { !$0.isDanger }
                    let danger = items.filter { $0.isDanger }
                    if !plain.isEmpty {
                        Section { ForEach(plain) { item in actionRow(item) } }
                    }
                    if !danger.isEmpty {
                        Section { ForEach(danger) { item in actionRow(item) } }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: copy("帖文操作", "Post actions")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close", action: onClose)
                        .accessibilityIdentifier("square.cloud.actions.close")
                }
            }
        }
        .confirmationDialog(
            Text(verbatim: copy("删除这条动态「\(SquarePostExcerpt.text(summary))」?", "Delete this post “\(SquarePostExcerpt.text(summary))”?")),
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) { onDelete?() } label: {
                Text(verbatim: appLocalized("square.cloud.delete.confirm", locale: locale))
            }
            .accessibilityIdentifier("square.cloud.actions.deleteConfirm")
            Button(role: .cancel) { confirmingDelete = false } label: {
                Text(verbatim: appLocalized("action.cancel", locale: locale))
            }
            .accessibilityIdentifier("square.cloud.actions.deleteCancel")
        } message: {
            Text(verbatim: appLocalized("square.cloud.delete.c1", locale: locale) + "\n" + appLocalized("square.cloud.delete.c2", locale: locale))
                .accessibilityIdentifier("square.cloud.actions.deleteTitle")
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("square.cloud.actions")
    }

    private func actionRow(_ item: ActionItem) -> some View {
        Button(role: item.isDanger ? .destructive : nil) { select(item.id) } label: {
            Label { Text(verbatim: item.title) } icon: { Image(systemName: item.systemImage) }
        }
        .accessibilityIdentifier(item.identifier)
    }

    private func select(_ id: String) {
        switch id {
        case "bookmark": onBookmark?()
        case "edit": onEdit?()
        case "delete": confirmingDelete = true
        case "report": onReport?()
        default: break
        }
    }

    private var actionItems: [ActionItem] {
        var result: [ActionItem] = []
        if bookmarkable, onBookmark != nil {
            result.append(ActionItem(
                id: "bookmark",
                title: bookmarked ? copy("取消收藏", "Remove bookmark") : copy("收藏", "Bookmark"),
                systemImage: bookmarked ? "star.fill" : "star",
                identifier: "square.cloud.actions.bookmark"
            ))
        }
        if owner, onEdit != nil {
            result.append(ActionItem(id: "edit", title: copy("编辑", "Edit"), systemImage: "pencil", identifier: "square.cloud.actions.edit"))
        }
        if owner, onDelete != nil {
            result.append(ActionItem(id: "delete", title: copy("删除", "Delete"), systemImage: "trash", isDanger: true, identifier: "square.cloud.actions.delete"))
        }
        if onReport != nil {
            result.append(ActionItem(id: "report", title: copy("举报", "Report"), systemImage: "exclamationmark.triangle", isDanger: true, identifier: "square.cloud.actions.report"))
        }
        return result
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

enum SquareCloudRead<Value> {
    case rows([Value])
    case empty
    case failed
    case offline
    case permission
}

/// Joined and hosted activities from `cy/post-compose`.
struct SquareCloudJoinedActivityList: View {
    var load: () async -> SquareCloudRead<SquareComposeActivityOption>
    var onSelect: (SquareComposeActivityOption) -> Void
    var onCompleted: (() -> Void)? = nil
    var onClose: () -> Void
    @Environment(\.locale) private var locale
    @State private var phase: SquareCloudRead<SquareComposeActivityOption> = .rows([])
    @State private var started = false

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: copy("选择活动", "Choose an activity")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel(Text(verbatim: copy("关闭", "Close")))
                    .accessibilityIdentifier("square.cloud.activity.close")
            }
        }
        .task { if !started { started = true; await reload() } }
        .refreshable { await reload() }
        .accessibilityIdentifier("square.cloud.activity")
    }

    @ViewBuilder private var content: some View {
        if let onCompleted {
            Section {
                Button(action: onCompleted) {
                    Label { Text(verbatim: copy("选择已完成的活动", "Choose a cleared activity")) } icon: { Image(systemName: "checkmark.circle") }
                }
                .accessibilityIdentifier("square.cloud.completed.entry")
            }
        }
        switch phase {
        case .rows(let rows) where rows.isEmpty && !started:
            ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity).accessibilityIdentifier("square.cloud.activity.loading")
        case .rows(let rows) where rows.isEmpty:
            ContentUnavailableView {
                Label { Text(verbatim: copy("还没有可关联的活动", "No activity to attach")).accessibilityIdentifier("square.cloud.activity.empty") } icon: { Image(systemName: "flag") }
            } description: {
                Text(verbatim: copy("只显示你参加过或主办的活动", "Only activities you joined or hosted"))
            }
        case .rows(let rows):
            Section {
                ForEach(rows) { item in
                    Button { onSelect(item) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.name).foregroundStyle(.primary)
                            Text(verbatim: item.sourceLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("square.cloud.activity.row.\(item.activityID)")
                }
            }
        case .empty:
            ContentUnavailableView {
                Label { Text(verbatim: copy("还没有可关联的活动", "No activity to attach")).accessibilityIdentifier("square.cloud.activity.empty") } icon: { Image(systemName: "flag") }
            }
        case .failed:
            notice("活动列表加载失败", "The activity list did not load", symbol: "exclamationmark.triangle", identifier: "square.cloud.activity.error")
        case .offline:
            notice("你离线了", "You're offline", symbol: "wifi.slash", identifier: "square.cloud.activity.offline")
        case .permission:
            notice("没有活动列表的读取权限", "No permission to read activities", symbol: "lock", identifier: "square.cloud.activity.permission")
        }
    }

    private func notice(_ zh: String, _ en: String, symbol: String, identifier: String) -> some View {
        ContentUnavailableView {
            Label { Text(verbatim: copy(zh, en)).accessibilityIdentifier(identifier) } icon: { Image(systemName: symbol) }
        } description: {
            Text(verbatim: copy("不会编一份活动列表", "No stand-in list is shown"))
        } actions: {
            Button { Task { await reload() } } label: { Text(verbatim: copy("重试", "Retry")) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("square.cloud.activity.retry")
        }
    }

    private func reload() async {
        phase = .rows([])
        started = false
        let value = await load()
        phase = value
        started = true
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

/// `components/activity-picker`. Completed activities, cover, progress, and a route-preview step with no invented image.
struct SquareCloudCompletedActivityPicker: View {
    var load: () async -> SquareCloudRead<SquareCompletedActivity>
    var onSelect: (SquareCompletedActivity, String?) -> Void
    var onClose: () -> Void
    @Environment(\.locale) private var locale
    @State private var phase: SquareCloudRead<SquareCompletedActivity> = .rows([])
    @State private var started = false
    @State private var generating = false
    @State private var previewTopicID = ""

    var body: some View {
        List {
            list
            if generating {
                Section {
                    SquareCloudRouteMap(phase: .loading, points: [], sourceText: nil)
                    Text(verbatim: copy("生成路线预览中…", "Making a route preview…"))
                        .font(.subheadline)
                        .accessibilityIdentifier("square.cloud.completed.generating")
                        .accessibilityValue(Text(verbatim: previewTopicID))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: copy("选择已完成的活动", "Choose a cleared activity")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel(Text(verbatim: copy("关闭活动选择", "Close activity picker")))
                    .accessibilityIdentifier("square.cloud.completed.close")
            }
        }
        .task {
            guard !started else { return }
            phase = await load()
            started = true
        }
        .refreshable { phase = await load() }
        .accessibilityIdentifier("square.cloud.completed")
    }

    @ViewBuilder private var list: some View {
        switch phase {
        case .rows(let rows) where rows.isEmpty && !started:
            ProgressView {
                Text(verbatim: copy("正在读取已完成的活动…", "Loading cleared activities…"))
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("square.cloud.completed.loading")
        case .rows(let rows):
            if rows.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(rows) { item in
                        Button { choose(item) } label: { completedRow(item) }
                            .accessibilityIdentifier("square.cloud.completed.row.\(item.activityID)")
                    }
                }
            }
        case .empty:
            emptyState
        case .failed:
            status("活动列表没能打开", "The activity list did not open", symbol: "exclamationmark.triangle", identifier: "square.cloud.completed.error")
        case .offline:
            status("你离线了", "You're offline", symbol: "wifi.slash", identifier: "square.cloud.completed.offline")
        case .permission:
            status("没有已完成活动的读取权限", "No permission to read cleared activities", symbol: "lock", identifier: "square.cloud.completed.permission")
        }
    }

    /// MP `cy-empty`: title plus 仅显示已完成的活动 in every empty case.
    private var emptyState: some View {
        ContentUnavailableView {
            Label { Text(verbatim: copy("暂无可关联的已完成活动或主题", "No cleared activity or topic to attach")).accessibilityIdentifier("square.cloud.completed.empty") } icon: { Image(systemName: "checkmark.circle") }
        } description: {
            Text(verbatim: copy("仅显示已完成的活动", "Only cleared activities"))
        }
    }

    private func completedRow(_ item: SquareCompletedActivity) -> some View {
        HStack {
            if let cover = item.cover, let url = URL(string: cover), cover.hasPrefix("https://") {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    .frame(width: 56, height: 56)
                    .clipped()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name).foregroundStyle(.primary)
                Text(verbatim: copy("完成 \(SquareStravaCard.nodeText(done: item.doneCount, total: item.total)) · 已通关", "Done \(SquareStravaCard.nodeText(done: item.doneCount, total: item.total)) · cleared"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark").accessibilityHidden(true).foregroundStyle(.green)
        }
    }

    private func status(_ zh: String, _ en: String, symbol: String, identifier: String) -> some View {
        ContentUnavailableView {
            Label { Text(verbatim: copy(zh, en)).accessibilityIdentifier(identifier) } icon: { Image(systemName: symbol) }
        } description: {
            Text(verbatim: copy("活动列表加载失败，请重试", "The activity list did not load. Try again."))
        } actions: {
            Button { Task { phase = await load() } } label: { Text(verbatim: copy("重试", "Retry")) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("square.cloud.completed.retry")
        }
    }

    private func choose(_ item: SquareCompletedActivity) {
        guard let topic = item.topicID, !topic.isEmpty else {
            onSelect(item, nil)
            return
        }
        generating = true
        previewTopicID = topic
        generating = false
        onSelect(item, nil)
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

extension SquareXcxPostCard {
    /// Activity block for posts that carry one. Text and image posts skip it.
    @MainActor var stravaSection: some View { SquareCloudStravaSection(post: post) }
}

/// Reads the feed environment so the list call site can stay unchanged.
@MainActor struct SquareCloudStravaSection: View {
    let post: SquarePost
    @Environment(\.squareCloudFeed) private var feed
    @Environment(\.locale) private var locale

    var body: some View {
        if post.strava.showsActivity {
            VStack(alignment: .leading) {
                if showsFollow {
                    Button { feed?.onFollow?(post) } label: {
                        Text(verbatim: locale.pick("关注", "Follow"))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("square.cloud.follow")
                }
                SquareCloudStravaBlock(
                    card: post.strava,
                    title: post.referenceTitle,
                    onDoubleTapLike: feed?.onDoubleTapLike == nil ? nil : { feed?.onDoubleTapLike?(post) },
                    onRepost: canRepost ? { feed?.onRepost?(post) } : nil)
                HStack {
                    if feed?.onActions != nil {
                        Button { feed?.onActions?(post) } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text(verbatim: locale.pick("帖文操作", "Post actions")))
                        .accessibilityIdentifier("square.cloud.cardActions")
                    }
                    if hasMenuItems {
                        // Source `cy/popover` author menu, as the system pull-down menu.
                        Menu {
                            ForEach(menuItems, id: \.key) { item in
                                Button { pick(item.key) } label: {
                                    Label { Text(verbatim: item.label) } icon: { Image(systemName: item.symbol) }
                                }
                                .accessibilityIdentifier("square.cloud.popover.\(item.key)")
                            }
                        } label: {
                            Label { Text(verbatim: locale.pick("作者菜单", "Author menu")) } icon: { Image(systemName: "person.crop.circle") }
                        }
                        .accessibilityIdentifier("square.cloud.authorMenu")
                    }
                }
            }
        }
    }

    private var showsFollow: Bool {
        feed?.onFollow != nil && post.strava.followed == false && post.memberID > 0 && post.memberID != feed?.viewerID
    }

    private var canRepost: Bool {
        feed?.onRepost != nil && SquareShareCard.build(id: post.id, audience: post.audience, lifecycle: post.lifecycle, contents: post.contents, images: post.images).includesPost
    }

    private var menuItems: [(key: String, label: String, symbol: String)] {
        var items: [(key: String, label: String, symbol: String)] = []
        if showsFollow { items.append(("follow", locale.pick("关注", "Follow"), "plus")) }
        if feed?.onProfile != nil { items.append(("profile", locale.pick("访问主页", "Profile"), "person")) }
        if feed?.onReport != nil { items.append(("report", locale.pick("举报", "Report"), "exclamationmark.triangle")) }
        if feed?.onCopyLink != nil, canRepost { items.append(("copy", locale.pick("复制链接", "Copy link"), "link")) }
        return items
    }

    private var hasMenuItems: Bool { !menuItems.isEmpty }

    private func pick(_ key: String) {
        switch key {
        case "follow": feed?.onFollow?(post)
        case "profile": feed?.onProfile?(post)
        case "report": feed?.onReport?(post)
        case "copy": feed?.onCopyLink?(post)
        default: break
        }
    }
}
