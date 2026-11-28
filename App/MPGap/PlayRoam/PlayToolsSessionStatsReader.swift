import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-journey r3: MP 游玩工具 `loadSessionStats` (`pages/play/utils/play-hud-overlays.js`). Reads
/// `GET /api/orient/scoring/session/{id}` and then the optional `/leaderboard` with the same c6 service and live token as
/// the 本局成绩 page (`CloudB3SessionBridge.orientRoundsLoader`, `OrientScoreBoardRead`). A nil result hides the rows
/// (scoring off for this round, MP `ORIENT_SCORING_DISABLED` / `ORIENT_SCORING_NOT_APPLICABLE`).
typealias PlayToolsSessionStatsLoader = (_ sessionID: Int, _ scope: OrientSessionScope) async -> PlayToolsSessionStats?

@MainActor enum PlayToolsSessionStatsRead {
    static func make(session: AppSession) -> PlayToolsSessionStatsLoader? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        let access = session.squareGovernanceAccess()
        return { sessionID, scope in
            guard let token = access.token, AuthRequestBuilder.isValidToken(token) else { return .failed }
            let score: OrientSessionScore
            do {
                score = try await service.score(sessionID: sessionID, scope: scope, token: token)
            } catch {
                return PlayToolsSessionStats.hidesRows(for: error) ? nil : .failed
            }
            let board = try? await service.leaderboard(sessionID: sessionID, token: token)
            return PlayToolsSessionStats.project(score: score, board: board)
        }
    }
}

private struct PlayToolsSessionStatsLoaderKey: EnvironmentKey {
    static let defaultValue: PlayToolsSessionStatsLoader? = nil
}

/// MP `openBoard` orient branch: the 同行者榜 read for a city-orientation round (`OrientScoreBoardRead`).
private struct PlayOrientBoardLoaderKey: EnvironmentKey {
    static let defaultValue: ((Int) async throws -> OrientSessionLeaderboard)? = nil
}

extension EnvironmentValues {
    var playToolsSessionStatsLoader: PlayToolsSessionStatsLoader? {
        get { self[PlayToolsSessionStatsLoaderKey.self] }
        set { self[PlayToolsSessionStatsLoaderKey.self] = newValue }
    }
    var playOrientBoardLoader: ((Int) async throws -> OrientSessionLeaderboard)? {
        get { self[PlayOrientBoardLoaderKey.self] }
        set { self[PlayOrientBoardLoaderKey.self] = newValue }
    }
}

/// mp-journey-b r3: MP 同行者榜 `openBoard` on a city run reads the orient-scoring board for `routeState.sessionId` first
/// (same c6 service and live token as `PlayToolsSessionStatsRead`).
typealias PlayOrientBoardLoader = (_ sessionID: Int) async -> PlayOrientBoardRead

@MainActor enum PlayOrientBoardReadFactory {
    static func make(session: AppSession) -> PlayOrientBoardLoader? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        let access = session.squareGovernanceAccess()
        return { sessionID in
            guard let token = access.token, AuthRequestBuilder.isValidToken(token) else { return .failed }
            do {
                return .board(PlayOrientBoard(try await service.leaderboard(sessionID: sessionID, token: token)))
            } catch {
                return PlayToolsSessionStats.hidesRows(for: error) ? .scoringOff : .failed
            }
        }
    }
}

private struct PlayOrientBoardLoaderKey: EnvironmentKey {
    static let defaultValue: PlayOrientBoardLoader? = nil
}

extension EnvironmentValues {
    var playOrientBoardLoader: PlayOrientBoardLoader? {
        get { self[PlayOrientBoardLoaderKey.self] }
        set { self[PlayOrientBoardLoaderKey.self] = newValue }
    }
}
