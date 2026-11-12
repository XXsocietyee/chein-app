import SwiftUI

// MARK: - 我的举报 entry in the system conversation

/// Mini-program `subpackageB/pages/im/chat` (type 2, 城瘾小助手): a 「我的举报」 row above the
/// transcript with the unread count of 举报进度 notices (`/api/v1/community/notifications`, action REPORT_*).
/// The destination is the existing my-reports page. Host injects it with
/// `.environment(\.imReportProgressDestination, …)`; nil ⇒ the row is hidden.
/// BINDING STUB for Cursor: `imReportProgressUnread` (unread REPORT_* notices; read-on-open) is not wired;
/// nil hides the badge only.
private struct IMReportProgressDestinationKey: EnvironmentKey { static let defaultValue: (@MainActor () -> AnyView)? = nil }
private struct IMReportProgressUnreadKey: EnvironmentKey { static let defaultValue: Int? = nil }
extension EnvironmentValues {
    var imReportProgressDestination: (@MainActor () -> AnyView)? {
        get { self[IMReportProgressDestinationKey.self] }
        set { self[IMReportProgressDestinationKey.self] = newValue }
    }
    var imReportProgressUnread: Int? {
        get { self[IMReportProgressUnreadKey.self] }
        set { self[IMReportProgressUnreadKey.self] = newValue }
    }
}

@MainActor struct IMReportProgressEntry: View {
    @Environment(\.imReportProgressDestination) private var destination
    @Environment(\.imReportProgressUnread) private var unread
    var body: some View {
        if let destination {
            NavigationLink { destination() } label: {
                HStack(spacing: CYSpacing.md) {
                    Image(systemName: "flag.fill").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                    Text("report.history.title", tableName: "MemberReportProgress")
                        .font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                    Spacer(minLength: CYSpacing.sm)
                    if let unread, unread > 0 {
                        Text(verbatim: unread > 99 ? "99+" : String(unread))
                            .font(CYTypography.caption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                            .background(CYColor.dangerText, in: Capsule())
                    }
                    Image(systemName: "chevron.right").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                }
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: 48)
                .background(CYColor.bgElevated)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(unread.map { $0 > 0 ? Text("mpd.im.reportUnread \($0)") : Text(verbatim: "") } ?? Text(verbatim: ""))
            .accessibilityIdentifier("im.chat.reportMine")
        }
    }
}

// MARK: - 邀约提醒 toggle

/// Mini-program message list: 「协作邀请 · 邀约提醒」 switch beside the received-invites title. On iOS the
/// reminder is a notification preference. BINDING STUB for Cursor: inject an `IMInviteReminderBinding`
/// (reads the current state; `setEnabled(true)` asks for notification permission if needed and reports
/// whether it ended up on). Nil ⇒ the switch is hidden.
@MainActor protocol IMInviteReminderBinding: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ on: Bool) async -> Bool
}

private struct IMInviteReminderKey: EnvironmentKey { static let defaultValue: (any IMInviteReminderBinding)? = nil }
extension EnvironmentValues {
    var imInviteReminder: (any IMInviteReminderBinding)? {
        get { self[IMInviteReminderKey.self] }
        set { self[IMInviteReminderKey.self] = newValue }
    }
}

@MainActor struct IMInviteReminderToggle: View {
    @Environment(\.imInviteReminder) private var binding
    @State private var on = false
    @State private var busy = false
    @State private var result: LocalizedStringKey?
    var body: some View {
        if let binding {
            VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                Toggle(isOn: Binding(get: { on }, set: { value in Task { await change(value, binding) } })) {
                    Text("mpd.im.inviteReminder").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                .toggleStyle(.switch).controlSize(.mini).fixedSize()
                .disabled(busy)
                .accessibilityIdentifier("im.coopStrip.inviteReminder")
                if let result {
                    Text(result).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                        .transition(.opacity)
                }
            }
            .onAppear { on = binding.isEnabled }
        }
    }
    private func change(_ value: Bool, _ binding: any IMInviteReminderBinding) async {
        busy = true; defer { busy = false }
        let final = await binding.setEnabled(value)
        withAnimation(CYMotion.standard) {
            on = final
            result = value ? (final ? "mpd.im.inviteReminder.on" : "mpd.im.inviteReminder.denied") : nil
        }
    }
}

// MARK: - Review result: current audit record

/// Mini-program chat 「生成时记录」 sheet, second half: 「当前审核记录」 (status + timeline) read from the
/// card's audit detail. BINDING STUB for Cursor: inject an `IMReviewAuditReading`; nil ⇒ section hidden.
struct IMReviewAuditRecord: Equatable {
    struct Step: Equatable, Identifiable { let id: Int; let time: String; let label: String; let reason: String? }
    let statusLabel: String?
    let timeline: [Step]
}

@MainActor protocol IMReviewAuditReading {
    func record(taskID: String) async throws -> IMReviewAuditRecord
}

private struct IMReviewAuditReaderKey: EnvironmentKey { static let defaultValue: (any IMReviewAuditReading)? = nil }
extension EnvironmentValues {
    var imReviewAuditReader: (any IMReviewAuditReading)? {
        get { self[IMReviewAuditReaderKey.self] }
        set { self[IMReviewAuditReaderKey.self] = newValue }
    }
}

@MainActor struct IMReviewCurrentRecordSection: View {
    let taskID: String?
    @Environment(\.imReviewAuditReader) private var reader
    @State private var phase: Phase = .loading
    enum Phase: Equatable { case loading, failed, ready(IMReviewAuditRecord) }

    var body: some View {
        if let reader, let taskID, !taskID.isEmpty {
            Section {
                switch phase {
                case .loading:
                    HStack(spacing: CYSpacing.sm) { ProgressView(); Text("mpd.review.loading") }
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("im.review.record.loading")
                case .failed:
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("mpd.review.failed").font(CYTypography.meta).foregroundStyle(CYColor.warningText)
                        Button("mpd.common.retry") { Task { await load(reader, taskID) } }
                            .accessibilityIdentifier("im.review.record.retry")
                    }
                case .ready(let record):
                    if let status = record.statusLabel, !status.isEmpty {
                        CYListRow("mpd.review.status", trailing: .value(status)) { CYRowIcon(systemImage: "checkmark.seal") }
                    }
                    ForEach(record.timeline) { step in
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(verbatim: step.label).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                            Text(verbatim: step.time + ((step.reason ?? "").isEmpty ? "" : " · " + (step.reason ?? "")))
                                .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        }
                    }
                }
            } header: { CYSectionHeader("mpd.review.current") }
            .task(id: taskID) { await load(reader, taskID) }
        }
    }
    private func load(_ reader: any IMReviewAuditReading, _ taskID: String) async {
        phase = .loading
        do { phase = .ready(try await reader.record(taskID: taskID)) } catch is CancellationError {} catch { phase = .failed }
    }
}
