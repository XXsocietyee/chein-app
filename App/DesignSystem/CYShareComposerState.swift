import SwiftUI
import UIKit

// Share composer state machine (motion-system spec, subsystem B). One enum replaces the ad-hoc
// `image` / `renderFailed` / `sourceChanged` booleans so illegal combinations cannot be represented.
//
//   editing --prepare--> rendering --rendered(img)--> ready | --rendered(nil)--> renderFailed
//   ready | done --styleChanged | captionChanged | invalidate--> editing   (image dropped, ready row fades out)
//   ready | done --export(channel)--> exporting --exportFinished(true)--> done | (false) --> ready
//   any --sourceChanged--> stale   (terminal until the page is dismissed)
//
// The machine is a value type held in `@State`; the views own the Photos / system-sheet plumbing and feed events.

enum CYShareChannel: Equatable {
    case photos, system, albumGuide
}

enum CYShareComposerState: Equatable {
    case editing
    case rendering
    case ready(UIImage)
    case exporting(UIImage, CYShareChannel)
    case done(UIImage)
    case renderFailed
    case stale

    /// The prepared bitmap while one exists (ready, exporting, done).
    var image: UIImage? {
        switch self {
        case .ready(let image), .done(let image): return image
        case .exporting(let image, _): return image
        case .editing, .rendering, .renderFailed, .stale: return nil
        }
    }
    var isRendering: Bool { if case .rendering = self { return true } else { return false } }
    var isStale: Bool { if case .stale = self { return true } else { return false } }
    var isExporting: Bool { if case .exporting = self { return true } else { return false } }

    static func == (lhs: CYShareComposerState, rhs: CYShareComposerState) -> Bool {
        switch (lhs, rhs) {
        case (.editing, .editing), (.rendering, .rendering), (.renderFailed, .renderFailed), (.stale, .stale): return true
        case let (.ready(a), .ready(b)): return a === b
        case let (.done(a), .done(b)): return a === b
        case let (.exporting(a, ca), .exporting(b, cb)): return a === b && ca == cb
        default: return false
        }
    }
}

enum CYShareComposerEvent {
    case styleChanged
    case captionChanged
    /// A privacy toggle or owner check dropped the prepared image without marking the page stale.
    case invalidate
    case prepare
    case rendered(UIImage?)
    case export(CYShareChannel)
    case exportFinished(Bool)
    case sourceChanged
}

struct CYShareComposerMachine: Equatable {
    private(set) var state: CYShareComposerState = .editing
    /// Increments on each entry into `.ready`, so a view fires exactly one `.impactLight` per prepared card.
    private(set) var readyTick = 0
    /// Increments on each entry into `.done`, so a view fires exactly one `.success` per completed export.
    private(set) var doneTick = 0

    var image: UIImage? { state.image }

    mutating func send(_ event: CYShareComposerEvent) {
        if state.isStale { return }
        switch event {
        case .styleChanged, .captionChanged, .invalidate:
            // Also cancels an in-flight render: its late `rendered` event finds no `.rendering` state and is ignored.
            state = .editing
        case .prepare:
            switch state {
            case .editing, .renderFailed, .ready, .done: state = .rendering
            case .rendering, .exporting, .stale: break
            }
        case .rendered(let image):
            guard state.isRendering else { return }
            if let image { state = .ready(image); readyTick += 1 } else { state = .renderFailed }
        case .export(let channel):
            switch state {
            case .ready(let image), .done(let image): state = .exporting(image, channel)
            default: break
            }
        case .exportFinished(let success):
            guard case .exporting(let image, _) = state else { return }
            if success { state = .done(image); doneTick += 1 } else { state = .ready(image) }
        case .sourceChanged:
            state = .stale
        }
    }
}

// MARK: - Render budget

/// Spec budget for one 3x export. Measured around `CYShareCardRenderer.render`; DEBUG logs an overrun.
enum CYShareRenderBudget {
    static let maximumSeconds: Double = 0.120
    static func check(_ elapsed: Double, ratio: CYShareCardRatio) {
        #if DEBUG
        if elapsed > maximumSeconds {
            print("share.render over budget: \(Int(elapsed * 1000)) ms for \(ratio.rawValue) (budget \(Int(maximumSeconds * 1000)) ms)")
        }
        #endif
    }
}

// MARK: - Prepare button with the 150 ms spinner threshold

/// The primary pill while a render may be running. A spinner appears only once rendering has taken more than
/// 150 ms, so a fast export never flashes one. The caller hands in the catalog key for the title.
struct CYSharePrepareButton: View {
    let title: LocalizedStringKey
    var systemImage: String = "photo"
    let state: CYShareComposerState
    var identifier: String
    let action: () -> Void
    @State private var showsSpinner = false
    @Environment(\.cyPalette) private var palette

    var body: some View {
        CYPillButton(title, systemImage: systemImage, action: action)
            .disabled(state.isRendering)
            .overlay(alignment: .trailing) {
                if showsSpinner {
                    ProgressView().tint(palette.textPrimary)
                        .padding(.trailing, CYSpacing.xl)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeInOut(duration: CYMotion.Duration.quick), value: showsSpinner)
            .accessibilityIdentifier(identifier)
            .task(id: state.isRendering) {
                showsSpinner = false
                guard state.isRendering else { return }
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                showsSpinner = true
            }
    }
}

// MARK: - Ready row

/// "Card ready": the exact prepared bitmap as a 72 pt thumbnail with one foil sheen, a success chip and a hint.
/// Enters with `cyEntrance` (fade, rise, 0.9 to 1 scale); appears at once under Reduce Motion.
struct CYShareReadyRow: View {
    let image: UIImage
    let title: LocalizedStringKey
    let hint: LocalizedStringKey
    let previewLabel: LocalizedStringKey
    var identifier: String

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(height: 72)
                .overlay { CYFoilSheen() }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityLabel(Text(previewLabel))
                .accessibilityIdentifier(identifier)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                CYStatusChip(title, tone: .success, systemImage: "checkmark.seal")
                Text(hint).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .cyEntrance()
    }
}

/// One-shot foil sheen: a thin diagonal highlight sweeps across once (1.1 s, easeOut) and never loops.
/// Reduce Motion: a static highlight. Use inside a clipped overlay only (`blendMode(.screen)`).
struct CYFoilSheen: View {
    var duration: Double = 1.1
    @QuestifyReduceMotion private var reduceMotion
    @State private var progress: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(colors: [.clear, .white.opacity(0.0), .white.opacity(0.55), .white.opacity(0.0), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: max(1, width * 0.6))
                .rotationEffect(.degrees(18))
                .offset(x: reduceMotion ? width * 0.25 : progress * width * 1.6)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
        }
    }
}

// MARK: - Announcements

enum CYShareAnnouncer {
    /// VoiceOver announcement for state changes that have no focused element ("Card ready", "Saved to Photos").
    static func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
