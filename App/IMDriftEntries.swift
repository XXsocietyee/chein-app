import SwiftUI
import UIKit

// MARK: - 我的举报 entry in the system conversation

/// Mini-program `subpackageB/pages/im/chat` (type 2, 城瘾小助手): a 「我的举报」 row above the
/// transcript with the unread count of 举报进度 notices (`/api/v1/community/notifications`, action REPORT_*).
/// The destination is the existing my-reports page. Host injects it with
/// `.environment(\.imReportProgressDestination, …)` and `.environment(\.imReportProgressUnread, …)`; nil hides the row/badge.
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
                HStack {
                    Label {
                        Text("report.history.title", tableName: "MemberReportProgress")
                    } icon: {
                        Image(systemName: "flag.fill").accessibilityHidden(true)
                    }
                    Spacer(minLength: 8)
                    if let unread, unread > 0 {
                        Text(verbatim: unread > 99 ? "99+" : String(unread))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                }
                .padding(.horizontal).padding(.vertical, 12)
                .background(.bar)
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

/// Mini-program message list: 「协作邀请 · 邀约提醒」 switch beside the received-invites title.
/// There is no server preference. The binding is a local choice plus notification permission.
/// `setEnabled(true)` returns true only when that choice is on and alerts are allowed.
/// Nil ⇒ the switch is hidden.
enum IMInviteReminderPresentation: Equatable {
    case off, on, unknown
    /// Unknown status, in English and Simplified Chinese. Not a hyphen, and not 0.
    static let unknownMark = "\u{2014}"
    var isEnabled: Bool { self == .on }
}

@MainActor protocol IMInviteReminderBinding: AnyObject {
    var isEnabled: Bool { get }
    var presentation: IMInviteReminderPresentation { get }
    var offersSettings: Bool { get }
    func reload() async
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
    @Environment(\.openURL) private var openURL
    @State private var presentation: IMInviteReminderPresentation = .unknown
    @State private var offersSettings = false
    @State private var ready = false
    @State private var busy = false
    @State private var result: LocalizedStringKey?
    var body: some View {
        if let binding {
            VStack(alignment: .trailing, spacing: 2) {
                inviteSwitch(binding)
                if ready && presentation == .unknown {
                    Text("mpd.im.inviteReminder.unknown")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel(Text("mpd.im.inviteReminder.unknownLabel"))
                        .accessibilityIdentifier("im.coopStrip.inviteReminder.unknown")
                } else if let result {
                    Text(result).font(.caption).foregroundStyle(.secondary)
                }
                if offersSettings {
                    Button(action: openNotificationSettings) {
                        Text("d7.notifyPermission.settings")
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                        .font(.caption).buttonStyle(.borderless)
                        .accessibilityIdentifier("im.coopStrip.inviteReminder.settings")
                        .accessibilityLabel(Text("d7.notifyPermission.settings"))
                        .accessibilityValue(Text(LocalizedStringKey(presentation == .unknown ? "mpd.im.inviteReminder.unknownLabel" : "mpd.im.inviteReminder.denied")))
                        .accessibilityHint(Text("d7.notifyPermission.settings"))
                }
            }
            .task {
                await reload(binding)
                ready = true
            }
        }
    }
    @ViewBuilder private func inviteSwitch(_ binding: any IMInviteReminderBinding) -> some View {
        Group {
            Toggle(isOn: Binding(get: { presentation == .on }, set: { value in Task { await change(value, binding) } })) {
                Text("mpd.im.inviteReminder").font(.footnote).foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
        }
        .controlSize(.mini)
        .fixedSize()
        .disabled(busy)
        .accessibilityIdentifier("im.coopStrip.inviteReminder")
        .accessibilityLabel(Text("mpd.im.inviteReminder"))
        .accessibilityValue(inviteSpokenValue)
        .accessibilityHint(Text("mpd.im.inviteReminder"))
    }

    private var inviteSpokenValue: Text {
        if !ready || presentation == .unknown { return Text("mpd.im.inviteReminder.unknownLabel") }
        if presentation == .on { return Text("mpd.im.inviteReminder.on") }
        if offersSettings { return Text("mpd.im.inviteReminder.denied") }
        return Text("mpd.im.inviteReminder")
    }
    private func reload(_ binding: any IMInviteReminderBinding) async {
        await binding.reload()
        apply(binding, changedTo: nil)
    }
    private func change(_ value: Bool, _ binding: any IMInviteReminderBinding) async {
        busy = true; defer { busy = false }
        _ = await binding.setEnabled(value)
        apply(binding, changedTo: value)
    }
    private func apply(_ binding: any IMInviteReminderBinding, changedTo value: Bool?) {
        presentation = binding.presentation
        offersSettings = binding.offersSettings
        switch binding.presentation {
        case .unknown:
            result = nil
        case .on:
            result = value == true ? "mpd.im.inviteReminder.on" : nil
        case .off:
            result = value == true ? "mpd.im.inviteReminder.denied" : nil
        }
    }
    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }
}

// MARK: - Review result: current audit record

/// Mini-program chat 「生成时记录」 sheet, second half: 「当前审核记录」 (status + timeline) read from
/// `GET /api/audit/{taskId}/detail` (`data.task`). Nil reader hides the section. Closed-group
/// card titles skip the read. The reader does not mark notifications read and does not write.
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
    var cardTitle: String? = nil
    @Environment(\.imReviewAuditReader) private var reader
    @State private var phase: Phase = .loading
    enum Phase: Equatable { case loading, failed, ready(IMReviewAuditRecord) }

    var body: some View {
        if let reader, let taskID, !taskID.isEmpty, !IMReviewAuditDetail.hidesDetail(cardTitle: cardTitle) {
            Section {
                switch phase {
                case .loading:
                    HStack(spacing: 8) { ProgressView(); Text("mpd.review.loading") }
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("im.review.record.loading")
                case .failed:
                    Label("mpd.review.failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CYColor.warningText)
                    Button("mpd.common.retry") { Task { await load(reader, taskID) } }
                        .accessibilityIdentifier("im.review.record.retry")
                case .ready(let record):
                    if let status = record.statusLabel, !status.isEmpty {
                        LabeledContent {
                            Text(verbatim: status)
                        } label: {
                            Label("mpd.review.status", systemImage: "checkmark.seal")
                        }
                    }
                    ForEach(record.timeline) { step in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: step.label)
                            Text(verbatim: step.time + ((step.reason ?? "").isEmpty ? "" : " · " + (step.reason ?? "")))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: { Text("mpd.review.current") }
            .task(id: taskID) { await load(reader, taskID) }
        }
    }
    private func load(_ reader: any IMReviewAuditReading, _ taskID: String) async {
        phase = .loading
        do { phase = .ready(try await reader.record(taskID: taskID)) } catch is CancellationError {} catch { phase = .failed }
    }
}
