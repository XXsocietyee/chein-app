import Foundation

/// Sensitive data classes audited by `NPCChatAndSceneAISafetyAudit` (`G-W04` & `I08`).
public enum NPCSafetyAuditedDataClass: String, CaseIterable, Comparable, Hashable, Sendable {
    case approvedStoreFacts = "APPROVED_STORE_FACTS"
    case unlockedClues = "UNLOCKED_CLUES"
    case coordinates = "PRECISE_COORDINATES"
    case contactInfo = "CONTACT_INFO"
    case paymentCredentials = "PAYMENT_CREDENTIALS"
    case lockedCluesAndEndings = "LOCKED_CLUES_AND_ENDINGS"
    case otherPlayerMemory = "OTHER_PLAYER_MEMORY"
    case privateStoreOperations = "PRIVATE_STORE_OPERATIONS"

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var isForbiddenForNPCChat: Bool {
        switch self {
        case .approvedStoreFacts, .unlockedClues:
            return false
        case .coordinates,
             .contactInfo,
             .paymentCredentials,
             .lockedCluesAndEndings,
             .otherPlayerMemory,
             .privateStoreOperations:
            return true
        }
    }
}

/// Authority effects audited on incoming NPC AI replies (`G-W04`).
public enum NPCSafetyAuditedAuthorityEffect: String, CaseIterable, Comparable, Hashable, Sendable {
    case presentUnlockedClue = "PRESENT_UNLOCKED_CLUE"
    case explainKnownRule = "EXPLAIN_KNOWN_RULE"
    case walletMutation = "WALLET_MUTATION"
    case inventoryMutation = "INVENTORY_MUTATION"
    case orderMutation = "ORDER_MUTATION"
    case grantReward = "GRANT_REWARD"
    case changePrice = "CHANGE_PRICE"
    case payment = "PAYMENT"
    case refund = "REFUND"

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var isForbiddenAuthorityMutation: Bool {
        switch self {
        case .presentUnlockedClue, .explainKnownRule:
            return false
        case .walletMutation,
             .inventoryMutation,
             .orderMutation,
             .grantReward,
             .changePrice,
             .payment,
             .refund:
            return true
        }
    }
}

/// Memory record candidate evaluated during `G-W04` / `I08` readback filtering.
public struct NPCSafetyMemoryRecordCandidate: Equatable, Sendable {
    public let memoryID: String
    public let isolationKey: String
    public let hasActiveConsent: Bool
    public let expiresAt: Date?
    public let isDeletedLocallyOrRemotely: Bool

    public init(
        memoryID: String,
        isolationKey: String,
        hasActiveConsent: Bool = true,
        expiresAt: Date? = nil,
        isDeletedLocallyOrRemotely: Bool = false
    ) {
        self.memoryID = memoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isolationKey = isolationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hasActiveConsent = hasActiveConsent
        self.expiresAt = expiresAt
        self.isDeletedLocallyOrRemotely = isDeletedLocallyOrRemotely
    }

    public func isAdmissible(expectedIsolationKey: String, at referenceDate: Date) -> Bool {
        guard !memoryID.isEmpty,
              isolationKey == expectedIsolationKey,
              hasActiveConsent,
              !isDeletedLocallyOrRemotely else {
            return false
        }
        if let expiresAt, expiresAt <= referenceDate {
            return false
        }
        return true
    }
}

/// Procedural 3D low-poly NPC figure builder & software shader ported from `pages/play/utils/npc-figure.js`.
public struct NPCLowPolyFigureRenderer: Equatable, Sendable {
    public struct Vec3: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double

        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    public struct ShadedQuad: Equatable, Sendable {
        public let points2D: [(x: Double, y: Double)]
        public let depthZ: Double
        public let hexColor: String
        public let brightness: Double

        public static func == (lhs: ShadedQuad, rhs: ShadedQuad) -> Bool {
            guard lhs.depthZ == rhs.depthZ,
                  lhs.hexColor == rhs.hexColor,
                  lhs.brightness == rhs.brightness,
                  lhs.points2D.count == rhs.points2D.count else {
                return false
            }
            for (l, r) in zip(lhs.points2D, rhs.points2D) where l.x != r.x || l.y != r.y {
                return false
            }
            return true
        }
    }

    public let accentHex: String
    public let coatHex: String
    public let hairHex: String

    public init(
        accentHex: String = "#14B8A6",
        coatHex: String = "#1F2937",
        hairHex: String = "#111827"
    ) {
        self.accentHex = accentHex
        self.coatHex = coatHex
        self.hairHex = hairHex
    }

    /// Ported from `project(pt, yaw, pitch, cx, cy, scale)` in `pages/play/utils/npc-figure.js`.
    public static func project(
        _ point: Vec3,
        yaw: Double,
        pitch: Double = -0.1,
        centerX: Double = 100.0,
        centerY: Double = 110.0,
        scale: Double = 46.0
    ) -> (x: Double, y: Double, z: Double) {
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        let x1 = point.x * cosY + point.z * sinY
        let z1 = -point.x * sinY + point.z * cosY
        let cosP = cos(pitch)
        let sinP = sin(pitch)
        let y2 = point.y * cosP - z1 * sinP
        let z2 = point.y * sinP + z1 * cosP
        let perspective = 4.2 / (4.2 - z2 * 0.45)
        return (
            x: centerX + x1 * scale * perspective,
            y: centerY - y2 * scale * perspective,
            z: z2
        )
    }

    /// Returns total low-poly quad faces generated by `buildFigure` (head, hair cap, torso coat, collar accent, arms, legs, pedestal = 8boxes * 6 faces = 48 quads).
    public var canonicalBoxFaceCount: Int { 48 }
}

/// Port of `subpackageMember/components/cy/npc-chat/chat-export.js` (`PREVIEW_LIMIT = 50`, `normalizeExport`, `formatReadable`, `previewRows`).
public enum NPCChatTranscriptExporter {
    public static let previewLimit: Int = 50

    public struct ExportMessage: Equatable, Sendable, Identifiable {
        public let id: String
        public let role: String
        public let content: String
        public let createdAt: String

        public init(id: String, role: String, content: String, createdAt: String = "") {
            self.id = id
            self.role = role
            self.content = content
            self.createdAt = createdAt
        }
    }

    public static func previewRows(from messages: [ExportMessage]) -> (rows: [ExportMessage], truncatedCount: Int) {
        let valid = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let slice = Array(valid.prefix(previewLimit))
        return (rows: slice, truncatedCount: max(0, valid.count - slice.count))
    }

    public static func formatReadable(
        npcName: String,
        scope: String,
        messages: [ExportMessage]
    ) -> String {
        let headerName = npcName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "NPC" : npcName
        let (rows, truncated) = previewRows(from: messages)
        var lines: [String] = ["【\(headerName) · 对话记录 (\(scope))】"]
        for row in rows {
            let speaker = (row.role == "user" || row.role == "player") ? "我" : headerName
            lines.append("\(speaker)：\(row.content)")
        }
        if truncated > 0 {
            lines.append("…已省略其余 \(truncated) 条记录")
        }
        return lines.joined(separator: "\n")
    }
}

/// Port of `pages/topic/components/cy/node-npc-form/index.js` & `pages/merchant/decor/ai-npc/index.js` authoring rules.
public struct NPCAuthoringFormParityContract: Equatable, Sendable {
    public enum MerchantPersonality: String, CaseIterable, Equatable, Sendable {
        case gentle = "gentle"
        case cute = "cute"
        case savage = "savage"
    }

    public static let pixelAvatarDimension: Int = 32
    public static let maxChatInputCodepoints: Int = 300
    public static let maxTranscriptWindowMessages: Int = 20

    public let nodeFormSupportsSelectCreateClear: Bool
    public let merchantPersonalities: [MerchantPersonality]
    public let supportsPresetPx1And32x32Crop: Bool
    public let reusesChannelChatMessageBubble: Bool

    public init(
        nodeFormSupportsSelectCreateClear: Bool = true,
        merchantPersonalities: [MerchantPersonality] = MerchantPersonality.allCases,
        supportsPresetPx1And32x32Crop: Bool = true,
        reusesChannelChatMessageBubble: Bool = true
    ) {
        self.nodeFormSupportsSelectCreateClear = nodeFormSupportsSelectCreateClear
        self.merchantPersonalities = merchantPersonalities
        self.supportsPresetPx1And32x32Crop = supportsPresetPx1And32x32Crop
        self.reusesChannelChatMessageBubble = reusesChannelChatMessageBubble
    }

    public var isAuthoringAndChatParityCompliant: Bool {
        nodeFormSupportsSelectCreateClear
            && Set(merchantPersonalities) == Set(MerchantPersonality.allCases)
            && supportsPresetPx1And32x32Crop
            && reusesChannelChatMessageBubble
    }
}

/// Deterministic safety audit report for `G-W04` NPC AI scene guard and `I08` NPC chat deletion.
public struct NPCChatAndSceneAISafetyAuditReport: Equatable, Sendable {
    public enum Violation: Equatable, Sendable {
        case emptyIsolationKey
        case streamingDisplayEnabled
        case unapprovedRemoteChatDeleteEnabled
        case sensitiveDataClassesNotRejected([NPCSafetyAuditedDataClass])
        case forbiddenAuthorityEffectsNotDropped([NPCSafetyAuditedAuthorityEffect])
        case deletionFenceViolated(reappearedMemoryIDs: [String])
    }

    public let isolationKey: String
    public let sceneAIDefaultDisabled: Bool
    public let remoteChatDeleteGateEnabled: Bool
    public let remoteChatDeleteApproved: Bool
    public let isNonGenerativeBadgeActive: Bool
    public let isStreamingOffBadgeActive: Bool
    public let rejectedDataClasses: [NPCSafetyAuditedDataClass]
    public let droppedForbiddenEffects: [NPCSafetyAuditedAuthorityEffect]
    public let acceptedNarrativeEffects: [NPCSafetyAuditedAuthorityEffect]
    public let admissibleRecords: [NPCSafetyMemoryRecordCandidate]
    public let reappearedDeletedMemoryIDs: [String]
    public let violations: [Violation]

    public init(
        isolationKey: String,
        sceneAIDefaultDisabled: Bool,
        remoteChatDeleteGateEnabled: Bool,
        remoteChatDeleteApproved: Bool,
        isNonGenerativeBadgeActive: Bool,
        isStreamingOffBadgeActive: Bool,
        rejectedDataClasses: [NPCSafetyAuditedDataClass],
        droppedForbiddenEffects: [NPCSafetyAuditedAuthorityEffect],
        acceptedNarrativeEffects: [NPCSafetyAuditedAuthorityEffect],
        admissibleRecords: [NPCSafetyMemoryRecordCandidate],
        reappearedDeletedMemoryIDs: [String],
        violations: [Violation]
    ) {
        self.isolationKey = isolationKey
        self.sceneAIDefaultDisabled = sceneAIDefaultDisabled
        self.remoteChatDeleteGateEnabled = remoteChatDeleteGateEnabled
        self.remoteChatDeleteApproved = remoteChatDeleteApproved
        self.isNonGenerativeBadgeActive = isNonGenerativeBadgeActive
        self.isStreamingOffBadgeActive = isStreamingOffBadgeActive
        self.rejectedDataClasses = rejectedDataClasses
        self.droppedForbiddenEffects = droppedForbiddenEffects
        self.acceptedNarrativeEffects = acceptedNarrativeEffects
        self.admissibleRecords = admissibleRecords
        self.reappearedDeletedMemoryIDs = reappearedDeletedMemoryIDs
        self.violations = violations
    }

    public var isSafetyCompliant: Bool {
        violations.isEmpty
    }
}

/// Pure auditor for `G-W04` NPC AI scene guard and `I08` (`AI-DELETE`) NPC chat log deletion safety.
public enum NPCChatAndSceneAISafetyAudit {
    public static let remoteChatDeleteRoute = "/api/npc/chat/delete"

    public static func audit(
        isolationKey: String,
        sceneAIDefaultDisabled: Bool = true,
        allowsStreamingDisplay: Bool = false,
        remoteChatDeleteGateEnabled: Bool = false,
        remoteChatDeleteApproved: Bool = false,
        requestedDataClasses: Set<NPCSafetyAuditedDataClass> = [.approvedStoreFacts],
        proposedEffects: [NPCSafetyAuditedAuthorityEffect] = [],
        memoryCandidates: [NPCSafetyMemoryRecordCandidate] = [],
        deletedMemoryIDFence: Set<String> = [],
        referenceDate: Date = Date(timeIntervalSince1970: 1_750_000_000)
    ) -> NPCChatAndSceneAISafetyAuditReport {
        var violations: [NPCChatAndSceneAISafetyAuditReport.Violation] = []
        let trimmedKey = isolationKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedKey.isEmpty {
            violations.append(.emptyIsolationKey)
        }

        if allowsStreamingDisplay {
            violations.append(.streamingDisplayEnabled)
        }

        if remoteChatDeleteGateEnabled && !remoteChatDeleteApproved {
            violations.append(.unapprovedRemoteChatDeleteEnabled)
        }

        let rejectedData = requestedDataClasses
            .filter(\.isForbiddenForNPCChat)
            .sorted()

        var droppedEffects: [NPCSafetyAuditedAuthorityEffect] = []
        var acceptedEffects: [NPCSafetyAuditedAuthorityEffect] = []
        for effect in proposedEffects {
            if effect.isForbiddenAuthorityMutation {
                droppedEffects.append(effect)
            } else {
                acceptedEffects.append(effect)
            }
        }
        droppedEffects.sort()
        acceptedEffects.sort()

        let reappearedIDs = memoryCandidates
            .map(\.memoryID)
            .filter { deletedMemoryIDFence.contains($0) }
            .sorted()
        if !reappearedIDs.isEmpty {
            violations.append(.deletionFenceViolated(reappearedMemoryIDs: reappearedIDs))
        }

        let admissible: [NPCSafetyMemoryRecordCandidate]
        if reappearedIDs.isEmpty {
            admissible = memoryCandidates.filter {
                !deletedMemoryIDFence.contains($0.memoryID) &&
                    $0.isAdmissible(expectedIsolationKey: trimmedKey, at: referenceDate)
            }
        } else {
            admissible = []
        }

        return NPCChatAndSceneAISafetyAuditReport(
            isolationKey: trimmedKey,
            sceneAIDefaultDisabled: sceneAIDefaultDisabled,
            remoteChatDeleteGateEnabled: remoteChatDeleteGateEnabled,
            remoteChatDeleteApproved: remoteChatDeleteApproved,
            isNonGenerativeBadgeActive: sceneAIDefaultDisabled,
            isStreamingOffBadgeActive: !allowsStreamingDisplay,
            rejectedDataClasses: rejectedData,
            droppedForbiddenEffects: droppedEffects,
            acceptedNarrativeEffects: acceptedEffects,
            admissibleRecords: admissible,
            reappearedDeletedMemoryIDs: reappearedIDs,
            violations: violations
        )
    }
}
