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

/// Two paper cards fanned behind a glowing medallion, a corner badge and sparkles. 132pt design size, scales with `size`.
struct CYStateArt: View {
    let kind: CYStateKind
    var size: CGFloat = 132
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        if let illustration = CYEmptyIllustration.kind(matching: kind == .orders ? "ticket" : kind.symbol) {
            CYEmptyIllustration(kind: illustration, size: size)
        } else {
            illustrated
        }
    }

    @ViewBuilder
    private var illustrated: some View {
        let hue = kind.hue
        let sat = kind.muted ? 0.12 : 0.62
        let top = Color(hue: hue, saturation: sat, brightness: kind.muted ? 0.62 : 0.86)
        let bottom = Color(hue: (hue + 0.06).truncatingRemainder(dividingBy: 1), saturation: min(1, sat + 0.2), brightness: kind.muted ? 0.30 : 0.42)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [top.opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: size * 0.72))
                .frame(width: size * 1.5, height: size * 1.5)
            RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                .fill(palette.bgRaised)
                .overlay(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1))
                .frame(width: size * 0.66, height: size * 0.76)
                .rotationEffect(.degrees(-10))
                .offset(x: -size * 0.10, y: size * 0.02)
            RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                .fill(LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .overlay(
                    Image(systemName: kind.symbol)
                        .font(.system(size: size * 0.30, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                )
                .frame(width: size * 0.66, height: size * 0.76)
                .rotationEffect(.degrees(6))
                .offset(x: size * 0.06, y: -size * 0.02)
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            if let accessory = kind.accessory {
                Image(systemName: accessory)
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundStyle(palette.textInverse)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .background(Circle().fill(palette.brand))
                    .overlay(Circle().strokeBorder(palette.bgPage, lineWidth: 3))
                    .offset(x: size * 0.30, y: size * 0.30)
            }
            Image(systemName: "sparkle").font(.system(size: size * 0.11)).foregroundStyle(top.opacity(0.9)).offset(x: -size * 0.40, y: -size * 0.34)
            Image(systemName: "sparkle").font(.system(size: size * 0.07)).foregroundStyle(top.opacity(0.7)).offset(x: size * 0.38, y: -size * 0.40)
            Circle().fill(top.opacity(0.55)).frame(width: size * 0.05, height: size * 0.05).offset(x: -size * 0.44, y: size * 0.18)
        }
        .frame(width: size * 1.2, height: size * 1.1)
        .offset(y: floating && !reduceMotion ? -3 : 3)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: floating)
        .onAppear { floating = true }
        .accessibilityHidden(true)
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
        VStack(spacing: CYSpacing.md) {
            Group {
                if let emptyIllustration {
                    CYEmptyIllustration(kind: emptyIllustration, size: artSize)
                } else {
                    CYStateArt(kind: kind, size: artSize)
                }
            }
                .padding(.bottom, CYSpacing.xs)
            title
                .cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                detail
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let primary {
                CYPillButton(primary.title, style: primaryStyle, fullWidth: false, action: primary.action)
                    .padding(.top, CYSpacing.sm)
                    .ifLet(primaryIdentifier) { $0.accessibilityIdentifier($1) }
            } else if let primaryVerbatim {
                CYPillButton(verbatim: primaryVerbatim.title, style: primaryStyle, fullWidth: false, action: primaryVerbatim.action)
                    .padding(.top, CYSpacing.sm)
                    .ifLet(primaryIdentifier) { $0.accessibilityIdentifier($1) }
            }
            if let secondaryVerbatim {
                CYPillButton(verbatim: secondaryVerbatim.title, style: .tertiary, fullWidth: false, action: secondaryVerbatim.action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.xxl)
        .padding(.horizontal, CYSpacing.xxl)
        .accessibilityElement(children: .contain)
    }
}

extension View {
    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, _ transform: (Self, T) -> Content) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

// MARK: - Offline

/// Offline / stale strip: a quiet capsule above cached content, not an alert.
struct CYOfflineStrip: View {
    var onRetry: (() -> Void)? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let t = CYKitCopy(locale: locale)
        Group {
            if dynamicTypeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    stripLabel(t)
                    stripRetry(t)
                }
            } else {
                HStack(spacing: CYSpacing.sm) {
                    stripLabel(t)
                    Spacer(minLength: 0)
                    stripRetry(t)
                }
            }
        }
        .foregroundStyle(palette.textPrimary)
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.sm)
        .background(
            RoundedRectangle(
                cornerRadius: dynamicTypeSize >= .xxLarge ? CYRadius.lg : CYRadius.pill,
                style: .continuous
            )
            .fill(palette.bgRaised)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: dynamicTypeSize >= .xxLarge ? CYRadius.lg : CYRadius.pill,
                style: .continuous
            )
            .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func stripLabel(_ t: CYKitCopy) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: "wifi.slash").font(.footnote.weight(.semibold))
            Text(verbatim: appLocalized("cy.kit.offline.saved", locale: t.resourceLocale))
                .cyText(.meta)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func stripRetry(_ t: CYKitCopy) -> some View {
        if let onRetry {
            Button(action: onRetry) {
                Text(verbatim: appLocalized("cy.kit.offline.retry", locale: t.resourceLocale))
                    .cyText(.meta, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
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
    @Environment(\.cyPalette) private var palette
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
                        .cyText(.pageTitle)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: kind.benefit(t))
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
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
            .background(palette.bgPage)
        }
        .cyDomainPageBackground()
    }
}

/// In-place card for a permission that was declined: says what is lost, offers Settings once. Replaces ad-hoc captions.
struct CYPermissionDeniedCard: View {
    let kind: CYPermissionKind
    let onOpenSettings: () -> Void
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale

    var body: some View {
        let t = CYKitCopy(locale: locale)
        VStack(spacing: CYSpacing.md) {
            CYStateArt(kind: kind.artKind, size: 96)
            Text(verbatim: kind == .location ? t("Location is off", "定位没开") : t("Camera is off", "相机没开"))
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
            Text(verbatim: kind == .location
                 ? t("Turn it on in Settings to roam and collect nearby stamps.", "在“设置”中开启后，即可漫游并收集附近的印章。")
                 : t("Turn it on in Settings to take stamp photos.", "在“设置”中开启后，即可拍摄印章照片。"))
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            CYPillButton(verbatim: t("Open Settings", "打开设置"), style: .secondary, fullWidth: false, action: onOpenSettings)
        }
        .frame(maxWidth: .infinity)
        .padding(CYSpacing.lg)
    }
}
