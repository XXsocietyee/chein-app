import SwiftUI
import UIKit

// M5 (native r2 motion, owner 11-26: "all pop-ups must have this animation").
//
// `cySheet` / `cyFullScreenCover` have the exact signatures of SwiftUI's `.sheet(isPresented:)`, `.sheet(item:)`
// and `.fullScreenCover(...)`, so call sites keep their arguments and type inference. Each presentation registers
// with the nearest `PresentationBackdrop` (installed at the app root by `cyPresentationBackdropHost()`, and again
// inside every presented sheet so a nested sheet blurs the sheet under it). The host then puts the M2 backdrop on
// the content behind the sheet: a top-heavy blur ramp (2 → 16 pt) under a white 0.92 → 0.15 gradient (dark:
// black 0.6 → 0.1), animated with the sheet's spring. Reduce Motion keeps the gradient and drops the blur ramp.
// Sheets keep the system detents, grabber and dimming. `.alert` / `.confirmationDialog` stay Apple's.
//
// Gate: `NativeR2Flags.sheetBackdrop` (`-nativeR2.sheetBackdrop NO` = plain system sheets, nothing registered).

extension NativeR2Flags {
    /// Every sheet / full-screen cover gets the M2 backdrop motion.
    static var sheetBackdrop: Bool { isEnabled("nativeR2.sheetBackdrop") }
}

/// One presentation layer's backdrop state: which sheets presented from this layer are up, and how tall they are.
@MainActor
@Observable
final class PresentationBackdrop {
    /// Sheet height ÷ layer height of every presentation currently up from this layer (nil = not measured yet).
    private(set) var active: [UUID: CGFloat?] = [:]
    /// Height of the layer the backdrop is drawn on; the detent fraction is measured against it.
    var layerHeight: CGFloat = 0

    /// 0 = nothing presented, 1 = a large sheet or full-screen cover is up. Small detents give a lighter backdrop.
    var intensity: CGFloat {
        guard !active.isEmpty else { return 0 }
        let fractions = active.values.compactMap { $0 }
        guard let tallest = fractions.max() else { return 1 }
        return min(1, max(0.4, tallest / 0.9))
    }

    func activate(_ token: UUID) {
        guard active[token] == nil else { return }
        withAnimation(Self.currentAnimation) { active[token] = .some(nil) }
    }

    func deactivate(_ token: UUID) {
        guard active[token] != nil else { return }
        withAnimation(Self.currentAnimation) { _ = active.removeValue(forKey: token) }
    }

    func report(_ token: UUID, sheetHeight: CGFloat) {
        guard active[token] != nil, layerHeight > 0 else { return }
        let fraction = min(1, max(0, sheetHeight / layerHeight))
        if let current = active[token] ?? nil, abs(current - fraction) < 0.01 { return }
        withAnimation(Self.currentAnimation) { active[token] = fraction }
    }

    /// Close to UIKit's sheet presentation spring (critically damped, ~0.5 s).
    static let animation = Animation.spring(response: 0.5, dampingFraction: 1)

    /// Reduce Motion sets the backdrop instantly; scoped to the backdrop so other animations are untouched.
    private static var currentAnimation: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}

private struct PresentationBackdropKey: EnvironmentKey {
    static let defaultValue: PresentationBackdrop? = nil
}

extension EnvironmentValues {
    /// The backdrop of the presentation layer this view lives in; nil outside a host (then `cySheet` is plain `.sheet`).
    var presentationBackdrop: PresentationBackdrop? {
        get { self[PresentationBackdropKey.self] }
        set { self[PresentationBackdropKey.self] = newValue }
    }
}

extension View {
    /// Installs a presentation layer: sheets presented from inside register here and this view gets the backdrop.
    func cyPresentationBackdropHost() -> some View {
        modifier(PresentationBackdropHostModifier())
    }
}

private struct PresentationBackdropHostModifier: ViewModifier {
    @State private var backdrop = PresentationBackdrop()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if NativeR2Flags.sheetBackdrop {
            backdropped(content)
        } else {
            content
        }
    }

    private func backdropped(_ content: Content) -> some View {
        let level = backdrop.intensity
        return content
            .environment(\.presentationBackdrop, backdrop)
            .blur(radius: reduceMotion ? 0 : 2 * level)
            .overlay {
                if level > 0 {
                    ZStack {
                        if !reduceMotion {
                            // Top-heavy blur ramp: a material masked so it reads ~16 pt at the top, ~2 pt at the bottom.
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .mask(LinearGradient(colors: [.black, .black.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                        }
                        LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)
                    }
                    .opacity(level)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { backdrop.layerHeight = $0 }
    }

    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [Color.black.opacity(0.6), Color.black.opacity(0.1)]
            : [Color.white.opacity(0.92), Color.white.opacity(0.15)]
    }
}

/// Registers one presentation with the backdrop of the layer it is presented from, and makes the presented content
/// its own layer so sheets it presents blur it.
private struct PresentationBackdropRegistration: ViewModifier {
    let backdrop: PresentationBackdrop?
    let token: UUID

    func body(content: Content) -> some View {
        content
            .cyPresentationBackdropHost()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { backdrop?.report(token, sheetHeight: $0) }
            .onAppear { backdrop?.activate(token) }
            .onDisappear { backdrop?.deactivate(token) }
    }
}

private enum CYPresentationStyle {
    case sheet, fullScreenCover
}

private struct CYBoolPresentationModifier<SheetContent: View>: ViewModifier {
    let style: CYPresentationStyle
    let isPresented: Binding<Bool>
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent
    @Environment(\.presentationBackdrop) private var backdrop
    @State private var token = UUID()

    func body(content: Content) -> some View {
        let backdrop = NativeR2Flags.sheetBackdrop ? backdrop : nil
        let wrapped: () -> ModifiedContent<SheetContent, PresentationBackdropRegistration> = { [token] in
            sheetContent().modifier(PresentationBackdropRegistration(backdrop: backdrop, token: token))
        }
        return Group {
            if backdrop == nil {
                plain(content)
            } else {
                switch style {
                case .sheet: content.sheet(isPresented: isPresented, onDismiss: onDismiss, content: wrapped)
                case .fullScreenCover: content.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: wrapped)
                }
            }
        }
        .onChange(of: isPresented.wrappedValue, initial: true) { _, presented in
            // Start the backdrop with the sheet's own spring, and fade it as the dismissal starts (not after it ends).
            if presented { backdrop?.activate(token) } else { backdrop?.deactivate(token) }
        }
        .onDisappear { backdrop?.deactivate(token) }
    }

    @ViewBuilder
    private func plain(_ content: Content) -> some View {
        switch style {
        case .sheet: content.sheet(isPresented: isPresented, onDismiss: onDismiss, content: sheetContent)
        case .fullScreenCover: content.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: sheetContent)
        }
    }
}

private struct CYItemPresentationModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    let style: CYPresentationStyle
    let item: Binding<Item?>
    let onDismiss: (() -> Void)?
    let sheetContent: (Item) -> SheetContent
    @Environment(\.presentationBackdrop) private var backdrop
    @State private var token = UUID()

    func body(content: Content) -> some View {
        let backdrop = NativeR2Flags.sheetBackdrop ? backdrop : nil
        let wrapped: (Item) -> ModifiedContent<SheetContent, PresentationBackdropRegistration> = { [token] value in
            sheetContent(value).modifier(PresentationBackdropRegistration(backdrop: backdrop, token: token))
        }
        return Group {
            if backdrop == nil {
                plain(content)
            } else {
                switch style {
                case .sheet: content.sheet(item: item, onDismiss: onDismiss, content: wrapped)
                case .fullScreenCover: content.fullScreenCover(item: item, onDismiss: onDismiss, content: wrapped)
                }
            }
        }
        .onChange(of: item.wrappedValue?.id, initial: true) { _, id in
            if id != nil { backdrop?.activate(token) } else { backdrop?.deactivate(token) }
        }
        .onDisappear { backdrop?.deactivate(token) }
    }

    @ViewBuilder
    private func plain(_ content: Content) -> some View {
        switch style {
        case .sheet: content.sheet(item: item, onDismiss: onDismiss, content: sheetContent)
        case .fullScreenCover: content.fullScreenCover(item: item, onDismiss: onDismiss, content: sheetContent)
        }
    }
}

extension View {
    /// `.sheet(isPresented:onDismiss:content:)` plus the M5 backdrop motion on the presenting layer.
    func cySheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CYBoolPresentationModifier(style: .sheet, isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    /// `.sheet(item:onDismiss:content:)` plus the M5 backdrop motion on the presenting layer.
    func cySheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(CYItemPresentationModifier(style: .sheet, item: item, onDismiss: onDismiss, sheetContent: content))
    }

    /// `.fullScreenCover(isPresented:onDismiss:content:)` plus the M5 backdrop motion on the presenting layer.
    func cyFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CYBoolPresentationModifier(style: .fullScreenCover, isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
    }

    /// `.fullScreenCover(item:onDismiss:content:)` plus the M5 backdrop motion on the presenting layer.
    func cyFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(CYItemPresentationModifier(style: .fullScreenCover, item: item, onDismiss: onDismiss, sheetContent: content))
    }
}
