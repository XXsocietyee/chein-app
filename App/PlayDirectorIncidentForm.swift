import SwiftUI

/// MP `pages/club/components/club-director-incident-sheet` (topic-detail wxml:281-282, 414-422; director.js:466-552, 667-760):
/// 现场事件 → event rows (商家暂停 / 待核验积压 / 待核验提交 / 任务驳回) → 处理方式 (only what the row allows) → 确认处理.
/// 商家暂停 → 恢复本站 (CLUB_STATION_RESUME); 待核验积压 → 暂停本站 (CLUB_STATION_PAUSE, reason ≥ 2, ETA +30 min, the one plan);
/// 待核验提交 → 驳回重交 (CLUB_REJECT_SUBMISSION, reason ≥ 2); 任务驳回 is final and offers no mode.
enum PlayDirectorIncidents {
    enum Kind: Equatable { case paused, backlog, pendingSubmit, rejected }
    enum Mode: String, Identifiable { case resume, pause, reject; var id: String { rawValue } }

    struct Row: Identifiable {
        let id: String
        let kind: Kind
        let nodeID: Int?
        let submissionID: Int?
        let station: PlayWireValue
        let submission: PlayWireValue
    }

    /// director.js:478 `incidentRows`.
    static func rows(_ projection: PlayDirectorProjection) -> [Row] {
        var rows: [Row] = []
        for station in projection.stations {
            guard let node = station["nodeId"].integer else { continue }
            if station["status"].text == "PAUSED" {
                rows.append(Row(id: "pause:\(node)", kind: .paused, nodeID: node, submissionID: nil, station: station, submission: .null))
            } else if (station["pendingVerificationCount"].integer ?? 0) > 0 {
                rows.append(Row(id: "backlog:\(node)", kind: .backlog, nodeID: node, submissionID: nil, station: station, submission: .null))
            }
        }
        for submission in projection.submissions {
            guard let id = submission["submissionId"].integer else { continue }
            let rejected = submission["status"].text == "REJECTED"
            rows.append(Row(id: "sub:\(id)", kind: rejected ? .rejected : .pendingSubmit, nodeID: nil, submissionID: id, station: .null, submission: submission))
        }
        return rows
    }

    /// director.js:538 `incidentModesFor`: a rejected submission is final, so it has no mode.
    static func modes(_ row: Row?) -> [Mode] {
        switch row?.kind {
        case .paused: return [.resume]
        case .backlog: return [.pause]
        case .pendingSubmit: return [.reject]
        default: return []
        }
    }

    static func plans(_ row: Row) -> [PlayWireValue] { row.station["fallbackPlanOptions"].array ?? [] }

    /// director.js:466 `resumeEtaIn(30)`: China wall-clock `yyyy-MM-dd HH:mm:00`.
    static func resumeETA(from now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:00"
        return formatter.string(from: now.addingTimeInterval(30 * 60))
    }

    /// director.js:688-760 `submitIncident`; nil when the row and mode do not make a valid command.
    static func command(_ row: Row, mode: Mode, reason: String, projection: PlayDirectorProjection, now: Date = Date()) -> PlayDirectorCommand? {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let action: PlayDirectorAction
        var payload: [String: PlayWireValue] = [:]
        var nodeID: Int?
        switch mode {
        case .resume:
            action = .resume
            nodeID = row.nodeID
        case .reject:
            guard let id = row.submissionID, trimmed.count >= 2 else { return nil }
            action = .reject
            payload = ["submissionId": .int(id), "reasonCode": .string("ONSITE_REJECT"), "reason": .string(trimmed)]
        case .pause:
            let options = plans(row)
            guard trimmed.count >= 2, options.count <= 1 else { return nil }
            action = .pause
            nodeID = row.nodeID
            payload = ["reasonCode": .string("ONSITE"), "reason": .string(trimmed), "resumeEta": .string(resumeETA(from: now))]
            if let plan = options.first, let code = plan["planCode"].text {
                payload["fallbackPlanCode"] = .string(code)
                payload["fallbackPlanVersion"] = plan["version"]
            }
        }
        guard let command = try? PlayDirectorCommand(activityID: projection.activityID, nodeID: nodeID, expectedRevision: projection.revision, action: action, payload: payload),
              projection.allows(command) else { return nil }
        return command
    }
}

/// The 现场事件 sheet of `PlayDirectorView`.
@MainActor struct PlayDirectorIncidentEditor: View {
    let projection: PlayDirectorProjection
    let submit: (PlayDirectorCommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedID = ""
    @State private var mode: PlayDirectorIncidents.Mode?
    @State private var reason = ""
    @State private var draft: PlayDirectorCommand?
    @State private var confirm = false

    private var rows: [PlayDirectorIncidents.Row] { PlayDirectorIncidents.rows(projection) }
    private var selected: PlayDirectorIncidents.Row? { rows.first { $0.id == selectedID } }
    private var modes: [PlayDirectorIncidents.Mode] { PlayDirectorIncidents.modes(selected) }
    private var tooManyPlans: Bool {
        guard mode == .pause, let selected else { return false }
        return PlayDirectorIncidents.plans(selected).count > 1
    }
    private var ready: Bool {
        guard let selected, let mode else { return false }
        return PlayDirectorIncidents.command(selected, mode: mode, reason: reason, projection: projection) != nil
    }

    var body: some View {
        Form {
            Section {
                ForEach(rows) { row in
                    incidentRow(row)
                }
            }
            if !modes.isEmpty {
                Section("playx.director.incident.modeTitle") {
                    Picker("playx.director.incident.modeTitle", selection: $mode) {
                        ForEach(modes) { item in
                            Text(modeKey(item)).tag(Optional(item))
                        }
                    }
                    .labelsHidden()
                    .cyAdaptiveSegmented()
                    .accessibilityIdentifier("playx.director.incident.modePicker")
                }
            }
            if mode == .pause || mode == .reject {
                Section {
                    TextField(reasonKey, text: $reason, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("playx.director.incident.reason")
                        .onChange(of: reason) { _, newValue in
                            if newValue.count > 200 { reason = String(newValue.prefix(200)) }
                        }
                }
            }
            Section {
                Button { prepare() } label: {
                    Text("playx.director.incident.confirm").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!ready)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("playx.director.incident.submit")
            } footer: {
                captionText
            }
        }
        .cyGroupedSurface()
        .cyPageTitle("playx.director.incident.title")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playx.cancel") { dismiss() }.accessibilityIdentifier("playx.director.incident.cancel") } }
        .onChange(of: selectedID) { _, _ in
            let next = PlayDirectorIncidents.modes(selected)
            mode = next.count == 1 ? next.first : nil
            reason = ""
        }
        .cyModalOverlay(isPresented: confirm) {
            CYModal(
                title: appLocalized(confirmTitleKey, locale: locale),
                message: appLocalized(confirmMessageKey, locale: locale),
                cancelTitle: PlayCloseCopy.cancel(locale),
                confirmTitle: appLocalized(confirmButtonKey, locale: locale),
                onCancel: { confirm = false },
                onConfirm: {
                    confirm = false
                    if let draft { submit(draft) }
                }
            )
        }
    }

    private func incidentRow(_ row: PlayDirectorIncidents.Row) -> some View {
        let on = row.id == selectedID
        return Button {
            selectedID = row.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey(row.kind)).foregroundStyle(.primary)
                    detailText(row).font(.footnote).foregroundStyle(.secondary)
                    subText(row).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if on {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playx.director.incident.row.\(row.id)")
    }

    private func titleKey(_ kind: PlayDirectorIncidents.Kind) -> LocalizedStringKey {
        switch kind {
        case .paused: return "playx.director.incident.kind.paused"
        case .backlog: return "playx.director.incident.kind.backlog"
        case .pendingSubmit: return "playx.director.incident.kind.pendingSubmit"
        case .rejected: return "playx.director.incident.kind.rejected"
        }
    }

    private func nodeName(_ raw: PlayWireValue) -> String {
        raw["nodeName"].text ?? appLocalized("playx.director.incident.untitledNode", locale: locale)
    }

    /// director.js:487 / 499 / 512 row text.
    @ViewBuilder private func detailText(_ row: PlayDirectorIncidents.Row) -> some View {
        switch row.kind {
        case .paused:
            let reasonText = row.station["pauseReason"].text ?? row.station["pauseReasonCode"].text ?? appLocalized("playx.director.incident.noReason", locale: locale)
            if let eta = row.station["resumeEta"].text {
                Text("playx.director.incident.pausedEta \(nodeName(row.station)) \(reasonText) \(eta)")
            } else {
                Text("playx.director.incident.paused \(nodeName(row.station)) \(reasonText)")
            }
        case .backlog:
            Text("playx.director.incident.backlog \(nodeName(row.station)) \(row.station["pendingVerificationCount"].integer ?? 0)")
        case .pendingSubmit, .rejected:
            let name = nodeName(row.submission)
            let rejected = row.kind == .rejected
            if let team = row.submission["teamId"].integer {
                if rejected { Text("playx.director.incident.teamRejected \(team) \(name)") } else { Text("playx.director.incident.teamPending \(team) \(name)") }
            } else {
                if rejected { Text("playx.director.incident.rejectedText \(name)") } else { Text("playx.director.incident.pendingText \(name)") }
            }
        }
    }

    @ViewBuilder private func subText(_ row: PlayDirectorIncidents.Row) -> some View {
        if row.kind == .paused {
            if let plan = row.station["fallbackPlanCode"].text {
                Text("playx.director.incident.planBound \(plan)")
            } else {
                Text("playx.director.incident.noPlan")
            }
        } else if row.kind == .rejected, let reason = row.submission["decisionReason"].text {
            Text(verbatim: reason)
        }
    }

    private func modeKey(_ mode: PlayDirectorIncidents.Mode) -> LocalizedStringKey {
        switch mode {
        case .resume: return "playx.director.incident.mode.resume"
        case .pause: return "playx.director.incident.mode.pause"
        case .reject: return "playx.director.incident.mode.reject"
        }
    }

    private var reasonKey: LocalizedStringKey {
        mode == .reject ? "playx.director.incident.rejectReason" : "playx.director.incident.pauseReason"
    }

    /// incident-sheet index.js caption; director.js:737 swaps it when the station has no approved plan.
    @ViewBuilder private var captionText: some View {
        if tooManyPlans {
            Text("playx.director.incident.manyPlans")
        } else if mode == .pause, let selected, PlayDirectorIncidents.plans(selected).isEmpty {
            Text("playx.director.incident.noPlanCaption")
        } else {
            Text("playx.director.incident.caption")
        }
    }

    private var confirmTitleKey: String.LocalizationValue {
        switch mode {
        case .reject: return "playx.director.incident.mode.reject"
        case .pause: return "playx.director.incident.mode.pause"
        default: return "playx.director.incident.mode.resume"
        }
    }

    private var confirmMessageKey: String.LocalizationValue {
        if mode == .pause, let selected, PlayDirectorIncidents.plans(selected).isEmpty { return "playx.director.incident.noPlanCaption" }
        if mode == .reject { return "playx.director.incident.rejectNotice" }
        return "playx.director.incident.caption"
    }

    private var confirmButtonKey: String.LocalizationValue {
        switch mode {
        case .reject: return "playx.director.incident.confirmReject"
        case .pause: return "playx.director.incident.confirmPause"
        default: return "playx.director.incident.confirm"
        }
    }

    private func prepare() {
        guard let selected, let mode, let command = PlayDirectorIncidents.command(selected, mode: mode, reason: reason, projection: projection) else { return }
        if mode == .resume {
            submit(command)
            return
        }
        draft = command
        confirm = true
    }
}
