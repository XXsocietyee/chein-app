import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Navigation decision after tapping Settings -> Become / Manage Club Host (`POST /api/club/my`).
public enum SettingsClubPickerOutcome: Equatable {
    /// User currently owns no clubs and should proceed to club host onboarding/status.
    case applyForHost
    /// User owns a single club that can be opened directly.
    case openClub(ClubRecord)
    /// User owns multiple clubs and must choose one via the option sheet.
    case chooseClub([ClubRecord])
    /// Reading owned clubs failed with exact mini-program localized copy (`俱乐部信息加载失败` or network variant).
    case failed(message: String)
}

/// Queries `POST /api/club/my` when opening the Settings club-host entry so existing owners
/// jump to club management or selection rather than always opening the application form.
public struct SettingsClubPickerService {
    public static let loadFailureMessage = "俱乐部信息加载失败"
    public static let networkFailureMessage = "网络异常，俱乐部信息加载失败"

    private let clubService: ClubService

    public init(clubService: ClubService) {
        self.clubService = clubService
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.clubService = ClubService(configuration: configuration, transport: transport)
    }

    /// Loads the caller's owned clubs via `POST /api/club/my` and classifies the destination.
    public func resolveEntry(token: String?) async -> SettingsClubPickerOutcome {
        switch await loadOwned(token: token) {
        case .unsigned:
            return .applyForHost
        case .failed(let message):
            return .failed(message: message)
        case .clubs(let owned):
            if owned.isEmpty { return .applyForHost }
            if owned.count == 1, let first = owned.first { return .openClub(first) }
            return .chooseClub(owned)
        }
    }

    /// shezhi `pickClub`: any owned club opens the manage tab; a leader with none creates; everyone else applies.
    /// Several owned clubs still open the first record on `manageTab`. `resolveEntry` keeps the chooser.
    public func resolveHostRoute(token: String?, isClubLeader: Bool) async -> SettingsClubHostRoute {
        switch await loadOwned(token: token) {
        case .unsigned:
            return .applyForHost
        case .failed(let message):
            return .failed(message: message)
        case .clubs(let owned):
            if let first = owned.first { return .openManage(first) }
            return isClubLeader ? .createClub : .applyForHost
        }
    }

    private enum OwnedLoad {
        case unsigned
        case clubs([ClubRecord])
        case failed(String)
    }

    private func loadOwned(token: String?) async -> OwnedLoad {
        guard let token, AuthRequestBuilder.isValidToken(token) else { return .unsigned }
        do {
            return .clubs(try await clubService.owned(token: token))
        } catch let error as ClubReadFailure {
            switch error {
            case .unauthorized, .forbidden, .httpStatus, .rejected, .membershipRequired:
                return .failed(Self.loadFailureMessage)
            }
        } catch is URLError {
            return .failed(Self.networkFailureMessage)
        } catch {
            return .failed(Self.loadFailureMessage)
        }
    }
}

/// shezhi `pickClub` destination. `manageTab` is the `tab=manage` query the detail page reads.
public enum SettingsClubHostRoute: Equatable {
    case applyForHost
    case createClub
    case openManage(ClubRecord)
    case failed(message: String)
    public static let manageTab = "manage"
}

/// Drops a second tap while `POST /api/club/my` is in flight, matching `_clubTargetLoading`.
@MainActor
public final class SettingsClubHostRouter {
    private let service: SettingsClubPickerService
    private var loading = false
    public var isLoading: Bool { loading }
    public init(service: SettingsClubPickerService) { self.service = service }
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.service = SettingsClubPickerService(configuration: configuration, transport: transport)
    }
    public func resolve(token: String?, isClubLeader: Bool) async -> SettingsClubHostRoute? {
        guard !loading else { return nil }
        loading = true
        defer { loading = false }
        return await service.resolveHostRoute(token: token, isClubLeader: isClubLeader)
    }
}
