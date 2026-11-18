import SwiftUI
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Claim flow N18–N27 (204:26708 … 204:27271): one place throughout; four checks (distance,
// accuracy, dwell, photo) tick as they pass; the price and the protection end are stated once.
// The photo is live capture only (in-app camera, never the library); the server re-checks every
// rule and answers with reasons, which the sheet turns into one sentence and one way forward.

/// Uploads the claim photo and returns the asset reference the claim command sends.
@MainActor protocol CityClaimPhotoUploading {
    var isAvailable: Bool { get }
    func upload(jpeg: Data, width: Int, height: Int) async throws -> String
}

/// Live upload through the retained-image uploader the roam territory already uses.
@MainActor struct CityRetainedClaimPhotoUploader: CityClaimPhotoUploading {
    let context: RetainedImageSelectionContext
    var isAvailable: Bool { context.uploads.uploader.isConfigured }
    func upload(jpeg: Data, width: Int, height: Int) async throws -> String {
        let selection = try RetainedSelectedImage(jpeg: jpeg, width: width, height: height)
        let uploaded = try await context.uploads.uploader.upload(RetainedImageUploadReview(scope: context.scope, selection: selection))
        return uploaded.url.absoluteString
    }
}

/// `ClaimCameraView` (204:26816): the system camera, live capture only.
struct CityCameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) { self.onCapture = onCapture; self.onCancel = onCancel }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) } else { onCancel() }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

/// One evidence row: tick (passed), spinner (in progress), clock (waiting), cross (failed, ink text + red glyph).
struct CityCheckRow: View {
    enum State: Equatable { case passed, working, waiting, failed }
    let title: String
    let detail: String
    let state: State
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Group {
                switch state {
                case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.success)
                case .working: ProgressView().controlSize(.small)
                case .waiting: Image(systemName: "clock").foregroundStyle(palette.textTertiary)
                case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(palette.danger)
                }
            }
            .font(.title3).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                Text(verbatim: detail).font(CYTypography.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: stateLabel))
    }
    private var stateLabel: String {
        let copy = CityCopy(locale: locale)
        switch state {
        case .passed: return copy("已通过", "Passed")
        case .working: return copy("检查中", "Checking")
        case .waiting: return copy("等待中", "Waiting")
        case .failed: return copy("未通过", "Not passed")
        }
    }
}

struct CityClaimSheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let uploader: CityClaimPhotoUploading?
    var fixture: CityClaimFixture? = nil
    let onMoment: (CityMomentRoute) -> Void
    let onClose: () -> Void

    @State private var fixes: [RoamDeviceFix] = []
    @State private var sampling: Task<Void, Never>?
    @State private var showsCamera = false
    @State private var photo: UIImage?
    @State private var photoRef: String?
    @State private var uploading = false
    @State private var uploadFailed = false
    @State private var tick = 0
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var quote: CityTerritoryQuote? { store.pendingQuote?.kind == .claim ? store.pendingQuote?.quote : nil }
    private var price: Int64 { quote?.price ?? place.claimPrice ?? 0 }
    private var balance: Int64? { store.points?.balance }
    private var short: Bool { (balance ?? .max) < price }
    private var checks: [CityPresenceCheck] {
        CityPresencePreflight.evaluate(fixes: fixes, anchor: place.coordinate, requirePhoto: false, hasPhoto: photoRef != nil)
    }
    private var rejection: [String] { store.lastResult?.kind == .rejected ? (store.lastResult?.reasons ?? []) : [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CitySheetTitle(title: copy("圈下 ", "Claim ") + copy.title(place), tags: [copy.tier(place.tier)].compactMap { $0 },
                               districtIndex: place.districtIndex, district: copy.district(place), onClose: close)
                if !rejection.isEmpty {
                    CityBanner(text: rejection.map { CityReasonCopy.text($0, chinese: copy.chinese) }.joined(separator: "\n"),
                               symbol: "xmark.octagon", tone: .error)
                        .accessibilityIdentifier("city.claim.rejected")
                } else if short {
                    CityBanner(text: copy("积分还差 \(price - (balance ?? 0))。完成一次漫游或打卡就能攒到。", "\(price - (balance ?? 0)) points short. One roam or check-in earns that."),
                               symbol: "exclamationmark.triangle", tone: .warning)
                }
                VStack(spacing: CYSpacing.xs) {
                    ForEach(checkRows, id: \.title) { CityCheckRow(title: $0.title, detail: $0.detail, state: $0.state) }
                }
                .padding(CYSpacing.md)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill().frame(height: 120).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityLabel(Text(verbatim: copy("现场照片", "On-site photo")))
                }
                CityFactTable(rows: [
                    .init(label: copy("占领价", "Claim price"), value: String(price), coin: true),
                    .init(label: copy("积分余额", "Points balance"), value: balance.map { $0 >= price ? "\($0) → \($0 - price)" : copy("\($0)（还差 \(price - $0)）", "\($0) (\(price - $0) short)") } ?? "—"),
                    .init(label: copy("占领后保护到", "Protected until"), value: copy.clock(Date().addingTimeInterval(TimeInterval((quote?.protectionHours ?? CityMonopolyRules.protectionAfterClaimHours) * 3600))))
                ])
                primary
                Text(verbatim: copy("报价 5 分钟内有效 · 确认前不扣积分", "Quote valid 5 minutes · nothing is charged before you confirm"))
                    .font(CYTypography.caption).foregroundStyle(palette.textTertiary).frame(maxWidth: .infinity)
                if let issue = store.issueCode {
                    CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
        }
        .sensoryFeedback(.selection, trigger: tick)
        .fullScreenCover(isPresented: $showsCamera) {
            CityCameraCapture(onCapture: { image in showsCamera = false; Task { await accept(image) } }, onCancel: { showsCamera = false })
                .ignoresSafeArea()
        }
        .task {
            store.clearResult()
            let first = try? await captureFix?()
            if let first { fixes = [first] }
            await store.quote(.claim, place: place, fix: first)
            if let fixture, let first {
                // DEBUG fixture: a minute of dwell already collected and a photo already uploaded.
                fixes = (0..<4).compactMap { step in
                    try? RoamDeviceFix(coordinate: first.coordinate, accuracyMeters: first.accuracyMeters,
                                       measuredAt: first.measuredAt.addingTimeInterval(Double(step - 3) * 20), datum: first.datum)
                }
                photoRef = fixture.photoRef
                if fixture.autoSubmit { await submit() }
                return
            }
            startSampling()
        }
        .onDisappear { sampling?.cancel() }
        .accessibilityIdentifier("city.claim.sheet")
    }

    private struct RowModel { let title: String; let detail: String; let state: CityCheckRow.State }

    private var checkRows: [RowModel] {
        let byKind = Dictionary(checks.map { ($0.kind, $0) }, uniquingKeysWith: { a, _ in a })
        func row(_ kind: CityPresenceCheck.Kind, _ title: String, _ waiting: String) -> RowModel {
            guard let check = byKind[kind] else { return RowModel(title: title, detail: waiting, state: sampling == nil ? .waiting : .working) }
            let working = kind == .dwell && !check.passed && sampling != nil
            return RowModel(title: title, detail: check.detail(chinese: copy.chinese), state: check.passed ? .passed : (working ? .working : .failed))
        }
        let photoState: CityCheckRow.State = photoRef != nil ? .passed : (uploading ? .working : (uploadFailed ? .failed : .waiting))
        let photoDetail: String
        if photoRef != nil { photoDetail = copy("照片已拍好", "Photo taken") }
        else if uploadFailed { photoDetail = copy("照片没传上去，请重拍。", "The photo did not upload. Take it again.") }
        else if !CityCameraCapture.isAvailable { photoDetail = copy("这台设备没有相机，无法现场拍照。", "This device has no camera for an on-site photo.") }
        else { photoDetail = copy("用 App 相机现拍一张，不能从相册选", "Take one with the in-app camera; the library is not allowed") }
        return [
            row(.distance, copy("距离", "Distance"), copy("正在定位…", "Locating…")),
            row(.accuracy, copy("定位精度", "Accuracy"), copy("正在定位…", "Locating…")),
            row(.dwell, copy("现场停留", "Stay on site"), copy("停留满 60 秒即可", "Stay 60 seconds")),
            RowModel(title: copy("现场照片", "On-site photo"), detail: photoDetail, state: photoState)
        ]
    }

    @ViewBuilder private var primary: some View {
        if photoRef == nil {
            CYPillButton(verbatim: uploading ? copy("上传中…", "Uploading…") : copy("打开相机拍照", "Open camera")) { showsCamera = true }
                .disabled(!CityCameraCapture.isAvailable || uploading || uploader?.isAvailable != true || quote == nil)
                .accessibilityIdentifier("city.claim.camera")
        } else {
            CYPillButton(verbatim: store.busy ? copy("校验中", "Checking") : copy("确认圈地 · \(price) 积分", "Claim · \(price) pts")) {
                Task { await submit() }
            }
            .disabled(store.busy || quote == nil || short || !checks.contains { $0.kind == .dwell && $0.passed })
            .accessibilityIdentifier("city.claim.confirm")
        }
    }

    /// Four fixes 20 s apart (≥ 3 samples over ≥ 60 s, §2.2); each passed check ticks once.
    private func startSampling() {
        guard let captureFix, sampling == nil else { return }
        sampling = Task { @MainActor in
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                if let next = try? await captureFix() { fixes.append(next); tick += 1 }
            }
            sampling = nil
        }
    }

    private func accept(_ image: UIImage) async {
        photo = image
        guard let uploader, let jpeg = image.jpegData(compressionQuality: 0.82), let cg = image.cgImage else { uploadFailed = true; return }
        uploading = true; uploadFailed = false
        defer { uploading = false }
        do {
            photoRef = try await uploader.upload(jpeg: jpeg, width: cg.width, height: cg.height)
            tick += 1
        } catch {
            uploadFailed = true
        }
    }

    private func submit() async {
        let result = await store.confirm(fixes: fixes, photoAssetId: photoRef)
        guard let result else { return }
        switch result.kind {
        case .applied, .pendingReview:
            // The store reloaded the layer after the command, so the claimed place carries its server state.
            let claimed = store.place(id: result.property?.propertyId)
                ?? store.mine.first { $0.poiId != nil ? $0.poiId == place.poiId : ($0.pointId != nil && $0.pointId == place.pointId) }
                ?? CityPlace(id: place.id, title: place.title, coordinate: place.coordinate, poiId: place.poiId, boardId: place.boardId,
                             pointId: place.pointId, districtId: place.districtId, districtIndex: place.districtIndex, tier: place.tier,
                             level: 0, ownership: .mine, protectedUntil: Date().addingTimeInterval(TimeInterval((quote?.protectionHours ?? 24) * 3600)),
                             photoURL: photoRef)
            onMoment(.claimed(claimed, photo: photo, protectionHours: quote?.protectionHours ?? result.protectionHours ?? 24, price: price))
        default:
            break
        }
    }

    private func close() { sampling?.cancel(); store.cancelQuote(); onClose() }
}
