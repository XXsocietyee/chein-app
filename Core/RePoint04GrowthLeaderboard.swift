import Foundation

/// RP-04 (NOT COMPILED). Production serves only `POST /api/growth/leaderboard`
/// (ApiGrowthController, form-bound LeaderboardQueryDTO); `/api/growth/leaderboard/anonymous`
/// does not exist there. This factory pins the existing `.legacy` read contract, which already
/// targets the production path and maps to `GrowthLeaderboard`. It grants no transport access;
/// callers still sit behind the existing gates.
public enum RePoint04GrowthLeaderboard {
    public static let productionPath = "api/growth/leaderboard"
    public static let unservedPath = "api/growth/leaderboard/anonymous"

    public static func service(configuration: APIConfiguration, transport: any HTTPTransport) -> GrowthCenterService {
        GrowthCenterService(configuration: configuration, transport: transport, leaderboardContract: .legacy)
    }
}
