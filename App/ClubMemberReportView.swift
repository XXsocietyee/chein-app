import SwiftUI

/// Only prepares the existing platform-report flow. Target name is display-only;
/// the immutable MEMBER/id anchors use the existing exact governance contract.
@MainActor struct ClubMemberReportView: View {
    let target: ClubMemberReportTarget
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
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
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text("club.memberReport.target").font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                        if let name = target.displayName { Text(verbatim: name).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary) }
                        else { Text("club.memberReport.unnamed").font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary) }
                        Text("club.memberReport.explanation").font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CYSpacing.lg)
                    .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("club.memberReport.target")
                    ClubGovernanceCommandForm(route: .init(operation: .report, scope: target.scope,
                                                   seed: target.seed.merging(ClubGovernanceReportPort.displayName(target.displayName).map { ["targetName": ClubGovernanceValue.string($0)] } ?? [:]) { current, _ in current }),
                                              identity: identity, access: governance.access, coordinator: governance.coordinator)
                        .id(target.id)
                }
            } else {
                CYEmptyState(systemImage: "arrow.triangle.2.circlepath", "club.gov.changed").onAppear { closeStale() }
            }
        }
        .onChange(of: currentContext) { _, _ in closeStale() }
        .onDisappear { governance.coordinator.cancelReview() }
    }
    private func closeStale() {
        governance.coordinator.cancelReview(); dismiss()
    }
}
