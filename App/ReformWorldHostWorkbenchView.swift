import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Unified Reform World & Release Host Diagnostics Workbench View.
///
/// Summarizes `WaveUnifiedParityInventory` counts (`wave2Count == 21`, `wave3Count == 13`,
/// `reformWorkPackageCount == 19`, `unifiedDecisionCount == 8`, and fail-closed switch evaluation)
/// and embeds `ReleasePreflightDiagnosticsView`, `RunAuthorityHostSectionView`, and
/// `NPCAISceneGuardSectionView` using `Text(verbatim:)` throughout (0 new `.xcstrings` keys).
@MainActor
public struct ReformWorldHostWorkbenchView: View {
    public let readinessReport: WaveUnifiedParityInventory.ReleaseReadinessReport
    public let highRiskSwitches: [WaveUnifiedParityInventory.HighRiskSwitchStatus]
    public let preflightDiagnosticsView: ReleasePreflightDiagnosticsView
    public let runAuthoritySectionView: RunAuthorityHostSectionView
    public let npcAISceneGuardSectionView: NPCAISceneGuardSectionView

    public init(
        readinessReport: WaveUnifiedParityInventory.ReleaseReadinessReport = WaveUnifiedParityInventory.verifyReleaseReadinessInvariants(),
        highRiskSwitches: [WaveUnifiedParityInventory.HighRiskSwitchStatus] = WaveUnifiedParityInventory.evaluateHighRiskSwitches(),
        preflightDiagnosticsView: ReleasePreflightDiagnosticsView? = nil,
        runAuthoritySectionView: RunAuthorityHostSectionView? = nil,
        npcAISceneGuardSectionView: NPCAISceneGuardSectionView? = nil
    ) {
        self.readinessReport = readinessReport
        self.highRiskSwitches = highRiskSwitches
        self.preflightDiagnosticsView = preflightDiagnosticsView ?? ReleasePreflightDiagnosticsView()
        self.runAuthoritySectionView = runAuthoritySectionView ?? Self.makeDefaultRunAuthoritySectionView()
        self.npcAISceneGuardSectionView = npcAISceneGuardSectionView ?? NPCAISceneGuardSectionView()
    }

    public static func makeDefaultRunAuthoritySectionView() -> RunAuthorityHostSectionView {
        let fallbackProjection = (try? RunAuthorityProjection(
            runId: "run-workbench-01",
            stateVersion: 1,
            status: .active,
            nodes: ["node-entry": .available, "node-stage-2": .locked]
        )) ?? RunAuthorityProjection.placeholder
        let coordinator = RunAuthorityHostCoordinator(
            projection: fallbackProjection,
            capabilities: .disabled
        )
        return RunAuthorityHostSectionView(coordinator: coordinator)
    }

    // MARK: - Derived Summary Strings

    public var readinessVerdictBadgeText: String {
        readinessReport.isReleaseReady
            ? "RELEASE READY · FAIL-CLOSED VERIFIED"
            : "BLOCKED · INVARIANT VIOLATION"
    }

    public var parityCountsSummaryText: String {
        "Wave-2: \(readinessReport.wave2Count)/21 · Wave-3: \(readinessReport.wave3Count)/13 · Reform W02–W20: \(readinessReport.reformWorkPackageCount)/19 · Decisions U01–U08: \(readinessReport.unifiedDecisionCount)/8"
    }

    public var wave2SummaryText: String {
        "Wave-2 Mini-Program Parity Scopes: \(readinessReport.wave2Count) / 21 (missing: \(readinessReport.missingWave2IDs.count))"
    }

    public var wave3SummaryText: String {
        "Wave-3 Handoff Scopes (I00–I11, BK): \(readinessReport.wave3Count) / 13 (missing: \(readinessReport.missingWave3IDs.count))"
    }

    public var reformPackagesSummaryText: String {
        "Reform Plan v9 Work Packages (W02–W20): \(readinessReport.reformWorkPackageCount) / 19 (missing: \(readinessReport.missingReformPackageIDs.count))"
    }

    public var unifiedDecisionsSummaryText: String {
        "Unified Decisions (U01–U08): \(readinessReport.unifiedDecisionCount) / 8 (missing: \(readinessReport.missingUnifiedDecisionIDs.count))"
    }

    public var failClosedSwitchesSummaryText: String {
        let closedCount = highRiskSwitches.filter(\.isFailClosed).count
        if readinessReport.allHighRiskSwitchesFailClosed && closedCount == highRiskSwitches.count {
            return "High-Risk Write/Payment/Cash Switches: \(closedCount)/\(highRiskSwitches.count) FAIL-CLOSED (0 enabled)"
        }
        let openNames = readinessReport.openHighRiskSwitches.joined(separator: ", ")
        return "High-Risk Write/Payment/Cash Switches: \(readinessReport.openHighRiskSwitches.count) OPEN (\(openNames))"
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CYHeroHeader(verbatim: "Reform World & Release Host Workbench")
                inventoryOverviewCard
                highRiskSwitchesCard
                embeddedRunAuthorityCard
                embeddedNPCAISceneGuardCard
                embeddedReleasePreflightCard
            }
            .padding(16)
        }
                .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.root")
    }

    private var inventoryOverviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "Wave 1–5 Unified Master Parity Inventory")
                    .cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                Spacer()
                Text(verbatim: readinessVerdictBadgeText)
                    .cyText(.caption, weight: .semibold)
                    .foregroundStyle(readinessReport.isReleaseReady ? CYColor.successText : CYColor.dangerText)
                    .accessibilityIdentifier("reformWorldWorkbench.verdictBadge")
            }

            Text(verbatim: parityCountsSummaryText)
                .cyText(.numericBody)
                .accessibilityIdentifier("reformWorldWorkbench.parityCountsSummary")

            Text(verbatim: wave2SummaryText)
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("reformWorldWorkbench.wave2Summary")

            Text(verbatim: wave3SummaryText)
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("reformWorldWorkbench.wave3Summary")

            Text(verbatim: reformPackagesSummaryText)
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("reformWorldWorkbench.reformPackagesSummary")

            Text(verbatim: unifiedDecisionsSummaryText)
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("reformWorldWorkbench.unifiedDecisionsSummary")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CYColor.textSecondary.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.inventorySection")
    }

    private var highRiskSwitchesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Fail-Closed Switch Evaluation")
                .cyText(.cardTitle).accessibilityAddTraits(.isHeader)

            Text(verbatim: failClosedSwitchesSummaryText)
                .font(.footnote.monospaced())
                .foregroundStyle(readinessReport.allHighRiskSwitchesFailClosed ? CYColor.textSecondary : CYColor.dangerText)
                .accessibilityIdentifier("reformWorldWorkbench.failClosedSwitchesSummary")

            ForEach(highRiskSwitches, id: \.name) { item in
                HStack {
                    Text(verbatim: item.name)
                        .font(.caption.monospaced())
                    Spacer()
                    Text(verbatim: item.isFailClosed ? "OFF (Fail-Closed)" : "ON (Open)")
                        .font(.caption.monospaced())
                        .foregroundStyle(item.isFailClosed ? CYColor.textSecondary : CYColor.dangerText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reformWorldWorkbench.switchRow.\(item.name)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CYColor.textSecondary.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.switchesSection")
    }

    private var embeddedRunAuthorityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Embedded Run Authority & CAS Section")
                .cyText(.bodyMedium)
            runAuthoritySectionView
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.runAuthorityContainer")
    }

    private var embeddedNPCAISceneGuardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Embedded NPC AI Scene Guard Section")
                .cyText(.bodyMedium)
            npcAISceneGuardSectionView
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.npcAISceneGuardContainer")
    }

    private var embeddedReleasePreflightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Embedded Release Preflight & UI Readiness Diagnostics")
                .cyText(.bodyMedium)
            preflightDiagnosticsView
                .frame(minHeight: 360)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reformWorldWorkbench.releasePreflightContainer")
    }
}
