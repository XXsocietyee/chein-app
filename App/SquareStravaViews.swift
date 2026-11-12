import SwiftUI

/// Activity block for a square or club post. Posts without an activity do not use this view.
struct SquareStravaActivityBlock: View {
    let facts: SquareStravaFacts
    var routeSnapshot: String? = nil
    var mediaScope: UUID = UUID()
    var onDoubleTapLike: (() -> Void)? = nil
    var onFollow: (() -> Void)? = nil
    var onRepost: ((String) async -> SquareStravaRepostStart)? = nil
    var confirmResult: ((String) async -> SquareStravaReread)? = nil
    @State private var ledger = SquareStravaWriteLedger()

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if facts.viewerFollowing == false, let onFollow {
                Button(action: onFollow) { Text("strava.follow", tableName: "SquareStrava").font(CYTypography.label) }
                    .buttonStyle(.borderless)
                    .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .accessibilityIdentifier("square.strava.follow")
            }
            if let title = facts.title {
                Text(verbatim: title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                    .accessibilityIdentifier("square.strava.title")
            }
            stats
            if facts.showsRoute {
                routeLine
            } else if let routeSnapshot, !routeSnapshot.isEmpty {
                NativeMediaGalleryEntry(sources: [routeSnapshot], scope: mediaScope, titleKey: "media.destination.squareImages", compact: true)
                    .accessibilityIdentifier("square.strava.map")
            }
            if facts.cleared { clearedBanner }
            actions
            if facts.showsKudos { kudos }
            if facts.showsComment, let author = facts.commentAuthor, let body = facts.commentBody {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    Text(verbatim: author).font(CYTypography.label).lineLimit(1)
                    Text(verbatim: body).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary).lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("square.strava.comment")
            }
            if let requestID = ledger.lockedRequestID, let confirmResult {
                SquareStravaConfirmResultButton(requestID: requestID, reread: confirmResult)
            } else if case .notSent = ledger.phase {
                Text("strava.notSent", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("square.strava.notSent")
            } else if case .rejected = ledger.phase {
                Text("strava.rejected", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("square.strava.rejected")
            }
        }
        .padding(CYSpacing.md)
        .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.strava.card")
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            metric("strava.stats.distance", value: facts.distanceText, unit: facts.distanceText == SquareCountDisplay.unknownMark ? nil : "strava.stats.km", id: "square.strava.distance")
            metric("strava.stats.pace", value: facts.paceText, unit: nil, id: "square.strava.pace")
            metric("strava.stats.duration", value: facts.durationText, unit: nil, id: "square.strava.duration")
        }
        .accessibilityIdentifier("square.strava.stats")
    }

    private func metric(_ label: String, value: String, unit: String?, id: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(LocalizedStringKey(stringLiteral: label), tableName: "SquareStrava").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
                Text(verbatim: value).font(CYTypography.numericBody).foregroundStyle(CYColor.textPrimary)
                if let unit { Text(LocalizedStringKey(stringLiteral: unit), tableName: "SquareStrava").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder private var routeLine: some View {
        let line = SquareStravaRouteLine(points: facts.route)
            .accessibilityLabel(Text("strava.map.preview", tableName: "SquareStrava"))
            .accessibilityIdentifier("square.strava.map")
        if let onDoubleTapLike {
            line.onTapGesture(count: 2, perform: onDoubleTapLike)
        } else {
            line
        }
        Text("strava.map.preview", tableName: "SquareStrava").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
    }

    private var clearedBanner: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "trophy.fill").foregroundStyle(CYNight.lantern).accessibilityHidden(true)
            Text("strava.cleared", tableName: "SquareStrava").font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.sm)
        .background(CYNight.ink2, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityIdentifier("square.strava.cleared")
    }

    private var actions: some View {
        HStack(spacing: CYSpacing.lg) {
            likeControl
            Label { Text(verbatim: facts.commentCountText).monospacedDigit() } icon: { Image(systemName: "bubble") }
                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("square.strava.comments")
            if facts.showsRepost { repostControl }
        }
    }

    @ViewBuilder private var likeControl: some View {
        let label = Label { Text(verbatim: facts.likeText).monospacedDigit() } icon: { Image(systemName: facts.liked ? "heart.fill" : "heart") }
            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        if let onDoubleTapLike {
            Button(action: onDoubleTapLike) { label }
                .buttonStyle(.borderless)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("square.strava.like")
        } else {
            label.accessibilityIdentifier("square.strava.like")
        }
    }

    @ViewBuilder private var repostControl: some View {
        let title = Text(facts.reposted == true ? "strava.repost.undo" : "strava.repost", tableName: "SquareStrava")
        let count = Text(verbatim: facts.repostCountText ?? SquareCountDisplay.unknownMark).monospacedDigit()
        let label = HStack(spacing: CYSpacing.xs) {
            Image(systemName: "arrow.2.squarepath")
            title
            count
        }
        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        if let onRepost {
            Button { Task { await repost(onRepost) } } label: { label }
                .buttonStyle(.borderless)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .disabled(ledger.locks)
                .accessibilityIdentifier("square.strava.repost")
        } else {
            label.accessibilityIdentifier("square.strava.repost")
        }
    }

    private var kudos: some View {
        HStack(spacing: -CYSpacing.sm) {
            ForEach(Array(facts.kudosAvatars.prefix(3).enumerated()), id: \.offset) { _, _ in
                Image(systemName: "person.crop.circle.fill").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                    .background(CYNight.ink1, in: Circle())
            }
            Text("strava.kudos", tableName: "SquareStrava").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: String(facts.kudosAvatars.count)).font(CYTypography.caption).monospacedDigit().foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.strava.kudos")
    }

    private func repost(_ send: (String) async -> SquareStravaRepostStart) async {
        let requestID = UUID().uuidString
        guard SquareStravaWriteLedger.valid(requestID), !ledger.locks else { return }
        switch await send(requestID) {
        case .notSent: ledger.noteNotSent()
        case .unknown: ledger.noteUnknown(requestID: requestID)
        case .rejected: ledger.noteRejected(requestID: requestID)
        }
    }
}

private struct SquareStravaRouteLine: View {
    let points: [SquareRoutePoint]
    @QuestifyReduceMotion private var reduceMotion
    @State private var drawn = false

    var body: some View {
        Canvas { context, size in
            let units = SquareStravaRouteMap.unitPoints(points)
            guard units.count >= 2 else { return }
            var path = Path()
            let inset = CYSpacing.lg
            let width = max(size.width - inset * 2, 1)
            let height = max(size.height - inset * 2, 1)
            for (index, unit) in units.enumerated() {
                let point = CGPoint(x: inset + unit.x * width, y: inset + unit.y * height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(CYNight.ember), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 160)
        .background(CYNight.indigo)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .opacity(reduceMotion || drawn ? 1 : 0)
        .onAppear { drawn = true }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: drawn)
        .accessibilityIdentifier("square.strava.route")
    }
}

struct SquareStravaConfirmResultButton: View {
    let requestID: String
    let reread: (String) async -> SquareStravaReread
    @State private var ledger = SquareStravaWriteLedger()
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: requestID).font(CYTypography.meta).monospacedDigit().textSelection(.enabled)
                .accessibilityIdentifier("square.strava.requestID")
            CYPillButton("strava.confirmResult", style: .secondary, fullWidth: false, tableName: "SquareStrava") {
                Task { await confirm() }
            }
            .disabled(busy || ledger.phase == .confirmed(requestID: requestID))
            .accessibilityIdentifier("square.strava.confirmResult")
            switch ledger.phase {
            case .confirmed:
                Text("strava.confirmed", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            case .rejected:
                Text("strava.rejected", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
            case .locked:
                Text("strava.unknown", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("square.strava.stillUnknown")
            default:
                EmptyView()
            }
        }
        .onAppear { if case .idle = ledger.phase { ledger.noteUnknown(requestID: requestID) } }
    }

    private func confirm() async {
        guard !busy, ledger.locks else { return }
        busy = true
        defer { busy = false }
        let reading = await reread(requestID)
        ledger.apply(reread: reading, savedRequestID: requestID)
    }
}

protocol SquareStravaDraftStoring {
    func load(accountID: Int) -> SquareStravaDraftBox
    func write(_ box: SquareStravaDraftBox, accountID: Int) -> Bool
    func loadPending(accountID: Int) -> String?
    func writePending(_ requestID: String?, accountID: Int) -> Bool
}

struct SquareStravaDraftDefaults: SquareStravaDraftStoring {
    func load(accountID: Int) -> SquareStravaDraftBox {
        guard accountID > 0, let data = UserDefaults.standard.data(forKey: key(accountID)),
              let box = try? JSONDecoder().decode(SquareStravaDraftBox.self, from: data) else { return SquareStravaDraftBox() }
        return box
    }
    func write(_ box: SquareStravaDraftBox, accountID: Int) -> Bool {
        guard accountID > 0, let data = try? JSONEncoder().encode(box) else { return false }
        UserDefaults.standard.set(data, forKey: key(accountID))
        return true
    }
    func loadPending(accountID: Int) -> String? {
        guard accountID > 0, let id = UserDefaults.standard.string(forKey: pendingKey(accountID)), SquareStravaWriteLedger.valid(id) else { return nil }
        return id
    }
    func writePending(_ requestID: String?, accountID: Int) -> Bool {
        guard accountID > 0 else { return false }
        let key = pendingKey(accountID)
        if let requestID {
            guard SquareStravaWriteLedger.valid(requestID) else { return false }
            UserDefaults.standard.set(requestID, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return true
    }
    private func key(_ accountID: Int) -> String { "strava.drafts.\(accountID)" }
    private func pendingKey(_ accountID: Int) -> String { "strava.pending.\(accountID)" }
}

private enum SquareStravaStep: Hashable { case drafts, activities, review }

/// Square composer. Drafts and the activity list are pages in this one sheet.
@MainActor struct SquarePostComposeView: View {
    let coordinator: SocialActionCoordinator
    var loadActivities: (() async -> Result<[SquareStravaActivityChoice], SquareStravaActivityIssue>)? = nil
    var confirmResult: (String) async -> SquareStravaReread = { _ in .stillUnknown }
    var draftsStore: any SquareStravaDraftStoring = SquareStravaDraftDefaults()
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selected: SquareStravaActivityChoice?
    @State private var box = SquareStravaDraftBox()
    @State private var draftIssue = false
    @State private var activityPhase: SquareStravaActivityPhase = .idle
    @State private var path: [SquareStravaStep] = []
    @State private var review: SocialActionReview?
    @State private var preparing = false
    @State private var busy = false
    @State private var issue: Error?
    @State private var revision = 0
    @State private var ownerID = UUID()
    @State private var draftID = UUID().uuidString
    @State private var lockedRequestID: String?
    @State private var confirmsDiscard = false
    @State private var discarded = false
    @State private var sessionIdentity: SocialAccountIdentity?
    @FocusState private var textFocused: Bool

    private var accountID: Int? { coordinator.identity.accountID }
    private var state: SocialActionState { _ = revision; return coordinator.state(target: .newPost) }
    private var canPublish: Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return accountID != nil && lockedRequestID == nil && !body.isEmpty && text.count <= 8000 && !state.locksForm && !preparing
            && coordinator.availability(for: .newPost(text: text), target: .newPost) == .approved
    }

    var body: some View {
        NavigationStack(path: $path) {
            compose
                .navigationTitle(Text("strava.compose.title", tableName: "SquareStrava"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { close() } label: { Text("strava.compose.cancel", tableName: "SquareStrava") }
                            .accessibilityIdentifier("social.editor.close")
                    }
                    if accountID != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { textFocused = false; path.append(.drafts) } label: { Text("strava.compose.drafts", tableName: "SquareStrava") }
                                .accessibilityIdentifier("square.strava.drafts")
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button { textFocused = false } label: { Text("action.done") }
                            .accessibilityIdentifier("social.editor.keyboardDone")
                    }
                }
                .navigationDestination(for: SquareStravaStep.self) { step in
                    switch step {
                    case .drafts: drafts.navigationTitle(Text("strava.drafts.title", tableName: "SquareStrava")).navigationBarTitleDisplayMode(.inline)
                    case .activities: activities.navigationTitle(Text("strava.activity.title", tableName: "SquareStrava")).navigationBarTitleDisplayMode(.inline)
                    case .review: reviewPage.navigationTitle(Text("strava.review.title", tableName: "SquareStrava")).navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
        .background(CYNight.ink0)
        .confirmationDialog("social.editor.discardTitle", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("social.editor.discard", role: .destructive) { discarded = true; text = ""; selected = nil; dismiss() }
            Button("social.editor.keepEditing", role: .cancel) {}
        } message: { Text("social.editor.discardMessage") }
        .onAppear {
            sessionIdentity = coordinator.identity
            reloadDrafts()
            if lockedRequestID == nil, let accountID, let pending = draftsStore.loadPending(accountID: accountID) { lockedRequestID = pending }
        }
        .onDisappear {
            if !discarded { persist() }
            if let sessionIdentity { coordinator.leaveScreen(target: .newPost, expectedIdentity: sessionIdentity, ownerID: ownerID) }
        }
        .accessibilityIdentifier("social.editor")
    }

    private var compose: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if accountID == nil {
                    Text("strava.signIn", tableName: "SquareStrava").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("square.strava.signIn")
                }
                if coordinator.availability == .syntheticOnly {
                    Text("strava.offline", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("square.strava.offline")
                } else if coordinator.availability(for: .newPost(text: " "), target: .newPost) == .disabled {
                    Text("strava.writesOff", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("square.strava.writesOff")
                }
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("strava.compose.placeholder", tableName: "SquareStrava").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                            .padding(.top, CYSpacing.sm)
                    }
                    TextEditor(text: $text).frame(minHeight: 160).focused($textFocused).disabled(state.locksForm)
                        .accessibilityLabel(Text("strava.compose.placeholder", tableName: "SquareStrava"))
                        .accessibilityIdentifier("social.editor.text")
                }
                Text(verbatim: "\(text.count)/8000").font(CYTypography.meta).monospacedDigit().foregroundStyle(text.count > 8000 ? CYColor.dangerText : CYColor.textSecondary)
                    .accessibilityIdentifier("square.strava.count")
                if text.count > 8000 {
                    Text("strava.compose.tooLong", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
                }
                if let selected {
                    HStack(spacing: CYSpacing.sm) {
                        Image(systemName: "flag").foregroundStyle(CYColor.textSecondary)
                        Text(verbatim: selected.name).font(CYTypography.bodyCompact).lineLimit(1)
                        Spacer(minLength: CYSpacing.sm)
                        Button { self.selected = nil } label: { Image(systemName: "xmark") }
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                            .accessibilityLabel(Text("strava.compose.clearActivity", tableName: "SquareStrava"))
                            .accessibilityIdentifier("square.strava.clearActivity")
                    }
                    .accessibilityIdentifier("square.strava.activityChip")
                }
                if loadActivities != nil {
                    Button { textFocused = false; path.append(.activities) } label: {
                        Label { Text("strava.compose.activity", tableName: "SquareStrava") } icon: { Image(systemName: "flag") }
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .disabled(state.locksForm)
                    .accessibilityIdentifier("square.strava.activity")
                }
                if draftIssue {
                    Text("strava.drafts.error", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("square.strava.draftError")
                }
                if let issue { SocialIssueView(error: issue) }
                if let lockedRequestID {
                    SquareStravaConfirmResultButton(requestID: lockedRequestID, reread: confirmResult)
                }
                CYPillButton("strava.compose.publish", tableName: "SquareStrava") {
                    textFocused = false
                    path.append(.review)
                }
                .disabled(!canPublish)
                .accessibilityIdentifier("social.editor.review")
            }
            .padding(CYSpacing.lg)
        }
        .background(CYNight.ink0)
    }

    private var drafts: some View {
        Group {
            if accountID == nil {
                Text("strava.signIn", tableName: "SquareStrava").font(CYTypography.body).padding(CYSpacing.lg)
            } else if box.drafts.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("strava.drafts.empty", tableName: "SquareStrava").font(CYTypography.cardTitle)
                    Text("strava.drafts.emptyDetail", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("square.strava.drafts.empty")
            } else {
                List(box.drafts) { draft in
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        Button { apply(draft) } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: draft.summary).font(CYTypography.body).lineLimit(2)
                                if let name = draft.activityName { Text(verbatim: name).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1) }
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("square.strava.draft.\(draft.id)")
                        Button { remove(draft) } label: { Image(systemName: "trash") }
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                            .accessibilityLabel(Text("strava.drafts.delete", tableName: "SquareStrava"))
                            .accessibilityIdentifier("square.strava.draft.delete.\(draft.id)")
                    }
                }
                .accessibilityIdentifier("square.strava.drafts.list")
            }
        }
        .background(CYNight.ink0)
    }

    private var activities: some View {
        Group {
            switch activityPhase {
            case .idle, .loading:
                CYSkeleton().padding(CYSpacing.lg).accessibilityLabel(Text("strava.activity.loading", tableName: "SquareStrava"))
                    .accessibilityIdentifier("square.strava.activity.loading")
            case .empty:
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text("strava.activity.empty", tableName: "SquareStrava").font(CYTypography.cardTitle)
                    Text("strava.activity.emptyDetail", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("square.strava.activity.empty")
            case .failed(let issue):
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text(LocalizedStringKey(stringLiteral: issue.key), tableName: "SquareStrava").font(CYTypography.body)
                    if issue.allowsRetry {
                        CYPillButton("strava.activity.retry", style: .secondary, fullWidth: false, tableName: "SquareStrava") { Task { await reloadActivities() } }
                            .accessibilityIdentifier("square.strava.activity.retry")
                    }
                }
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("square.strava.activity.error")
            case .ready(let rows):
                List(rows) { row in
                    Button { selected = row; path.removeAll { $0 == .activities } } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: row.name).font(CYTypography.body).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                            Text(verbatim: SquareStravaFacts.pace(done: row.doneCount, total: row.total, provided: row.doneCount != nil || row.total != nil))
                                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(row.id == selected?.id ? CYNight.selection.opacity(0.22) : CYNight.ink1)
                    .accessibilityIdentifier("square.strava.activity.\(row.id)")
                }
                .accessibilityIdentifier("square.strava.activity.list")
            }
        }
        .background(CYNight.ink0)
        .task { await reloadActivities() }
    }

    private var reviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text(verbatim: text).font(CYTypography.body).textSelection(.enabled)
                if let selected {
                    Text("strava.review.activity", tableName: "SquareStrava").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: selected.name).font(CYTypography.body)
                    Text("strava.review.activityNote", tableName: "SquareStrava").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                if preparing { CYSkeleton().accessibilityLabel(Text("social.loading")) }
                if let issue { SocialIssueView(error: issue) }
                status
                if let lockedRequestID {
                    SquareStravaConfirmResultButton(requestID: lockedRequestID, reread: confirmResult)
                }
                CYPillButton("strava.review.submit", tableName: "SquareStrava") { Task { await submit() } }
                    .disabled(busy || review == nil || state != .reviewing || coordinator.availability != .approved)
                    .accessibilityIdentifier("social.review.confirm")
            }
            .padding(CYSpacing.lg)
        }
        .background(CYNight.ink0)
        .task { await prepare() }
        .accessibilityIdentifier("social.review")
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .submitting, .preparing, .preflighting:
            Text("social.loading").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        case .notSent:
            Text("social.notSent").font(CYTypography.meta)
        case .rejected:
            Text("social.rejected").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
        case .outcomeUnknown:
            Text("social.unknown").font(CYTypography.meta).accessibilityIdentifier("social.state.unknown")
        case .acknowledged(let receipt):
            Text(LocalizedStringKey(receipt.synthetic ? "social.simulated" : "social.acknowledged")).font(CYTypography.meta)
                .accessibilityIdentifier("social.state.acknowledged")
        default:
            EmptyView()
        }
    }

    private func close() {
        textFocused = false
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected != nil { confirmsDiscard = true } else { dismiss() }
    }
    private func reloadDrafts() {
        guard let accountID else { box = SquareStravaDraftBox(); return }
        box = draftsStore.load(accountID: accountID)
    }
    private func persist() {
        guard let accountID else { return }
        var next = box
        guard next.save(accountID: accountID, text: text, activityID: selected?.id, activityName: selected?.name, now: Date().timeIntervalSince1970, id: draftID) != nil else { return }
        draftIssue = !draftsStore.write(next, accountID: accountID)
        if !draftIssue { box = next }
    }
    private func apply(_ draft: SquareStravaDraft) {
        draftID = draft.id
        text = draft.text
        if let id = draft.activityID, let name = draft.activityName {
            selected = SquareStravaActivityChoice(id: id, name: name, topicID: nil, doneCount: nil, total: nil, cover: nil)
        }
        path.removeAll { $0 == .drafts }
    }
    private func remove(_ draft: SquareStravaDraft) {
        guard let accountID else { return }
        var next = box
        guard next.delete(id: draft.id, accountID: accountID) else { return }
        if draftsStore.write(next, accountID: accountID) { box = next; draftIssue = false } else { draftIssue = true }
    }
    private func reloadActivities() async {
        guard let loadActivities else { activityPhase = .failed(.notConfigured); return }
        activityPhase = .loading
        let result = await loadActivities()
        if Task.isCancelled { return }
        switch result {
        case .success(let rows): activityPhase = rows.isEmpty ? .empty : .ready(rows)
        case .failure(let issue): activityPhase = .failed(issue)
        }
    }
    private func prepare() async {
        let identity = coordinator.identity
        guard review == nil, !preparing, identity.accountID != nil else { return }
        guard lockedRequestID == nil else { return }
        let command = SocialActionCommand.newPost(text: text, activityID: selected?.id)
        preparing = true
        issue = nil
        defer { preparing = false; revision += 1 }
        do {
            let value = try await coordinator.prepare(command, target: .newPost, ownerID: ownerID, expectedIdentity: identity)
            guard !Task.isCancelled, coordinator.identity == identity else { coordinator.cancel(value); return }
            review = value
        } catch {
            if coordinator.identity == identity { issue = error }
        }
    }
    private func submit() async {
        guard let review, !busy, state == .reviewing else { return }
        busy = true
        defer { busy = false; revision += 1 }
        await coordinator.confirm(review)
        switch coordinator.state(target: .newPost) {
        case .outcomeUnknown:
            let id = review.command.idempotencyKey ?? lockedRequestID
            lockedRequestID = id
            if let accountID, let id { _ = draftsStore.writePending(id, accountID: accountID) }
        case .acknowledged:
            discarded = true
            clearDraft()
            lockedRequestID = nil
            if let accountID { _ = draftsStore.writePending(nil, accountID: accountID) }
        case .notSent, .rejected:
            lockedRequestID = nil
            if let accountID { _ = draftsStore.writePending(nil, accountID: accountID) }
        default:
            break
        }
    }
    private func clearDraft() {
        guard let accountID else { return }
        var next = box
        guard next.delete(id: draftID, accountID: accountID) else { return }
        if draftsStore.write(next, accountID: accountID) { box = next }
    }
}

private enum SquareStravaActivityPhase: Equatable {
    case idle, loading, empty, ready([SquareStravaActivityChoice]), failed(SquareStravaActivityIssue)
}

private extension SquareStravaActivityIssue {
    var key: String {
        switch self {
        case .offline: return "strava.activity.offline"
        case .permission: return "strava.activity.permission"
        case .notConfigured: return "strava.activity.notConfigured"
        case .failed: return "strava.activity.failed"
        }
    }
    var allowsRetry: Bool { self == .offline || self == .failed }
}
