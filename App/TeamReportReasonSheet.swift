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
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .underline()
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
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
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Int?
    @State private var state: TeamReportState = .idle
    static let reasonKeys = ["mpfresh.teamReport.reason.ads", "mpfresh.teamReport.reason.illegal", "mpfresh.teamReport.reason.fraud",
                             "mpfresh.teamReport.reason.abuse", "mpfresh.teamReport.reason.other"]
    /// The server reason is the source Chinese label, sent verbatim (same text as the mini-program).
    static let sourceReasons = ["广告或营销骚扰", "色情低俗或违法内容", "诈骗或虚假信息", "辱骂或人身攻击", "其他问题"]

    var body: some View {
        CYSheetContainer(
            title: String(localized: LocalizedStringResource("mpfresh.teamReport.title", table: "MpFresh", locale: locale)),
            onClose: state == .submitting ? nil : { dismiss() }
        ) {
            Group {
                switch state {
                case .submitting:
                    VStack(spacing: CYSpacing.md) {
                        ProgressView { Text("mpfresh.teamReport.busy", tableName: "MpFresh") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
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
                        Button { dismiss() } label: { Text("mpfresh.teamReport.cancel", tableName: "MpFresh") }
                            .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                    }
                    .accessibilityIdentifier("teamReport.fail")
                case .idle:
                    picker
                }
            }
        }
        .cyDomainSheet(detents: [.half, .full])
        .interactiveDismissDisabled(state == .submitting)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            ScrollView {
                VStack(spacing: CYSpacing.xs) {
                    ForEach(Self.reasonKeys.indices, id: \.self) { index in
                        Button {
                            withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { selected = index }
                        } label: {
                            HStack(spacing: CYSpacing.sm) {
                                Text(LocalizedStringKey(Self.reasonKeys[index]), tableName: "MpFresh")
                                    .cyText(.body)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if selected == index {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CYColor.brand)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, CYSpacing.md)
                            .padding(.vertical, CYSpacing.sm)
                            .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == index ? [.isSelected] : [])
                        .accessibilityIdentifier("teamReport.reason.\(index)")
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { Task { await submit() } } label: {
                Text("mpfresh.teamReport.submit", tableName: "MpFresh")
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
            .disabled(selected == nil)
            .accessibilityIdentifier("teamReport.submit")

            Button { dismiss() } label: {
                Text("mpfresh.teamReport.cancel", tableName: "MpFresh")
            }
            .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
        }
    }

    private func result(icon: String, tint: Color, title: String, detail: String, primary: String,
                        action: @escaping () -> Void) -> some View {
        VStack(spacing: CYSpacing.md) {
            Image(systemName: icon).font(.largeTitle).imageScale(.large).foregroundStyle(tint).accessibilityHidden(true)
            Text(LocalizedStringKey(title), tableName: "MpFresh")
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(detail), tableName: "MpFresh")
                .cyText(.bodyCompact)
                .foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(LocalizedStringKey(primary), tableName: "MpFresh")
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
        }
        .padding(.vertical, CYSpacing.md)
        .frame(maxWidth: .infinity)
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
