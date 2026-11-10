import SwiftUI
import UIKit

/// Native counterpart of mini-program pages/crop: a centered frame of the requested ratio, pinch/pan
/// under it (clamped by `MiniCropGeometry`), and cancel / use-original / confirm for each image in turn.
/// Purely local: it returns source rectangles and never uploads or writes anything.
@MainActor struct MiniCropView: View {
    enum Result: Equatable { case original, crop(MiniCropGeometry.SourceRect) }

    let images: [UIImage]
    let ratio: String
    let onFinish: ([Result]) -> Void
    let onCancel: () -> Void
    @State private var session: MiniCropSession
    @State private var gestureScale = 1.0
    @State private var gestureOffset = CGSize.zero

    init(images: [UIImage], ratio: String, onFinish: @escaping ([Result]) -> Void, onCancel: @escaping () -> Void) {
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

    var body: some View {
        // Mini `pages/crop`: bar / near-black stage with a fixed frame / bottom bar (取消 text left, 选取 solid right).
        VStack(spacing: 0) {
            if images.count > 1 {
                Text("publishParity.crop.progress \(index + 1) \(images.count)").font(CYTypography.caption).monospacedDigit()
                    .foregroundStyle(CYColor.textSecondary).padding(.vertical, CYSpacing.sm)
                    .accessibilityIdentifier("miniCrop.progress")
            }
            Group {
                if images.indices.contains(index) { canvas(images[index]) }
                else {
                    Text("publishParity.crop.failed").font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("miniCrop.failed")
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: CYSpacing.md) {
                CYPillButton("publishParity.crop.cancel", style: .tertiary, fullWidth: false, action: onCancel)
                    .accessibilityIdentifier("miniCrop.cancel")
                Spacer(minLength: CYSpacing.sm)
                CYPillButton("publishParity.crop.useOriginal", style: .tertiary, fullWidth: false) { if session.useOriginal() { afterAdvance() } }
                    .accessibilityIdentifier("miniCrop.useOriginal")
                CYPillButton("publishParity.crop.confirm", fullWidth: false) { confirm() }
                    .accessibilityIdentifier("miniCrop.confirm")
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
            .background(CYColor.bgPage)
            .overlay(alignment: .top) { Rectangle().fill(CYColor.borderSubtle).frame(height: 1) }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .navigationTitle(Text("publishParity.crop.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func canvas(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            let size = image.size
            if let frame = MiniCropGeometry.frame(ratio: ratio, imageWidth: size.width, imageHeight: size.height,
                                                  availableWidth: proxy.size.width, availableHeight: proxy.size.height) {
                let live = clamped(scale: scale * gestureScale, x: offset.width + gestureOffset.width,
                                   y: offset.height + gestureOffset.height, image: size, frame: frame)
                let base = max(frame.width / size.width, frame.height / size.height)
                Image(uiImage: image).resizable()
                    .frame(width: size.width * base * live.scale, height: size.height * base * live.scale)
                    .offset(x: live.x, y: live.y)
                    .frame(width: frame.width, height: frame.height).clipped()
                    .overlay(Rectangle().stroke(CYColor.borderStrong, lineWidth: 1))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .gesture(SimultaneousGesture(
                        MagnifyGesture().onChanged { gestureScale = $0.magnification }.onEnded { _ in commit(image: size, frame: frame) },
                        DragGesture().onChanged { gestureOffset = $0.translation }.onEnded { _ in commit(image: size, frame: frame) }))
                    .accessibilityLabel(Text("image.crop.preview"))
                    .accessibilityIdentifier("miniCrop.canvas")
                    .task(id: frame.width * 10_000 + frame.height) { session.setFrame(width: frame.width, height: frame.height) }
            }
        }.frame(minHeight: 240)
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
