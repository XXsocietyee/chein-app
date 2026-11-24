import SwiftUI

/// Read-only P045 calendar. It uses the existing service's access/me preflight;
/// it neither creates a new transport nor enables any dormant write capability.
@MainActor final class ClubEventCalendarReadModel: ObservableObject {
    @Published private(set) var reportSnapshot: ClubGovernanceSnapshot?
    @Published private(set) var snapshot: ClubEventCalendarSnapshot?
    @Published private(set) var activityOverview: ClubActivityOverview?
    @Published private(set) var context: ClubGovernanceReadContext?
    @Published private(set) var loading = false
    @Published private(set) var failure: ClubGovernanceFailure?
    private(set) var generation: UInt64 = 0
    private(set) var snapshotGeneration: UInt64 = 0
    private var active = true

    func invalidate() {
        generation &+= 1; reportSnapshot = nil; snapshot = nil; activityOverview = nil; context = nil; loading = false; failure = nil
    }
    func suspend() {
        active = false; generation &+= 1; loading = false
    }
    func resume() { active = true }
    func live(_ expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> Bool {
        expected.operation == .topics && (expected.scope.clubID ?? 0) > 0 &&
        (expected.identity?.accountID ?? 0) > 0 && access.isConfigured &&
        expected.identity == access.identity && expected.authorizationGeneration == access.authorizationGeneration &&
        expected.accessIdentity == ObjectIdentifier(access)
    }
    func accepted(_ expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> Bool {
        context == expected && snapshot != nil && live(expected, access: access)
    }
    func canSelect(_ expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess) -> Bool {
        active && !loading && accepted(expected, access: access)
    }
    func load(_ expected: ClubGovernanceReadContext, access: any ClubGovernanceAccess, now: () -> Date = Date.init) async {
        invalidate(); let revision = generation
        guard active, !Task.isCancelled else { return }
        guard (expected.identity?.accountID ?? 0) > 0 else { failure = .signedOut; return }
        guard live(expected, access: access) else { failure = .notConfigured; return }
        loading = true
        defer { if revision == generation { loading = false } }
        func check() throws {
            guard active, revision == generation, live(expected, access: access), !Task.isCancelled else { throw CancellationError() }
        }
        do {
            // This check occurs before the first dispatch and after each await.
            try check()
            let response = try await access.read(.topics, scope: expected.scope, options: [:], check: check)
            try check()
            let projected = try ClubActivityOverview(snapshot: response, context: expected, now: now())
            reportSnapshot = response; context = expected; snapshotGeneration = revision; snapshot = projected.calendar; activityOverview = projected
        } catch {
            guard active, revision == generation, live(expected, access: access), !Task.isCancelled else { return }
            failure = error as? ClubGovernanceFailure ?? .malformed
        }
    }
}

@MainActor struct ClubEventCalendarView: View {
    let clubID: Int
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext
    var reportClub: ClubRecord? = nil
    var reportReader: (any ClubReading)? = nil
    @StateObject private var reportPresentation = ClubActivityReportPresentation()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = ClubEventCalendarReadModel()
    @State private var month = ClubEventMonth()
    @State private var calendarMode = false
    @State private var selectedDay: ClubEventDay?
    @State private var destination: ClubEventTopicRoute?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var daySide: CGFloat = 44
    @ScaledMetric(relativeTo: .headline) private var coverSide: CGFloat = 56
    private var readContext: ClubGovernanceReadContext {
        .init(operation: .topics, scope: .init(clubID: clubID), identity: identity,
              viewerRevision: governance.viewerRevision, authorizationGeneration: governance.access.authorizationGeneration,
              accessIdentity: ObjectIdentifier(governance.access))
    }
    private var reportHost: ClubActivityReportPresentation.Host {
        .init(context: readContext, readerID: reportReader.map { ObjectIdentifier($0) }, club: reportClub)
    }
    private var accepted: ClubEventCalendarSnapshot? {
        model.accepted(readContext, access: governance.access) ? model.snapshot : nil
    }
    var body: some View {
        List {
            Picker("club.calendar.display", selection: $calendarMode) {
                Text("club.calendar.list").tag(false)
                Text("club.calendar.monthView").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("club.calendar.mode")
            .clubCalendarRow()
            if model.loading {
                CYSkeleton()
                    .accessibilityIdentifier("club.calendar.loading")
                    .clubCalendarRow()
            }
            if let failure = model.failure {
                CYNoteBanner(text: Text(LocalizedStringKey(failure.localizationKey)), symbol: "exclamationmark.triangle", tone: .danger)
                    .accessibilityIdentifier("club.calendar.error")
                    .clubCalendarRow()
            }
            if let snapshot = accepted {
                if calendarMode { calendar(snapshot) }
                else if let overview = model.activityOverview {
                    let renderedContext = readContext, renderedGeneration = model.snapshotGeneration
                    ClubActivityListContent(overview: overview, canOpen: governance.topicDestination != nil && model.canSelect(readContext, access: governance.access), open: { row in
                        guard overview == model.activityOverview, renderedContext == readContext, renderedGeneration == model.snapshotGeneration,
                              overview.rows.contains(row) else { return }
                        select(row.id)
                    }, report: { row in AnyView(reportButton(row.id)) })
                }
            }
            NavigationLink {
                ClubCalendarSessionsView(context: readContext, access: governance.access)
            } label: { sessionsRow }
                .accessibilityIdentifier("club.calendar.sessions.open")
                .clubCalendarRow()
            CYPillButton("club.gov.refresh", style: model.failure == nil ? .secondary : .primary, systemImage: "arrow.clockwise") { refresh() }
                .disabled(model.loading)
                .accessibilityIdentifier("club.calendar.refresh")
                .clubCalendarRow()
        }
        .listStyle(.plain)
        .cyGroupedSurface()
        .cyDomainPageBackground()
        .cyHaptic(.selection, trigger: selectedDay?.id ?? "")
        .background {
            if let item = reportPresentation.presented {
                ClubActivityReportSheetOwner(item: item, presentation: reportPresentation,
                    coordinator: governance.coordinator, dismissed: reportDismissed).id(item.id)
            }
        }
        .navigationDestination(item: $destination) { target in
            if current(target), let detail = governance.topicDestination {
                detail(target.topicID).id(target.id)
            } else {
                Color.clear.onAppear { if destination?.id == target.id { destination = nil } }
            }
        }
        .task(id: reportHost) { await loadCalendar() }
        .onChange(of: reportHost) { _, host in
            if reportPresentation.bind(host, active: scenePhase == .active) { governance.coordinator.cancelReview() }
            destination = nil; selectedDay = nil; model.invalidate()
            if reportPresentation.visible && scenePhase == .active { scheduleCalendarRead() }
        }
        .onChange(of: scenePhase) { _, phase in
            if reportPresentation.bind(reportHost, active: phase == .active) { governance.coordinator.cancelReview() }
            if phase != .active { model.suspend() }
            else if reportPresentation.visible { model.resume(); scheduleCalendarRead() }
        }
        .onAppear {
            if reportPresentation.appear(reportHost, active: scenePhase == .active) { governance.coordinator.cancelReview() }
            if scenePhase == .active { model.resume() }
            if reportPresentation.hasPendingReturn { scheduleCalendarRead(returning: true) }
            else if model.context == nil { scheduleCalendarRead() }
        }
        .onDisappear {
            reportPresentation.disappear()
            if reportPresentation.presented == nil { model.suspend() }
        }
        .refreshable { closeReport(); destination = nil; await loadCalendar() }
        .cyPageTitle("club.calendar.title")
    }
    @ViewBuilder private func calendar(_ snapshot: ClubEventCalendarSnapshot) -> some View {
        Section {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .disabled(month.shifted(by: -1) == nil)
                    .accessibilityLabel("club.calendar.previous")
                    .accessibilityIdentifier("club.calendar.previous")
                Spacer(minLength: CYSpacing.sm)
                Text(verbatim: month.key)
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("club.calendar.month")
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                Button { shift(1) } label: { Image(systemName: "chevron.forward") }
                    .buttonStyle(.borderless)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .disabled(month.shifted(by: 1) == nil)
                    .accessibilityLabel("club.calendar.next")
                    .accessibilityIdentifier("club.calendar.next")
            }
            Text("club.calendar.startDates")
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            let cells = month.cells(events: snapshot.events)
            if dynamicTypeSize.isAccessibilitySize {
                // Keep long names and every event reachable with large text.
                ForEach(cells.filter { !$0.events.isEmpty }) { cell in
                    Text(verbatim: cell.day.id)
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(cell.events) { event in eventRow(event, showDate: false) }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CYSpacing.xs), count: 7), spacing: CYSpacing.sm) {
                    ForEach(1...7, id: \.self) { day in
                        Text(LocalizedStringKey("club.calendar.weekday." + String(day)))
                            .cyText(.caption)
                            .foregroundStyle(palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }
                    ForEach(cells) { cell in
                        let selected = selectedDay == cell.day
                        Button { selectedDay = cell.day } label: {
                            VStack(spacing: CYSpacing.xxs) {
                                Text(cell.day.day, format: .number)
                                    .font(selected ? CYTypography.numericBody : CYTypography.meta)
                                    .monospacedDigit()
                                    .foregroundStyle(selected ? palette.actionPrimaryFg : (cell.inMonth ? palette.textPrimary : palette.textTertiary))
                                    .frame(minWidth: daySide, minHeight: daySide)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .background(selected ? palette.actionPrimaryBg : Color.clear, in: Circle())
                                Circle()
                                    .fill(cell.events.isEmpty ? Color.clear : palette.info)
                                    .frame(width: 5, height: 5)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("club.calendar.day \(cell.day.id) \(cell.events.count)"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("club.calendar.day.\(cell.day.id)")
                    }
                }
                if let selectedDay {
                    Text(verbatim: selectedDay.id)
                        .cyText(.sectionTitle)
                        .foregroundStyle(palette.textPrimary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, CYSpacing.sm)
                        .accessibilityAddTraits(.isHeader)
                    let events = snapshot.events.filter { $0.startDay == selectedDay }
                    if events.isEmpty {
                        Label("club.calendar.noDayEvents", systemImage: "calendar.badge.clock")
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                            .labelStyle(.titleAndIcon)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    }
                    ForEach(events) { event in eventRow(event, showDate: false) }
                } else {
                    Text("club.calendar.pickDay")
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !cells.contains(where: { $0.inMonth && !$0.events.isEmpty }) {
                CYEmptyState(systemImage: "calendar", "club.calendar.noMonthEvents")
                    .accessibilityIdentifier("club.calendar.monthEmpty")
            }
        }
        if !snapshot.undated.isEmpty {
            Section("club.calendar.undated") {
                Text("club.calendar.undatedHint")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(snapshot.undated) { event in eventRow(event, showDate: false) }
            }
        }
    }
    @ViewBuilder private func eventRow(_ event: ClubCalendarEvent, showDate: Bool) -> some View {
        if governance.topicDestination != nil {
            Button { select(event.id) } label: { eventLabel(event, showDate: showDate) }
                .accessibilityIdentifier("club.calendar.topic.\(event.id)")
        } else { eventLabel(event, showDate: showDate) }
        reportButton(event.id)
    }
    private func eventLabel(_ event: ClubCalendarEvent, showDate: Bool) -> some View {
        let title = event.name ?? appLocalized("club.calendar.untitled", locale: locale)
        let meta: String? = showDate ? (event.startDay?.id ?? appLocalized("club.calendar.dateUnknown", locale: locale)) : nil
        return CYListRow(verbatim: title, meta: meta, trailing: governance.topicDestination != nil ? .chevron : .none) {
            CYCoverArt(seed: event.name ?? String(event.id), symbol: "calendar", showsDebugLabel: false)
                .frame(width: coverSide, height: coverSide)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityHidden(true)
        }
    }
    /// The sessions title lives in ClubCalendarSessions, not the default catalog.
    private var sessionsRow: some View {
        HStack(spacing: CYSpacing.md) {
            CYRowIcon(systemImage: "calendar.badge.clock")
            Text("sessions.title", tableName: "ClubCalendarSessions")
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
    }
    private func reportSource(_ topicID: Int) -> ClubActivityReportSource? {
        guard reportPresentation.canOpen(reportHost), destination == nil, let reportClub, let reportReader,
              reportReader.clubIdentity == identity, reportReader.isClubConfigured,
              model.canSelect(readContext, access: governance.access), let snapshot = model.reportSnapshot else { return nil }
        return .init(topicID: topicID, club: reportClub, snapshot: snapshot, context: readContext, generation: model.snapshotGeneration)
    }
    @ViewBuilder private func reportButton(_ topicID: Int) -> some View {
        if ClubActivityReportExposure.playerEntryVisible, let source = reportSource(topicID) {
            Button { openReport(source) } label: { Label("club.activityReport.action", systemImage: "flag") }
                .buttonStyle(.borderless).accessibilityIdentifier("club.activityReport.open.\(topicID)")
        }
    }
    private func openReport(_ source: ClubActivityReportSource) {
        guard let reportReader, let current = reportSource(source.topicID),
              current.context == source.context, current.generation == source.generation,
              current.authorID == source.authorID else { return }
        let host = reportHost, owner = reportPresentation, readModel = model, access = governance.access
        let flow = ClubActivityReportFlow(source: source, reader: reportReader, access: access, sourceIsCurrent: { [weak owner, weak readModel] in
            guard let owner, let readModel else { return false }
            return owner.isPresenting(source.id, host: host) && readModel.snapshotGeneration == source.generation &&
                readModel.generation == source.generation && readModel.accepted(source.context, access: access)
        })
        _ = owner.open(flow, host: host)
    }
    private func closeReport() {
        if reportPresentation.cancel() { governance.coordinator.cancelReview() }
    }
    private func reportDismissed(_ id: UUID) {
        guard reportPresentation.dismissed(id) else { return }
        governance.coordinator.cancelReview()
        if !reportPresentation.visible { model.suspend(); return }
        scheduleCalendarRead(returning: true)
    }
    private func scheduleCalendarRead(returning: Bool = false) {
        guard let ticket = reportPresentation.beginRead(reportHost, returning: returning) else { return }
        Task { await performCalendarRead(ticket) }
    }
    private func loadCalendar() async {
        guard let ticket = reportPresentation.beginRead(reportHost) else { return }
        await performCalendarRead(ticket)
    }
    private func performCalendarRead(_ ticket: ClubActivityReportPresentation.ReadTicket) async {
        defer { reportPresentation.endRead(ticket) }
        guard reportPresentation.canRead(ticket), !Task.isCancelled else { return }
        destination = nil; selectedDay = nil; model.resume()
        await model.load(ticket.host.context, access: governance.access)
    }
    private func shift(_ delta: Int) {
        guard let next = month.shifted(by: delta) else { return }
        month = next; selectedDay = nil
    }
    private func refresh() {
        closeReport(); destination = nil
        scheduleCalendarRead()
    }
    private func select(_ topicID: Int) {
        guard destination == nil, governance.topicDestination != nil,
              model.canSelect(readContext, access: governance.access), let snapshot = accepted else { return }
        destination = .init(topicID: topicID, snapshot: snapshot, context: readContext, snapshotGeneration: model.snapshotGeneration)
    }
    private func current(_ route: ClubEventTopicRoute) -> Bool {
        governance.topicDestination != nil && model.accepted(readContext, access: governance.access) &&
        route.isCurrent(snapshot: accepted, context: readContext, snapshotGeneration: model.snapshotGeneration)
    }
}

private extension View {
    func clubCalendarRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
