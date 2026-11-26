import SwiftUI

// System-state kit (e5c): generated state art, illustrated empty/error/offline layouts, permission priming.
// Presentation only. Art is drawn in SwiftUI (no asset files), tinted from a per-kind hue (never violet),
// decorative (hidden from VoiceOver) and floats gently unless Reduce Motion is on.

/// Bilingual copy for kit defaults that have no string-catalog key yet (keeps callers free of table lookups).
struct CYKitCopy {
    let locale: Locale
    func callAsFunction(_ en: String, _ zh: String) -> String {
        AppLanguage.interfaceIsChinese(locale) ? zh : en
    }

    /// Catalog lookup locale. Explicit zh-Hans / en so a region locale cannot skip the translation.
    var resourceLocale: Locale { AppLanguage.interfaceIsChinese(locale) ? Locale(identifier: "zh-Hans") : Locale(identifier: "en") }
}

// MARK: - Kind

enum CYStateKind: Equatable {
    /// Alias used by restyled screens for a plain empty state.
    static var empty: CYStateKind { .generic }
    case generic, inbox, orders, favorites, notices, search, projects, offline, failure
    case location, camera, notifications, photos

    /// Maps the SF Symbol legacy callers already pass to a themed art kind.
    init(symbol: String) {
        switch symbol {
        case "bubble.left.and.bubble.right", "bubble.left", "message", "envelope": self = .inbox
        case "ticket", "doc.text", "bag", "cart", "creditcard": self = .orders
        case "heart", "bookmark", "star": self = .favorites
        case "bell", "bell.slash", "megaphone": self = .notices
        case "magnifyingglass": self = .search
        case "folder", "square.stack", "hammer": self = .projects
        case "wifi.slash", "icloud.slash": self = .offline
        case "exclamationmark.triangle", "exclamationmark.circle": self = .failure
        case "location", "location.slash", "map": self = .location
        case "camera", "camera.fill": self = .camera
        default: self = .generic
        }
    }

    var symbol: String {
        switch self {
        case .generic: "tray"
        case .inbox: "bubble.left.and.bubble.right.fill"
        case .orders: "ticket.fill"
        case .favorites: "heart.fill"
        case .notices: "bell.fill"
        case .search: "magnifyingglass"
        case .projects: "square.stack.3d.up.fill"
        case .offline: "wifi.slash"
        case .failure: "exclamationmark"
        case .location: "location.fill"
        case .camera: "camera.fill"
        case .notifications: "bell.badge.fill"
        case .photos: "photo.on.rectangle.angled"
        }
    }

    /// Small round badge on the art's corner (action hint).
    var accessory: String? {
        switch self {
        case .inbox: "plus"
        case .orders: "sparkles"
        case .favorites: "plus"
        case .notices: "checkmark"
        case .search: "questionmark"
        case .projects: "plus"
        case .offline: "arrow.clockwise"
        case .failure: "arrow.clockwise"
        case .location: "mappin"
        case .camera: "sparkles"
        case .notifications: "xmark"
        case .photos: "plus"
        case .generic: nil
        }
    }

    /// Hue 0...1. Warm/teal/blue families; violet (0.72...0.78) is reserved for the selected tab.
    var hue: Double {
        switch self {
        case .generic: 0.58
        case .inbox: 0.54
        case .orders: 0.08
        case .favorites: 0.97
        case .notices: 0.12
        case .search: 0.50
        case .projects: 0.40
        case .offline: 0.60
        case .failure: 0.03
        case .location: 0.45
        case .camera: 0.07
        case .notifications: 0.60
        case .photos: 0.33
        }
    }

    var muted: Bool { self == .offline }
}

// MARK: - Art

/// Native r2: no drawn art. The mini-program illustration when one exists (`MPAsset`), otherwise the plain
/// SF Symbol the system `ContentUnavailableView` would show. No glow, cards, sparkles or float motion.
struct CYStateArt: View {
    let kind: CYStateKind
    var size: CGFloat = 132

    var body: some View {
        if let illustration = CYEmptyIllustration.kind(matching: kind == .orders ? "ticket" : kind.symbol) {
            CYEmptyIllustration(kind: illustration, size: size)
        } else {
            Image(systemName: kind.symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Layout

/// Shared layout for illustrated states: art, title, one calm sentence, one primary action, optional quiet secondary.
struct CYStateLayout: View {
    let kind: CYStateKind
    let title: Text
    var detail: Text? = nil
    var primary: (title: LocalizedStringKey, action: () -> Void)? = nil
    var primaryVerbatim: (title: String, action: () -> Void)? = nil
    var primaryStyle: CYPillStyle = .secondary
    var secondaryVerbatim: (title: String, action: () -> Void)? = nil
    var primaryIdentifier: String? = nil
    var artSize: CGFloat = 132
    /// Set by `CYEmptyState` when the caller's symbol has a mini-program illustration (`sparkles` → no data).
    var emptyIllustration: CYEmptyIllustration.Kind? = nil
    @Environment(\.cyPalette) private var palette

    var body: some View {
        // Native iOS restyle r1: the system `ContentUnavailableView` (title, one sentence, one action).
        ContentUnavailableView {
            Label {
                title
            } icon: {
                if let emptyIllustration {
                    // MP empty-state figure (C7/Q4): the exact mini-program illustration.
                    CYEmptyIllustration(kind: emptyIllustration, size: artSize)
                } else {
                    Image(systemName: kind.symbol)
                }
            }
        } description: {
            if let detail { detail }
        } actions: {
            actions
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var actions: some View {
        if let primary {
            CYStateActionButton(style: primaryStyle, action: primary.action) { Text(primary.title) }
                .ifLet(primaryIdentifier) { $0.accessibilityIdentifier($1) }
        } else if let primaryVerbatim {
            CYStateActionButton(style: primaryStyle, action: primaryVerbatim.action) { Text(verbatim: primaryVerbatim.title) }
                .ifLet(primaryIdentifier) { $0.accessibilityIdentifier($1) }
        }
        if let secondaryVerbatim {
            CYStateActionButton(style: .tertiary, action: secondaryVerbatim.action) { Text(verbatim: secondaryVerbatim.title) }
        }
    }
}

/// The one state vocabulary (native restyle r1, spec §3.5) on the system `ContentUnavailableView`: empty, failed,
/// signed out, gated and offline. Use it for new code and in the R1-R5 sweeps; `CYEmptyState`, `CYErrorState`,
/// `CYStateLayout` and `CYStateView` already render through `ContentUnavailableView` too.
/// One action at most: `.borderedProminent` when it is the screen's next step, `.bordered` for 重试.
struct CYContentState: View {
    enum Kind: Equatable {
        case empty(String)
        case failed
        case signedOut
        case gated
        case offline

        var symbol: String {
            switch self {
            case .empty(let symbol): symbol
            case .failed: "exclamationmark.triangle"
            case .signedOut: "person.crop.circle.badge.questionmark"
            case .gated: "lock"
            case .offline: "wifi.slash"
            }
        }

        /// Retry is secondary; sign-in and a gate's next step are the screen's one primary.
        var actionStyle: CYPillStyle {
            switch self {
            case .failed, .offline: .secondary
            case .empty, .signedOut, .gated: .primary
            }
        }
    }

    let kind: Kind
    let title: LocalizedStringKey
    var description: LocalizedStringKey? = nil
    var descriptionVerbatim: String? = nil
    var action: (label: LocalizedStringKey, run: () -> Void)? = nil
    var actionIdentifier: String? = nil
    @Environment(\.cyPalette) private var palette

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: kind.symbol)
            }
        } description: {
            if let descriptionVerbatim {
                Text(verbatim: descriptionVerbatim)
            } else if let description {
                Text(description)
            }
        } actions: {
            if let action {
                CYStateActionButton(style: kind.actionStyle, action: action.run) { Text(action.label) }
                    .ifLet(actionIdentifier) { $0.accessibilityIdentifier($1) }
            }
        }
    }
}

/// System button for state actions: `.borderedProminent` for the screen's one primary, `.bordered` for a retry or
/// secondary, borderless for a quiet link. 44 pt minimum target.
struct CYStateActionButton<ButtonLabel: View>: View {
    let style: CYPillStyle
    let action: () -> Void
    @ViewBuilder let label: () -> ButtonLabel

    var body: some View {
        switch style {
        case .primary:
            Button(action: action, label: label)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .secondary:
            Button(action: action, label: label)
                .buttonStyle(.bordered)
                .controlSize(.large)
        case .tertiary:
            Button(action: action, label: label)
                .buttonStyle(.borderless)
                .controlSize(.large)
        }
    }
}

extension View {
    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, _ transform: (Self, T) -> Content) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

// MARK: - Offline

/// Offline / stale strip (native r2): a `Label(wifi.slash)` footnote and a borderless retry. No capsule chrome.
struct CYOfflineStrip: View {
    var onRetry: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        let t = CYKitCopy(locale: locale)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.sm) {
                stripLabel(t)
                Spacer(minLength: 0)
                stripRetry(t)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                stripLabel(t)
                stripRetry(t)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stripLabel(_ t: CYKitCopy) -> some View {
        Label {
            Text(verbatim: appLocalized("cy.kit.offline.saved", locale: t.resourceLocale))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func stripRetry(_ t: CYKitCopy) -> some View {
        if let onRetry {
            Button(action: onRetry) {
                Text(verbatim: appLocalized("cy.kit.offline.retry", locale: t.resourceLocale))
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
    }
}

// MARK: - Permission priming

enum CYPermissionKind: Equatable {
    case location, camera, notifications, photos

    var artKind: CYStateKind {
        switch self {
        case .location: .location
        case .camera: .camera
        case .notifications: .notifications
        case .photos: .photos
        }
    }

    /// Notifications are intentionally out of scope: the app sends no push, so there is nothing to allow.
    var isInformational: Bool { self == .notifications }

    func title(_ t: CYKitCopy) -> String {
        switch self {
        case .location: t("Turn on location. Walk, and it lights up.", "打开定位，走到哪，亮到哪")
        case .camera: t("Stamp the moment", "为这一刻盖章")
        case .notifications: t("No push notifications", "不会向你推送通知")
        case .photos: t("Add a photo to your stamp", "给印章配一张照片")
        }
    }

    func benefit(_ t: CYKitCopy) -> String {
        switch self {
        case .location: t("While you roam, we use your location to light up the map and find stamps nearby. Only while the app is open; you can turn it off anytime.", "漫游时，我们用你的位置点亮地图、找到附近的印章。仅在使用 App 时读取，随时可以关闭。")
        case .camera: t("Take a photo at the spot to collect its stamp. The photo stays on your phone until you choose to post it.", "在现场拍一张照片即可收集印章。照片在你选择发布之前只保存在手机里。")
        case .notifications: t("Reminders and replies wait for you in your inbox. We never push alerts to your lock screen.", "提醒和回复都会留在站内消息里，我们不会向锁屏推送任何通知。")
        case .photos: t("Pick a picture from your library to attach to a stamp or post. We only see the ones you choose.", "从相册里选一张图片添加到印章或帖子，我们只能看到你选中的照片。")
        }
    }

    func primary(_ t: CYKitCopy) -> String {
        switch self {
        case .location: t("Use my location", "允许使用位置")
        case .camera: t("Allow camera", "允许使用相机")
        case .notifications: t("Got it", "知道了")
        case .photos: t("Choose photos", "选择照片")
        }
    }

    func notNow(_ t: CYKitCopy) -> String {
        switch self {
        case .location: t("Not now", "以后再说")
        case .camera: t("Not now", "以后再说")
        case .notifications: t("Open my inbox", "查看站内消息")
        case .photos: t("Not now", "以后再说")
        }
    }
}

/// Calm, benefit-led pre-permission screen: art, one title, one benefit sentence, ONE primary action, a quiet "not now".
/// Shown before the system prompt so the person is never ambushed; declining is always free.
struct CYPermissionPriming: View {
    let kind: CYPermissionKind
    let onAllow: () -> Void
    let onNotNow: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let t = CYKitCopy(locale: locale)
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: CYSpacing.lg) {
                    Spacer(minLength: CYSpacing.xxl)
                    CYStateArt(kind: kind.artKind, size: typeSize.isAccessibilitySize ? 88 : 168)
                    Text(verbatim: kind.title(t))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: kind.benefit(t))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, CYSpacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: CYSpacing.xs) {
                CYPillButton(verbatim: kind.primary(t), style: .primary, action: onAllow)
                    .accessibilityIdentifier("permission.priming.allow")
                CYPillButton(verbatim: kind.notNow(t), style: .tertiary, action: onNotNow)
                    .accessibilityIdentifier("permission.priming.notNow")
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.top, CYSpacing.sm)
            .padding(.bottom, CYSpacing.md)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

/// In-place state for a permission that was declined (native r2): `ContentUnavailableView` with one Settings action.
struct CYPermissionDeniedCard: View {
    let kind: CYPermissionKind
    let onOpenSettings: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        let t = CYKitCopy(locale: locale)
        ContentUnavailableView {
            Label {
                Text(verbatim: kind == .location ? t("Location is off", "定位没开") : t("Camera is off", "相机没开"))
            } icon: {
                Image(systemName: kind == .location ? "location.slash" : "camera")
            }
        } description: {
            Text(verbatim: kind == .location
                 ? t("Turn it on in Settings to roam and collect nearby stamps.", "在“设置”中开启后，即可漫游并收集附近的印章。")
                 : t("Turn it on in Settings to take stamp photos.", "在“设置”中开启后，即可拍摄印章照片。"))
        } actions: {
            CYPillButton(verbatim: t("Open Settings", "打开设置"), style: .secondary, fullWidth: false, action: onOpenSettings)
        }
    }
}
