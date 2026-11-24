import SwiftUI

@MainActor struct SessionRoamStampCameraView: View {
    @EnvironmentObject private var session: AppSession
    /// SCAM-2: true only from the citystamp route.
    var showsCaption = false
    var body: some View {
        // Caption text is local even when no capture coordinator can be made. Recreate
        // that state on owner/realm/epoch changes, including nil-to-nil capability states.
        ScopedSessionRoamStampCameraView(showsCaption: showsCaption)
            .id(session.walletCommerceScope)
            .id(session.sessionRevision)
    }
}
@MainActor private struct ScopedSessionRoamStampCameraView: View {
    @EnvironmentObject private var session: AppSession
    let showsCaption: Bool
    @State private var coordinator: RoamStampCaptureCoordinator?
    var body: some View {
        RoamStampCameraView(coordinator: coordinator, cameraEnabled: session.stampCameraEnabled,
            album: RoamStampAlbumContinuation(reader: session.roamExperienceReader, camera: { AnyView(SessionRoamStampCameraView()) }),
            exchange: { try await session.exchangeStamp(givenStampID: $0) }, showsCaption: showsCaption)
            .id(coordinator.map { ObjectIdentifier($0) })
            .task(id: session.walletCommerceScope) { coordinator?.cancel(); coordinator = session.makeRoamStampCaptureCoordinator() }
            .onChange(of: session.walletCommerceScope) { _, _ in coordinator?.cancel(); coordinator = nil }
    }
}
@MainActor struct SessionRoamPosterView: View {
    @EnvironmentObject private var session: AppSession
    let node: RoamNodeDetail
    @State private var coordinator: RoamPosterCoordinator?
    var body: some View {
        RoamPosterScanView(node: node, coordinator: coordinator, cameraEnabled: false)
            .id(coordinator.map { ObjectIdentifier($0) })
            .task(id: session.walletCommerceScope) { coordinator?.cancel(); coordinator = session.makeRoamPosterCoordinator(node: node) }
            .onChange(of: session.walletCommerceScope) { _, _ in coordinator?.cancel(); coordinator = nil }
    }
}
@MainActor final class DisabledRoamPosterLocation: RoamDeviceLocationProviding {
    func currentFix() async throws -> RoamDeviceFix { throw RoamExperienceFailure.capabilityUnavailable }
    func stop() {}
}

/// `subpackageRoam/citystamp?kind=&place=` (ROAM-2 / RSTAMP-1): the live 投一张换一张 flow. The photo step
/// opens the session stamp camera; the exchange coordinator stays nil until the owner enables
/// `RoamExperienceCapabilities.stampExchange`, so the page shows its dormant line instead of sending.
@MainActor struct SessionRoamCityStampFlowView: View {
    let kind: String?
    let place: String?
    var body: some View {
        RoamCityStampFlowView(kind: kind, place: place, cameraDestination: { AnyView(SessionRoamStampCameraView(showsCaption: true)) })
    }
}

/// Check-in follow-up rows (pages/roam wxml:702-725 `onCheckinStamp` / `onCheckinSign`): 城市贴纸 and 今日城市签,
/// each pushing the citystamp flow for the visited place.
@MainActor struct RoamCheckinStampRows: View {
    let place: String?
    var body: some View {
        NavigationLink { SessionRoamCityStampFlowView(kind: "sticker", place: place) } label: {
            Label("roam.checkin.sticker", systemImage: "seal")
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("roam.checkin.sticker")
        NavigationLink { SessionRoamCityStampFlowView(kind: "sign", place: place) } label: {
            Label("roam.checkin.sign", systemImage: "signature")
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("roam.checkin.sign")
    }
}
