import SwiftUI

@MainActor struct NativeStepsHostView: View {
    @Bindable var advanced: PlayAdvancedCoordinator
    let segment: PlayWireValue
    @Environment(\.nativePlatformRuntime) private var runtime
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: NativeStepCoordinator?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                CYRowIcon(systemImage: "figure.walk")
                CYSectionHeader("nativePlatform.steps.title")
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("nativePlatform.steps.host")
            if let goal = segment["goal"].integer {
                LabeledContent("playkit.walk.goal") {
                    Text("playkit.steps.goalSteps \(goal)").cyText(.numericBody).monospacedDigit()
                }
            }
            ForEach(["co2Label", "remainLabel"], id: \.self) { key in
                if let line = segment[key].text, !line.isEmpty {
                    Text(verbatim: line).cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
            if let enrollment = runtime?.enrollment {
                NavigationLink("nativeEnrollment.manage") { NativeEnrollmentView(model: enrollment, privacyURL: runtime?.acceptance.privacyNoticeURL) }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("nativeEnrollment.open")
            }
            if let stage, let runtime { NativeStepsControls(stage: stage, advanced: advanced, privacyURL: runtime.acceptance.privacyNoticeURL) }
            else {
                Label("nativePlatform.disabled", systemImage: "lock.shield")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nativePlatform.steps.disabled")
            }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task(id: advanced.state?.sessionID) { await runtime?.enrollment?.load(); if let id = advanced.state?.sessionID { stage = runtime?.stepModel(for: id) } }
    }
}

@MainActor struct NativeStepsControls: View {
    @Bindable var stage: NativeStepCoordinator
    @Bindable var advanced: PlayAdvancedCoordinator
    let privacyURL: URL?
    @State private var purpose = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Text(LocalizedStringKey("nativePlatform.steps.phase." + stage.phase))
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nativePlatform.steps.phase")
            if let issue = stage.issue { issueText("nativePlatform.issue." + issue.rawValue, identifier: "nativePlatform.steps.issue") }
            if stage.phase == "review", let sample = stage.reading, let challenge = stage.challenge {
                Text(verbatim: String(sample.steps))
                    .cyText(.data2XL)
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nativePlatform.steps.count")
                LabeledContent("nativePlatform.steps.day") { Text(verbatim: challenge.dayKey).monospacedDigit() }
                Text("nativePlatform.steps.sharePurpose")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("nativePlatform.steps.send", systemImage: "paperplane.fill") { Task { await stage.submitReviewed(); await refresh() } }
                    .disabled(!advanced.isCurrent)
                    .accessibilityIdentifier("nativePlatform.steps.send")
                Button("nativePlatform.cancel", role: .cancel) { stage.interrupt() }
                    .buttonStyle(CYPillButtonStyle(style: .tertiary, fullWidth: true))
            } else if stage.phase == "unknown" {
                Text("nativePlatform.steps.unknownBoundary")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("nativePlatform.steps.retryExact", systemImage: "arrow.clockwise") { Task { await stage.retryExact(); await refresh() } }
                    .disabled(!advanced.isCurrent)
                    .accessibilityIdentifier("nativePlatform.steps.retry")
            } else if ["reading", "signing", "submitting"].contains(stage.phase) {
                CYSkeleton().accessibilityLabel(Text("nativePlatform.working"))
                Button("nativePlatform.cancel", role: .cancel) { stage.interrupt() }
                    .buttonStyle(CYPillButtonStyle(style: .tertiary, fullWidth: true))
            } else {
                if let receipt = stage.receipt {
                    if let baseline = receipt["baselineSteps"].integer {
                        LabeledContent("nativePlatform.steps.baseline") { Text(verbatim: String(baseline)).cyText(.numericBody).monospacedDigit() }
                    }
                    if let delta = receipt["acceptedDelta"].integer {
                        LabeledContent("nativePlatform.steps.delta") { Text(verbatim: String(delta)).cyText(.numericBody).monospacedDigit() }
                    }
                }
                CYPillButton("nativePlatform.steps.read", systemImage: "figure.walk") { purpose = true }
                    .disabled(!advanced.canInteract || !stage.supported)
                    .accessibilityIdentifier("nativePlatform.steps.read")
                if !stage.supported {
                    Text("nativePlatform.issue.unsupported")
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .sheet(isPresented: $purpose) {
            NavigationStack {
                Form {
                    Section {
                        Text("nativePlatform.steps.purpose").fixedSize(horizontal: false, vertical: true)
                        Text("nativePlatform.steps.integrity").fixedSize(horizontal: false, vertical: true)
                        if let privacyURL { Link("nativePlatform.privacy", destination: privacyURL) }
                    }
                    CYPillButton("nativePlatform.steps.continue") {
                        purpose = false
                        guard let state = advanced.state else { return }
                        Task { await stage.read(sessionID: state.sessionID, version: state.version); await refresh() }
                    }
                    .disabled(!advanced.canInteract)
                    .accessibilityIdentifier("nativePlatform.steps.consent")
                    .listRowBackground(Color.clear)
                }
                .cyText(.body)
                .cyGroupedSurface()
                .navigationTitle("nativePlatform.steps.purposeTitle").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("nativePlatform.cancel") { purpose = false } } }
                .roleThemedPresentation()
            }
        }
        .onChange(of: advanced.state?.version) { _, version in if let version { stage.observeVersion(version) } }
        .cyHapticEvent(.sensorStepsProgress, trigger: stage.receipt?["acceptedDelta"].integer) { old, next in
            (next ?? 0) > (old ?? 0)
        }
        .cyHapticEvent(.sensorStepsComplete, trigger: stage.receipt?["completed"].bool) { old, next in
            old != true && next == true
        }
        .onChange(of: advanced.isCurrent) { _, current in if !current { purpose = false; stage.invalidate() } }
        .onChange(of: scenePhase) { _, next in if next == .background { purpose = false; stage.interrupt() } }
        .onDisappear { stage.interrupt() }
    }
    private func issueText(_ key: String, identifier: String) -> some View {
        Text(LocalizedStringKey(key))
            .cyText(.body)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }
    private func refresh() async { if stage.latestState != nil && advanced.isCurrent { await advanced.refreshAuthoritative() } }
}

@MainActor struct NativeTimeWindowHostView: View {
    @Bindable var advanced: PlayAdvancedCoordinator
    let segment: PlayWireValue
    @Environment(\.nativePlatformRuntime) private var runtime
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: NativeLocalReminderCoordinator?
    @State private var reviewed: NativeTimeWindow?
    @State private var readIssue: NativePlatformIssue?
    @Environment(\.locale) private var locale
    private var active: Bool { runtime?.isCurrent == true }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                CYRowIcon(systemImage: "bell")
                CYSectionHeader("nativePlatform.reminder.title")
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("nativePlatform.reminder.host")
            // Mini-program line: "开放时段 23:00 – 01:00", then a large countdown to the next opening.
            if segment["openFrom"].text != nil || segment["openTo"].text != nil {
                Text("playkitLegacy.window.range \(clock(segment["openFrom"].text)) \(clock(segment["openTo"].text))")
                    .cyText(.bodyMedium).monospacedDigit()
                    .foregroundStyle(CYColor.brand)
                    .accessibilityIdentifier("nativePlatform.reminder.range")
            }
            if let window = stage?.window, !window.openNow {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline, spacing: CYSpacing.sm) { countdown(window.countdownSeconds); afterLabel }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) { countdown(window.countdownSeconds); afterLabel }
                }
                .accessibilityIdentifier("nativePlatform.reminder.countdown")
            } else if stage?.window == nil, readIssue != nil {
                countdown(nil)
                    .accessibilityIdentifier("nativePlatform.reminder.countdown")
            }
            Text("nativePlatform.reminder.boundary")
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // Legacy subscribed is deliberately neither read nor written here.
            if let stage {
                if let window = stage.window {
                    LabeledContent("nativePlatform.timeZone") { Text(verbatim: window.timeZone.isEmpty ? "—" : window.timeZone) }
                    LabeledContent("nativePlatform.reminder.next") { Text(verbatim: formatted(window.nextOpenAt, zone: window.timeZone)).monospacedDigit() }
                    CYStatusChip(window.openNow ? "nativePlatform.reminder.open" : "nativePlatform.reminder.closed", tone: window.openNow ? .success : .neutral, systemImage: window.openNow ? "clock" : "clock.badge.xmark")
                }
                if let scheduled = stage.scheduled {
                    Label("nativePlatform.reminder.scheduled", systemImage: "bell.badge")
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativePlatform.reminder.scheduled")
                    Text(verbatim: formatted(scheduled.fireAt, zone: scheduled.timeZone))
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Button("nativePlatform.reminder.cancel", role: .destructive) { stage.cancel() }
                        .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                        .accessibilityIdentifier("nativePlatform.reminder.cancel")
                } else {
                    CYPillButton("nativePlatform.reminder.enable", systemImage: "bell") { reviewed = stage.window }
                        .disabled(stage.window == nil || stage.phase == "scheduling" || !active)
                        .accessibilityIdentifier("nativePlatform.reminder.enable")
                }
                if let issue = readIssue ?? stage.issue {
                    Text(LocalizedStringKey("nativePlatform.issue." + issue.rawValue))
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativePlatform.reminder.issue")
                }
                CYPillButton("nativePlatform.reminder.refresh", style: .secondary, systemImage: "arrow.clockwise") { Task { await refresh() } }
                    .disabled(!active)
                    .accessibilityIdentifier("nativePlatform.reminder.refresh")
            } else {
                Label("nativePlatform.disabled", systemImage: "lock.shield")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nativePlatform.reminder.disabled")
            }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task(id: "\(advanced.activityID):\(advanced.topicID):\(advanced.nodeID)") {
            stage = runtime?.reminderModel(activityID: advanced.activityID, topicID: advanced.topicID, nodeID: advanced.nodeID); await refresh()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if Task.isCancelled { return }
                if scenePhase == .active, let stage { await stage.refresh(stage.window) }
            }
        }
        .onChange(of: segment) { _, _ in reviewed = nil; Task { await refresh() } }
        .onChange(of: active) { _, current in if !current { reviewed = nil; stage?.invalidate() } }
        .onChange(of: scenePhase) { _, next in if next == .active { Task { await refresh() } } else { reviewed = nil } }
        .sheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil } })) {
            if let reviewed, let stage {
                NavigationStack {
                    Form {
                        Section {
                            Text("nativePlatform.reminder.purpose").fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: formatted(reviewed.nextOpenAt, zone: reviewed.timeZone)).monospacedDigit()
                            Text(verbatim: reviewed.timeZone.isEmpty ? "—" : reviewed.timeZone)
                            if let url = runtime?.acceptance.privacyNoticeURL { Link("nativePlatform.privacy", destination: url) }
                        }
                        CYPillButton("nativePlatform.reminder.confirm") {
                            self.reviewed = nil
                            let title = appLocalized("nativePlatform.reminder.notificationTitle", locale: locale)
                            let body = appLocalized("nativePlatform.reminder.notificationBody", locale: locale)
                            Task { await stage.enable(reviewed: reviewed, title: title, body: body) }
                        }
                        .accessibilityIdentifier("nativePlatform.reminder.consent")
                        .listRowBackground(Color.clear)
                    }
                    .cyText(.body)
                    .cyGroupedSurface()
                    .navigationTitle("nativePlatform.reminder.purposeTitle").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("nativePlatform.cancel") { self.reviewed = nil } } }
                    .roleThemedPresentation()
                }
            }
        }
    }
    private func clock(_ value: String?) -> String {
        let shown = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return shown.isEmpty ? "—" : shown
    }
    private func countdown(_ left: Int?) -> some View {
        let text: String
        if let left, left >= 0 {
            text = String(format: "%02d:%02d:%02d", left / 3600, (left % 3600) / 60, left % 60)
        } else {
            text = "—"
        }
        return Text(verbatim: text)
            .cyText(.data2XL).italic().monospacedDigit()
            .foregroundStyle(palette.textPrimary)
    }
    private var afterLabel: some View {
        Text("playkitLegacy.window.after").cyText(.meta).foregroundStyle(palette.textSecondary)
    }
    private func refresh() async {
        guard let runtime, let stage, active else { return }
        do {
            let window = try await runtime.service.timeWindow(activityID: advanced.activityID, topicID: advanced.topicID, nodeID: advanced.nodeID)
            guard active else { stage.invalidate(); return }
            readIssue = nil; await stage.refresh(window)
        } catch { readIssue = error as? NativePlatformIssue ?? .network; await stage.refresh(nil) }
    }
    private func formatted(_ date: Date, zone: String) -> String {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateStyle = .medium; formatter.timeStyle = .short; return formatter.string(from: date)
    }
}
