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
            // MP `playkit-steps` body: eyebrow → 走起来 · 刷新 · 落章 → today / goal 步 → co2 → remain → 刷新步数.
            Label("playkit.steps.eyebrow", systemImage: "figure.walk")
                .font(.headline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("nativePlatform.steps.host")
            Text("nativePlatform.steps.title").font(.footnote).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CYSpacing.lg) { stepIcons }
                VStack(alignment: .leading, spacing: CYSpacing.sm) { stepIcons }
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            if let goal = segment["goal"].integer, goal > 0 {
                let today = max(0, segment["todaySteps"].integer ?? 0)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                        Text(today, format: .number).font(.largeTitle.bold()).monospacedDigit()
                            .contentTransition(.numericText())
                        Text("playkit.steps.goalSteps \(goal)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(min(today, goal)), total: Double(goal))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("playkit.steps.today")
            }
            ForEach(["co2Label", "remainLabel"], id: \.self) { key in
                if let line = segment[key].text, !line.isEmpty {
                    Text(verbatim: line).font(.footnote).foregroundStyle(.secondary)
                }
            }
            // MP `readError` (报过失败、还没同步到步数) and the skipped station line.
            if segment["skipped"].bool == true {
                Text("playkit.sensor.skipped").font(.footnote).foregroundStyle(.secondary)
            } else if (segment["failedReads"].integer ?? 0) > 0, (segment["todaySteps"].integer ?? 0) <= 0, segment["reached"].bool != true {
                Label("playkit.steps.readError", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            }
            if let enrollment = runtime?.enrollment {
                NavigationLink("nativeEnrollment.manage") { NativeEnrollmentView(model: enrollment, privacyURL: runtime?.acceptance.privacyNoticeURL) }
                    .accessibilityIdentifier("nativeEnrollment.open")
            }
            if let stage, let runtime { NativeStepsControls(stage: stage, advanced: advanced, privacyURL: runtime.acceptance.privacyNoticeURL) }
            else {
                Label("nativePlatform.disabled", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nativePlatform.steps.disabled")
            }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task(id: advanced.state?.sessionID) { await runtime?.enrollment?.load(); if let id = advanced.state?.sessionID { stage = runtime?.stepModel(for: id) } }
    }
}

extension NativeStepsHostView {
    /// MP `stepIcons('steps')`: 走起来 · 刷新 · 落章 (numbered, symbol + short label).
    @ViewBuilder var stepIcons: some View {
        Label("playkit.steps.icon.walk", systemImage: "1.circle.fill")
        Label("playkit.steps.icon.refresh", systemImage: "2.circle.fill")
        Label("playkit.steps.icon.stamp", systemImage: "3.circle.fill")
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
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nativePlatform.steps.phase")
            if let issue = stage.issue { issueText("nativePlatform.issue." + issue.rawValue, identifier: "nativePlatform.steps.issue") }
            if stage.phase == "review", let sample = stage.reading, let challenge = stage.challenge {
                Text(verbatim: String(sample.steps))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("nativePlatform.steps.count")
                LabeledContent("nativePlatform.steps.day") { Text(verbatim: challenge.dayKey).monospacedDigit() }
                Text("nativePlatform.steps.sharePurpose")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Task { await stage.submitReviewed(); await refresh() } } label: {
                    Label("nativePlatform.steps.send", systemImage: "paperplane.fill")
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!advanced.isCurrent)
                    .accessibilityIdentifier("nativePlatform.steps.send")
                Button("nativePlatform.cancel", role: .cancel) { stage.interrupt() }
                    .buttonStyle(.borderless)
            } else if stage.phase == "unknown" {
                Text("nativePlatform.steps.unknownBoundary")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Task { await stage.retryExact(); await refresh() } } label: {
                    Label("nativePlatform.steps.retryExact", systemImage: "arrow.clockwise")
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!advanced.isCurrent)
                    .accessibilityIdentifier("nativePlatform.steps.retry")
            } else if ["reading", "signing", "submitting"].contains(stage.phase) {
                ProgressView().accessibilityLabel(Text("nativePlatform.working"))
                Button("nativePlatform.cancel", role: .cancel) { stage.interrupt() }
                    .buttonStyle(.borderless)
            } else {
                if let receipt = stage.receipt {
                    if let baseline = receipt["baselineSteps"].integer {
                        LabeledContent("nativePlatform.steps.baseline") { Text(verbatim: String(baseline)).monospacedDigit() }
                    }
                    if let delta = receipt["acceptedDelta"].integer {
                        LabeledContent("nativePlatform.steps.delta") { Text(verbatim: String(delta)).monospacedDigit() }
                    }
                }
                Button { purpose = true } label: {
                    Label("nativePlatform.steps.read", systemImage: "figure.walk")
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!advanced.canInteract || !stage.supported)
                    .accessibilityIdentifier("nativePlatform.steps.read")
                if !stage.supported {
                    Text("nativePlatform.issue.unsupported")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .cySheet(isPresented: $purpose) {
            NavigationStack {
                Form {
                    Section {
                        Text("nativePlatform.steps.purpose").fixedSize(horizontal: false, vertical: true)
                        Text("nativePlatform.steps.integrity").fixedSize(horizontal: false, vertical: true)
                        if let privacyURL { Link("nativePlatform.privacy", destination: privacyURL) }
                    }
                }
                .navigationTitle("nativePlatform.steps.purposeTitle").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("nativePlatform.cancel") { purpose = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("nativePlatform.steps.continue") {
                            purpose = false
                            guard let state = advanced.state else { return }
                            Task { await stage.read(sessionID: state.sessionID, version: state.version); await refresh() }
                        }
                        .disabled(!advanced.canInteract)
                        .accessibilityIdentifier("nativePlatform.steps.consent")
                    }
                }
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
            .foregroundStyle(.secondary)
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
            Label("nativePlatform.reminder.title", systemImage: "bell")
                .font(.headline)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("nativePlatform.reminder.host")
            // Mini-program line: "开放时段 23:00 – 01:00", then a large countdown to the next opening.
            if segment["openFrom"].text != nil || segment["openTo"].text != nil {
                Text("playkitLegacy.window.range \(clock(segment["openFrom"].text)) \(clock(segment["openTo"].text))")
                    .font(.body.weight(.medium)).monospacedDigit()
                    .foregroundStyle(.tint)
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
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Legacy subscribed is deliberately neither read nor written here.
            if let stage {
                if let window = stage.window {
                    LabeledContent("nativePlatform.timeZone") { Text(verbatim: window.timeZone.isEmpty ? "—" : window.timeZone) }
                    LabeledContent("nativePlatform.reminder.next") { Text(verbatim: formatted(window.nextOpenAt, zone: window.timeZone)).monospacedDigit() }
                    Label(LocalizedStringKey(window.openNow ? "nativePlatform.reminder.open" : "nativePlatform.reminder.closed"), systemImage: window.openNow ? "clock" : "clock.badge.xmark")
                        .foregroundStyle(window.openNow ? Color.green : Color.secondary)
                }
                if let scheduled = stage.scheduled {
                    Label("nativePlatform.reminder.scheduled", systemImage: "bell.badge")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativePlatform.reminder.scheduled")
                    Text(verbatim: formatted(scheduled.fireAt, zone: scheduled.timeZone))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Button("nativePlatform.reminder.cancel", role: .destructive) { stage.cancel() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("nativePlatform.reminder.cancel")
                } else {
                    Button { reviewed = stage.window } label: {
                        Label("nativePlatform.reminder.enable", systemImage: "bell")
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(stage.window == nil || stage.phase == "scheduling" || !active)
                        .accessibilityIdentifier("nativePlatform.reminder.enable")
                }
                if let issue = readIssue ?? stage.issue {
                    Text(LocalizedStringKey("nativePlatform.issue." + issue.rawValue))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativePlatform.reminder.issue")
                }
                Button { Task { await refresh() } } label: {
                    Label("nativePlatform.reminder.refresh", systemImage: "arrow.clockwise")
                }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!active)
                    .accessibilityIdentifier("nativePlatform.reminder.refresh")
            } else {
                Label("nativePlatform.disabled", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
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
        .cySheet(isPresented: Binding(get: { reviewed != nil }, set: { if !$0 { reviewed = nil } })) {
            if let reviewed, let stage {
                NavigationStack {
                    Form {
                        Section {
                            Text("nativePlatform.reminder.purpose").fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: formatted(reviewed.nextOpenAt, zone: reviewed.timeZone)).monospacedDigit()
                            Text(verbatim: reviewed.timeZone.isEmpty ? "—" : reviewed.timeZone)
                            if let url = runtime?.acceptance.privacyNoticeURL { Link("nativePlatform.privacy", destination: url) }
                        }
                    }
                    .navigationTitle("nativePlatform.reminder.purposeTitle").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("nativePlatform.cancel") { self.reviewed = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("nativePlatform.reminder.confirm") {
                                self.reviewed = nil
                                let title = appLocalized("nativePlatform.reminder.notificationTitle", locale: locale)
                                let body = appLocalized("nativePlatform.reminder.notificationBody", locale: locale)
                                Task { await stage.enable(reviewed: reviewed, title: title, body: body) }
                            }
                            .accessibilityIdentifier("nativePlatform.reminder.consent")
                        }
                    }
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
            .font(.largeTitle.bold()).monospacedDigit()
    }
    private var afterLabel: some View {
        Text("playkitLegacy.window.after").font(.footnote).foregroundStyle(.secondary)
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
