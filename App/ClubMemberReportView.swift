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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("club.memberReport.target")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Group {
                            if let name = target.displayName {
                                Text(verbatim: name)
                            } else {
                                Text("club.memberReport.unnamed")
                            }
                        }
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        Text("club.memberReport.explanation")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .background(Color(uiColor: .systemGroupedBackground))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.memberReport.target")
                    ClubGovernanceCommandForm(route: .init(operation: .report, scope: target.scope,
                                                   seed: target.seed.merging(ClubGovernanceReportPort.displayName(target.displayName).map { ["targetName": ClubGovernanceValue.string($0)] } ?? [:]) { current, _ in current }),
                                              identity: identity, access: governance.access, coordinator: governance.coordinator)
                        .id(target.id)
                }
            } else {
                Text("club.gov.changed")
                    .foregroundStyle(.secondary)
                    .padding()
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
