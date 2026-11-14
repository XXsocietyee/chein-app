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
            else {
                CYSkeleton()
                    .padding(CYSpacing.lg)
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
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var burst: CGFloat = 160
    @State private var operation = NativeChannelActivityScreenTask()
    @State private var retry = false
    private var available: Bool { current() && scene == .active }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("d7.checkin.title") {
                    CheckinCover(seed: "checkin", symbol: "calendar.badge.checkmark")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                .listRowSeparator(.hidden)
            }
            if !flow.isCurrent { CYEmptyState(systemImage: "calendar.badge.checkmark", "d7.checkin.unavailable").listRowBackground(Color.clear) }
            else {
                notice
                if let reminderDate {
                    LabeledContent("d7.checkin.reminderDate", value: shown(reminderDate))
                        .font(CYTypography.body)
                }
                if let pending = flow.pending {
                    Section {
                        LabeledContent("d7.checkin.date", value: shown(pending.checkinDate))
                        CYPillButton("d7.checkin.pending.check", style: .secondary) {
                            run { current in await flow.recover(); guard current() else { return }; await refreshSettled() }
                        }
                        .disabled(flow.busy || !flow.service.canRecover)
                        .listRowBackground(Color.clear)
                        CYPillButton("d7.checkin.pending.retry", style: .tertiary) { retry = true }
                            .disabled(flow.busy || !flow.service.canRecover || !flow.service.canWrite)
                            .listRowBackground(Color.clear)
                    } header: { CYSectionHeader("d7.checkin.pending.title").textCase(nil) }
                }
                if let review = flow.review {
                    Section {
                        LabeledContent("d7.checkin.date", value: shown(review.checkinDate))
                        CYPillButton("d7.checkin.review.confirm") {
                            run { current in await flow.confirm(); guard current() else { return }; await refreshSettled() }
                        }
                        .disabled(flow.busy)
                        .listRowBackground(Color.clear)
                        Button("d7.channelActivity.cancel", role: .cancel) { flow.cancelReview() }
                            .font(CYTypography.label)
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            .disabled(flow.busy)
                    } header: { CYSectionHeader("d7.checkin.review.title").textCase(nil) }
                }
                if let status = flow.status { statusSections(status) }
                else if !flow.busy, flow.phase != .redacted {
                    CYEmptyState(systemImage: "calendar.badge.exclamationmark", "d7.checkin.loadFailed", actionTitle: "d7.channelActivity.retry", actionStyle: flow.review == nil ? .primary : .secondary) {
                        run { _ in await flow.refresh() }
                    }
                    .disabled(!flow.service.canRead || flow.review != nil)
                    .listRowBackground(Color.clear)
                }
                if flow.service.canRank {
                    NavigationLink { NativeChannelCheckinRankView(service: flow.service, current: current) } label: {
                        CYListRow("d7.checkin.leaderboard", trailing: .none) { CYRowIcon(systemImage: "list.number") }
                    }
                    .disabled(flow.busy || flow.review != nil)
                }
            }
        }
        .nativeChannelScreen()
        .cyHeroScreen()
        .privacySensitive()
        .task(id: available) { if available { await flow.activate(current: current) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
        .sheet(isPresented: $retry) {
            CYConfirmSheet(
                title: appLocalized("d7.checkin.retry.title", locale: locale),
                message: "",
                confirmTitle: appLocalized("d7.channelActivity.retry", locale: locale),
                cancelTitle: appLocalized("d7.channelActivity.cancel", locale: locale)
            ) {
                run { current in await flow.retryOriginal(); guard current() else { return }; await refreshSettled() }
            }
            .cyDomainSheet(detents: [.peek, .half])
        }
    }
    @ViewBuilder private func statusSections(_ status: NativeChannelCheckinStatus) -> some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("d7.checkin.streak.caption")
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("d7.checkin.streak.value \(status.streak)")
                    .font(CYTypography.data2XL)
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if status.checked {
                Label("d7.checkin.checkedToday", systemImage: "checkmark.seal.fill")
                    .font(CYTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
                    // Check-in moment: the seal bounces, success haptic, light confetti (all quiet under Reduce Motion).
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : status.checked)
                    .sensoryFeedback(.success, trigger: status.checked) { _, new in new }
                    .overlay {
                        CYConfettiBurst(trigger: status.checked ? 1 : 0)
                            .frame(height: burst)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
            } else {
                Label("d7.checkin.notCheckedToday", systemImage: "calendar")
                    .font(CYTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("d7.checkin.date", value: shown(status.checkinDate))
            if let fact = status.fact {
                LabeledContent("d7.checkin.checkedAt") { Text(Date(timeIntervalSince1970: Double(fact.checkedAt) / 1000), style: .time) }
            }
            if !status.checked, flow.review == nil, flow.pending == nil {
                CYPillButton("d7.checkin.checkIn", systemImage: "checkmark.seal") { flow.prepare() }
                    .disabled(!flow.canCheckin)
                    .listRowBackground(Color.clear)
            }
            CYPillButton("d7.channelActivity.refresh", style: .secondary) { run { _ in await flow.refresh() } }
                .disabled(flow.busy || flow.review != nil)
                .listRowBackground(Color.clear)
        }
        if status.makeupPolicy.configured, status.makeupPolicy.enabled, let days = status.makeupPolicy.windowDays, status.makeupPolicy.version != nil {
            Section { Text("d7.checkin.makeup \(days)").font(CYTypography.body).fixedSize(horizontal: false, vertical: true) }
        }
        Section {
            if status.history.isEmpty {
                Label("d7.checkin.history.empty", systemImage: "calendar")
                    .font(CYTypography.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
            }
            ForEach(status.history) { day in historyRow(day) }
        } header: { CYSectionHeader("d7.checkin.history").textCase(nil) }
    }
    private func historyRow(_ day: NativeChannelCheckinHistory) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            CheckinCover(seed: day.checkinDate, symbol: day.kind == "MAKEUP" ? "calendar.badge.plus" : "checkmark.seal", side: 40)
            Text(verbatim: shown(day.checkinDate))
                .font(CYTypography.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            if day.kind == "MAKEUP" {
                CYStatusChip("d7.checkin.history.makeup", tone: .warning, systemImage: "calendar.badge.plus")
            } else {
                CYStatusChip("d7.checkin.history.checked", tone: .success, systemImage: "checkmark")
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var notice: some View {
        switch flow.phase {
        case .reading:
            CYSkeleton()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("d7.channelActivity.loading"))
                .listRowBackground(Color.clear)
        case .submitting:
            ProgressView("d7.checkin.submitting")
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        case .unknown: Text("d7.checkin.notice.unknown").nativeChannelNotice(systemImage: "clock")
        case .applied: Text("d7.checkin.notice.applied").font(CYTypography.body).fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var page: NativeChannelCheckinRank?
    @State private var busy = false
    @State private var failed = false
    @State private var generation: UInt64 = 0
    @State private var active = false
    private var available: Bool { current() && service.isCurrent && scene == .active }
    var body: some View {
        List {
            Section {
                CYHeroHeader("d7.checkinRank.title")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            if !available { CYEmptyState(systemImage: "list.number", "d7.checkinRank.unavailable").listRowBackground(Color.clear) }
            else {
                if busy {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("d7.channelActivity.loading"))
                        .listRowBackground(Color.clear)
                }
                if failed { CYEmptyState(systemImage: "exclamationmark.circle", "d7.checkinRank.loadFailed", kind: .failure).listRowBackground(Color.clear) }
                if let page {
                    Section { row(page.me) } header: { CYSectionHeader("d7.checkinRank.me").textCase(nil) }
                    if page.othersVisible {
                        Section {
                            ForEach(page.list) { row($0) }
                            if page.list.isEmpty {
                                Label("d7.checkin.history.empty", systemImage: "person.2")
                                    .font(CYTypography.body)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if page.hasMore {
                                CYPillButton("d7.checkinRank.showTop50", style: .secondary) { Task { await load(50) } }
                                    .disabled(busy)
                                    .listRowBackground(Color.clear)
                            }
                        } header: { CYSectionHeader("d7.checkinRank.top \(page.limit)").textCase(nil) }
                    }
                }
                CYPillButton("d7.channelActivity.refresh", style: failed && page == nil ? .primary : .secondary) { Task { await load(10) } }
                    .disabled(busy)
                    .listRowBackground(Color.clear)
            }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .cyHeroScreen()
        .privacySensitive()
        .task(id: available) { if available { active = true; await load(10) } else { stop() } }
        .onChange(of: current()) { _, valid in if !valid { stop() } }
        .onChange(of: scene) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
    }
    private func row(_ row: NativeChannelCheckinRankRow) -> some View {
        let days = Text("d7.checkinRank.days \(row.days)").font(CYTypography.numericBody).foregroundStyle(palette.textSecondary).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        return HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Text(verbatim: row.rank.map { String($0) } ?? "—")
                .font(CYTypography.numericBody)
                .foregroundStyle(palette.textSecondary)
                .frame(minWidth: 28, alignment: .leading)
            CheckinAvatar(seed: row.memberId, avatar: row.avatar)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                rankName(row)
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("d7.checkinRank.detail \(row.streak) \(row.makeupDays)")
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textTertiary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize { days }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: CYSpacing.sm)
                days
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
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

/// Banner art for the check-in hero. Decorative.
private struct CheckinCover: View {
    let seed: String
    var symbol: String
    var side: CGFloat? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var banner: CGFloat = 112
    var body: some View {
        CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, cornerRadius: side.map { $0 / 2 } ?? CYRadius.lg)
            .frame(width: side, height: side ?? banner)
            .frame(maxWidth: side == nil ? .infinity : nil)
            .clipShape(RoundedRectangle(cornerRadius: side.map { $0 / 2 } ?? CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Person mark. An https avatar replaces the generated cover. Hidden from VoiceOver; the row name is the label.
private struct CheckinAvatar: View {
    let seed: String
    let avatar: String?
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 40
    var body: some View {
        Group {
            if let avatar, let url = URL(string: avatar), url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { CYCoverArt(seed: seed, symbol: "person.fill", showsDebugLabel: false) }
                }
            } else {
                CYCoverArt(seed: seed, symbol: "person.fill", showsDebugLabel: false)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
