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
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .underline()
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("mpfresh.teamReport.title", tableName: "MpFresh"))
            .accessibilityIdentifier("nearby.team.report.\(teamID)")
            .sheet(isPresented: $presented) { TeamReportReasonSheet(teamID: teamID) }
        }
    }
}

/// Source `components/cy/team-report-sheet`: pick one of five fixed reasons → submit → receipt / retry.
@MainActor struct TeamReportReasonSheet: View {
    let teamID: Int
    @Environment(\.teamOrientBoardAccess) private var access
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    result(icon: "checkmark.circle.fill", tint: CYColor.successText, title: "mpfresh.teamReport.ok.title",
                           detail: "mpfresh.teamReport.ok.detail", primary: "mpfresh.teamReport.ok.done") { dismiss() }
                        .accessibilityIdentifier("teamReport.ok")
                case .unavailable:
                    result(icon: "exclamationmark.triangle", tint: CYColor.warningText, title: "mpfresh.teamReport.fail.title",
                           detail: "mpfresh.teamReport.unavailable", primary: "mpfresh.teamReport.ok.done") { dismiss() }
                        .accessibilityIdentifier("teamReport.unavailable")
                case .failed(let failure):
                    VStack(spacing: CYSpacing.md) {
                        result(icon: "xmark.octagon", tint: CYColor.dangerText, title: "mpfresh.teamReport.fail.title",
                               detail: failureKey(failure), primary: "mpfresh.teamReport.retry") { Task { await submit() } }
                        CYPillButton("mpfresh.teamReport.cancel", style: .tertiary, tableName: "MpFresh") { dismiss() }
                            .padding(.horizontal, CYSpacing.pageHorizontal)
                    }
                    .accessibilityIdentifier("teamReport.fail")
                case .idle:
                    picker
                }
            }
            .cyDomainPageBackground()
            .navigationTitle(Text("mpfresh.teamReport.title", tableName: "MpFresh"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("mpfresh.teamReport.cancel", tableName: "MpFresh") }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(state == .submitting)
    }

    private var picker: some View {
        List {
            Section {
                ForEach(Self.reasonKeys.indices, id: \.self) { index in
                    Button {
                        withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { selected = index }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(Self.reasonKeys[index]), tableName: "MpFresh").foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            if selected == index { Image(systemName: "checkmark").foregroundStyle(CYColor.accent).transition(.scale.combined(with: .opacity)) }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(selected == index ? [.isSelected] : [])
                    .accessibilityIdentifier("teamReport.reason.\(index)")
                }
            }
            Section {
                CYPillButton("mpfresh.teamReport.submit", tableName: "MpFresh") { Task { await submit() } }
                    .disabled(selected == nil)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("teamReport.submit")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func result(icon: String, tint: Color, title: String, detail: String, primary: String,
                        action: @escaping () -> Void) -> some View {
        VStack(spacing: CYSpacing.md) {
            Image(systemName: icon).font(.largeTitle).imageScale(.large).foregroundStyle(tint).accessibilityHidden(true)
            Text(LocalizedStringKey(title), tableName: "MpFresh").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary)
            Text(LocalizedStringKey(detail), tableName: "MpFresh").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            CYPillButton(LocalizedStringKey(primary), tableName: "MpFresh", action: action)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
