import SwiftUI

@MainActor struct NativeChannelCheckinLaunchView: View {
    let makeFlow: () -> NativeChannelCheckinFlow?
    let current: () -> Bool
    var reminderDate: String? = nil
    @State private var flow: NativeChannelCheckinFlow?
    @State private var attempted = false
    var body: some View {
        Group {
            if let flow { NativeChannelCheckinView(flow: flow, current: current, reminderDate: reminderDate) }
            else if attempted { CYEmptyState(systemImage: "calendar.badge.checkmark", "d7.checkin.unavailable") }
            else { CYSkeleton() }
        }.task { guard !attempted else { return }; attempted = true; if current() { flow = makeFlow() } }
    }
}
@MainActor private struct NativeChannelCheckinView: View {
    @Bindable var flow: NativeChannelCheckinFlow
    let current: () -> Bool
    let reminderDate: String?
    @Environment(\.scenePhase) private var scene
    @State private var operation = NativeChannelActivityScreenTask()
    @State private var retry = false
    private var available: Bool { current() && scene == .active }
    var body: some View {
        Form {
            CYHeroHeader("d7.checkin.title")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if !flow.isCurrent { CYEmptyState(systemImage: "calendar.badge.checkmark", "d7.checkin.unavailable") }
            else {
                notice
                if let reminderDate { LabeledContent("d7.checkin.reminderDate", value: reminderDate) }
                if let pending = flow.pending {
                    Section("d7.checkin.pending.title") {
                        LabeledContent("d7.checkin.date", value: pending.checkinDate)
                        CYPillButton("d7.checkin.pending.check", style: .secondary) { run { current in await flow.recover(); guard current() else { return }; await refreshSettled() } }.disabled(flow.busy || !flow.service.canRecover)
                        CYPillButton("d7.checkin.pending.retry", style: .secondary) { retry = true }.disabled(flow.busy || !flow.service.canRecover || !flow.service.canWrite)
                    }
                }
                if let review = flow.review {
                    Section("d7.checkin.review.title") {
                        LabeledContent("d7.checkin.date", value: review.checkinDate)
                        CYPillButton("d7.checkin.review.confirm") { run { current in await flow.confirm(); guard current() else { return }; await refreshSettled() } }.disabled(flow.busy)
                        Button("d7.channelActivity.cancel", role: .cancel) { flow.cancelReview() }.font(Theme.Font.button).frame(minHeight: 44).disabled(flow.busy)
                    }
                }
                if let status = flow.status {
                    Section {
                        QuestifyHeroValue(value: Text("d7.checkin.streak.value \(status.streak)"), caption: Text("d7.checkin.streak.caption"))
                            .monospacedDigit()
                        if status.checked {
                            Label("d7.checkin.checkedToday", systemImage: "checkmark.seal.fill").fixedSize(horizontal: false, vertical: true)
                                // Check-in moment: the seal bounces, success haptic, light confetti (all quiet under Reduce Motion).
                                .symbolEffect(.bounce, options: .nonRepeating, value: status.checked)
                                .sensoryFeedback(.success, trigger: status.checked) { _, new in new }
                                .overlay { CYConfettiBurst(trigger: status.checked ? 1 : 0).frame(height: 160) }
                        }
                        else { Label("d7.checkin.notCheckedToday", systemImage: "calendar").fixedSize(horizontal: false, vertical: true) }
                        LabeledContent("d7.checkin.date", value: status.checkinDate)
                        if let fact = status.fact {
                            LabeledContent("d7.checkin.checkedAt") { Text(Date(timeIntervalSince1970: Double(fact.checkedAt) / 1000), style: .time) }
                        }
                        if !status.checked, flow.review == nil, flow.pending == nil {
                            CYPillButton("d7.checkin.checkIn") { flow.prepare() }.disabled(!flow.canCheckin)
                        }
                        CYPillButton("d7.channelActivity.refresh", style: .secondary) { run { _ in await flow.refresh() } }.disabled(flow.busy || flow.review != nil)
                    }
                    if status.makeupPolicy.configured, status.makeupPolicy.enabled, let days = status.makeupPolicy.windowDays, status.makeupPolicy.version != nil {
                        Section { Text("d7.checkin.makeup \(days)").fixedSize(horizontal: false, vertical: true) }
                    }
                    Section("d7.checkin.history") {
                        if status.history.isEmpty { Text("d7.checkin.history.empty").foregroundStyle(.secondary) }
                        ForEach(status.history) { day in
                            LabeledContent {
                                if day.kind == "MAKEUP" { Text("d7.checkin.history.makeup") } else { Text("d7.checkin.history.checked") }
                            } label: { Text(verbatim: day.checkinDate) }
                        }
                    }
                } else if !flow.busy, flow.phase != .redacted {
                    ContentUnavailableView {
                        Label("d7.checkin.loadFailed", systemImage: "calendar.badge.exclamationmark")
                    } actions: {
                        CYPillButton("d7.channelActivity.retry", style: .secondary) { run { _ in await flow.refresh() } }.disabled(!flow.service.canRead || flow.review != nil)
                    }
                }
                if flow.service.canRank {
                    NavigationLink("d7.checkin.leaderboard") { NativeChannelCheckinRankView(service: flow.service, current: current) }
                        .disabled(flow.busy || flow.review != nil)
                }
            }
        }
        .font(Theme.Font.body)
        .nativeChannelScreen()
        .cyGroupedSurface()
        .cyHeroScreen().privacySensitive()
        .task(id: available) { if available { await flow.activate(current: current) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
        .confirmationDialog("d7.checkin.retry.title", isPresented: $retry, titleVisibility: .visible) {
            Button("d7.channelActivity.retry") { run { current in await flow.retryOriginal(); guard current() else { return }; await refreshSettled() } }
            Button("d7.channelActivity.cancel", role: .cancel) {}
        }
    }
    @ViewBuilder private var notice: some View {
        switch flow.phase {
        case .reading: CYSkeleton()
        case .submitting: CYSkeleton()
        case .unknown: Text("d7.checkin.notice.unknown").nativeChannelNotice(systemImage: "clock")
        case .applied: Text("d7.checkin.notice.applied").font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
        case .redacted: Text("d7.checkin.notice.redacted").nativeChannelNotice(systemImage: "checkmark.seal")
        case .expiredUnapplied: Text("d7.checkin.notice.expired").nativeChannelNotice(systemImage: "calendar.badge.exclamationmark")
        case .rejected(let code):
            if code == "SCREENING_PENDING" { Text("d7.channelActivity.rulesPending").nativeChannelNotice(systemImage: "exclamationmark.circle") }
            else { Text("d7.checkin.notice.rejected").nativeChannelNotice(systemImage: "exclamationmark.circle") }
        case .persistenceFailed: Text("d7.channelActivity.saveFailed").nativeChannelNotice(systemImage: "exclamationmark.circle")
        default: EmptyView()
        }
    }
    private func run(_ action: @escaping NativeChannelActivityScreenWork) { operation.start(current: { available && flow.isCurrent }, work: action) }
    private func refreshSettled() async { if flow.isCurrent, flow.pending == nil, flow.phase != .redacted, flow.phase != .persistenceFailed { await flow.refresh() } }
    private func stop() { operation.retire(); flow.deactivate(); retry = false }
}

@MainActor private struct NativeChannelCheckinRankView: View {
    let service: NativeChannelCheckinService
    let current: () -> Bool
    @Environment(\.scenePhase) private var scene
    @State private var page: NativeChannelCheckinRank?
    @State private var busy = false
    @State private var failed = false
    @State private var generation: UInt64 = 0
    @State private var active = false
    private var available: Bool { current() && service.isCurrent && scene == .active }
    var body: some View {
        List {
            if !available { CYEmptyState(systemImage: "list.number", "d7.checkinRank.unavailable") }
            else {
                if busy { CYSkeleton() }
                if failed { CYEmptyState(systemImage: "exclamationmark.circle", "d7.checkinRank.loadFailed") }
                if let page {
                    Section("d7.checkinRank.me") { row(page.me) }
                    if page.othersVisible {
                        Section("d7.checkinRank.top \(page.limit)") {
                            ForEach(page.list) { row($0) }
                            if page.list.isEmpty { Text("d7.checkin.history.empty").foregroundStyle(.secondary) }
                            if page.hasMore { CYPillButton("d7.checkinRank.showTop50", style: .secondary) { Task { await load(50) } }.disabled(busy) }
                        }
                    }
                }
                CYPillButton("d7.channelActivity.refresh", style: .secondary) { Task { await load(10) } }.disabled(busy)
            }
        }.font(Theme.Font.body).nativeChannelScreen().listStyle(.insetGrouped).navigationTitle("d7.checkinRank.title").privacySensitive()
        .task(id: available) { if available { active = true; await load(10) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
    }
    private func row(_ row: NativeChannelCheckinRankRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s3) {
            Text(verbatim: row.rank.map { String($0) } ?? "—").font(Theme.Font.body.weight(.semibold)).monospacedDigit().frame(minWidth: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                Group {
                    if row.memberId == service.actorID { Text("d7.checkinRank.me") }
                    else if let nickname = row.nickname { Text(verbatim: nickname) }
                    else { Text("d7.checkinRank.member") }
                }.font(Theme.Font.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text("d7.checkinRank.detail \(row.streak) \(row.makeupDays)").font(Theme.Font.label).foregroundStyle(.secondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.s2)
            Text("d7.checkinRank.days \(row.days)").monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
    private func load(_ limit: Int) async {
        guard active, available, !busy else { return }; generation &+= 1; let run = generation; busy = true; page = nil; failed = false
        defer { if generation == run { busy = false } }
        do { let value = try await service.rank(limit: limit, source: { active && available && generation == run }); guard active, available, generation == run else { return }; page = value }
        catch { if active, available, generation == run { page = nil; failed = true } }
    }
    private func stop() { active = false; generation &+= 1; page = nil; busy = false; failed = false }
}
