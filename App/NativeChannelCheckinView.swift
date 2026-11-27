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
            else if attempted { ContentUnavailableView("d7.checkin.unavailable", systemImage: "calendar.badge.checkmark") }
            else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("d7.channelActivity.loading"))
            }
        }.task { guard !attempted else { return }; attempted = true; if current() { flow = makeFlow() } }
    }
}
@MainActor private struct NativeChannelCheckinView: View {
    @Bindable var flow: NativeChannelCheckinFlow
    let current: () -> Bool
    let reminderDate: String?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var operation = NativeChannelActivityScreenTask()
    @State private var retry = false
    private var available: Bool { current() && scene == .active }
    var body: some View {
        Form {
            if !flow.isCurrent { Section { ContentUnavailableView("d7.checkin.unavailable", systemImage: "calendar.badge.checkmark") } }
            else {
                notice
                if let reminderDate {
                    LabeledContent("d7.checkin.reminderDate", value: shown(reminderDate))
                }
                if let pending = flow.pending {
                    Section {
                        LabeledContent("d7.checkin.date", value: shown(pending.checkinDate))
                        Button("d7.checkin.pending.check") {
                            run { current in await flow.recover(); guard current() else { return }; await refreshSettled() }
                        }
                        .disabled(flow.busy || !flow.service.canRecover)
                        Button("d7.checkin.pending.retry") { retry = true }
                            .disabled(flow.busy || !flow.service.canRecover || !flow.service.canWrite)
                    } header: { Text("d7.checkin.pending.title") }
                }
                if let review = flow.review {
                    Section {
                        LabeledContent("d7.checkin.date", value: shown(review.checkinDate))
                        Button("d7.checkin.review.confirm") {
                            run { current in await flow.confirm(); guard current() else { return }; await refreshSettled() }
                        }
                        .disabled(flow.busy)
                        Button("d7.channelActivity.cancel", role: .cancel) { flow.cancelReview() }
                            .disabled(flow.busy)
                    } header: { Text("d7.checkin.review.title") }
                }
                if let status = flow.status { statusSections(status) }
                else if !flow.busy, flow.phase != .redacted {
                    Section {
                        ContentUnavailableView {
                            Label("d7.checkin.loadFailed", systemImage: "calendar.badge.exclamationmark")
                        } actions: {
                            Button("d7.channelActivity.retry") { run { _ in await flow.refresh() } }
                                .buttonStyle(.bordered)
                                .disabled(!flow.service.canRead || flow.review != nil)
                        }
                    }
                }
                if flow.service.canRank {
                    NavigationLink { NativeChannelCheckinRankView(service: flow.service, current: current) } label: {
                        Label("d7.checkin.leaderboard", systemImage: "list.number")
                    }
                    .disabled(flow.busy || flow.review != nil)
                }
            }
        }
        .nativeChannelScreen()
        .navigationTitle(Text("d7.checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task(id: available) { if available { await flow.activate(current: current) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
        .confirmationDialog(appLocalized("d7.checkin.retry.title", locale: locale), isPresented: $retry, titleVisibility: .visible) {
            Button(appLocalized("d7.channelActivity.retry", locale: locale)) {
                run { current in await flow.retryOriginal(); guard current() else { return }; await refreshSettled() }
            }
            Button(appLocalized("d7.channelActivity.cancel", locale: locale), role: .cancel) {}
        }
    }
    @ViewBuilder private func statusSections(_ status: NativeChannelCheckinStatus) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("d7.checkin.streak.caption")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("d7.checkin.streak.value \(status.streak)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if status.checked {
                Label("d7.checkin.checkedToday", systemImage: "checkmark.seal.fill")
                    .fixedSize(horizontal: false, vertical: true)
                    // Check-in moment: the system symbol bounce and success haptic (quiet under Reduce Motion).
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : status.checked)
                    .sensoryFeedback(.success, trigger: status.checked) { _, new in new }
            } else {
                Label("d7.checkin.notCheckedToday", systemImage: "calendar")
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("d7.checkin.date", value: shown(status.checkinDate))
            if let fact = status.fact {
                LabeledContent("d7.checkin.checkedAt") { Text(Date(timeIntervalSince1970: Double(fact.checkedAt) / 1000), style: .time) }
            }
            if !status.checked, flow.review == nil, flow.pending == nil {
                Button { flow.prepare() } label: { Label("d7.checkin.checkIn", systemImage: "checkmark.seal") }
                    .disabled(!flow.canCheckin)
            }
            Button("d7.channelActivity.refresh") { run { _ in await flow.refresh() } }
                .disabled(flow.busy || flow.review != nil)
        }
        if status.makeupPolicy.configured, status.makeupPolicy.enabled, let days = status.makeupPolicy.windowDays, status.makeupPolicy.version != nil {
            Section { Text("d7.checkin.makeup \(days)").fixedSize(horizontal: false, vertical: true) }
        }
        Section {
            if status.history.isEmpty {
                ContentUnavailableView("d7.checkin.history.empty", systemImage: "calendar")
            }
            ForEach(status.history) { day in historyRow(day) }
        } header: { Text("d7.checkin.history") }
    }
    private func historyRow(_ day: NativeChannelCheckinHistory) -> some View {
        LabeledContent {
            if day.kind == "MAKEUP" {
                Label("d7.checkin.history.makeup", systemImage: "calendar.badge.plus")
            } else {
                Label("d7.checkin.history.checked", systemImage: "checkmark")
            }
        } label: {
            Label {
                Text(verbatim: shown(day.checkinDate))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: day.kind == "MAKEUP" ? "calendar.badge.plus" : "checkmark.seal")
                    .foregroundStyle(day.kind == "MAKEUP" ? Color.orange : Color.green)
            }
        }
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var notice: some View {
        switch flow.phase {
        case .reading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("d7.channelActivity.loading"))
        case .submitting:
            ProgressView("d7.checkin.submitting")
                .frame(maxWidth: .infinity)
        case .unknown: Text("d7.checkin.notice.unknown").nativeChannelNotice(systemImage: "clock")
        case .applied: Text("d7.checkin.notice.applied").fixedSize(horizontal: false, vertical: true)
        case .redacted: Text("d7.checkin.notice.redacted").nativeChannelNotice(systemImage: "checkmark.seal")
        case .expiredUnapplied: Text("d7.checkin.notice.expired").nativeChannelNotice(systemImage: "calendar.badge.exclamationmark")
        case .rejected(let code):
            if code == "SCREENING_PENDING" { Text("d7.channelActivity.rulesPending").nativeChannelNotice(systemImage: "exclamationmark.circle") }
            else { Text("d7.checkin.notice.rejected").nativeChannelNotice(systemImage: "exclamationmark.circle") }
        case .persistenceFailed: Text("d7.channelActivity.saveFailed").nativeChannelNotice(systemImage: "exclamationmark.circle")
        default: EmptyView()
        }
    }
    private func shown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func run(_ action: @escaping NativeChannelActivityScreenWork) { operation.start(current: { available && flow.isCurrent }, work: action) }
    private func refreshSettled() async { if flow.isCurrent, flow.pending == nil, flow.phase != .redacted, flow.phase != .persistenceFailed { await flow.refresh() } }
    private func stop() { operation.retire(); flow.deactivate(); retry = false }
}

@MainActor private struct NativeChannelCheckinRankView: View {
    let service: NativeChannelCheckinService
    let current: () -> Bool
    @Environment(\.scenePhase) private var scene
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var page: NativeChannelCheckinRank?
    @State private var busy = false
    @State private var failed = false
    @State private var generation: UInt64 = 0
    @State private var active = false
    private var available: Bool { current() && service.isCurrent && scene == .active }
    var body: some View {
        List {
            if !available { Section { ContentUnavailableView("d7.checkinRank.unavailable", systemImage: "list.number") } }
            else {
                if busy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("d7.channelActivity.loading"))
                }
                if failed { Section { ContentUnavailableView("d7.checkinRank.loadFailed", systemImage: "exclamationmark.circle") } }
                if let page {
                    Section { row(page.me) } header: { Text("d7.checkinRank.me") }
                    if page.othersVisible {
                        Section {
                            ForEach(page.list) { row($0) }
                            if page.list.isEmpty {
                                ContentUnavailableView("d7.checkin.history.empty", systemImage: "person.2")
                            }
                            if page.hasMore {
                                Button("d7.checkinRank.showTop50") { Task { await load(50) } }
                                    .disabled(busy)
                            }
                        } header: { Text("d7.checkinRank.top \(page.limit)") }
                    }
                }
                Section {
                    Button("d7.channelActivity.refresh") { Task { await load(10) } }
                        .disabled(busy)
                }
            }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .navigationTitle(Text("d7.checkinRank.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task(id: available) { if available { active = true; await load(10) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
    }
    private func row(_ row: NativeChannelCheckinRankRow) -> some View {
        let days = Text("d7.checkinRank.days \(row.days)").foregroundStyle(.secondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        return HStack(alignment: .center, spacing: 12) {
            Text(verbatim: row.rank.map { String($0) } ?? "—")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .leading)
            CheckinAvatar(avatar: row.avatar)
            VStack(alignment: .leading, spacing: 2) {
                rankName(row)
                    .fixedSize(horizontal: false, vertical: true)
                Text("d7.checkinRank.detail \(row.streak) \(row.makeupDays)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize { days }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 8)
                days
            }
        }
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private func rankName(_ row: NativeChannelCheckinRankRow) -> some View {
        if row.memberId == service.actorID { Text("d7.checkinRank.me") }
        else if let nickname = row.nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty { Text(verbatim: nickname) }
        else if row.nickname == nil { Text("d7.checkinRank.member") }
        else { Text(verbatim: "—") }
    }
    private func load(_ limit: Int) async {
        guard active, available, !busy else { return }; generation &+= 1; let run = generation; busy = true; page = nil; failed = false
        defer { if generation == run { busy = false } }
        do { let value = try await service.rank(limit: limit, source: { active && available && generation == run }); guard active, available, generation == run else { return }; page = value }
        catch { if active, available, generation == run { page = nil; failed = true } }
    }
    private func stop() { active = false; generation &+= 1; page = nil; busy = false; failed = false }
}

/// Person mark. An https avatar replaces the generated cover. Hidden from VoiceOver; the row name is the label.
private struct CheckinAvatar: View {
    let avatar: String?
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 40
    var body: some View {
        Group {
            if let avatar, let url = URL(string: avatar), url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
