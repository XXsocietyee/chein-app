import SwiftUI
import UIKit

/// Native counterpart of mini-program pages/crop: a centered frame of the requested ratio, pinch/pan
/// under it (clamped by `MiniCropGeometry`), and cancel / reset (use-original after a failure) / confirm for each image in turn.
/// Purely local: it returns source rectangles and never uploads or writes anything.
@MainActor struct MiniCropView: View {
    enum Result: Equatable { case original, crop(MiniCropGeometry.SourceRect) }

    let images: [UIImage]
    let ratio: String
    let onFinish: ([Result]) -> Void
    let onCancel: () -> Void
    /// A7-04: true when the cropper is its own pushed page (MP pages/crop); embedded hosts keep their title.
    var showsNavigationTitle = false
    /// r8 A7-05 (MP crop wxml:2 `shape`): `.circle` for avatars; the frame stays the ratio's frame.
    var shape: CropGapShape = .rect
    @State private var session: MiniCropSession
    @State private var gestureScale = 1.0
    @State private var gestureOffset = CGSize.zero
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(images: [UIImage], ratio: String, showsNavigationTitle: Bool = false, shape: CropGapShape = .rect, onFinish: @escaping ([Result]) -> Void, onCancel: @escaping () -> Void) {
        self.showsNavigationTitle = showsNavigationTitle
        self.shape = shape
        self.images = images
        self.ratio = ratio
        self.onFinish = onFinish
        self.onCancel = onCancel
        _session = State(initialValue: MiniCropSession(
            ratio: ratio,
            imageSizes: images.map { MiniCropSession.ImageSize(width: Double($0.size.width), height: Double($0.size.height)) }))
    }

    private var index: Int { session.index }
    private var scale: Double { session.scale }
    private var offset: CGSize { CGSize(width: session.offsetX, height: session.offsetY) }
    /// pages/crop page model: phase, batch position (`—` when unknown, never 0/0) and action gates.
    private var page: CropPageFacts { CropPageModel.facts(session: session) }

    var body: some View {
        // Mini `pages/crop`: bar / near-black stage with a fixed frame / bottom bar (取消 text left, 选取 solid right).
        VStack(spacing: 0) {
            // A7-04: no hero header. Standalone, the inline nav title reads 裁剪 (i/n); embedded in a host form, one
            // compact 裁剪 i/n line stands in, so the host page keeps its own navigation title.
            if !showsNavigationTitle {
                HStack(spacing: CYSpacing.sm) {
                    // `publishParity.crop.progress` already reads 裁剪 i/n; one image reads 裁剪.
                    Group {
                        if images.count > 1 { progressLabel.monospacedDigit().accessibilityIdentifier("miniCrop.progress") }
                        else { Text("publishParity.crop.title") }
                    }
                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.sm)
                .accessibilityElement(children: .combine)
            }
            Group {
                // The canvas measures the frame, so it stays mounted while the page model is still loading.
                if images.indices.contains(index), page.phase != .error, page.phase != .unknown { canvas(images[index]) }
                else if images.isEmpty {
                    ContentUnavailableView(LocalizedStringKey(CropPageModel.Copy.empty), systemImage: "info.circle")
                        .accessibilityIdentifier("miniCrop.empty")
                } else if page.phase == .unknown {
                    ContentUnavailableView(LocalizedStringKey(CropPageModel.Copy.unknown), systemImage: "questionmark.square.dashed")
                        .accessibilityIdentifier("miniCrop.unknown")
                } else {
                    // A7-08-r7: MP source error 图片没能打开 (pages.crop.error); 使用原图 / 取消 stay in the bar.
                    // r9 A7-08b: MP crop/index.wxml:26 `retry="重试" bind:retry="onRetrySource"` → index.js:149
                    // `startAt(this.idx)`, i.e. re-open the current image: `MiniCropSession.retryCurrent()`.
                    ContentUnavailableView {
                        Label(LocalizedStringKey(CropPageModel.Copy.error), systemImage: "photo.badge.exclamationmark")
                            .accessibilityIdentifier("miniCrop.failed")
                    } actions: {
                        Button("common.retry", action: retrySource)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("miniCrop.retry")
                    }
                }
            }
            .overlay {
                // A7-08-r7: MP waiting state 正在准备图片 until the frame is measured.
                if page.phase == .loading, !images.isEmpty {
                    ProgressView { Text(LocalizedStringKey(CropPageModel.Copy.loading)) }
                        .accessibilityIdentifier("miniCrop.loading")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: typeSize.isAccessibilitySize ? 180 : 240)
            controls
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.sm)
                .background(CYColor.bgPage)
                .overlay(alignment: .top) { Rectangle().fill(CYColor.borderSubtle).frame(height: 1).accessibilityHidden(true) }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .modifier(MiniCropNavigationTitle(enabled: showsNavigationTitle, count: images.count, index: index))
        .transaction { transaction in
            if reduceMotion { transaction.disablesAnimations = true }
        }
    }

    /// MP `onReset` (还原): the frame returns to the initial scale and offset.
    private func resetFrame() {
        gestureScale = 1
        gestureOffset = .zero
        session.reset()
    }

    /// r9 A7-08b: MP `onRetrySource` re-starts the current image without advancing.
    private func retrySource() {
        gestureScale = 1
        gestureOffset = .zero
        session.retryCurrent()
    }

    /// Localized `1/2` when the model knows the position; the em dash otherwise. One image shows nothing.
    @ViewBuilder private var progressLabel: some View {
        let text = page.progressText
        Group {
            if text.isEmpty { EmptyView() }
            else if text == CropPageModel.unknownDisplay { Text(verbatim: text) }
            else { Text("publishParity.crop.progress \(index + 1) \(images.count)") }
        }
    }

    @ViewBuilder private var controls: some View {
        if images.isEmpty {
            // Mini-program missing-source state: one full-width 返回上一页, no crop actions.
            Button(action: onCancel) { Text("pages.crop.back").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("miniCrop.cancel")
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.sm) { controlButtons }
        } else {
            HStack(spacing: CYSpacing.md) { controlButtons }
        }
    }

    @ViewBuilder private var controlButtons: some View {
        Button("publishParity.crop.cancel", role: .cancel, action: onCancel)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("miniCrop.cancel")
        if !typeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
        // mp-settings r3: MP crop/index.wxml:56-66 — a ready frame offers 取消 · 还原 · 选取; 使用原图 appears only when the
        // source failed to open or the export failed (page.canUseOriginal).
        if page.canUseOriginal {
            Button("publishParity.crop.useOriginal") { if session.useOriginal() { afterAdvance() } }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("miniCrop.useOriginal")
        } else if page.phase != .error {
            Button { resetFrame() } label: { Label("fixr8.crop.reset", systemImage: "arrow.counterclockwise") }
                .buttonStyle(.bordered)
                .disabled(!page.canReset)
                .accessibilityIdentifier("miniCrop.reset")
        }
        Button(LocalizedStringKey(page.confirmKey)) { confirm() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!page.canConfirm && page.phase != .loading)
            .accessibilityIdentifier("miniCrop.confirm")
    }

    private func canvas(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            let size = image.size
            if let frame = MiniCropGeometry.frame(ratio: ratio, imageWidth: size.width, imageHeight: size.height,
                                                  availableWidth: proxy.size.width, availableHeight: proxy.size.height) {
                let live = clamped(scale: scale * gestureScale, x: offset.width + gestureOffset.width,
                                   y: offset.height + gestureOffset.height, image: size, frame: frame)
                let base = max(frame.width / size.width, frame.height / size.height)
                // r8 A7-01/03: the whole image stays visible under a dimmed mask (MP crop wxml:38, 45-47); only the
                // frame cut-out is clear, with the rule-of-thirds grid or the circle. The canvas clips at its edges only.
                Image(uiImage: image).resizable()
                    .frame(width: size.width * base * live.scale, height: size.height * base * live.scale)
                    .offset(x: live.x, y: live.y)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .overlay {
                        MiniCropGapOverlay(shape: shape, cropSize: CGSize(width: frame.width, height: frame.height)) {
                            // A7-03 还原: back to the session's initial transform (scale 1, centred), clamped as usual.
                            gestureScale = 1; gestureOffset = .zero
                            session.applyGesture(scale: 1, x: 0, y: 0)
                        }
                        .accessibilityIdentifier("miniCrop.overlay")
                    }
                    .contentShape(Rectangle())
                    .gesture(SimultaneousGesture(
                        MagnifyGesture().onChanged { gestureScale = $0.magnification }.onEnded { _ in commit(image: size, frame: frame) },
                        DragGesture().onChanged { gestureOffset = $0.translation }.onEnded { _ in commit(image: size, frame: frame) }))
                    .accessibilityLabel(Text("image.crop.preview"))
                    .accessibilityValue(Text(verbatim: "\(Int((live.scale * 100).rounded()))%"))
                    // A7-07: VoiceOver swipe up / down zooms in 25% steps (pinch has no accessible equivalent).
                    .accessibilityAdjustableAction { direction in
                        let step = direction == .increment ? 1.25 : 0.8
                        session.applyGesture(scale: scale * step, x: offset.width, y: offset.height)
                    }
                    .accessibilityIdentifier("miniCrop.canvas")
                    .task(id: frame.width * 10_000 + frame.height) { session.setFrame(width: frame.width, height: frame.height) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func clamped(scale: Double, x: Double, y: Double, image: CGSize, frame: (width: Double, height: Double)) -> MiniCropGeometry.Transform {
        MiniCropGeometry.clamp(scale: scale, x: x, y: y, imageWidth: image.width, imageHeight: image.height,
                               frameWidth: frame.width, frameHeight: frame.height)
    }

    private func commit(image: CGSize, frame: (width: Double, height: Double)) {
        session.applyGesture(scale: scale * gestureScale, x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
        gestureScale = 1; gestureOffset = .zero
    }

    private func confirm() { if session.confirm() { afterAdvance() } }

    private func afterAdvance() {
        gestureScale = 1; gestureOffset = .zero
        if session.isFinished {
            onFinish(session.outcomes.map { outcome -> Result in
                switch outcome {
                case .original: return .original
                case .crop(let rect): return .crop(rect)
                }
            })
        }
    }
}


/// A7-04: MP pages/crop nav bar title 裁剪, with i/n for a batch. Inline, system back.
private struct MiniCropNavigationTitle: ViewModifier {
    let enabled: Bool
    let count: Int
    let index: Int
    func body(content: Content) -> some View {
        if enabled {
            if count > 1 {
                content.navigationTitle(Text("publishParity.crop.progress \(index + 1) \(count)")).navigationBarTitleDisplayMode(.inline)
            } else {
                content.navigationTitle(Text("publishParity.crop.title")).navigationBarTitleDisplayMode(.inline)
            }
        } else {
            content
        }
    }
}
