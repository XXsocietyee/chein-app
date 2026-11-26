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

/// The one sheet header: grabber 36 × 5 (resizable sheets only), round ✕ or ‹ at the leading edge,
/// black `完成` pill (44 high) at the trailing edge, title 20 Bold centred below with an optional 12 pt eyebrow.
/// Pick-one sheets that commit on tap pass `done == nil`. Result sheets do not use a header (CF-41).
struct EditorSheetHeader: View {
    let title: Text
    var eyebrow: Text? = nil
    var leading: EditorSheetLeading = .close
    var showsGrabber: Bool = false
    var doneTitle: Text? = nil
    var doneEnabled: Bool = true
    var onLeading: () -> Void = {}
    var onDone: (() -> Void)? = nil

    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if showsGrabber {
                Capsule(style: .continuous)
                    .fill(palette.sheetHandle)
                    .frame(width: EditorKitMetric.grabberWidth, height: EditorKitMetric.grabberHeight)
                    .padding(.top, CYSpacing.s1_5)
                    .accessibilityHidden(true)
            }
            HStack {
                leadingControl
                Spacer(minLength: CYSpacing.sm)
                if let onDone {
                    Button(action: onDone) { doneTitle ?? EditorKitText.text("editorKit.done") }
                        .buttonStyle(.editorPrimary)
                        .disabled(!doneEnabled)
                        .accessibilityIdentifier("editorKit.sheet.done")
                } else {
                    Color.clear.frame(width: EditorKitMetric.hit, height: EditorKitMetric.hit).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 52)
            VStack(spacing: 2) {
                if let eyebrow {
                    eyebrow
                        .cyText(.meta)
                        .foregroundStyle(palette.textTertiary)
                        .multilineTextAlignment(.center)
                }
                title
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.top, 2)
            .padding(.bottom, CYSpacing.md)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var leadingControl: some View {
        switch leading {
        case .close, .back:
            Button(action: onLeading) {
                Image(systemName: leading == .close ? "xmark" : "chevron.backward")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: EditorKitMetric.closeVisual, height: EditorKitMetric.closeVisual)
                    .background(Circle().fill(palette.brandSoft))
                    .editorHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(EditorKitText.text(leading == .close ? "editorKit.close" : "editorKit.back"))
            .accessibilityIdentifier(leading == .close ? "editorKit.sheet.close" : "editorKit.sheet.back")
        case .none:
            Color.clear.frame(width: EditorKitMetric.hit, height: EditorKitMetric.hit).accessibilityHidden(true)
        }
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
    @Environment(\.editorSheetIsResizable) private var isResizable
    @State private var confirmDiscard = false
    @State private var headerHeight: CGFloat = 0

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
        .safeAreaInset(edge: .top, spacing: 0) {
            EditorSheetHeader(
                title: title, eyebrow: eyebrow, leading: leading,
                showsGrabber: isResizable && leading != .back,
                doneTitle: doneTitle, doneEnabled: doneEnabled,
                onLeading: { leadingTapped() }, onDone: onDone
            )
            .background(palette.bgPage)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: EditorSheetHeaderHeightKey.self, value: proxy.size.height)
            })
        }
        .onPreferenceChange(EditorSheetHeaderHeightKey.self) { headerHeight = $0 }
        .background(palette.bgPage.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(EditorKitText.text("editorKit.discard.title"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { close() } label: { EditorKitText.text("editorKit.discard.confirm") }
            Button(role: .cancel) {} label: { EditorKitText.text("editorKit.discard.keep") }
        }
        .sensoryFeedback(.warning, trigger: confirmDiscard) { _, new in new }
    }

    private func leadingTapped() {
        if leading == .back { dismiss(); return }
        if isDirty { confirmDiscard = true } else { close() }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

private struct EditorSheetHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
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
            .presentationDragIndicator(.hidden)
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
