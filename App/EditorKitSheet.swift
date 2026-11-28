import SwiftUI

// Design hand-off r1 · Editor/Sheet Header (CF-11) and Editor/Sheet (CF-12, CF-13, section 3).

/// `Editor/Sheet Header` leading control.
enum EditorSheetLeading: Sendable {
    /// Round ✕ (32 visual in a 44 target).
    case close
    /// ‹ on a sub-page pushed inside the sheet's own navigation stack.
    case back
    case none
}

/// native-a r3: the sheet header is the system navigation bar of the sheet's own `NavigationStack` (inline title,
/// optional eyebrow above it in the principal slot, ✕ as the cancellation action, 完成 / Done as the confirmation
/// action, the system back button on pushed sub-pages) and the system drag indicator on resizable sheets. The
/// former hand-drawn grabber / round ✕ / black Done pill header is gone.
private struct EditorSheetNavigationTitle: View {
    let title: Text
    let eyebrow: Text?
    var body: some View {
        VStack(spacing: 0) {
            if let eyebrow {
                eyebrow.font(.caption).foregroundStyle(.secondary)
            }
            title.font(.headline).accessibilityAddTraits(.isHeader)
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
}

// MARK: - Sheet page (header pinned, body scrolls only at the largest detent)

private struct EditorSheetFitHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct EditorSheetScrollEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct EditorSheetResizableKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Section 3.1: the inner scroll view is locked until the sheet is at its largest detent.
    var editorSheetScrollEnabled: Bool {
        get { self[EditorSheetScrollEnabledKey.self] }
        set { self[EditorSheetScrollEnabledKey.self] = newValue }
    }
    var editorSheetIsResizable: Bool {
        get { self[EditorSheetResizableKey.self] }
        set { self[EditorSheetResizableKey.self] = newValue }
    }
}

/// One editing page inside an editor sheet: pinned header, body that reports its natural height
/// (for the `fit` detent) and scrolls only at the largest detent. Sub-editors push another
/// `EditorSheetPage` with `leading: .back` (CF-12: never a sheet on a sheet).
/// ✕ or a swipe on a dirty page asks `放弃修改？` first (CF-77).
struct EditorSheetPage<Content: View>: View {
    let title: Text
    var eyebrow: Text? = nil
    var leading: EditorSheetLeading = .close
    var doneTitle: Text? = nil
    var doneEnabled: Bool = true
    var isDirty: Bool = false
    var banner: Text? = nil
    var onDone: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
    @Environment(\.editorSheetScrollEnabled) private var scrollEnabled
    @State private var confirmDiscard = false
    /// The inline navigation bar the sheet's `fit` detent has to make room for (it sits outside the measured body).
    @ScaledMetric(relativeTo: .headline) private var headerHeight: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let banner {
                    Label { banner } icon: { Image(systemName: "exclamationmark.circle.fill") }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.danger)
                        .padding(CYSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous).fill(palette.dangerSoft))
                        .accessibilityIdentifier("editorKit.sheet.banner")
                }
                content()
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.top, CYSpacing.xs)
            .padding(.bottom, CYSpacing.xxxl)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: EditorSheetFitHeightKey.self, value: proxy.size.height + headerHeight)
            })
        }
        .scrollDisabled(!scrollEnabled)
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.bgPage.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(leading != .back)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EditorSheetNavigationTitle(title: title, eyebrow: eyebrow)
            }
            ToolbarItem(placement: .cancellationAction) {
                if leading == .close {
                    Button { leadingTapped() } label: {
                        Label { EditorKitText.text("editorKit.close") } icon: { Image(systemName: "xmark") }
                    }
                    .accessibilityIdentifier("editorKit.sheet.close")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if let onDone {
                    Button(action: onDone) { doneTitle ?? EditorKitText.text("editorKit.done") }
                        .disabled(!doneEnabled)
                        .accessibilityIdentifier("editorKit.sheet.done")
                }
            }
        }
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(EditorKitText.text("editorKit.discard.title"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { close() } label: { EditorKitText.text("editorKit.discard.confirm") }
            Button(role: .cancel) {} label: { EditorKitText.text("editorKit.discard.keep") }
        }
        .sensoryFeedback(.warning, trigger: confirmDiscard, condition: CYHapticTransition.isOn)
    }

    private func leadingTapped() {
        if leading == .back { dismiss(); return }
        if isDirty { confirmDiscard = true } else { close() }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

// MARK: - Resizable sheet (section 3)

extension CYSheetSize {
    /// The editor family table (Core `EditorSheetDetent`) in the shared sheet's terms.
    init(_ detent: EditorSheetDetent) {
        switch detent {
        case .fit: self = .fit
        case .height(let value): self = .height(CGFloat(value))
        case .fraction(let value): self = .fraction(CGFloat(value))
        case .medium: self = .medium
        case .large: self = .large
        }
    }
}

/// Editor sheets run on the shared design r1 sheet engine: detents are `CYSheetSize` values from the family table
/// (section 3.3), `fit` is `CYResizableSheet.fitHeight` capped at `CYSheetMetrics.fitCap` (62%), scrolling follows
/// `CYResizableSheet.scrollEnabled`, detent changes use the `CYMotion.sheetDetent` spring (cross-fade under Reduce
/// Motion), and only a settled drag plays `.selection`. Unlike a `CYResizableSheet` root, the root here is a
/// NavigationStack, because sub-editors push inside the sheet (CF-12) and each `EditorSheetPage` pins its own header.
struct EditorSheetHost<Content: View>: View {
    let family: EditorSheetFamily
    let isDirty: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var measured: CGFloat = 0
    @State private var selection: PresentationDetent
    @State private var programmatic = false
    @State private var settleTick = 0

    init(family: EditorSheetFamily, isDirty: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.family = family
        self.isDirty = isDirty
        self.content = content
        let first = family.detents.first.map(CYSheetSize.init) ?? .medium
        _selection = State(initialValue: first.presentationDetent(fitHeight: CYResizableSheet<EmptyView>.unmeasuredFit))
    }

    private var sizes: [CYSheetSize] { family.detents.map(CYSheetSize.init) }
    private var fitHeight: CGFloat {
        CYResizableSheet<EmptyView>.fitHeight(content: measured, chrome: 0, cap: CYSheetMetrics.fitCap)
    }
    private var detents: [PresentationDetent] { sizes.map { $0.presentationDetent(fitHeight: fitHeight) } }
    private var scrollEnabled: Bool {
        CYResizableSheet<EmptyView>.scrollEnabled(sizes: sizes, atLargest: selection == (detents.last ?? .large),
                                                  natural: measured, cap: CYSheetMetrics.fitCap)
    }

    var body: some View {
        NavigationStack { content() }
            .onPreferenceChange(EditorSheetFitHeightKey.self) { measured = $0 }
            .environment(\.editorSheetScrollEnabled, scrollEnabled)
            .environment(\.editorSheetIsResizable, family.isResizable)
            .presentationDetents(Set(detents), selection: $selection)
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(family.isResizable ? .visible : .hidden)
            .presentationCornerRadius(CYRadius.sheet)
            .presentationBackground(palette.bgPage)
            .presentationBackgroundInteraction(.disabled)
            .interactiveDismissDisabled(isDirty)
            .animation(CYMotion.resolve(CYMotion.sheetDetent, reduceMotion: reduceMotion), value: fitHeight)
            .animation(CYMotion.resolve(CYMotion.sheetDetent, reduceMotion: reduceMotion), value: selection)
            .cyHaptic(.selection, trigger: settleTick)
            .onChange(of: fitHeight) { old, new in
                // Stay on the fit detent while the content grows or shrinks.
                guard sizes.contains(.fit), selection == .height(old) else { return }
                programmatic = true
                selection = .height(new)
            }
            .onChange(of: selection) { _, _ in
                if programmatic { programmatic = false } else { settleTick += 1 }
            }
    }
}

private struct EditorSheetPresenter<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let family: EditorSheetFamily
    let isDirty: Bool
    let onDismiss: (() -> Void)?
    let sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content
            .cySheet(item: $item, onDismiss: onDismiss) { value in
                EditorSheetHost(family: family, isDirty: isDirty) { sheetContent(value) }
            }
    }
}

/// Boolean presentation wrapper for `editorSheet(isPresented:)`.
struct EditorSheetToken: Identifiable, Hashable { let id = 0 }

extension View {
    /// Presents one editor sheet with the section 3.3 detents of `family`.
    func editorSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        family: EditorSheetFamily,
        isDirty: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(EditorSheetPresenter(item: item, family: family, isDirty: isDirty, onDismiss: onDismiss, sheetContent: content))
    }

    func editorSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        family: EditorSheetFamily,
        isDirty: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        let token = Binding<EditorSheetToken?>(
            get: { isPresented.wrappedValue ? EditorSheetToken() : nil },
            set: { isPresented.wrappedValue = $0 != nil }
        )
        return modifier(EditorSheetPresenter(item: token, family: family, isDirty: isDirty, onDismiss: onDismiss, sheetContent: { _ in content() }))
    }
}
