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
    @QuestifyReduceMotion private var reduceMotion
    private var swap: AnyTransition { reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace).combined(with: .scale(scale: 0.6)) }
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            // The glyph changes in place (spinner → tick), xrefs-1 B.1: one slot, a short blur-replace.
            ZStack {
                switch state {
                case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.success).transition(swap)
                case .working: ProgressView().controlSize(.small).transition(swap)
                case .waiting: Image(systemName: "clock").foregroundStyle(palette.textTertiary).transition(swap)
                case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(palette.danger).transition(swap)
                }
            }
            .cyText(.sectionTitle).frame(width: 28, height: 28).accessibilityHidden(true)
            .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: state)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                Text(verbatim: detail).cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
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

/// The 圈下了 moment the claim sheet opens over itself (so the photo can travel from its thumbnail).
struct CityClaimedRoute: Identifiable {
    let id = UUID()
    let place: CityPlace
    let photo: UIImage?
    let hours: Int
    let price: Int64
    let source: CGRect?
}

struct CityClaimSheet: View {
    let place: CityPlace
    @ObservedObject var store: CityBoardStore
    let captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    let uploader: CityClaimPhotoUploading?
    var fixture: CityClaimFixture? = nil
    let onMoment: (CityMomentRoute) -> Void
    /// 去看看我的地盘 from the 圈下了 moment (the root closes the sheet and pushes 我的地盘).
    var onMine: (() -> Void)? = nil
    let onClose: () -> Void

    @State private var phase: CYResultPhase = .idle
    /// The 64 pt claim thumbnail's frame in the window: where the photo → deed flight starts (K0).
    @State private var thumbFrame: CGRect = .zero
    @State private var claimed: CityClaimedRoute?
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
                if let photo { thumbnail(photo) }
                CityFactTable(rows: [
                    .init(label: copy("占领价", "Claim price"), value: String(price), coin: true),
                    balanceRow,
                    .init(label: copy("占领后保护到", "Protected until"), value: copy.clock(Date().addingTimeInterval(TimeInterval((quote?.protectionHours ?? CityMonopolyRules.protectionAfterClaimHours) * 3600))))
                ])
                primary
                Text(verbatim: copy("报价 5 分钟内有效 · 确认前不扣积分", "Quote valid 5 minutes · nothing is charged before you confirm"))
                    .cyText(.caption).foregroundStyle(palette.textTertiary).frame(maxWidth: .infinity)
                if let issue = store.issueCode {
                    CityBanner(text: CityReasonCopy.text(issue, chinese: copy.chinese), symbol: "exclamationmark.circle", tone: .error)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
        }
        .sensoryFeedback(.selection, trigger: tick)
        // 圈下了 opens over this sheet with no slide and a clear ground: the moment fades its own ground in (200 ms)
        // while the photo flies from the thumbnail into the deed (xrefs-1 C1, K0 → K3).
        .cyFullScreenCover(item: $claimed) { route in
            CityClaimedMoment(place: route.place, photo: route.photo, protectionHours: route.hours, price: route.price,
                              source: route.source, onMine: { (onMine ?? onClose)() }, onDone: onClose)
                .presentationBackground(.clear)
                .themeDomain(.player)
        }
        .cyFullScreenCover(isPresented: $showsCamera) {
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
            VStack(spacing: CYSpacing.sm) {
                if let reason = blockingReason, phase == .idle {
                    // The reason sits directly above the disabled button (xrefs-1 B.1).
                    Text(verbatim: reason).cyText(.meta).foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
                CYResultButton(verbatim: copy("确认圈地 · \(price) 积分", "Claim · \(price) pts"), loading: copy("正在确认", "Confirming"),
                               done: copy("已圈下", "Claimed"), phase: phase) {
                    Task { await submit() }
                }
                .identifier("city.claim.confirm")
                .disabled(phase == .idle && blockingReason != nil)
            }
            .animation(CYMotion.standard, value: blockingReason)
        }
    }

    /// Why the confirm is disabled, in one line (nil when it can go).
    private var blockingReason: String? {
        if quote == nil { return copy("正在报价…", "Getting a quote…") }
        if short { return copy("积分还差 \(price - (balance ?? 0))", "\(price - (balance ?? 0)) points short") }
        if !checks.contains(where: { $0.kind == .dwell && $0.passed }) { return copy("在现场停留满 60 秒就能确认", "Stay 60 seconds on site to confirm") }
        if store.busy && phase == .idle { return copy("校验中", "Checking") }
        return nil
    }

    /// 积分余额 as one number with a −N chip; after the claim lands it rolls to the new balance and the chip fades.
    private var balanceRow: CityFactTable.Row {
        let label = copy("积分余额", "Points balance")
        guard let balance else { return .init(label: label, value: "—") }
        if balance < price { return .init(label: label, value: copy("\(balance)（还差 \(price - balance)）", "\(balance) (\(price - balance) short)"), coin: true) }
        let applied = phase == .done
        return .init(label: label, value: "", coin: true, number: applied ? balance - price : balance, delta: -price, holdsDelta: !applied)
    }

    /// K0: the photo the player just took, 64 × 64, the source of the flight into the deed.
    private func thumbnail(_ photo: UIImage) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(uiImage: photo).resizable().scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.textPrimary.opacity(0.9), lineWidth: 1.5))
                .opacity(claimed == nil ? 1 : 0)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { thumbFrame = $0 }
                .accessibilityLabel(Text(verbatim: copy("现场照片", "On-site photo")))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: copy("现场照片", "On-site photo")).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                Text(verbatim: copy("圈下后它就是这张地契的封面", "Once claimed, it becomes this deed's cover"))
                    .cyText(.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
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
        guard phase == .idle else { return }
        phase = .loading
        let result = await store.confirm(fixes: fixes, photoAssetId: photoRef)
        guard let result, result.kind == .applied || result.kind == .pendingReview else {
            // Failure: back to the label on the release spring; the sheet shows the server's reason above.
            withAnimation(CYMotion.release) { phase = .idle }
            return
        }
        // The store reloaded the layer after the command, so the claimed place carries its server state.
        // The command's `property.deedSerial` (fix/city-gaps-r3) fills 地契 · No. N if the reload has not caught up.
        let claimedPlace = (store.place(id: result.property?.propertyId)
            ?? store.mine.first { $0.poiId != nil ? $0.poiId == place.poiId : ($0.pointId != nil && $0.pointId == place.pointId) }
            ?? CityPlace(id: place.id, title: place.title, coordinate: place.coordinate, poiId: place.poiId, boardId: place.boardId,
                         pointId: place.pointId, districtId: place.districtId, districtIndex: place.districtIndex, tier: place.tier,
                         level: 0, ownership: .mine, protectedUntil: Date().addingTimeInterval(TimeInterval((quote?.protectionHours ?? 24) * 3600)),
                         photoURL: photoRef, districtName: place.districtName))
            .withDeedSerial(result.property?.deedSerial)
        let hours = quote?.protectionHours ?? result.protectionHours ?? 24
        // Done in place first (check + 已圈下, the balance rolls), then the moment grows out of the photo.
        phase = .done
        try? await Task.sleep(for: .milliseconds(450))
        guard photo != nil else {
            onMoment(.claimed(claimedPlace, photo: photo, protectionHours: hours, price: price))
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            claimed = CityClaimedRoute(place: claimedPlace, photo: photo, hours: hours, price: price, source: thumbFrame == .zero ? nil : thumbFrame)
        }
    }

    private func close() { sampling?.cancel(); store.cancelQuote(); onClose() }
}
