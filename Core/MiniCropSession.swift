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

    /// Re-attempt the current image. Does not advance and does not drop a finished result.
    public mutating func retryCurrent() {
        guard currentSize != nil else { return }
        scale = 1
        offsetX = 0
        offsetY = 0
    }

    /// 还原: the current frame returns to the initial scale and offset.
    public mutating func reset() {
        scale = 1
        offsetX = 0
        offsetY = 0
    }

    private mutating func advance(_ outcome: Outcome) {
        outcomes.append(outcome)
        scale = 1
        offsetX = 0
        offsetY = 0
        if index + 1 < imageSizes.count { index += 1 }
    }
}

/// pages/crop/index. Projects `cropInit` and `MiniCropSession`.
/// Waiting, missing, error, and ready match the mini page. UNKNOWN is not a source token there;
/// a token, ratio, or number the contract does not name stays unknown.
/// Nothing is sent. No route is installed or marked live.
public enum CropPagePhase: Equatable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

public struct CropPageFacts: Equatable {
    public let phase: CropPagePhase
    public let countText: String
    public let indexText: String
    public let progressText: String
    public let widthText: String
    public let heightText: String
    public let frameWidthText: String
    public let frameHeightText: String
    public let ratioText: String
    public let round: Bool
    public let merchantLight: Bool
    public let canConfirm: Bool
    public let canUseOriginal: Bool
    public let canReset: Bool
    public let uploadEnabled: Bool
    public let copyKey: String
    public let confirmKey: String
}

public enum CropPageModel {
    public static let unknownDisplay = "—"
    public static let routeInstalled = false
    public static let routeMarkedLive = false
    public static let uploadEnabled = false
    public static let showsMerchantChoice = false
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false

    public enum Copy {
        public static let loading = "pages.crop.loading"
        public static let empty = "pages.crop.empty"
        public static let error = "pages.crop.error"
        public static let unknown = "pages.crop.unknown"
        public static let busy = "pages.crop.busy"
        public static let retry = "pages.crop.retry"
        public static let title = "publishParity.crop.title"
        public static let confirm = "publishParity.crop.confirm"
        public static let useOriginal = "publishParity.crop.useOriginal"
    }

    /// Nil is unknown. A literal 0 stays "0". A numeric string is not a JSON number.
    public static func countText(_ count: Int?) -> String {
        guard let count else { return unknownDisplay }
        return String(count)
    }

    public static func countText(numericString _: String) -> String { unknownDisplay }

    public static func dimensionText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return unknownDisplay }
        if value == 0 { return "0" }
        if value == value.rounded(), value >= Double(Int.min), value <= Double(Int.max) {
            return String(Int(value))
        }
        return String(value)
    }

    public static func dimensionText(numericString _: String) -> String { unknownDisplay }

    /// One image has no fraction. A missing batch position is an em dash, never 0/0.
    public static func progressText(index: Int?, count: Int?) -> String {
        guard let count else { return unknownDisplay }
        if count <= 1 { return "" }
        guard let index, index >= 0, index < count else { return unknownDisplay }
        return "\(index + 1)/\(count)"
    }

    /// `paths == nil` is not an empty queue. `[]` is empty and its count is 0.
    /// No opener never reads paths; the queue stays empty.
    public static func facts(hasOpener: Bool, paths: [String]?, ratio: String? = nil, shape: String? = nil,
                             merchant: Bool? = nil, width: Double? = nil, height: Double? = nil,
                             index: Int? = nil, source: String? = nil, failed: Bool = false,
                             busy: Bool = false, exportFailed: Bool = false) -> CropPageFacts {
        let count: Int? = hasOpener ? paths?.count : .some(0)
        return classify(hasOpener: hasOpener, count: count, index: index,
                 ratio: ratio, shape: shape, merchant: merchant, width: width, height: height,
                 frameWidth: nil, frameHeight: nil, frameRequired: false, source: source,
                 failed: failed, busy: busy, exportFailed: exportFailed, acceptsMore: true)
    }

    /// The session's 0×0 frame is unset, not a measured zero. A measured 0 is passed only as a number.
    public static func facts(session: MiniCropSession, shape: String? = nil, merchant: Bool? = nil,
                             source: String? = nil, failed: Bool = false, busy: Bool = false,
                             exportFailed: Bool = false) -> CropPageFacts {
        let shown = session.currentSize ?? (session.isFinished && session.imageSizes.indices.contains(session.index)
            ? session.imageSizes[session.index] : nil)
        let frameUnset = session.frameWidth == 0 && session.frameHeight == 0
        return classify(hasOpener: true, count: session.imageSizes.count,
                        index: session.imageSizes.isEmpty ? nil : session.index,
                        ratio: session.ratio, shape: shape, merchant: merchant,
                        width: shown?.width, height: shown?.height,
                        frameWidth: frameUnset ? nil : session.frameWidth,
                        frameHeight: frameUnset ? nil : session.frameHeight,
                        frameRequired: true, source: source, failed: failed, busy: busy,
                        exportFailed: exportFailed, acceptsMore: session.canConfirm)
    }

    private enum SourceToken { case unspecified, waiting, ready, missing, failed, unknown }

    private static func sourceToken(_ raw: String?) -> SourceToken {
        guard let raw else { return .unspecified }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "waiting": return .waiting
        case "ready": return .ready
        case "missing": return .missing
        case "error": return .failed
        case "": return .unknown
        default: return .unknown
        }
    }

    private static func classify(hasOpener: Bool, count: Int?, index: Int?, ratio: String?, shape: String?,
                                 merchant: Bool?, width: Double?, height: Double?, frameWidth: Double?,
                                 frameHeight: Double?, frameRequired: Bool, source: String?, failed: Bool,
                                 busy: Bool, exportFailed: Bool, acceptsMore: Bool) -> CropPageFacts {
        let token = sourceToken(source)
        let ratioTrimmed = ratio?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ratioUnknown = ratioTrimmed?.uppercased() == "UNKNOWN"
        let ratioText = ratioUnknown ? unknownDisplay : ((ratioTrimmed?.isEmpty == false) ? ratioTrimmed! : "free")
        let phase = resolvedPhase(token: token, hasOpener: hasOpener, count: count, index: index,
                                  ratioUnknown: ratioUnknown, width: width, height: height,
                                  frameWidth: frameWidth, frameHeight: frameHeight, frameRequired: frameRequired,
                                  failed: failed)
        let knownBatch = progressText(index: index, count: count)
        let canConfirm = phase == .ready && !busy && acceptsMore
        // pages/publish/crop: 使用原图 only when the source failed to open, or a ready frame failed to export.
        let canUseOriginal = !busy && (count ?? 0) > 0 && (phase == .error || (exportFailed && phase == .ready))
        return CropPageFacts(
            phase: phase,
            countText: countText(count),
            indexText: index.map { String($0) } ?? unknownDisplay,
            progressText: knownBatch,
            widthText: dimensionText(width),
            heightText: dimensionText(height),
            frameWidthText: dimensionText(frameWidth),
            frameHeightText: dimensionText(frameHeight),
            ratioText: ratioText,
            round: shape?.trimmingCharacters(in: .whitespacesAndNewlines) == "circle",
            merchantLight: merchant == true,
            canConfirm: canConfirm,
            canUseOriginal: canUseOriginal,
            canReset: phase == .ready && !busy && acceptsMore,
            uploadEnabled: uploadEnabled,
            copyKey: copyKey(phase),
            confirmKey: busy ? Copy.busy : (exportFailed ? Copy.retry : Copy.confirm))
    }

    private static func resolvedPhase(token: SourceToken, hasOpener: Bool, count: Int?, index: Int?,
                                      ratioUnknown: Bool, width: Double?, height: Double?, frameWidth: Double?,
                                      frameHeight: Double?, frameRequired: Bool, failed: Bool) -> CropPagePhase {
        if token == .unknown { return .unknown }
        if failed || token == .failed { return .error }
        if ratioUnknown { return .unknown }
        if token == .waiting { return .loading }
        if token == .missing || !hasOpener { return .empty }
        if count == nil { return token == .ready ? .unknown : .loading }
        if count == 0 { return .empty }
        if let width, let height, !width.isFinite || !height.isFinite || width <= 0 || height <= 0 { return .error }
        if width == nil || height == nil { return token == .ready ? .unknown : .loading }
        if let index, index < 0 || index >= count! { return .error }
        if index == nil, count! > 1 { return .unknown }
        if frameRequired, frameWidth == nil || frameHeight == nil { return token == .ready ? .unknown : .loading }
        if frameRequired, let frameWidth, let frameHeight, frameWidth <= 0 || frameHeight <= 0 { return .error }
        return .ready
    }

    private static func copyKey(_ phase: CropPagePhase) -> String {
        switch phase {
        case .loading: return Copy.loading
        case .empty: return Copy.empty
        case .error: return Copy.error
        case .unknown: return Copy.unknown
        case .ready: return Copy.title
        }
    }
}
