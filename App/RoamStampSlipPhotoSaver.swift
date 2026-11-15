import Foundation
import SwiftUI
import UIKit

/// WIRE-2: explicit-action "save to Photos" for the city-stamp slip picture.
/// Add-only permission (existing `RoamSharePhotoLibraryWriter`); the picture is the same https URL the
/// slip already displays. Nothing happens until the user taps the button.
@MainActor final class RoamStampSlipPhotoSaver: ObservableObject {
    enum Phase: Equatable { case idle, saving, saved, needsTear, noPicture, permissionDenied, restricted, unavailable, failed }
    @Published private(set) var phase: Phase = .idle
    private let writer: any RoamSharePhotoWriting
    private let fetch: @Sendable (URL) async throws -> Data
    private var task: Task<Void, Never>?
    init(writer: (any RoamSharePhotoWriting)? = nil,
         fetch: (@Sendable (URL) async throws -> Data)? = nil) {
        self.writer = writer ?? RoamSharePhotoLibraryWriter()
        self.fetch = fetch ?? { url in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return data
        }
    }
    func save(torn: Bool, pictureURL: String?) {
        guard phase != .saving else { return }
        switch RoamStampSlipSavePolicy.decide(torn: torn, pictureURL: pictureURL) {
        case .needsTear: phase = .needsTear
        case .noPicture: phase = .noPicture
        case .ready(let url):
            phase = .saving
            task = Task { [weak self] in
                guard let self else { return }
                defer { self.task = nil }
                var status = self.writer.authorizationStatus()
                if case .notDetermined = status { status = await self.writer.requestAuthorization() }
                guard !Task.isCancelled else { self.phase = .idle; return }
                switch status {
                case .authorized: break
                case .denied: self.phase = .permissionDenied; return
                case .restricted: self.phase = .restricted; return
                case .unavailable: self.phase = .unavailable; return
                case .notDetermined: self.phase = .idle; return
                }
                do {
                    let data = try await self.fetch(url)
                    guard !Task.isCancelled else { self.phase = .idle; return }
                    guard let image = UIImage(data: data) else { self.phase = .failed; return }
                    try await self.writer.add(image)
                    self.phase = .saved
                } catch { self.phase = Task.isCancelled ? .idle : .failed }
            }
        }
    }
    func cancel() { task?.cancel() }
    var statusKey: String? {
        switch phase {
        case .idle, .saving: return nil
        case .saved: return "roam.share.savedPhotos"
        case .needsTear: return "roamSub.wire2.stamp.saveTearFirst"
        case .noPicture: return "roamSub.wire2.stamp.saveNoPicture"
        case .permissionDenied: return "roam.share.photoPermissionDenied"
        case .restricted: return "roam.share.photoPermissionRestricted"
        case .unavailable: return "roam.share.photoSaveUnavailable"
        case .failed: return "roam.share.photoSaveFailed"
        }
    }
}

/// "保存到相册" row under the slip picture, shown for a successful exchange.
struct RoamStampSlipSaveRow: View {
    let torn: Bool
    let pictureURL: String?
    @StateObject private var saver = RoamStampSlipPhotoSaver()
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var showingPermissionModal = false
    @State private var toastMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                saver.save(torn: torn, pictureURL: pictureURL)
            } label: { Label("roam.share.savePhotos", systemImage: "square.and.arrow.down") }
                .disabled(saver.phase == .saving || saver.phase == .saved)
                .accessibilityIdentifier("roamSub.w208.stamp.save")
            if saver.phase == .saving {
                ProgressView("roam.share.savingPhotos")
            } else if let key = saver.statusKey {
                Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("roamSub.w208.stamp.saveStatus")
            }
            if saver.phase == .permissionDenied {
                Button("roam.share.openPhotoSettings") {
                    showingPermissionModal = true
                }
                .accessibilityLabel(Text("roam.share.openPhotoSettings"))
                .accessibilityValue(Text("roam.share.photoPermissionDenied"))
                .accessibilityHint(Text("roam.share.openPhotoSettings"))
            }
        }
        .cyModalOverlay(isPresented: showingPermissionModal) {
            PlayPhotoAlbumPermissionModal(
                onOpenSettings: {
                    showingPermissionModal = false
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                },
                onBack: { showingPermissionModal = false }
            )
        }
        .cyToast(verbatimMessage: $toastMessage)
        .onChange(of: saver.phase) { _, next in
            switch next {
            case .permissionDenied:
                showingPermissionModal = true
            case .saved:
                toastMessage = PlayCloseCopy.text("已保存到相册", "Saved to Photos", locale)
            case .needsTear:
                toastMessage = PlayCloseCopy.text("撕开邮票后可保存纪念图", "Tear the stamp first to save the image", locale)
            case .noPicture:
                toastMessage = PlayCloseCopy.text("本枚邮票暂无图片可保存", "This stamp has no image to save", locale)
            case .failed, .unavailable, .restricted:
                toastMessage = PlayCloseCopy.text("保存失败，请重试", "Could not save photo. Try again.", locale)
            case .idle, .saving:
                break
            }
        }
        .onDisappear { saver.cancel() }
    }
}
