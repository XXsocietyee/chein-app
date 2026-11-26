import SwiftUI
import UIKit

// M5 (native r2 motion, owner 11-26: "all pop-ups must have this animation").
//
// `cySheet` / `cyFullScreenCover` have the exact signatures of SwiftUI's `.sheet(isPresented:)`, `.sheet(item:)`
// and `.fullScreenCover(...)`, so call sites keep their arguments and type inference. Each presentation registers
// with the nearest `PresentationBackdrop` (installed at the app root by `cyPresentationBackdropHost()`, and again
// inside every presented sheet so a nested sheet blurs the sheet under it).
//
// The look is NOT implemented here: the host applies motion-r1's M2 modifier `NativeR2SheetBackdrop`
// (`NativeR2SheetBackdrop.swift`: blur 2 -> 16 pt by detent fraction under the white 0.92 -> 0.15 / black 0.6 -> 0.1
// wash, Reduce Motion = wash only), and each presented sheet reports its height with `nativeR2SheetBackdropSource()`.
// One implementation; this file only decides *when* it is on. Sheets keep system detents, grabber and dimming.
// `.alert` / `.confirmationDialog` stay Apple's.
//
// Gate: `NativeR2Flags.sheetBackdrop` (`-nativeR2.sheetBackdrop NO` = plain system sheets, nothing registered).
// The shared modifier also honours `NativeR2Flags.motion`.

extension NativeR2Flags {
    /// Every sheet / full-screen cover gets the M2 backdrop motion.
    static var sheetBackdrop: Bool { isEnabled("nativeR2.sheetBackdrop") }
}

/// One presentation layer's registry: which sheets presented from this layer are up.
@MainActor
@Observable
final class PresentationBackdrop {
    private(set) var active: Set<UUID> = []

    var isPresenting: Bool { !active.isEmpty }

    func activate(_ token: UUID) {
        guard !active.contains(token) else { return }
        withAnimation(Self.animation) { _ = active.insert(token) }
    }

    func deactivate(_ token: UUID) {
        guard active.contains(token) else { return }
        withAnimation(Self.animation) { _ = active.remove(token) }
    }

    /// Close to UIKit's sheet presentation spring; nil under Reduce Motion (the backdrop is set at once).
    private static var animation: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.5, dampingFraction: 1)
    }
}

private struct PresentationBackdropKey: EnvironmentKey {
    static let defaultValue: PresentationBackdrop? = nil
}

extension EnvironmentValues {
    /// The registry of the presentation layer this view lives in; nil outside a host (then `cySheet` is plain `.sheet`).
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

    @ViewBuilder
    func body(content: Content) -> some View {
        if NativeR2Flags.sheetBackdrop {
            content
                .environment(\.presentationBackdrop, backdrop)
                .nativeR2SheetBackdrop(isPresented: backdrop.isPresenting)
        } else {
            content
        }
    }
}

/// Registers one presentation with the layer it is presented from, reports its height to that layer's backdrop,
/// and makes the presented content its own layer so sheets it presents blur it.
private struct PresentationBackdropRegistration: ViewModifier {
    let backdrop: PresentationBackdrop?
    let token: UUID
    @State private var exempt = false

    func body(content: Content) -> some View {
        content
            .cyPresentationBackdropHost()
            // Outside the inner host, so it reads the presenter's tracker (sheets inherit the presenter's environment).
            .nativeR2SheetBackdropSource()
            // A sheet that keeps the map behind it interactive (persistent map sheets) opts out: no blur under it.
            .onPreferenceChange(CYSheetBackdropExemptKey.self) { value in
                exempt = value
                if value { backdrop?.deactivate(token) }
            }
            .onAppear { if !exempt { backdrop?.activate(token) } }
            .onDisappear { backdrop?.deactivate(token) }
    }
}

/// Set by sheet content that leaves the presenter interactive (`presentationBackgroundInteraction(.enabled…)`).
struct CYSheetBackdropExemptKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
    /// Marks a presented sheet as a persistent, map-interactive sheet: the M5 backdrop is not applied under it.
    func cySheetBackdropExempt(_ exempt: Bool = true) -> some View {
        preference(key: CYSheetBackdropExemptKey.self, value: exempt)
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
            // Start the backdrop with the sheet, and fade it as the dismissal starts (not after it ends).
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
