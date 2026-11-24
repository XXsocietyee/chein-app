import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Player kit, design hand-off r1 (`docs/design/handoff-r1` on `design/handoff-r1`; review/full-player.md §2–§3,
// revise/player.md "Player kit"). This file is the shared foundation the config, club and merchant pages adopt:
//   - `CYStatusTag`          Player/Status Tag: icon + word, never a dot alone (PL-14)
//   - `cyRootHeader(_:)`     Player/Root Header: large left title = the tab's label, 消息 then one page action (PL-11)
//   - `CYSheetSize`, `CYSheetKind`, `cyResizableSheet`  Player/Sheet + Editor/Sheet: resizable scrollable sheets (§3)
//   - `CYSheetHeader`        Editor/Sheet Header (TE): grabber, grey ✕, black 完成 pill, centred 20 Bold title
//   - `CYUnknownValue`       "—" for unknown values, never 0 (§2)
// Buttons are `CYPillButton` (Player/Button, 44 / 52), the toast is `CYToastPill`, inline states are `CYStateView`.

// MARK: - Motion values (hand-off §3.2 and PL-48)

extension CYMotion {
    /// Spring between sheet detents and for content-height changes: `spring(response: 0.38, dampingFraction: 0.86)`.
    static let sheetDetent = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// Full-screen cover rising from its button (play, roam, camera, dice): 400 ms, PL-41.
    static let fullScreenRise = Animation.spring(response: 0.45, dampingFraction: 0.86)
    /// Pin select on the map and small "lift" moments: `spring(.3, .7)`.
    static let pinSelect = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Avatar drops into a team slot, PL-31.
    static let slotDrop = Animation.spring(response: 0.35, dampingFraction: 0.6)
    /// Flag plants on the claimed cell, PL-44.
    static let flagPlant = Animation.spring(response: 0.4, dampingFraction: 0.55)
    /// Content fields fade in 180 ms, 60 ms after a sheet starts to grow.
    static let sheetFieldFade = Animation.easeOut(duration: 0.18).delay(0.06)
}

// MARK: - Unknown values

/// Unknown values read "—" with the reason in a caption (hand-off §2). Never print 0 for a value the server did not send.
enum CYUnknownValue {
    static let dash = "—"

    /// `value` formatted, or "—" when it is nil.
    static func text<T>(_ value: T?, format: (T) -> String) -> String {
        guard let value else { return dash }
        return format(value)
    }

    /// Integer counts (积分, 格子, 站数): "—" when nil.
    static func count(_ value: Int?) -> String {
        text(value) { String($0) }
    }

    /// Server strings: "—" when nil or blank.
    static func string(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? dash : trimmed
    }
}

// MARK: - Status tag (Player/Status Tag, PL-14)

/// The player status states, plus `failed` for the club and merchant kits (未通过 / failed, red).
/// Each has its own icon so the state never depends on colour alone. Blue is never used.
enum CYStatusTagState: CaseIterable, Hashable {
    case neutral, live, paused, warning, done, failed

    var tone: CYStatusTone {
        switch self {
        case .neutral, .paused: return .neutral
        case .live, .done: return .success
        case .warning: return .warning
        case .failed: return .danger
        }
    }

    var systemImage: String {
        switch self {
        case .neutral: return "clock"
        case .live: return "record.circle"
        case .paused: return "pause.circle"
        case .warning: return "exclamationmark.triangle"
        case .done: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        }
    }
}

/// Labelled status tag that replaces the status dots: soft fill, 12 pt icon, word.
/// Use the preset words in `CYStatusTag.Word` or pass any localized word.
struct CYStatusTag: View {
    /// Preset words for the roam and play states (`DesignR1` table).
    enum Word: String, CaseIterable {
        case ready = "statusTag.ready"
        case locating = "statusTag.locating"
        case recording = "statusTag.recording"
        case paused = "statusTag.paused"
        case notStarted = "statusTag.notStarted"
        case ended = "statusTag.ended"

        var state: CYStatusTagState {
            switch self {
            case .ready, .notStarted: return .neutral
            case .locating: return .neutral
            case .recording: return .live
            case .paused: return .paused
            case .ended: return .done
            }
        }

        /// Locating uses its own glyph so it reads differently from "ready".
        var systemImage: String {
            self == .locating ? "location" : state.systemImage
        }
    }

    private let chip: CYStatusChip

    init(_ word: Word) {
        chip = CYStatusChip(LocalizedStringKey(word.rawValue), tone: word.state.tone, systemImage: word.systemImage, tableName: "DesignR1")
    }

    init(_ text: LocalizedStringKey, state: CYStatusTagState, tableName: String? = nil) {
        chip = CYStatusChip(text, tone: state.tone, systemImage: state.systemImage, tableName: tableName)
    }

    /// Server status text. Blank renders "—".
    init(verbatim text: String, state: CYStatusTagState) {
        chip = CYStatusChip(verbatim: text, tone: state.tone, systemImage: state.systemImage)
    }

    var body: some View { chip }
}

// MARK: - Root header (Player/Root Header, PL-11)

/// One header for the five player tab roots: a large left title equal to the tab's label (首页 · 漫游 · 发布 · 俱乐部 · 我的).
/// Content scrolls under the system bar and the large title collapses on scroll (system motion). The page's own actions
/// stay in the trailing toolbar, after the 消息 entry, which sits in the same place on every root.
extension View {
    func cyRootHeader(_ tab: RootTab) -> some View {
        modifier(CYRootHeaderModifier(tab: tab))
    }
}

private struct CYRootHeaderModifier: ViewModifier {
    let tab: RootTab
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        // Same lookup as `appNavigationTitle`, so the in-app language switch applies to the root titles too.
        content
            .navigationTitle(appLocalized(String.LocalizationValue(stringLiteral: tab.titleKey), locale: locale))
            .navigationBarTitleDisplayMode(.large)
    }
}

/// Root subtitle line under the large title (首页: "小城，今天去哪"). 13 pt, secondary ink, one line.
struct CYRootSubtitle: View {
    private let text: Text
    @Environment(\.cyPalette) private var palette

    init(_ key: LocalizedStringKey, tableName: String? = nil) { text = Text(key, tableName: tableName) }
    init(verbatim: String) { text = Text(verbatim: verbatim) }

    var body: some View {
        text
            .cyText(.bodyCompact)
            .foregroundStyle(palette.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Round glass action for a root header or a map top bar: 44 pt target, optional count badge (消息).
struct CYHeaderCircleLabel: View {
    let systemImage: String
    let badge: Int?

    init(systemImage: String, badge: Int? = nil) {
        self.systemImage = systemImage
        self.badge = badge
    }

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Image(systemName: systemImage)
            .accessibilityHidden(true).font(.body.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(width: 36, height: 36)
            .background(reduceTransparency ? AnyShapeStyle(palette.bgElevated) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
            .overlay(alignment: .topTrailing) {
                if let badge, badge > 0 {
                    CYCountBadge(count: badge).offset(x: 6, y: -4)
                }
            }
            .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
    }
}

// MARK: - Resizable scrollable sheets (hand-off §3, owner's Kavsoft reference)

/// One detent of a resizable sheet. `fit` is the content's own height, capped at 62% of the screen.
enum CYSheetSize: Hashable {
    case fit
    case medium
    case large
    case height(CGFloat)
    case fraction(CGFloat)

    /// Largest `fit` as a share of the screen.
    static let fitCap: CGFloat = 0.62

    func presentationDetent(fitHeight: CGFloat) -> PresentationDetent {
        switch self {
        case .fit: return .height(fitHeight)
        case .medium: return .medium
        case .large: return .large
        case .height(let value): return .height(value)
        case .fraction(let value): return .fraction(value)
        }
    }
}

@MainActor enum CYSheetMetrics {
    /// Screen height for the 62% fit cap.
    static var screenHeight: CGFloat {
        #if canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.bounds.height ?? 852
        #else
        return 852
        #endif
    }

    /// Largest `fit` height on this screen.
    static var fitCap: CGFloat { screenHeight * CYSheetSize.fitCap }
}

extension View {
    /// `fit` detent for a short sheet that draws its own header (an option list that commits on tap): the sheet is as
    /// tall as its content, capped at 62%, and follows content-height changes with the sheet spring. No grabber.
    func cyFitSheetDetent() -> some View {
        modifier(CYFitSheetDetentModifier())
    }
}

private struct CYFitSheetDetentModifier: ViewModifier {
    @State private var height: CGFloat = 240
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, value in height = value }
                }
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(min(height, CYSheetMetrics.fitCap))])
            .presentationDragIndicator(.visible)
            .animation(CYMotion.resolve(CYMotion.sheetDetent, reduceMotion: reduceMotion), value: height)
    }
}

/// The detent table (full-player §3 and full-config §3.3). The first size is the opening detent.
/// `mapInteractive` sheets leave the map usable up through `.medium` and have no scrim.
enum CYSheetKind: CaseIterable, Hashable {
    // Player · map and CITY
    case propertyCard, claimFlow, challenge, propertyAction, district, roamNearby, liveRoam
    // Player · play
    case teamChat, channelEntry, hint, stationTask, safetyReview
    // Player · commerce and account
    case ticketType, login, share, clubWelcome, memberManagement, released
    // Merchant pickers on player pages, date and result sheets
    case pickerShort, pickerLong, datePicker, submitted
    // Editor sheets (config review §3.3)
    case editorFit, editorFitLarge, editorList, editorNode, editorLarge, editorTextName, editorTextDescription, editorTextStory

    var sizes: [CYSheetSize] {
        switch self {
        case .propertyCard: return [.fit, .large]
        case .claimFlow, .challenge, .propertyAction, .channelEntry, .stationTask, .safetyReview,
             .ticketType, .clubWelcome, .released, .pickerShort, .datePicker, .submitted, .editorFit:
            return [.fit]
        case .district: return [.height(96), .medium, .large]
        case .roamNearby: return [.height(64), .medium, .large]
        case .liveRoam: return [.height(120), .medium]
        // 提示 (396:4404) and 队伍聊天 (396:4449): medium / large, scrim 40 % (skill-r2 hand-off, SR2-49 table).
        case .teamChat, .hint, .memberManagement, .editorList: return [.medium, .large]
        case .login, .share, .editorLarge: return [.large]
        case .pickerLong, .editorFitLarge: return [.fit, .large]
        case .editorNode: return [.fraction(0.62), .large]
        case .editorTextName: return [.height(200), .large]
        case .editorTextDescription: return [.medium, .large]
        case .editorTextStory: return [.large]
        }
    }

    var mapInteractive: Bool {
        switch self {
        case .propertyCard, .district, .roamNearby, .liveRoam: return true
        default: return false
        }
    }
}

/// Header style. `.editor` is the TE header (✕ left, black 完成 pill right, title centred below);
/// `.player` puts the 20 Bold title left and the round ✕ right.
/// The sheet-header rule (handbook; verify-r1 Q10 and skill-r2 hand-off, owner 2026-11-16): three styles, one per
/// domain. Editor: ✕ leading, centred title, 完成 trailing. Player: title leading, ✕ trailing. Merchant: centred title,
/// ✕ trailing. `.automatic` picks the style from the sheet's own theme domain, so a sheet follows the rule without
/// naming it.
enum CYSheetHeaderStyle {
    case editor, player, merchant, automatic

    static func forDomain(_ domain: ThemeDomain) -> CYSheetHeaderStyle {
        switch domain {
        case .topicEditor: return .editor
        case .merchant: return .merchant
        case .player, .dark, .game: return .player
        }
    }
    func resolved(in domain: ThemeDomain) -> CYSheetHeaderStyle {
        self == .automatic ? Self.forDomain(domain) : self
    }
}

/// The one sheet header (Editor/Sheet Header and Player/Sheet): 36×5 grabber (drawn by the system when resizable),
/// a 52 pt bar, a 32 pt grey ✕ circle in a 44 pt target, a 44 pt black 完成 pill, and the scale's sheet title
/// (`.cyText(.sheetTitle)`: 22 pt bold = mini-program 44rpx, consist-1).
struct CYSheetHeader: View {
    let title: Text?
    let eyebrow: Text?
    let style: CYSheetHeaderStyle
    let doneTitle: LocalizedStringKey
    let doneTableName: String?
    let isDoneEnabled: Bool
    /// Pushed sub-editors show ‹ instead of ✕.
    let showsBack: Bool
    let onClose: (() -> Void)?
    let onDone: (() -> Void)?

    init(
        title: Text? = nil,
        eyebrow: Text? = nil,
        style: CYSheetHeaderStyle = .editor,
        doneTitle: LocalizedStringKey = "sheet.done",
        doneTableName: String? = "DesignR1",
        isDoneEnabled: Bool = true,
        showsBack: Bool = false,
        onClose: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.style = style
        self.doneTitle = doneTitle
        self.doneTableName = doneTableName
        self.isDoneEnabled = isDoneEnabled
        self.showsBack = showsBack
        self.onClose = onClose
        self.onDone = onDone
    }

    @Environment(\.cyPalette) private var palette

    var body: some View {
        let style = self.style.resolved(in: palette.domain)
        VStack(spacing: 0) {
            if style == .merchant {
                // Merchant: centred title, ✕ at the trailing edge (and 完成 when the sheet confirms).
                ZStack {
                    VStack(spacing: 2) {
                        if let eyebrow { eyebrow.cyText(.meta).foregroundStyle(palette.textTertiary) }
                        if let title {
                            title
                                .cyText(.sheetTitle)
                                .foregroundStyle(palette.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CYSpacing.minTouchTarget + CYSpacing.lg)
                    HStack {
                        if showsBack { leading }
                        Spacer(minLength: CYSpacing.sm)
                        if !showsBack, onClose != nil { closeButton }
                        if onDone != nil { trailing }
                    }
                }
                .frame(minHeight: 52)
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, CYSpacing.sm)
            } else if style == .editor {
                HStack {
                    leading
                    Spacer(minLength: CYSpacing.sm)
                    trailing
                }
                .frame(minHeight: 52)
                .padding(.horizontal, CYSpacing.lg)
                VStack(spacing: 2) {
                    if let eyebrow {
                        eyebrow.cyText(.meta).foregroundStyle(palette.textTertiary)
                    }
                    if let title {
                        title
                            .cyText(.sheetTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CYSpacing.lg)
                .padding(.top, 2)
                .padding(.bottom, CYSpacing.md)
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    if showsBack { leading }
                    if let title {
                        title
                            .cyText(.sheetTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
                    }
                    if !showsBack, onClose != nil { closeButton }
                    if onDone != nil { trailing }
                }
                .frame(minHeight: 52)
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, CYSpacing.sm)
            }
        }
        .padding(.top, 13)
    }

    @ViewBuilder private var leading: some View {
        if showsBack, let onClose {
            circleButton(systemImage: "chevron.left", label: Text("action.back"), action: onClose)
        } else if onClose != nil {
            closeButton
        } else {
            Color.clear.frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
        }
    }

    @ViewBuilder private var closeButton: some View {
        if let onClose {
            circleButton(systemImage: "xmark", label: Text("action.close"), action: onClose)
        }
    }

    @ViewBuilder private var trailing: some View {
        if let onDone {
            Button(action: onDone) {
                Text(doneTitle, tableName: doneTableName)
                    .cyText(.bodyMedium)
                    .foregroundStyle(isDoneEnabled ? palette.actionPrimaryFg : palette.textPlaceholder)
                    .padding(.horizontal, 18)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .background(Capsule(style: .continuous).fill(isDoneEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isDoneEnabled)
            .accessibilityIdentifier("sheet.header.done")
        } else if style == .editor {
            Color.clear.frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
        }
    }

    private func circleButton(systemImage: String, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Self.closeFill(in: palette)))
                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(systemImage == "xmark" ? "sheet.header.close" : "sheet.header.back")
    }

    /// Grey ✕ circle: `#3A3A3C` on the player sheet, `#EEEEEE` on merchant light.
    static func closeFill(in palette: CYDomainPalette) -> Color {
        palette.isDarkDomain ? palette.sheetCard : palette.actionSecondaryBg
    }
}

/// Primary pill pinned at the bottom of a sheet (one per sheet).
struct CYSheetPrimary {
    let title: LocalizedStringKey
    let tableName: String?
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, tableName: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.tableName = tableName
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Resizable scrollable sheet body. Opens at its smallest detent that shows the content, grows by drag, and its inner
/// scroll view stays locked until the sheet is at its largest detent (a single-detent sheet scrolls only when the content
/// is taller than the 62% cap). Detent changes use the `CYMotion.sheetDetent` spring; Reduce Motion cross-fades.
struct CYResizableSheet<Content: View>: View {
    let kind: CYSheetKind
    let sizes: [CYSheetSize]?
    let title: Text?
    let eyebrow: Text?
    let headerStyle: CYSheetHeaderStyle
    let isDirty: Bool
    let primary: CYSheetPrimary?
    let onDone: (() -> Void)?
    let onClose: (() -> Void)?
    let content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var contentHeight: CGFloat = 0
    @State private var chromeTop: CGFloat = 0
    @State private var chromeBottom: CGFloat = 0
    @State private var selection: PresentationDetent
    @State private var programmatic = false
    @State private var settleTick = 0
    @State private var confirmsDiscard = false

    init(
        kind: CYSheetKind,
        sizes: [CYSheetSize]? = nil,
        title: Text? = nil,
        eyebrow: Text? = nil,
        headerStyle: CYSheetHeaderStyle = .automatic,
        isDirty: Bool = false,
        primary: CYSheetPrimary? = nil,
        onDone: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.kind = kind
        self.sizes = sizes
        self.title = title
        self.eyebrow = eyebrow
        self.headerStyle = headerStyle
        self.isDirty = isDirty
        self.primary = primary
        self.onDone = onDone
        self.onClose = onClose
        self.content = content
        // Open on the smallest detent; `fit` starts at the unmeasured height and follows the first measure.
        let first = (sizes ?? kind.sizes).first ?? .medium
        _selection = State(initialValue: first.presentationDetent(fitHeight: Self.unmeasuredFit))
    }

    /// Fit height before the first layout pass.
    static var unmeasuredFit: CGFloat { 240 }

    private var chromeHeight: CGFloat { chromeTop + chromeBottom }

    private var resolvedSizes: [CYSheetSize] { sizes ?? kind.sizes }
    private var isResizable: Bool { resolvedSizes.count > 1 }

    private var fitCap: CGFloat { CYSheetMetrics.fitCap }

    /// Natural height (header + content + primary), capped at 62%; at least one row tall before the first measure.
    var fitHeight: CGFloat { Self.fitHeight(content: contentHeight, chrome: chromeHeight, cap: fitCap) }

    static func fitHeight(content: CGFloat, chrome: CGFloat, cap: CGFloat) -> CGFloat {
        let natural = content + chrome
        guard natural > 0 else { return min(unmeasuredFit, cap) }
        return min(natural, cap)
    }

    private var detents: [PresentationDetent] { resolvedSizes.map { $0.presentationDetent(fitHeight: fitHeight) } }
    private var largest: PresentationDetent { detents.last ?? .large }

    /// Scroll only at the largest detent; a single fit detent scrolls only when the content overflows the cap.
    private var scrollEnabled: Bool {
        Self.scrollEnabled(sizes: resolvedSizes, atLargest: selection == largest, natural: contentHeight + chromeHeight, cap: fitCap)
    }

    static func scrollEnabled(sizes: [CYSheetSize], atLargest: Bool, natural: CGFloat, cap: CGFloat) -> Bool {
        if sizes == [.fit] { return natural > cap }
        return atLargest
    }

    var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(
                title: title,
                eyebrow: eyebrow,
                style: headerStyle,
                onClose: close,
                onDone: onDone
            )
            .background(heightReader { chromeTop = $0 })

            ScrollView {
                content()
                    .padding(.horizontal, CYSpacing.lg)
                    .padding(.top, CYSpacing.xs)
                    .padding(.bottom, primary == nil ? CYSpacing.xxxl : CYSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(heightReader { contentHeight = $0 })
            }
            .scrollDisabled(!scrollEnabled)
            .scrollBounceBehavior(.basedOnSize)

            if let primary {
                CYPillButton(primary.title, tableName: primary.tableName, action: primary.action)
                    .disabled(!primary.isEnabled)
                    .padding(.horizontal, CYSpacing.lg)
                    .padding(.top, CYSpacing.sm)
                    .padding(.bottom, CYSpacing.lg)
                    .background(heightReader { chromeBottom = $0 })
            }
        }
        .environment(\.cyPillOnSheet, true)
        .presentationDetents(Set(detents), selection: $selection)
        .presentationContentInteraction(.resizes)
        .presentationDragIndicator(.visible)
        .modifier(CYSheetBackgroundInteraction(mapInteractive: kind.mapInteractive))
        .interactiveDismissDisabled(isDirty)
        .animation(CYMotion.resolve(CYMotion.sheetDetent, reduceMotion: reduceMotion), value: fitHeight)
        .animation(CYMotion.resolve(CYMotion.sheetDetent, reduceMotion: reduceMotion), value: selection)
        .cyHaptic(.selection, trigger: settleTick)
        .onChange(of: fitHeight) { old, new in
            // Keep the sheet on its fit detent while the content grows or shrinks (checks resolving, an error row).
            guard resolvedSizes.contains(.fit), selection == .height(old) else { return }
            programmatic = true
            selection = .height(new)
        }
        .onChange(of: selection) { _, _ in
            // `.selection` only when a drag settles on a new detent; programmatic growth is silent.
            if programmatic { programmatic = false } else { settleTick += 1 }
        }
        .confirmationDialog(Text("sheet.discard.title", tableName: "DesignR1"), isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { finishClose() } label: { Text("sheet.discard.confirm", tableName: "DesignR1") }
            Button(role: .cancel) {} label: { Text("sheet.discard.keep", tableName: "DesignR1") }
        }
        .roleThemedPresentation()
    }

    private func close() {
        if isDirty { confirmsDiscard = true } else { finishClose() }
    }

    private func finishClose() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func heightReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, height in update(height) }
        }
    }
}

/// Map sheets leave the map interactive up through `.medium` and draw no scrim; editor sheets keep it disabled.
private struct CYSheetBackgroundInteraction: ViewModifier {
    let mapInteractive: Bool
    func body(content: Content) -> some View {
        if mapInteractive {
            content.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            content.presentationBackgroundInteraction(.disabled)
        }
    }
}

extension View {
    /// Presents a `CYResizableSheet` with the detents of `kind` (hand-off §3).
    func cyResizableSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        kind: CYSheetKind,
        title: Text? = nil,
        headerStyle: CYSheetHeaderStyle = .automatic,
        isDirty: Bool = false,
        primary: CYSheetPrimary? = nil,
        onDone: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            CYResizableSheet(
                kind: kind,
                title: title,
                headerStyle: headerStyle,
                isDirty: isDirty,
                primary: primary,
                onDone: onDone,
                content: content
            )
        }
    }
}

// MARK: - Hold to start (PL-03, PL-42)

/// 52 pt white primary that starts after a 0.8 s hold. A ring fills around the pill while it is held and unwinds in
/// 200 ms when released early. VoiceOver: a double tap starts (the hold is not an accessible gesture).
/// Haptics: `.success` on start, `.impactLight` on an early release.
struct CYHoldToStartButton: View {
    let title: LocalizedStringKey
    let tableName: String?
    let systemImage: String?
    let onStart: () -> Void
    /// The line under the button. Defaults to the 按住开始 hint; a page whose button already says 按住开始 passes its own
    /// reassurance line (verify-r1 2.4 / N-13).
    let caption: LocalizedStringKey
    /// The VoiceOver action name. Defaults to the title.
    let accessibilityTitle: LocalizedStringKey?

    static let holdDuration: Double = 0.8

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @State private var progress: CGFloat = 0
    @State private var committed = false
    @State private var startTick = 0
    @State private var cancelTick = 0
    /// A tap (released before the hold completes) is not silent: the ring nudges and the caption says what to do.
    @State private var showsTapNudge = false
    @State private var nudgeTask: Task<Void, Never>?
    @QuestifyReduceMotion private var reduceMotion

    init(_ title: LocalizedStringKey, tableName: String? = nil, systemImage: String? = nil,
         caption: LocalizedStringKey = "roam.go.hint.hold", accessibilityTitle: LocalizedStringKey? = nil,
         onStart: @escaping () -> Void) {
        self.title = title
        self.tableName = tableName
        self.systemImage = systemImage
        self.caption = caption
        self.accessibilityTitle = accessibilityTitle
        self.onStart = onStart
    }

    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            pill
            Text(showsTapNudge ? "mp.hold.tapNudge" : caption)
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityHidden(true)
        }
        .cyHaptic(.success, trigger: startTick)
        .cyHaptic(.impactLight, trigger: cancelTick)
    }

    private var pill: some View {
        let shape = Capsule(style: .continuous)
        return HStack(spacing: CYSpacing.sm) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title, tableName: tableName)
        }
        .font(CYPillButtonStyle.labelFont)
        .foregroundStyle(isEnabled ? palette.actionPrimaryFg : palette.textPlaceholder)
        .padding(.horizontal, CYSpacing.xxl)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(shape.fill(isEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle))
        .overlay {
            shape.inset(by: -4)
                .trim(from: 0, to: progress)
                .stroke(palette.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .accessibilityHidden(true)
        }
        .scaleEffect(progress > 0 && !committed ? 0.97 : 1)
        .contentShape(shape)
        .onLongPressGesture(minimumDuration: Self.holdDuration, perform: commit) { pressing in
            guard isEnabled, !committed else { return }
            if pressing {
                withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
                cancelTick += 1
                nudge()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityTitle ?? title, tableName: tableName))
        .accessibilityHint(Text("roam.go.hint.hold"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
    }

    /// 200 ms ring nudge, then the caption reads 按住 1 秒开始 for 2 s. Reduce Motion: caption only.
    private func nudge() {
        nudgeTask?.cancel()
        nudgeTask = Task { @MainActor in
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.1)) { progress = 0.12 }
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeIn(duration: 0.1)) { progress = 0 }
            }
            withAnimation(CYMotion.resolve(.easeInOut(duration: 0.2), reduceMotion: reduceMotion)) { showsTapNudge = true }
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            withAnimation(CYMotion.resolve(.easeInOut(duration: 0.2), reduceMotion: reduceMotion)) { showsTapNudge = false }
        }
    }

    private func commit() {
        guard isEnabled, !committed else { return }
        nudgeTask?.cancel(); showsTapNudge = false
        committed = true
        progress = 1
        startTick += 1
        onStart()
        // Back to rest after the start so the control can be used again if the start is refused.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            committed = false
            progress = 0
        }
    }
}

// MARK: - Level-up moment (PL-45, PL-13)

/// One level change, from the last level this screen saw to the new one.
struct CYLevelUpPayload: Identifiable, Equatable {
    let from: Int
    let to: Int
    var id: Int { to }
}

/// Full-screen level-up (N68): the icon rises, the level rolls from the old value to the new one (600 ms), one primary.
/// Tap anywhere skips to the end state. Reduce Motion: a cross-fade, no rise. Haptics are played by the caller.
struct CYLevelUpMoment: View {
    let payload: CYLevelUpPayload
    let onDone: () -> Void

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false
    @State private var level: Int

    init(payload: CYLevelUpPayload, onDone: @escaping () -> Void) {
        self.payload = payload
        self.onDone = onDone
        _level = State(initialValue: payload.from)
    }

    var body: some View {
        VStack(spacing: CYSpacing.xl) {
            Spacer(minLength: CYSpacing.xxxl)
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.largeTitle.weight(.semibold))
                .imageScale(.large)
                .foregroundStyle(palette.textPrimary)
                .offset(y: shown || reduceMotion ? 0 : 40)
                .opacity(shown ? 1 : 0)
                .accessibilityHidden(true)
            Text(verbatim: "Lv\(level)")
                .cyText(.dataXL)
                .foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText(value: Double(level)))
            Text("levelUp.title", tableName: "DesignR1")
                .cyText(.sheetTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("levelUp.change \(payload.from) \(payload.to)", tableName: "DesignR1")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            Spacer()
            CYPillButton("sheet.done", size: .moment, tableName: "DesignR1", action: onDone)
                .accessibilityIdentifier("levelUp.done")
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.bottom, CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgPage.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { finish(animated: false) }
        .onAppear { finish(animated: !reduceMotion) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("levelUp.moment")
    }

    private func finish(animated: Bool) {
        if animated {
            withAnimation(CYMotion.entrance) { shown = true }
            withAnimation(.easeOut(duration: CYMotion.Duration.slow).delay(0.2)) { level = payload.to }
        } else {
            withAnimation(CYMotion.reduced) { shown = true; level = payload.to }
        }
    }
}

// MARK: - Previews

private struct CYPlayerKitPreviewBody: View {
    @State private var showsSheet = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    CYRootSubtitle(verbatim: "小城，今天去哪")
                    HStack(spacing: CYSpacing.sm) {
                        CYStatusTag(.locating)
                        CYStatusTag(.recording)
                        CYStatusTag(.paused)
                    }
                    CYPillButton(verbatim: "开始", action: {})
                    CYPillButton(verbatim: "看排行榜", style: .secondary, action: {})
                    CYPillButton(verbatim: "以后再说", style: .tertiary, action: {})
                }
                .padding(CYSpacing.pageHorizontal)
            }
            .cyRootHeader(.home)
            .cyResizableSheet(isPresented: $showsSheet, kind: .hint, title: Text(verbatim: "要点提示吗")) {
                Text(verbatim: "方向提示 · 免费")
            }
        }
        .cyDomainPageBackground()
    }
}
#Preview("Player kit · dark") { CYPlayerKitPreviewBody().themeDomain(.player) }
