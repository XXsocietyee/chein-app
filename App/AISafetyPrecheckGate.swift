import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Planning audit H-08b: the MP `fabu` publish runs `/api/ai/safety/precheck` before it opens the publish step
/// (`runPublishPrecheck` → `_afterPrecheck`). Here the editor's 下一步 / 提交草稿 call `begin`, and the step continues
/// on its own unless the AI reports a blocking issue. Every failure degrades to pass with a visible skip line.
@MainActor final class AISafetyPrecheckGate: ObservableObject {
    enum Phase: Equatable {
        case idle, running, passed
        case skipped(AISafetyPrecheckVerdict.Skip)
        case reported(AISafetyPrecheckVerdict)
    }
    struct Report: Identifiable {
        let id = UUID()
        let verdict: AISafetyPrecheckVerdict
    }
    @Published private(set) var phase: Phase = .idle
    @Published var report: Report?
    private var token = UUID()

    var isRunning: Bool { phase == .running }

    func begin(draft: ProjectEditDraft, source: AISafetyPrecheckSource?, then proceed: @escaping @MainActor () -> Void) {
        guard phase != .running else { return }
        guard let runner = source?.make() else {
            phase = .skipped(.unavailable)
            proceed()
            return
        }
        let fields = AISafetyPrecheckRequest.fields(for: draft)
        let current = UUID()
        token = current
        phase = .running
        Task { [weak self] in
            let verdict = await runner.run(fields)
            self?.finish(verdict, token: current, proceed: proceed)
        }
    }

    func reset() {
        token = UUID()
        phase = .idle
        report = nil
    }

    private func finish(_ verdict: AISafetyPrecheckVerdict, token current: UUID, proceed: @MainActor () -> Void) {
        guard token == current else { return }
        if let skip = verdict.skip {
            phase = .skipped(skip)
            proceed()
        } else if verdict.allowsPublish {
            phase = verdict.passed ? .passed : .reported(verdict)
            proceed()
        } else {
            phase = .reported(verdict)
            report = Report(verdict: verdict)
        }
    }
}

/// The editor row under the server publish check: what the AI precheck said last time.
@MainActor struct AISafetyPrecheckStatusSection: View {
    @ObservedObject var gate: AISafetyPrecheckGate

    var body: some View {
        Section {
            statusRow
        } header: {
            Text("aiSafety.title")
        } footer: {
            Text("aiSafety.footer")
        }
        .accessibilityIdentifier("aiSafety.section")
    }

    @ViewBuilder private var statusRow: some View {
        switch gate.phase {
        case .idle:
            Label("aiSafety.idle", systemImage: "checkmark.shield")
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text("aiSafety.running")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("aiSafety.running")
        case .passed:
            Label("aiSafety.passed", systemImage: "checkmark.shield.fill")
                .foregroundStyle(CYColor.successText)
                .accessibilityIdentifier("aiSafety.passed")
        case .skipped(let skip):
            Label(LocalizedStringKey(skip == .quota ? "aiSafety.skipped.quota" : "aiSafety.skipped.unavailable"), systemImage: "shield.slash")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("aiSafety.skipped")
        case .reported(let verdict):
            AISafetyIssueList(verdict: verdict)
        }
    }
}

/// Blocking issues first (danger), then advisories. The AI's own wording is shown verbatim.
@MainActor struct AISafetyIssueList: View {
    let verdict: AISafetyPrecheckVerdict

    var body: some View {
        ForEach(Array(verdict.blocking.enumerated()), id: \.offset) { _, issue in
            Label { Text(verbatim: issue.message).fixedSize(horizontal: false, vertical: true) } icon: {
                Image(systemName: "exclamationmark.octagon.fill")
            }
            .foregroundStyle(CYColor.dangerText)
            .accessibilityIdentifier("aiSafety.blocking")
        }
        ForEach(Array(verdict.advisory.enumerated()), id: \.offset) { _, issue in
            Label { Text(verbatim: issue.message).fixedSize(horizontal: false, vertical: true) } icon: {
                Image(systemName: "info.circle")
            }
            .accessibilityIdentifier("aiSafety.advisory")
        }
    }
}

/// MP publish-check popup for AI-blocked content: the issues, then one way back to editing.
@MainActor struct AISafetyPrecheckReportSheet: View {
    let report: AISafetyPrecheckGate.Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AISafetyIssueList(verdict: report.verdict)
                } footer: {
                    Text("aiSafety.blocked.footer")
                }
            }
            .navigationTitle(Text("aiSafety.blocked.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("aiSafety.blocked.keepEditing") { dismiss() }
                        .accessibilityIdentifier("aiSafety.blocked.keepEditing")
                }
            }
        }
    }
}

/// Presents the blocking report; typed so the editor body keeps only one modifier line.
struct AISafetyPrecheckPresenter: ViewModifier {
    @ObservedObject var gate: AISafetyPrecheckGate

    func body(content: Content) -> some View {
        content
            .sheet(item: $gate.report) { report in
                AISafetyPrecheckReportSheet(report: report)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.warning, trigger: gate.report?.id, condition: CYHapticTransition.becameSet)
    }
}
