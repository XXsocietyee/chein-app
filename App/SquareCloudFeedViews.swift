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

/// `components/route-map`. Orange line from real points. No points, no invented line.
struct SquareCloudRouteMap: View {
    var phase: SquareCloudRoutePhase
    var points: [SquareRoutePoint] = []
    var sourceText: String?
    var onRetry: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var drawn = false

    private var line: [SquareRouteUnitPoint] { SquareRouteCanvas.unitPoints(points) }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            switch phase {
            case .loading:
                CYSkeleton().accessibilityLabel(Text(verbatim: copy("正在读取路线", "Loading the route")))
                    .accessibilityIdentifier("square.cloud.route.loading")
            case .permission:
                state("没有路线读取权限", "No permission to read this route").accessibilityIdentifier("square.cloud.route.permission")
            case .offline:
                state("你离线了", "You're offline").accessibilityIdentifier("square.cloud.route.offline")
            case .failed:
                state("路线没能打开", "The route did not open").accessibilityIdentifier("square.cloud.route.failed")
                if let onRetry {
                    Button(action: onRetry) { Text(verbatim: copy("重试", "Retry")).frame(minHeight: CYSpacing.minTouchTarget) }
                        .accessibilityIdentifier("square.cloud.route.retry")
                }
            case .empty:
                state("这条活动没有可画的轨迹", "This activity has no route to draw").accessibilityIdentifier("square.cloud.route.empty")
            case .ready:
                if line.count >= 2 {
                    Canvas { context, size in
                        var path = Path()
                        for (index, point) in line.enumerated() {
                            let mark = CGPoint(x: point.x * size.width, y: point.y * size.height)
                            if index == 0 { path.move(to: mark) } else { path.addLine(to: mark) }
                        }
                        context.stroke(path, with: .color(CYNight.ember), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(CYNight.indigo, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .accessibilityLabel(Text(verbatim: copy("活动路线", "Activity route")))
                    .accessibilityIdentifier("square.cloud.route.map")
                    .accessibilityAction(named: Text(verbatim: copy("点赞", "Kudos"))) { onDoubleTap?() }
                    .gesture(TapGesture(count: 2).onEnded { onDoubleTap?() })
                    .onAppear { drawn = reduceMotion }
                    .opacity(reduceMotion || drawn ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: CYMotion.Duration.standard), value: drawn)
                    .task {
                        if reduceMotion { drawn = true } else { drawn = true }
                    }
                    if let sourceText, !sourceText.isEmpty {
                        Text(verbatim: sourceText).cyText(.meta).foregroundStyle(.secondary)
                            .accessibilityIdentifier("square.cloud.route.source")
                    }
                } else {
                    state("这条活动没有可画的轨迹", "This activity has no route to draw").accessibilityIdentifier("square.cloud.route.empty")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.cloud.route")
    }

    private func state(_ zh: String, _ en: String) -> some View {
        Text(verbatim: copy(zh, en))
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
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let name = card.name ?? title, !name.isEmpty {
                HStack(spacing: CYSpacing.sm) {
                    Text(verbatim: name).cyText(.cardTitle).foregroundStyle(.primary).lineLimit(2)
                    if card.cleared == true {
                        Image(systemName: "trophy.fill").foregroundStyle(.orange)
                            .accessibilityLabel(Text(verbatim: copy("已通关", "Cleared")))
                    }
                }
                .accessibilityIdentifier("square.cloud.activityTitle")
            }
            HStack(alignment: .top, spacing: CYSpacing.md) {
                stat(copy("距离", "Distance"), SquareStravaCard.distanceText(card.distanceKilometers)).accessibilityIdentifier("square.cloud.stat.distance")
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
                    .cyText(.meta).foregroundStyle(.secondary)
                    .accessibilityAction(named: Text(verbatim: copy("点赞", "Kudos"))) { onDoubleTapLike?() }
                    .accessibilityIdentifier("square.cloud.doubleTap")
            }
            if !card.kudosAvatars.isEmpty || card.kudosText != nil { kudos }
            if card.commentAuthor != nil || card.commentBody != nil { inlineComment }
            if onRepost != nil { repostButton }
        }
        .padding(CYSpacing.md)
        .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.cloud.strava")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: label).cyText(.meta).foregroundStyle(.secondary)
            Text(verbatim: value).cyText(.bodyMedium).foregroundStyle(.primary).monospacedDigit().cyWrapText()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var clearedBanner: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "trophy.fill").accessibilityHidden(true).foregroundStyle(.orange)
            Text(verbatim: copy("已通关", "Cleared")).cyText(.bodyMedium).foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityIdentifier("square.cloud.cleared")
    }

    private var kudos: some View {
        HStack(spacing: CYSpacing.sm) {
            HStack(spacing: -CYSpacing.sm) {
                ForEach(Array(card.kudosAvatars.prefix(3).enumerated()), id: \.offset) { _, _ in
                    Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                        .background(Circle().fill(CYColor.bgSurfaceSubtle))
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: card.kudosText ?? SquareCountDisplay.unknownMark)
                .cyText(.meta)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.cloud.kudos")
    }

    private var inlineComment: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Text(verbatim: card.commentAuthor ?? SquareCountDisplay.unknownMark).cyText(.bodyMedium).foregroundStyle(.primary).cyWrapText()
            Text(verbatim: card.commentBody ?? SquareCountDisplay.unknownMark).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.cloud.comment")
    }

    private var repostButton: some View {
        Button { onRepost?() } label: {
            Label { Text(verbatim: copy("转发", "Repost")) } icon: { Image(systemName: "arrowshape.turn.up.right") }
                .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .accessibilityIdentifier("square.cloud.repost")
    }

    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
}

/// `cy/popover`. Hidden when there is no anchor. Not a sheet and not a full-width menu.
struct SquareCloudPopover: View {
    let items: [(key: String, label: String, symbol: String)]
    let placement: SquarePopoverPlacement
    var onPick: (String) -> Void
    var onClose: () -> Void
    @Environment(\.locale) private var locale
    private var closeLabel: String { locale.pick("关闭菜单", "Close menu") }

    var body: some View {
        if placement.visible, !items.isEmpty {
            ZStack(alignment: .topLeading) {
                Color.clear.contentShape(Rectangle())
                    .accessibilityLabel(Text(verbatim: closeLabel))
                    .onTapGesture(perform: onClose)
                    .accessibilityIdentifier("square.cloud.popover.close")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.key) { item in
                        Button { onPick(item.key) } label: {
                            Label { Text(verbatim: item.label) } icon: { Image(systemName: item.symbol) }
                                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, CYSpacing.md)
                        .accessibilityIdentifier("square.cloud.popover.\(item.key)")
                    }
                }
                .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .frame(maxWidth: 240, alignment: .leading)
                .offset(x: placement.left, y: placement.top)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("square.cloud.popover")
            }
        }
    }
}

/// `cy/post-actions`. Edit and bookmark sit apart from delete and report. Delete confirms inside this sheet.
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

    var body: some View {
        Group {
            if confirmingDelete {
                let excerpt = SquarePostExcerpt.text(summary)
                CYConfirmSheet(
                    title: copy("删除这条动态「\(excerpt)」?", "Delete this post “\(excerpt)”?"),
                    message: appLocalized("square.cloud.delete.c1", locale: locale),
                    confirmTitle: appLocalized("square.cloud.delete.confirm", locale: locale),
                    cancelTitle: appLocalized("action.cancel", locale: locale),
                    isDestructive: true,
                    confirmIdentifier: "square.cloud.actions.deleteConfirm",
                    cancelIdentifier: cyAccessibilityID(id: "square.cloud.actions.deleteCancel"),
                    titleIdentifier: cyAccessibilityID(id: "square.cloud.actions.deleteTitle"),
                    consequences: [
                        CYConfirmConsequence(systemImage: "bubble.left.and.exclamationmark.bubble.right", text: appLocalized("square.cloud.delete.c1", locale: locale)),
                        CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: appLocalized("square.cloud.delete.c2", locale: locale))
                    ],
                    onCancel: { confirmingDelete = false },
                    onConfirm: { onDelete?() }
                )
            } else {
                let items = optionItems
                if items.isEmpty {
                    CYSheetContainer(
                        title: copy("帖文操作", "Post actions"),
                        closeIdentifier: cyAccessibilityID(id: "square.cloud.actions.close"),
                        onClose: onClose
                    ) {
                        Text(verbatim: copy("没有可做的操作", "Nothing to do here"))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, CYSpacing.md)
                            .accessibilityIdentifier("square.cloud.actions.empty")
                    }
                } else {
                    CYOptionSheet(
                        title: copy("帖文操作", "Post actions"),
                        items: items,
                        closeIdentifier: cyAccessibilityID(id: "square.cloud.actions.close"),
                        onSelect: { id in
                            switch id {
                            case "bookmark": onBookmark?()
                            case "edit": onEdit?()
                            case "delete": confirmingDelete = true
                            case "report": onReport?()
                            default: break
                            }
                        },
                        onClose: onClose
                    )
                }
            }
        }
        .cyDomainSheet(detents: [.half, .full])
        .accessibilityIdentifier("square.cloud.actions")
    }

    private var optionItems: [CYOptionSheetItem<String>] {
        var result: [CYOptionSheetItem<String>] = []
        if bookmarkable, onBookmark != nil {
            result.append(CYOptionSheetItem(
                id: "bookmark",
                title: bookmarked ? copy("取消收藏", "Remove bookmark") : copy("收藏", "Bookmark"),
                systemImage: bookmarked ? "star.fill" : "star",
                identifier: "square.cloud.actions.bookmark"
            ))
        }
        if owner, onEdit != nil {
            result.append(CYOptionSheetItem(
                id: "edit",
                title: copy("编辑", "Edit"),
                systemImage: "pencil",
                identifier: "square.cloud.actions.edit"
            ))
        }
        if owner, onDelete != nil {
            result.append(CYOptionSheetItem(
                id: "delete",
                title: copy("删除", "Delete"),
                systemImage: "trash",
                isDanger: true,
                identifier: "square.cloud.actions.delete"
            ))
        }
        if onReport != nil {
            result.append(CYOptionSheetItem(
                id: "report",
                title: copy("举报", "Report"),
                systemImage: "exclamationmark.triangle",
                isDanger: true,
                identifier: "square.cloud.actions.report"
            ))
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
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            content
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CYColor.bgPage)
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
        .accessibilityIdentifier("square.cloud.activity")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
        if let onCompleted {
            Button(action: onCompleted) {
                Text(verbatim: copy("选择已完成的活动", "Choose a cleared activity")).frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("square.cloud.completed.entry")
        }
        switch phase {
        case .rows(let rows) where rows.isEmpty && !started:
            CYSkeleton().accessibilityIdentifier("square.cloud.activity.loading")
        case .rows(let rows) where rows.isEmpty:
            Text(verbatim: copy("还没有可关联的活动", "No activity to attach")).cyText(.cardTitle).foregroundStyle(.primary)
                .accessibilityIdentifier("square.cloud.activity.empty")
            Text(verbatim: copy("只显示你参加过或主办的活动", "Only activities you joined or hosted")).font(.subheadline).foregroundStyle(.secondary)
        case .rows(let rows):
            ForEach(rows) { item in
                Button { onSelect(item) } label: {
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(verbatim: item.name).cyText(.cardTitle).foregroundStyle(.primary).cyWrapText()
                        Text(verbatim: item.sourceLabel).cyText(.meta).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("square.cloud.activity.row.\(item.activityID)")
            }
        case .empty:
            Text(verbatim: copy("还没有可关联的活动", "No activity to attach")).cyText(.cardTitle).foregroundStyle(.primary)
                .accessibilityIdentifier("square.cloud.activity.empty")
        case .failed:
            notice("活动列表加载失败", "The activity list did not load").accessibilityIdentifier("square.cloud.activity.error")
        case .offline:
            notice("你离线了", "You're offline").accessibilityIdentifier("square.cloud.activity.offline")
        case .permission:
            notice("没有活动列表的读取权限", "No permission to read activities").accessibilityIdentifier("square.cloud.activity.permission")
        }
        if showsRetry {
            Button { Task { await reload() } } label: {
                Text(verbatim: copy("重试", "Retry")).frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("square.cloud.activity.retry")
        }
        }
    }

    private var showsRetry: Bool {
        switch phase {
        case .failed, .offline, .permission: return true
        default: return false
        }
    }

    private func notice(_ zh: String, _ en: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: copy(zh, en)).cyText(.cardTitle).foregroundStyle(.primary)
            Text(verbatim: copy("不会编一份活动列表", "No stand-in list is shown")).font(.subheadline).foregroundStyle(.secondary)
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
    @QuestifyReduceMotion private var reduceMotion
    @State private var phase: SquareCloudRead<SquareCompletedActivity> = .rows([])
    @State private var started = false
    @State private var generating = false
    @State private var previewTopicID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            list
            if generating {
                SquareCloudRouteMap(phase: .loading, points: [], sourceText: nil)
                Text(verbatim: copy("生成路线预览中…", "Making a route preview…"))
                    .font(.subheadline).foregroundStyle(.primary)
                    .accessibilityIdentifier("square.cloud.completed.generating")
                    .accessibilityValue(Text(verbatim: previewTopicID))
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CYColor.bgPage)
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
        .accessibilityIdentifier("square.cloud.completed")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
        switch phase {
        case .rows(let rows) where rows.isEmpty && !started:
            CYSkeleton().accessibilityIdentifier("square.cloud.completed.loading")
        case .rows(let rows):
            if rows.isEmpty {
                Text(verbatim: copy("暂无可关联的已完成活动或主题", "No cleared activity or topic to attach")).cyText(.cardTitle).foregroundStyle(.primary)
                    .accessibilityIdentifier("square.cloud.completed.empty")
                Text(verbatim: copy("仅显示已完成的活动", "Only cleared activities")).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(rows) { item in
                Button { choose(item) } label: { completedRow(item) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("square.cloud.completed.row.\(item.activityID)")
            }
        case .empty:
            Text(verbatim: copy("暂无可关联的已完成活动或主题", "No cleared activity or topic to attach")).cyText(.cardTitle).foregroundStyle(.primary)
                .accessibilityIdentifier("square.cloud.completed.empty")
        case .failed:
            status("活动列表没能打开", "The activity list did not open").accessibilityIdentifier("square.cloud.completed.error")
        case .offline:
            status("你离线了", "You're offline").accessibilityIdentifier("square.cloud.completed.offline")
        case .permission:
            status("没有已完成活动的读取权限", "No permission to read cleared activities").accessibilityIdentifier("square.cloud.completed.permission")
        }
        if case .failed = phase { retry } else if case .offline = phase { retry } else if case .permission = phase { retry }
        }
    }

    private func completedRow(_ item: SquareCompletedActivity) -> some View {
        HStack(spacing: CYSpacing.md) {
            RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous)
                .fill(CYColor.bgSurfaceSubtle)
                .frame(width: 56, height: 56)
                .overlay {
                    if let cover = item.cover, let url = URL(string: cover), cover.hasPrefix("https://") {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: item.name).cyText(.cardTitle).foregroundStyle(.primary).cyWrapText()
                Text(verbatim: copy("完成 \(SquareStravaCard.nodeText(done: item.doneCount, total: item.total)) · 已通关", "Done \(SquareStravaCard.nodeText(done: item.doneCount, total: item.total)) · cleared"))
                    .cyText(.meta).foregroundStyle(.secondary)
            }
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "checkmark").accessibilityHidden(true).foregroundStyle(CYColor.successText)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
    }

    private var retry: some View {
        Button { Task { phase = await load() } } label: {
            Text(verbatim: copy("重试", "Retry")).frame(minHeight: CYSpacing.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("square.cloud.completed.retry")
    }

    private func status(_ zh: String, _ en: String) -> some View {
        Text(verbatim: copy(zh, en)).cyText(.cardTitle).foregroundStyle(.primary)
    }

    private func choose(_ item: SquareCompletedActivity) {
        guard let topic = item.topicID, !topic.isEmpty else {
            onSelect(item, nil)
            return
        }
        generating = true
        previewTopicID = topic
        if reduceMotion {
            generating = false
            onSelect(item, nil)
        } else {
            generating = false
            onSelect(item, nil)
        }
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
    @State private var popover = false

    var body: some View {
        if post.strava.showsActivity {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if showsFollow {
                    Button { feed?.onFollow?(post) } label: {
                        Text(verbatim: locale.pick("关注", "Follow")).frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("square.cloud.follow")
                }
                SquareCloudStravaBlock(
                    card: post.strava,
                    title: post.referenceTitle,
                    onDoubleTapLike: feed?.onDoubleTapLike == nil ? nil : { feed?.onDoubleTapLike?(post) },
                    onRepost: canRepost ? { feed?.onRepost?(post) } : nil)
                if feed?.onActions != nil {
                    Button { feed?.onActions?(post) } label: {
                        Image(systemName: "ellipsis").frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(verbatim: locale.pick("帖文操作", "Post actions")))
                    .accessibilityIdentifier("square.cloud.cardActions")
                }
                if popover { popoverLayer }
                else if hasPopoverItems {
                    Button { popover = true } label: {
                        Text(verbatim: locale.pick("作者菜单", "Author menu")).frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("square.cloud.authorMenu")
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

    private var popoverItems: [(key: String, label: String, symbol: String)] {
        var items: [(key: String, label: String, symbol: String)] = []
        if showsFollow { items.append(("follow", locale.pick("关注", "Follow"), "plus")) }
        if feed?.onProfile != nil { items.append(("profile", locale.pick("访问主页", "Profile"), "person")) }
        if feed?.onReport != nil { items.append(("report", locale.pick("举报", "Report"), "exclamationmark.triangle")) }
        if feed?.onCopyLink != nil, canRepost { items.append(("copy", locale.pick("复制链接", "Copy link"), "link")) }
        return items
    }

    private var hasPopoverItems: Bool { !popoverItems.isEmpty }

    private var popoverLayer: some View {
        let anchor = SquarePopoverAnchor(left: 16, top: 44, bottom: 88)
        let placement = SquarePopoverLayout.place(anchor: anchor, panelWidth: 220, panelHeight: Double(popoverItems.count) * 44, windowWidth: 390, windowHeight: 700, minTop: 8, safeBottom: 680)
        return SquareCloudPopover(items: popoverItems, placement: placement, onPick: { key in
            popover = false
            switch key {
            case "follow": feed?.onFollow?(post)
            case "profile": feed?.onProfile?(post)
            case "report": feed?.onReport?(post)
            case "copy": feed?.onCopyLink?(post)
            default: break
            }
        }, onClose: { popover = false })
    }
}
