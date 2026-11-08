import Foundation

/// Pure, UI-free state machine behind `MiniCropView` (mini-program pages/crop batch loop).
/// It owns the per-image pan/zoom transform, the "use original" and "confirm" shortcuts, and the
/// ordered results. Nothing is uploaded or written; it only produces source rectangles.
public struct MiniCropSession: Equatable {
    public enum Outcome: Equatable { case original, crop(MiniCropGeometry.SourceRect) }
    public struct ImageSize: Equatable {
        public let width: Double
        public let height: Double
        public init(width: Double, height: Double) { self.width = width; self.height = height }
    }

    public let ratio: String
    public let imageSizes: [ImageSize]
    public private(set) var index: Int
    public private(set) var outcomes: [Outcome]
    public private(set) var scale: Double
    public private(set) var offsetX: Double
    public private(set) var offsetY: Double
    public private(set) var frameWidth: Double
    public private(set) var frameHeight: Double

    public init(ratio: String, imageSizes: [ImageSize]) {
        self.ratio = ratio
        self.imageSizes = imageSizes
        self.index = 0
        self.outcomes = []
        self.scale = 1
        self.offsetX = 0
        self.offsetY = 0
        self.frameWidth = 0
        self.frameHeight = 0
    }

    public var isFinished: Bool { !imageSizes.isEmpty && outcomes.count == imageSizes.count }
    public var currentSize: ImageSize? { imageSizes.indices.contains(index) && !isFinished ? imageSizes[index] : nil }
    public var canConfirm: Bool { currentSize != nil }

    /// Records the on-screen frame the current image is displayed in (mini computeCropRect input).
    public mutating func setFrame(width: Double, height: Double) {
        frameWidth = width
        frameHeight = height
    }

    /// Applies a gesture result, clamped so the frame stays covered. No-op without a frame/image.
    public mutating func applyGesture(scale newScale: Double, x: Double, y: Double) {
        guard let size = currentSize, frameWidth > 0, frameHeight > 0 else { return }
        let t = MiniCropGeometry.clamp(scale: newScale, x: x, y: y, imageWidth: size.width, imageHeight: size.height,
                                       frameWidth: frameWidth, frameHeight: frameHeight)
        scale = t.scale
        offsetX = t.x
        offsetY = t.y
    }

    /// "使用原图": keeps the untouched image and moves to the next one.
    @discardableResult public mutating func useOriginal() -> Bool {
        guard canConfirm else { return false }
        advance(.original)
        return true
    }

    /// Confirm: untouched free crop keeps the original, otherwise the source rect for the transform.
    /// Returns false (and records nothing) when the frame is unknown or the geometry is degenerate.
    @discardableResult public mutating func confirm() -> Bool {
        guard let size = currentSize else { return false }
        if MiniCropGeometry.keepsOriginal(ratio: ratio, scale: scale, x: offsetX, y: offsetY) {
            advance(.original)
            return true
        }
        guard frameWidth > 0,
              let rect = MiniCropGeometry.cropRect(scale: scale, x: offsetX, y: offsetY,
                                                   imageWidth: size.width, imageHeight: size.height,
                                                   frameWidth: frameWidth, frameHeight: frameHeight) else { return false }
        advance(.crop(rect))
        return true
    }

    private mutating func advance(_ outcome: Outcome) {
        outcomes.append(outcome)
        scale = 1
        offsetX = 0
        offsetY = 0
        if index + 1 < imageSizes.count { index += 1 }
    }
}
