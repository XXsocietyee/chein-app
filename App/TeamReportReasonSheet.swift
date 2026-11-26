import SwiftUI

/// Report entry from `subpackageRoam/nearby` team sheet (`mt-report` 举报队伍, TEAM-REPORT-01, hengyin 0d681af55).
/// Hidden when no signed-in report access is wired (capability absent => hidden).
@MainActor struct TeamReportEntryButton: View {
    let teamID: Int
    @Environment(\.teamOrientBoardAccess) private var access
    @State private var presented = false
    var body: some View {
        if teamID > 0, let access, access.enabled {
            Button { presented = true } label: {
                Text("mpfresh.teamReport.entry", tableName: "MpFresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityLabel(Text("mpfresh.teamReport.title", tableName: "MpFresh"))
            .accessibilityIdentifier("nearby.team.report.\(teamID)")
            .sheet(isPresented: $presented) { Group { TeamReportReasonSheet(teamID: teamID) }.cySheet() }
        }
    }
}

/// Source `components/cy/team-report-sheet`: pick one of five fixed reasons → submit → receipt / retry.
@MainActor struct TeamReportReasonSheet: View {
    let teamID: Int
    @Environment(\.teamOrientBoardAccess) private var access
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int?
    @State private var state: TeamReportState = .idle
    static let reasonKeys = ["mpfresh.teamReport.reason.ads", "mpfresh.teamReport.reason.illegal", "mpfresh.teamReport.reason.fraud",
                             "mpfresh.teamReport.reason.abuse", "mpfresh.teamReport.reason.other"]
    /// The server reason is the source Chinese label, sent verbatim (same text as the mini-program).
    static let sourceReasons = ["广告或营销骚扰", "色情低俗或违法内容", "诈骗或虚假信息", "辱骂或人身攻击", "其他问题"]

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .submitting:
                    ProgressView { Text("mpfresh.teamReport.busy", tableName: "MpFresh") }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("teamReport.busy")
                case .submitted:
                    result(icon: "checkmark.circle.fill", tint: .green, title: "mpfresh.teamReport.ok.title",
                           detail: "mpfresh.teamReport.ok.detail", primary: "mpfresh.teamReport.ok.done") { dismiss() }
                        .accessibilityIdentifier("teamReport.ok")
                case .unavailable:
                    result(icon: "exclamationmark.triangle", tint: .orange, title: "mpfresh.teamReport.fail.title",
                           detail: "mpfresh.teamReport.unavailable", primary: "mpfresh.teamReport.ok.done") { dismiss() }
                        .accessibilityIdentifier("teamReport.unavailable")
                case .failed(let failure):
                    result(icon: "xmark.octagon", tint: .red, title: "mpfresh.teamReport.fail.title",
                           detail: failureKey(failure), primary: "mpfresh.teamReport.retry", showsCancel: true) { Task { await submit() } }
                        .accessibilityIdentifier("teamReport.fail")
                case .idle:
                    picker
                }
            }
            .navigationTitle(Text("mpfresh.teamReport.title", tableName: "MpFresh"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if state != .submitting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("mpfresh.teamReport.cancel", tableName: "MpFresh") }
                    }
                }
                if state == .idle {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await submit() } } label: { Text("mpfresh.teamReport.submit", tableName: "MpFresh") }
                            .disabled(selected == nil)
                            .accessibilityIdentifier("teamReport.submit")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(state == .submitting)
    }

    /// Settings-style single choice: one row per reason, checkmark on the chosen one.
    private var picker: some View {
        List {
            Section {
                ForEach(Self.reasonKeys.indices, id: \.self) { index in
                    Button { selected = index } label: {
                        HStack {
                            Text(LocalizedStringKey(Self.reasonKeys[index]), tableName: "MpFresh")
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if selected == index {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(selected == index ? [.isSelected] : [])
                    .accessibilityIdentifier("teamReport.reason.\(index)")
                }
            }
        }
    }

    private func result(icon: String, tint: Color, title: String, detail: String, primary: String,
                        showsCancel: Bool = false, action: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(title), tableName: "MpFresh")
            } icon: {
                Image(systemName: icon).foregroundStyle(tint)
            }
        } description: {
            Text(LocalizedStringKey(detail), tableName: "MpFresh")
        } actions: {
            Button(action: action) {
                Text(LocalizedStringKey(primary), tableName: "MpFresh")
            }
            .buttonStyle(.borderedProminent)
            if showsCancel {
                Button { dismiss() } label: { Text("mpfresh.teamReport.cancel", tableName: "MpFresh") }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func failureKey(_ failure: TeamReportFailure) -> String {
        switch failure {
        case .unauthorized: return "mpfresh.teamReport.fail.login"
        default: return "mpfresh.teamReport.fail.network"
        }
    }

    private func submit() async {
        guard let selected, Self.sourceReasons.indices.contains(selected) else { return }
        state = .submitting
        state = await TeamReportSubmission.run(access: access, teamID: teamID, reason: Self.sourceReasons[selected])
    }
}
