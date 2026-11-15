import SwiftUI
import CoreLocation

/// Live POI writes (mini-program scene-roam-poi-detail: toggleFavorite / completeNode), injected by the session.
/// nil in the environment hides the controls, e.g. for signed-out or preview hosts.
struct RoamPOIActions {
    var toggleFavorite: @MainActor (Int) async throws -> Bool
    var complete: @MainActor (Int) async throws -> RoamNodeCompletion
}

private struct RoamPOIActionsKey: EnvironmentKey { static let defaultValue: RoamPOIActions? = nil }
extension EnvironmentValues {
    var roamPOIActions: RoamPOIActions? {
        get { self[RoamPOIActionsKey.self] }
        set { self[RoamPOIActionsKey.self] = newValue }
    }
}

enum RoamDeviceFixGCJ {
    /// One foreground fix through the standard iOS permission flow, converted to GCJ-02 exactly once (backend datum).
    @MainActor static func currentGCJ02Fix(provider: any RoamDeviceLocationProviding) async throws -> RoamDeviceFix {
        let raw: RoamDeviceFix
        do { raw = try await provider.currentFix() }
        catch is CancellationError { throw CancellationError() }
        catch {
            if let denied = error as? CLError, denied.code == .denied { throw RoamActionFailure.locationDenied }
            if CLLocationManager().authorizationStatus == .denied || CLLocationManager().authorizationStatus == .restricted { throw RoamActionFailure.locationDenied }
            throw RoamActionFailure.locationUnavailable
        }
        guard raw.datum == .wgs84 else { return raw }
        let center = try RuntimeLocationProjection.gcj02MapCenter(.init(coordinate: raw.coordinate, datum: .wgs84))
        return try RoamDeviceFix(coordinate: center.coordinate, accuracyMeters: raw.accuracyMeters, measuredAt: raw.measuredAt, datum: .gcj02)
    }
}

/// State for one POI detail: favorite toggle and check-in with loading / success / error-retry, double-tap safe.
@MainActor final class RoamPOIActionModel: ObservableObject {
    enum Phase: Equatable { case idle, working, failed(Failure) }
    enum Failure: Equatable { case locationDenied, locationUnavailable, rejected(String), network, signIn }
    @Published var favoriteOverride: Bool?
    @Published var completedOverride: Bool?
    @Published var needRedeemOverride: Bool?
    @Published private(set) var favoritePhase: Phase = .idle
    @Published private(set) var checkInPhase: Phase = .idle
    @Published private(set) var checkInSuccess: RoamNodeCompletion?
    private var token = 0

    func reset() { favoriteOverride = nil; completedOverride = nil; needRedeemOverride = nil; favoritePhase = .idle; checkInPhase = .idle; checkInSuccess = nil; token += 1 }

    func toggleFavorite(poiID: Int, current: Bool, actions: RoamPOIActions) {
        guard favoritePhase != .working else { return }
        favoritePhase = .working
        let mine = token
        Task {
            do {
                let value = try await actions.toggleFavorite(poiID)
                guard mine == token else { return }
                favoriteOverride = value; favoritePhase = .idle
            } catch is CancellationError { if mine == token { favoritePhase = .idle } }
            catch { if mine == token { favoritePhase = .failed(Self.map(error)) } }
        }
    }

    func checkIn(poiID: Int, actions: RoamPOIActions) {
        guard checkInPhase != .working else { return }
        checkInPhase = .working; checkInSuccess = nil
        let mine = token
        Task {
            do {
                let receipt = try await actions.complete(poiID)
                guard mine == token else { return }
                completedOverride = !receipt.needRedeem; needRedeemOverride = receipt.needRedeem
                checkInSuccess = receipt; checkInPhase = .idle
            } catch is CancellationError { if mine == token { checkInPhase = .idle } }
            catch { if mine == token { checkInPhase = .failed(Self.map(error)) } }
        }
    }

    static func map(_ error: Error) -> Failure {
        switch error {
        case RoamActionFailure.locationDenied: return .locationDenied
        case RoamActionFailure.locationUnavailable: return .locationUnavailable
        case RoamActionFailure.rejected(let message): return .rejected(message)
        case APIError.unauthorized: return .signIn
        default: return .network
        }
    }
}

/// Favorite + check-in controls for the 你的状态 section.
struct RoamPOIActionRows: View {
    let node: RoamNodeDetail
    let actions: RoamPOIActions
    @ObservedObject var model: RoamPOIActionModel
    @Environment(\.openURL) private var openURL

    private var favorited: Bool { model.favoriteOverride ?? node.favorited }
    private var completed: Bool { model.completedOverride ?? node.completed }
    private var needRedeem: Bool { model.needRedeemOverride ?? node.needRedeem }

    var body: some View {
        Group {
            Button { model.toggleFavorite(poiID: node.poiId, current: favorited, actions: actions) } label: {
            HStack {
                Label(LocalizedStringKey(favorited ? "roam.poi.action.unfavorite" : "roam.poi.action.favorite"),
                      systemImage: favorited ? "heart.fill" : "heart")
                if model.favoritePhase == .working { Spacer(); ProgressView() }
            }.frame(minHeight: 44)
        }
        .disabled(model.favoritePhase == .working)
        .accessibilityIdentifier("roam.poi.favorite")
        if case .failed(let failure) = model.favoritePhase {
            failureRow(failure, retry: { model.toggleFavorite(poiID: node.poiId, current: favorited, actions: actions) })
        }
        if node.isPublished && !completed {
            Button { model.checkIn(poiID: node.poiId, actions: actions) } label: {
                HStack {
                    Label(LocalizedStringKey(needRedeem ? "roam.poi.action.checkIn.redeem" : "roam.poi.action.checkIn"), systemImage: "mappin.and.ellipse")
                    if model.checkInPhase == .working { Spacer(); ProgressView() }
                }.frame(minHeight: 44)
            }
            .disabled(model.checkInPhase == .working || needRedeem)
            .accessibilityIdentifier("roam.poi.checkin")
            Text("roam.poi.checkIn.footer").font(.footnote).foregroundStyle(.secondary)
        }
        if case .failed(let failure) = model.checkInPhase {
            failureRow(failure, retry: { model.checkIn(poiID: node.poiId, actions: actions) })
        }
        if let receipt = model.checkInSuccess {
            Label(LocalizedStringKey(receipt.needRedeem ? "roam.poi.checkIn.needRedeem" : (receipt.alreadyClaimed ? "roam.poi.checkIn.already" : "roam.poi.checkIn.success")),
                  systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                .accessibilityIdentifier("roam.poi.checkin.success")
        }
        }
        .cyHapticEvent(.checkInSuccess, trigger: model.checkInSuccess != nil) { old, new in !old && new }
        .cyHapticEvent(.wrongAnswer, trigger: model.checkInPhase) { _, next in
            if case .failed = next { return true }
            return false
        }
    }

    @ViewBuilder private func failureRow(_ failure: RoamPOIActionModel.Failure, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch failure {
            case .locationDenied:
                Label("roam.poi.location.denied.title", systemImage: "location.slash").font(.subheadline.weight(.semibold))
                Text("roam.poi.location.denied.message").font(.footnote).foregroundStyle(.secondary)
                Button("roam.poi.location.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.frame(minHeight: 44)
            case .locationUnavailable:
                Label("roam.poi.location.unavailable", systemImage: "location.slash").font(.subheadline)
                Button("action.retry", action: retry).frame(minHeight: 44)
            case .rejected(let message):
                Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }.font(.subheadline)
                Button("action.retry", action: retry).frame(minHeight: 44)
            case .signIn:
                Label("roam.poi.signIn", systemImage: "person.crop.circle.badge.exclamationmark").font(.subheadline)
            case .network:
                Label("roam.poi.action.failed", systemImage: "wifi.exclamationmark").font(.subheadline)
                Button("action.retry", action: retry).frame(minHeight: 44)
            }
        }
        .accessibilityIdentifier("roam.poi.action.error")
    }
}
