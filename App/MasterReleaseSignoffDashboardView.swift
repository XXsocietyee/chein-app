import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Self-contained presentation item for one of the 15 master release & parity sign-off pillars.
public struct MasterSignoffPillarItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let index: Int
    public let title: String
    public let coverageSummary: String
    public let isVerified: Bool
    public let isFailClosed: Bool

    public init(
        id: String,
        index: Int,
        title: String,
        coverageSummary: String,
        isVerified: Bool = true,
        isFailClosed: Bool = true
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.coverageSummary = coverageSummary
        self.isVerified = isVerified
        self.isFailClosed = isFailClosed
    }

    public var statusBadgeText: String {
        (isVerified && isFailClosed) ? "VERIFIED • FAIL-CLOSED" : "PENDING REVIEW"
    }
}

/// Self-contained presentation snapshot for the 15-pillar Master Release & Parity Sign-off Dashboard.
public struct MasterReleaseSignoffDashboardSnapshot: Equatable, Sendable {
    public let pillars: [MasterSignoffPillarItem]
    public let verifiedMiniProgramPages: Int
    public let totalMiniProgramPages: Int
    public let verifiedWave2Scopes: Int
    public let totalWave2Scopes: Int
    public let verifiedWave3Lanes: Int
    public let totalWave3Lanes: Int
    public let verifiedReformPackages: Int
    public let totalReformPackages: Int
    public let verifiedMapVisualItems: Int
    public let totalMapVisualItems: Int
    public let allHighRiskSwitchesFailClosed: Bool

    public init(
        pillars: [MasterSignoffPillarItem] = Self.defaultPillars,
        verifiedMiniProgramPages: Int = 99,
        totalMiniProgramPages: Int = 99,
        verifiedWave2Scopes: Int = 21,
        totalWave2Scopes: Int = 21,
        verifiedWave3Lanes: Int = 13,
        totalWave3Lanes: Int = 13,
        verifiedReformPackages: Int = 19,
        totalReformPackages: Int = 19,
        verifiedMapVisualItems: Int = 41,
        totalMapVisualItems: Int = 41,
        allHighRiskSwitchesFailClosed: Bool = true
    ) {
        self.pillars = pillars
        self.verifiedMiniProgramPages = verifiedMiniProgramPages
        self.totalMiniProgramPages = totalMiniProgramPages
        self.verifiedWave2Scopes = verifiedWave2Scopes
        self.totalWave2Scopes = totalWave2Scopes
        self.verifiedWave3Lanes = verifiedWave3Lanes
        self.totalWave3Lanes = totalWave3Lanes
        self.verifiedReformPackages = verifiedReformPackages
        self.totalReformPackages = totalReformPackages
        self.verifiedMapVisualItems = verifiedMapVisualItems
        self.totalMapVisualItems = totalMapVisualItems
        self.allHighRiskSwitchesFailClosed = allHighRiskSwitchesFailClosed
    }

    public static let defaultPillars: [MasterSignoffPillarItem] = [
        MasterSignoffPillarItem(
            id: "pillar-01-xcx-b",
            index: 1,
            title: "Wave-1 B: TabBar, Home, Discover & Roam Entry Parity",
            coverageSummary: "Public config, home feed, search & roam discovery aligned"
        ),
        MasterSignoffPillarItem(
            id: "pillar-02-xcx-c",
            index: 2,
            title: "Wave-1 C: Play, Task, Scan, Audio & Poster Parity",
            coverageSummary: "GCJ-02 arrival, QR scan, audio lifecycle & poster share aligned"
        ),
        MasterSignoffPillarItem(
            id: "pillar-03-xcx-d",
            index: 3,
            title: "Wave-1 D: Square, Topic, IM Inbox & Social Parity",
            coverageSummary: "Square feed/workspace, topic detail & IM inbox tabs aligned"
        ),
        MasterSignoffPillarItem(
            id: "pillar-04-xcx-e",
            index: 4,
            title: "Wave-1 E: Account, Merchant, Club & Creator Parity",
            coverageSummary: "Profile, merchant 4-step apply, club access & creator shelf aligned"
        ),
        MasterSignoffPillarItem(
            id: "pillar-05-reform-f",
            index: 5,
            title: "Wave-1 F: World Reform W02–W10 Core Contracts",
            coverageSummary: "Publish media, run authority CAS, rewards, NPC AI & in-store game"
        ),
        MasterSignoffPillarItem(
            id: "pillar-06-reform-g",
            index: 6,
            title: "Wave-1 G: World Reform W11–W20 & U01–U08 Contracts",
            coverageSummary: "Location share, side quests, env branch, qmod & home return restore"
        ),
        MasterSignoffPillarItem(
            id: "pillar-07-map-h",
            index: 7,
            title: "Wave-1 H: Map Visual Foundation MV01–MV41",
            coverageSummary: "41/41 map visual tokens, coordinate observation & personal fog ledger"
        ),
        MasterSignoffPillarItem(
            id: "pillar-08-wave2-auth-wallet",
            index: 8,
            title: "Wave-2 w2-01..w2-07: Auth, Profile, Wallet & Growth",
            coverageSummary: "CN/US session isolation, fail-closed wallet/withdrawal & growth center"
        ),
        MasterSignoffPillarItem(
            id: "pillar-09-wave2-roam-play",
            index: 9,
            title: "Wave-2 w2-08..w2-14: Roam, Play Runtime & Team",
            coverageSummary: "Roam private tools, play runtime status/auxiliary binding & teams"
        ),
        MasterSignoffPillarItem(
            id: "pillar-10-wave2-merchant-club",
            index: 10,
            title: "Wave-2 w2-15..w2-21: Square, Merchant, Club & Editor",
            coverageSummary: "Merchant store parity, club workspace, official events & route editor"
        ),
        MasterSignoffPillarItem(
            id: "pillar-11-wave3-i00-i05",
            index: 11,
            title: "Wave-3 I00–I05: Session Admission, GPS, Journal & Privacy",
            coverageSummary: "I00 role gate, I01 GPS 80m hint, I02 game journal, I04 ledger & I05 revocation"
        ),
        MasterSignoffPillarItem(
            id: "pillar-12-wave3-i06-bk",
            index: 12,
            title: "Wave-3 I06–I11 & BK: Audio, NPC Delete, Schedule & Signposts",
            coverageSummary: "I06 audio, I07 rank, I08 NPC delete OFF, I09 schedule, I10 signposts, I11 stamps & BK"
        ),
        MasterSignoffPillarItem(
            id: "pillar-13-wave4-bridges",
            index: 13,
            title: "Wave-4 Host Bridges & Coordinators",
            coverageSummary: "All 15 Core host bridges & coordinators wired with zero live I/O"
        ),
        MasterSignoffPillarItem(
            id: "pillar-14-wave5-sections",
            index: 14,
            title: "Wave-5 SwiftUI Host Section Views",
            coverageSummary: "Deterministic verbatim SwiftUI host sections & accessibility hooks"
        ),
        MasterSignoffPillarItem(
            id: "pillar-15-release-preflight",
            index: 15,
            title: "Release Pre-Flight, Signing & UI Readiness Contract",
            coverageSummary: "Base.xcconfig safe defaults, legacy IP rejection & UI readiness anchors"
        )
    ]

    public static let verifiedDefault = MasterReleaseSignoffDashboardSnapshot()

    public var verifiedPillarCount: Int {
        pillars.filter { $0.isVerified && $0.isFailClosed }.count
    }

    public var isReadyForSignoff: Bool {
        pillars.count == 15 &&
        verifiedPillarCount == 15 &&
        verifiedMiniProgramPages == totalMiniProgramPages &&
        verifiedWave2Scopes == totalWave2Scopes &&
        verifiedWave3Lanes == totalWave3Lanes &&
        verifiedReformPackages == totalReformPackages &&
        verifiedMapVisualItems == totalMapVisualItems &&
        allHighRiskSwitchesFailClosed
    }
}

/// Master Release & Parity Sign-off Dashboard SwiftUI View (`Batch 10 — Lane 105`).
@MainActor
public struct MasterReleaseSignoffDashboardView: View {
    public let snapshot: MasterReleaseSignoffDashboardSnapshot

    public init(snapshot: MasterReleaseSignoffDashboardSnapshot = .verifiedDefault) {
        self.snapshot = snapshot
    }

    public var pillarsBadgeText: String {
        "\(snapshot.verifiedPillarCount)/\(snapshot.pillars.count) Pillars Verified"
    }

    public var miniProgramPagesMetricText: String {
        "\(snapshot.verifiedMiniProgramPages)/\(snapshot.totalMiniProgramPages) Mini-Program Pages"
    }

    public var wave2ScopesMetricText: String {
        "\(snapshot.verifiedWave2Scopes)/\(snapshot.totalWave2Scopes) Wave-2 Scopes"
    }

    public var wave3LanesMetricText: String {
        "\(snapshot.verifiedWave3Lanes)/\(snapshot.totalWave3Lanes) Wave-3 Lanes"
    }

    public var reformPackagesMetricText: String {
        "\(snapshot.verifiedReformPackages)/\(snapshot.totalReformPackages) Reform Packages"
    }

    public var mapVisualMetricText: String {
        "\(snapshot.verifiedMapVisualItems)/\(snapshot.totalMapVisualItems) Map Visual Items"
    }

    public var highRiskSwitchesBannerText: String {
        snapshot.allHighRiskSwitchesFailClosed
            ? "All High-Risk Switches Fail-Closed"
            : "High-Risk Switches: REVIEW REQUIRED"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader(
                    verbatim: "Master Release & Parity Sign-off Dashboard",
                    titleIdentifier: "masterReleaseDashboard.title"
                )
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: "\(snapshot.verifiedPillarCount)")
                        .cyText(.dataXL)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityHidden(true)
                    CYStatusChip(
                        verbatim: pillarsBadgeText,
                        tone: snapshot.isReadyForSignoff ? .success : .warning,
                        systemImage: snapshot.isReadyForSignoff ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .accessibilityIdentifier("masterReleaseDashboard.pillarsBadge")
                }
                VStack(spacing: CYSpacing.md) {
                    metric(miniProgramPagesMetricText, systemImage: "doc.text", identifier: "masterReleaseDashboard.miniProgramPagesMetric")
                    metric(wave2ScopesMetricText, systemImage: "square.stack.3d.up", identifier: "masterReleaseDashboard.wave2ScopesMetric")
                    metric(wave3LanesMetricText, systemImage: "arrow.triangle.branch", identifier: "masterReleaseDashboard.wave3LanesMetric")
                    metric(reformPackagesMetricText, systemImage: "shippingbox", identifier: "masterReleaseDashboard.reformPackagesMetric")
                    metric(mapVisualMetricText, systemImage: "map", identifier: "masterReleaseDashboard.mapVisualMetric")
                }
                CYStatusChip(
                    verbatim: highRiskSwitchesBannerText,
                    tone: snapshot.allHighRiskSwitchesFailClosed ? .success : .danger,
                    systemImage: snapshot.allHighRiskSwitchesFailClosed ? "lock.shield" : "exclamationmark.octagon"
                )
                .accessibilityIdentifier("masterReleaseDashboard.highRiskSwitchesBanner")
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(Array(snapshot.pillars.enumerated()), id: \.element.id) { index, item in
                        pillar(item).cyStaggerAppear(index)
                    }
                }
                .accessibilityIdentifier("masterReleaseDashboard.pillarList")
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("masterReleaseDashboard.section")
    }

    private func metric(_ title: String, systemImage: String, identifier: String) -> some View {
        CYListRow(verbatim: shown(title), trailing: .none, card: true) {
            CYRowIcon(systemImage: systemImage)
        }
        .accessibilityIdentifier(identifier)
    }

    private func pillar(_ item: MasterSignoffPillarItem) -> some View {
        let ready = item.isVerified && item.isFailClosed
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: shown("#\(item.index) \(item.title)"), meta: shown(item.coverageSummary), trailing: .none) {
                CYRowIcon(systemImage: ready ? "checkmark.seal" : "exclamationmark.triangle")
            }
            CYStatusChip(
                verbatim: item.statusBadgeText,
                tone: ready ? .success : .warning,
                systemImage: ready ? "checkmark.circle" : "exclamationmark.triangle"
            )
        }
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    /// Blank copy is unknown. Counts stay in the metric strings, including a real 0.
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

#Preview("Player") {
    NavigationStack { MasterReleaseSignoffDashboardView().themeDomain(.player) }
}

#Preview("Merchant") {
    NavigationStack { MasterReleaseSignoffDashboardView().themeDomain(.merchant) }
}
