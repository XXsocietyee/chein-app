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
        guard let token, AuthRequestBuilder.isValidToken(token) else {
            return .applyForHost
        }
        do {
            let owned = try await clubService.owned(token: token)
            if owned.isEmpty {
                return .applyForHost
            }
            if owned.count == 1, let first = owned.first {
                return .openClub(first)
            }
            return .chooseClub(owned)
        } catch let error as ClubReadFailure {
            switch error {
            case .unauthorized, .forbidden, .httpStatus, .rejected, .membershipRequired:
                return .failed(message: Self.loadFailureMessage)
            }
        } catch is APIError {
            // APIError has no transport case; URLError below is the network failure.
            return .failed(message: Self.loadFailureMessage)
        } catch is URLError {
            return .failed(message: Self.networkFailureMessage)
        } catch {
            return .failed(message: Self.loadFailureMessage)
        }
    }
}
