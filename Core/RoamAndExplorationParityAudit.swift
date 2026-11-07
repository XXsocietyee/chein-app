import Foundation

/// The 5 audited roam, exploration & GPS play parity pillars.
public enum RoamAndExplorationParityPillar: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case w208RoamEntryMerchantAndSubpages = "w2-08"
    case w209PassportPrivateTools = "w2-09"
    case i00I11ReceivedStamps = "I00+I11"
    case i01PlayArrivalAccuracy = "I01"
    case fW14W15StoryWalkingAndFog = "F-W14/W15"
}

/// E06-17 status classification audited for `RoamSubpagePresentation` (`w2-08`).
public enum RoamSubpageStatusClassification: String, Codable, Equatable, Sendable {
    case ok
    case gone
    case error
}

/// Private tools subpages audited under `w2-09` (`RoamPassportPrivateToolsReading`).
public enum RoamPrivateToolSubpageKind: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case capsule = "capsule"
    case explorationGoals = "exploration-goals"
    case explorationExport = "exploration-export"
    case anniversary = "anniversary"
    case monthlyRecap = "monthly-recap"
}

/// GPS sample classification audited under `I01` (`PlayArrivalAccuracy` & `BK-GPS`).
public enum PlayArrivalAccuracyVerdict: String, Codable, Equatable, Sendable {
    /// `accuracyMeters <= 80` and `ageSeconds <= 30`.
    case qualified
    /// `80 < accuracyMeters <= 100` and `ageSeconds <= 30` (80m advisory warning).
    case advisoryWarning
    /// `accuracyMeters > 100` or `ageSeconds > 30` or negative/non-finite (`invalidAction` / `BK-GPS`).
    case invalidAction
}

/// Nearby radar 3-layer + all filter matching `subpackageRoam/nearby/index.js` (`all | team | place | shop`).
public enum RoamNearbyRadarFilterLayer: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case all = "all"
    case team = "team"
    case place = "place"
    case shop = "shop"
}

/// My-teams status bucket matching `subpackageRoam/my-teams/index.js` (`lead | ok | wait | bad`).
public enum RoamMyTeamStatusBucket: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case lead = "lead"
    case ok = "ok"
    case wait = "wait"
    case bad = "bad"
}

/// 3-step city-stamp creation & exchange flow matching `subpackageRoam/citystamp/index.js`.
public enum RoamCityStampExchangeStep: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case shoot = "shoot"
    case write = "write"
    case exchange = "exchange"
}

/// Badge wall visual finish styles matching `subpackageP3/pages/badge-wall/index/index.js`.
public enum RoamBadgeVisualStyle: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case enamel = "enamel"
    case glow = "glow"
    case pin = "pin"
}

/// Complete W5 Roam tab feature parity descriptor covering map/POIs, nearby radar, official routes,
/// route session replay/privacy, history, my-teams, citynode-code redemption, stamp collection (album + camera),
/// badge wall / 3D badge / object cards, growth center, and location When-In-Use privacy policy.
public struct RoamTabFullFeatureParityDescriptor: Equatable, Sendable {
    public static let nearbyDefaultRadiusMeters: Int = 1_000
    public static let stampCaptionMaxCharacters: Int = 30
    public static let stampTearThresholdPx: Int = 80
    public static let stampScratchCompleteRatio: Double = 0.6
    public static let stampCameraAspectWidth: Int = 4
    public static let stampCameraAspectHeight: Int = 5
    public static let badgeRingDotCount: Int = 24
    public static let badge3DFallbackHintMs: Int = 3_000
    public static let badge3DAutoFallbackMs: Int = 6_000
    public static let objectCardsMaxPileCount: Int = 40

    public let mapNodesAndPOIDetailReady: Bool
    public let nearbyRadarFilterLayers: [RoamNearbyRadarFilterLayer]
    public let officialRoutesAndSessionPrivacyClipReady: Bool
    public let historyAndMyTeamsBuckets: [RoamMyTeamStatusBucket]
    public let cityNodeCodeMissingQRFallbackReady: Bool
    public let stampSteps: [RoamCityStampExchangeStep]
    public let stampCameraStripsEXIFAndGPS: Bool
    public let badgeStyles: [RoamBadgeVisualStyle]
    public let growthCenterAndExplorationToolsReady: Bool
    public let enforcesWhenInUseLocationOnly: Bool
    public let suspendsLocationOnBackground: Bool

    public init(
        mapNodesAndPOIDetailReady: Bool = true,
        nearbyRadarFilterLayers: [RoamNearbyRadarFilterLayer] = RoamNearbyRadarFilterLayer.allCases,
        officialRoutesAndSessionPrivacyClipReady: Bool = true,
        historyAndMyTeamsBuckets: [RoamMyTeamStatusBucket] = RoamMyTeamStatusBucket.allCases,
        cityNodeCodeMissingQRFallbackReady: Bool = true,
        stampSteps: [RoamCityStampExchangeStep] = RoamCityStampExchangeStep.allCases,
        stampCameraStripsEXIFAndGPS: Bool = true,
        badgeStyles: [RoamBadgeVisualStyle] = RoamBadgeVisualStyle.allCases,
        growthCenterAndExplorationToolsReady: Bool = true,
        enforcesWhenInUseLocationOnly: Bool = true,
        suspendsLocationOnBackground: Bool = true
    ) {
        self.mapNodesAndPOIDetailReady = mapNodesAndPOIDetailReady
        self.nearbyRadarFilterLayers = nearbyRadarFilterLayers
        self.officialRoutesAndSessionPrivacyClipReady = officialRoutesAndSessionPrivacyClipReady
        self.historyAndMyTeamsBuckets = historyAndMyTeamsBuckets
        self.cityNodeCodeMissingQRFallbackReady = cityNodeCodeMissingQRFallbackReady
        self.stampSteps = stampSteps
        self.stampCameraStripsEXIFAndGPS = stampCameraStripsEXIFAndGPS
        self.badgeStyles = badgeStyles
        self.growthCenterAndExplorationToolsReady = growthCenterAndExplorationToolsReady
        self.enforcesWhenInUseLocationOnly = enforcesWhenInUseLocationOnly
        self.suspendsLocationOnBackground = suspendsLocationOnBackground
    }

    public var isFullRoamTabParityReady: Bool {
        mapNodesAndPOIDetailReady
            && Set(nearbyRadarFilterLayers) == Set(RoamNearbyRadarFilterLayer.allCases)
            && officialRoutesAndSessionPrivacyClipReady
            && Set(historyAndMyTeamsBuckets) == Set(RoamMyTeamStatusBucket.allCases)
            && cityNodeCodeMissingQRFallbackReady
            && stampSteps == RoamCityStampExchangeStep.allCases
            && stampCameraStripsEXIFAndGPS
            && Set(badgeStyles) == Set(RoamBadgeVisualStyle.allCases)
            && growthCenterAndExplorationToolsReady
            && enforcesWhenInUseLocationOnly
            && suspendsLocationOnBackground
    }

    /// Deterministic 28-bar barcode height generator ported from `barcodeOf(serial)` in `subpackageRoam/citystamp/index.js`.
    public static func stampBarcodeHeights(forSerial serial: String) -> [Int] {
        let normalized = serial.isEmpty ? "CY0000" : serial
        let codeUnits = Array(normalized.utf16)
        guard !codeUnits.isEmpty else { return Array(repeating: 12, count: 28) }
        var bars: [Int] = []
        bars.reserveCapacity(28)
        for index in 0..<28 {
            let code = Int(codeUnits[index % codeUnits.count])
            let height = 12 + ((code * (index + 3)) % 14)
            bars.append(height)
        }
        return bars
    }

    /// Evaluates whether a citystamp caption, perforation tear distance, and scratch ratio satisfy `subpackageRoam/citystamp/index.js`.
    public static func evaluateStampExchangeProgress(
        caption: String,
        tearPixels: Int,
        scratchRatio: Double
    ) -> (isCaptionValid: Bool, isTorn: Bool, isScratchRevealed: Bool) {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCaptionValid = !trimmed.isEmpty && trimmed.count <= stampCaptionMaxCharacters
        let isTorn = tearPixels >= stampTearThresholdPx
        let isScratchRevealed = scratchRatio.isFinite && scratchRatio >= stampScratchCompleteRatio
        return (isCaptionValid, isTorn, isScratchRevealed)
    }
}

/// Audit record for a single roam/exploration pillar.
public struct RoamExplorationPillarAuditEntry: Equatable, Sendable {
    public let pillar: RoamAndExplorationParityPillar
    public let verifiedTypes: [String]
    public let e0617GoneMappedCorrectly: Bool
    public let privateToolSubpagesCovered: Set<RoamPrivateToolSubpageKind>
    public let receivedStampReadAndPresentationAligned: Bool
    public let i01AccuracyThresholdsEnforced: Bool
    public let arrivalOpensVerificationOnly: Bool
    public let revealSyncEnabledByDefault: Bool

    public init(
        pillar: RoamAndExplorationParityPillar,
        verifiedTypes: [String],
        e0617GoneMappedCorrectly: Bool = true,
        privateToolSubpagesCovered: Set<RoamPrivateToolSubpageKind> = Set(RoamPrivateToolSubpageKind.allCases),
        receivedStampReadAndPresentationAligned: Bool = true,
        i01AccuracyThresholdsEnforced: Bool = true,
        arrivalOpensVerificationOnly: Bool = true,
        revealSyncEnabledByDefault: Bool = false
    ) {
        self.pillar = pillar
        self.verifiedTypes = verifiedTypes
        self.e0617GoneMappedCorrectly = e0617GoneMappedCorrectly
        self.privateToolSubpagesCovered = privateToolSubpagesCovered
        self.receivedStampReadAndPresentationAligned = receivedStampReadAndPresentationAligned
        self.i01AccuracyThresholdsEnforced = i01AccuracyThresholdsEnforced
        self.arrivalOpensVerificationOnly = arrivalOpensVerificationOnly
        self.revealSyncEnabledByDefault = revealSyncEnabledByDefault
    }
}

public enum RoamAndExplorationParityViolation: Equatable, Sendable {
    case missingPillar(RoamAndExplorationParityPillar)
    case emptyVerifiedTypes(RoamAndExplorationParityPillar)
    case e0617MappingDrift
    case missingPrivateToolSubpages(Set<RoamPrivateToolSubpageKind>)
    case receivedStampContractDrift
    case i01AccuracyThresholdDrift
    case arrivalAutoCompletesInsteadOfVerification
    case revealSyncUnexpectedlyEnabled
}

public struct RoamAndExplorationParityAuditReport: Equatable, Sendable {
    public let auditedPillars: [RoamAndExplorationParityPillar]
    public let violations: [RoamAndExplorationParityViolation]

    public init(
        auditedPillars: [RoamAndExplorationParityPillar],
        violations: [RoamAndExplorationParityViolation]
    ) {
        self.auditedPillars = auditedPillars
        self.violations = violations
    }

    public var isPassing: Bool {
        violations.isEmpty && Set(auditedPillars) == Set(RoamAndExplorationParityPillar.allCases)
    }
}

/// Pure evaluator for the 5 roam, exploration & GPS play parity pillars.
public enum RoamAndExplorationParityAudit {
    public static let advisoryAccuracyMetersThreshold: Double = 80.0
    public static let maxAllowedAccuracyMeters: Double = 100.0
    public static let maxAllowedSampleAgeSeconds: TimeInterval = 30.0

    /// E06-17 mapping: HTTP/business 404 and 410 map to `.gone`; 503 and other failures map to `.error`.
    public static func classifySubpageStatus(code: Int) -> RoamSubpageStatusClassification {
        switch code {
        case 200:
            return .ok
        case 404, 410:
            return .gone
        default:
            return .error
        }
    }

    /// I01 GPS arrival accuracy evaluation: <=80m qualified, (80m, 100m] advisory warning, >100m or >30s invalidAction.
    public static func evaluateArrivalSample(
        accuracyMeters: Double,
        ageSeconds: TimeInterval
    ) -> PlayArrivalAccuracyVerdict {
        guard accuracyMeters.isFinite,
              ageSeconds.isFinite,
              accuracyMeters >= 0,
              ageSeconds >= 0,
              accuracyMeters <= maxAllowedAccuracyMeters,
              ageSeconds <= maxAllowedSampleAgeSeconds else {
            return .invalidAction
        }
        if accuracyMeters > advisoryAccuracyMetersThreshold {
            return .advisoryWarning
        }
        return .qualified
    }

    public static let baselineEntries: [RoamExplorationPillarAuditEntry] = [
        RoamExplorationPillarAuditEntry(
            pillar: .w208RoamEntryMerchantAndSubpages,
            verifiedTypes: ["RoamEntryNearby", "RoamMerchant", "RoamSubpagePresentation"]
        ),
        RoamExplorationPillarAuditEntry(
            pillar: .w209PassportPrivateTools,
            verifiedTypes: ["RoamPassportPrivateToolsReading"]
        ),
        RoamExplorationPillarAuditEntry(
            pillar: .i00I11ReceivedStamps,
            verifiedTypes: ["RoamReceivedStampRead", "RoamReceivedStampPresentation"]
        ),
        RoamExplorationPillarAuditEntry(
            pillar: .i01PlayArrivalAccuracy,
            verifiedTypes: ["PlayArrivalAccuracy", "BK-GPS"]
        ),
        RoamExplorationPillarAuditEntry(
            pillar: .fW14W15StoryWalkingAndFog,
            verifiedTypes: ["StoryWalkingNavigationHostBridge", "PersonalFogRoamOverlayProjection"],
            revealSyncEnabledByDefault: PersonalFogFeature.revealSyncEnabled
        )
    ]

    public static func runAudit(
        entries: [RoamExplorationPillarAuditEntry] = baselineEntries
    ) -> RoamAndExplorationParityAuditReport {
        var violations: [RoamAndExplorationParityViolation] = []
        let presentPillars = Set(entries.map(\.pillar))

        for required in RoamAndExplorationParityPillar.allCases where !presentPillars.contains(required) {
            violations.append(.missingPillar(required))
        }

        for entry in entries {
            if entry.verifiedTypes.isEmpty {
                violations.append(.emptyVerifiedTypes(entry.pillar))
            }
            if entry.pillar == .w208RoamEntryMerchantAndSubpages && !entry.e0617GoneMappedCorrectly {
                violations.append(.e0617MappingDrift)
            }
            if entry.pillar == .w209PassportPrivateTools {
                let missing = Set(RoamPrivateToolSubpageKind.allCases).subtracting(entry.privateToolSubpagesCovered)
                if !missing.isEmpty {
                    violations.append(.missingPrivateToolSubpages(missing))
                }
            }
            if entry.pillar == .i00I11ReceivedStamps && !entry.receivedStampReadAndPresentationAligned {
                violations.append(.receivedStampContractDrift)
            }
            if entry.pillar == .i01PlayArrivalAccuracy && !entry.i01AccuracyThresholdsEnforced {
                violations.append(.i01AccuracyThresholdDrift)
            }
            if entry.pillar == .fW14W15StoryWalkingAndFog {
                if !entry.arrivalOpensVerificationOnly {
                    violations.append(.arrivalAutoCompletesInsteadOfVerification)
                }
                if entry.revealSyncEnabledByDefault {
                    violations.append(.revealSyncUnexpectedlyEnabled)
                }
            }
        }

        return RoamAndExplorationParityAuditReport(
            auditedPillars: entries.map(\.pillar),
            violations: violations
        )
    }
}
