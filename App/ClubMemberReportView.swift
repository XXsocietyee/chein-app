import SwiftUI

/// Only prepares the existing platform-report flow. Target name is display-only;
/// the immutable MEMBER/id anchors use the existing exact governance contract.
@MainActor struct ClubMemberReportView: View {
    let target: ClubMemberReportTarget
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext
    @Environment(\.dismiss) private var dismiss
    private var currentContext: ClubGovernanceReadContext {
        .init(operation: .members, scope: .init(clubID: target.clubID), identity: identity,
              viewerRevision: governance.viewerRevision, authorizationGeneration: governance.access.authorizationGeneration,
              accessIdentity: ObjectIdentifier(governance.access))
    }
    private var isCurrent: Bool {
        target.context == currentContext && identity == governance.access.identity && governance.access.isConfigured
    }
    var body: some View {
        Group {
            if isCurrent {
                VStack(alignment: .leading, spacing: 0) {
                    // The report form owns the one bar title (`club.gov.action.report`). A second hero would repeat it.
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text("club.memberReport.target")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let name = target.displayName {
                            Text(verbatim: name)
                                .cyText(.sectionTitle)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("club.memberReport.unnamed")
                                .cyText(.sectionTitle)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("club.memberReport.explanation")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CYSpacing.lg)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(CYColor.borderSubtle, lineWidth: 1))
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.top, CYSpacing.lg)
                    .padding(.bottom, CYSpacing.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.memberReport.target")
                    ClubGovernanceCommandForm(route: .init(operation: .report, scope: target.scope,
                                                   seed: target.seed.merging(ClubGovernanceReportPort.displayName(target.displayName).map { ["targetName": ClubGovernanceValue.string($0)] } ?? [:]) { current, _ in current }),
                                              identity: identity, access: governance.access, coordinator: governance.coordinator)
                        .id(target.id)
                }
                .cyDomainPageBackground()
            } else {
                Text("club.gov.changed")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .padding(CYSpacing.pageHorizontal)
                    .onAppear { closeStale() }
            }
        }
        .onChange(of: currentContext) { _, _ in closeStale() }
        .onDisappear { governance.coordinator.cancelReview() }
    }
    private func closeStale() {
        governance.coordinator.cancelReview(); dismiss()
    }
}
