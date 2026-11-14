import Foundation

/// History list and share snapshot for `subpackageRoam/history`. Both go through the existing readers.
@MainActor public enum WP06RoamHistoryClient {
    public static func records(_ reader: any RoamExperienceReading) throws -> [RoamHistoryRecord] {
        try reader.history()
    }

    public static func shareSnapshot(_ reader: any RoamShareSnapshotReading, token: RoamShareToken) async -> RoamShareSnapshotOutcome {
        await reader.snapshot(token)
    }
}
