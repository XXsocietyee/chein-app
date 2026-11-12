import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// CYPermissionPrimer: the card shown before a system location, camera, or notification prompt,
// and the denied-state card with Open Settings. Presentation only: it never asks the OS for anything.
// Location copy is the draft in docs/roam-fog/location-permission-copy.md. The host decides when to continue.

enum CYPermissionPromptKind: String, Equatable {
    case location, camera, notification
}

// MARK: - Content

struct CYPermissionPrimerContent: Equatable {
    var glyph: String
    var title: String
    var body: String
    var points: [String]
    var primaryTitle: String
    var secondaryTitle: String

    var allStrings: [String] { [title, body, primaryTitle, secondaryTitle] + points }

    /// Before the system prompt. The body is the owner-pending usage sentence, so the card and the OS prompt say one thing.
    static func locationPriming(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "location.fill",
            title: c("Light up where you walk", "点亮你走过的地方"),
            body: c("Chengyin uses your location while the app is open to light up the places you walk and show what is nearby. It never runs in the background.",
                    "城瘾仅在你使用时获取位置，用来点亮你走过的地方并显示附近内容，不会在后台定位。"),
            points: [
                c("Only while the app is open", "仅在使用 App 时"),
                c("Never in the background", "不会在后台定位"),
                c("You can turn it off anytime in Settings", "随时可在设置里关闭"),
            ],
            primaryTitle: c("Continue", "继续"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    /// After the OS said no. Roam keeps working from a chosen search area, so the card says what is lost, not a dead end.
    static func locationDenied(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "location.slash",
            title: c("Location is off", "定位已关闭"),
            body: c("Turn it on in Settings to light up the places you walk. You can still look around a place you pick.",
                    "在设置里打开定位，才能点亮你走过的地方。你仍然可以浏览自己选的地点。"),
            points: [],
            primaryTitle: c("Open Settings", "打开设置"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func cameraPriming(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "camera.fill",
            title: c("Camera for this moment", "相机只用于这一刻"),
            body: c("Chengyin uses the camera when you take a stamp photo, scan a code, or frame a play moment. It does not record in the background.",
                    "城瘾只在你拍摄印章、扫描二维码或完成玩法取景时使用相机，不会在后台录制。"),
            points: [
                c("Only when you choose to capture", "仅在你选择拍摄或扫码时"),
                c("Nothing is recorded in the background", "不会在后台录制"),
                c("You can turn it off anytime in Settings", "随时可在设置里关闭"),
            ],
            primaryTitle: c("Continue", "继续"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func cameraDenied(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "camera.fill",
            title: c("Camera is off", "相机已关闭"),
            body: c("Turn it on in Settings to take stamp photos and scan codes.",
                    "在设置里打开相机，才能拍摄印章和扫码。"),
            points: [],
            primaryTitle: c("Open Settings", "打开设置"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func notificationPriming(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "bell.badge",
            title: c("Reminders you turn on", "只提醒你打开的事项"),
            body: c("Chengyin asks to send alerts and sounds for reminders you turn on, such as a play window. It does not send marketing alerts.",
                    "城瘾会申请发送提醒和声音，用于你打开的事项，例如玩法时间窗。不会发送营销通知。"),
            points: [
                c("Only for reminders you turn on", "仅用于你打开的提醒"),
                c("No marketing alerts", "不会发送营销通知"),
                c("You can turn it off anytime in Settings", "随时可在设置里关闭"),
            ],
            primaryTitle: c("Continue", "继续"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func notificationDenied(locale: Locale) -> CYPermissionPrimerContent {
        let c = CYKitCopy(locale: locale)
        return CYPermissionPrimerContent(
            glyph: "bell.slash",
            title: c("Notifications are off", "通知已关闭"),
            body: c("Turn them on in Settings to receive the reminders you asked for.",
                    "在设置里打开通知，才能收到你要求的提醒。"),
            points: [],
            primaryTitle: c("Open Settings", "打开设置"),
            secondaryTitle: c("Not now", "以后再说")
        )
    }

    static func content(for step: RoamLocationPrimerStep, locale: Locale) -> CYPermissionPrimerContent {
        content(for: .location, denied: step == .denied, locale: locale)
    }

    static func content(for kind: CYPermissionPromptKind, denied: Bool, locale: Locale) -> CYPermissionPrimerContent {
        switch kind {
        case .location: denied ? .locationDenied(locale: locale) : .locationPriming(locale: locale)
        case .camera: denied ? .cameraDenied(locale: locale) : .cameraPriming(locale: locale)
        case .notification: denied ? .notificationDenied(locale: locale) : .notificationPriming(locale: locale)
        }
    }
}

// MARK: - View

struct CYPermissionPrimer: View {
    let step: RoamLocationPrimerStep
    let kind: CYPermissionPromptKind
    private let legacyIdentifier: Bool
    let content: CYPermissionPrimerContent
    var onPrimary: () -> Void
    var onSecondary: () -> Void
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .title2) private var glyphSize: CGFloat = 36

    init(step: RoamLocationPrimerStep, locale: Locale, onPrimary: @escaping () -> Void, onSecondary: @escaping () -> Void) {
        self.step = step
        self.kind = .location
        self.legacyIdentifier = true
        self.content = .content(for: step, locale: locale)
        self.onPrimary = onPrimary; self.onSecondary = onSecondary
    }

    init(kind: CYPermissionPromptKind, denied: Bool = false, locale: Locale, onPrimary: @escaping () -> Void, onSecondary: @escaping () -> Void) {
        self.step = denied ? .denied : .priming
        self.kind = kind
        self.legacyIdentifier = false
        self.content = .content(for: kind, denied: denied, locale: locale)
        self.onPrimary = onPrimary; self.onSecondary = onSecondary
    }

    private var identifierKind: String {
        let phase = step == .priming ? "priming" : "denied"
        return legacyIdentifier ? phase : kind.rawValue + "." + phase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Image(systemName: content.glyph)
                .font(.system(size: glyphSize, weight: .regular))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
            Text(verbatim: content.title)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: content.body)
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !content.points.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(content.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            Image(systemName: "checkmark").font(CYTypography.meta).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                            Text(verbatim: point).font(CYTypography.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            VStack(spacing: CYSpacing.xs) {
                CYPillButton(verbatim: content.primaryTitle, style: .primary, fullWidth: true, action: onPrimary)
                    .accessibilityIdentifier("cy.permission.\(identifierKind).primary")
                CYPillButton(verbatim: content.secondaryTitle, style: .tertiary, fullWidth: true, action: onSecondary)
                    .accessibilityIdentifier("cy.permission.\(identifierKind).secondary")
            }
            .padding(.top, CYSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.xl)
        .background(palette.cardFill, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cy.permission.\(identifierKind)")
    }
}

/// Full-screen primer. Dark player ground, one card, Continue or Not now.
struct CYPermissionPrimerScreen: View {
    let kind: CYPermissionPromptKind
    var onPrimary: () -> Void
    var onSecondary: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        CYPermissionPrimer(kind: kind, locale: locale, onPrimary: onPrimary, onSecondary: onSecondary)
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
            .themeDomain(.player)
            .preferredColorScheme(.dark)
            .accessibilityIdentifier("cy.permission.screen." + kind.rawValue)
    }
}

extension CYPermissionPrimer {
    /// The denied card's primary action: the app's own Settings page. Hosts pass `@Environment(\.openURL)`.
    static func openSettings(using openURL: OpenURLAction) {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// Shows `CYPermissionPrimerScreen` before a system prompt. A declined primer must not reach the OS.
/// The XCTest host cannot tap the screen, so it skips straight to the existing request.
@MainActor
enum CYPermissionSystemPrompt {
    private static var primed = Set<CYPermissionPromptKind>()

    static func notePrimed(_ kind: CYPermissionPromptKind) { primed.insert(kind) }

    static func precede(_ kind: CYPermissionPromptKind) async -> Bool {
        if primed.contains(kind) { return true }
        if suppressesInterface { return true }
        #if canImport(UIKit)
        let allowed = await CYPermissionPrimerWindow.shared.present(kind)
        if allowed { primed.insert(kind) }
        return allowed
        #else
        return true
        #endif
    }

    private static var suppressesInterface: Bool {
        let info = ProcessInfo.processInfo
        if info.environment["XCTestConfigurationFilePath"] != nil { return true }
        if info.environment["XCTestBundlePath"] != nil { return true }
        if info.environment["XCTestSessionIdentifier"] != nil { return true }
        return info.arguments.contains("-XCTest")
    }
}

#if canImport(UIKit)
@MainActor
final class CYPermissionPrimerWindow {
    static let shared = CYPermissionPrimerWindow()
    private var window: UIWindow?
    private var host: UIHostingController<AnyView>?
    private var current: CheckedContinuation<Bool, Never>?
    private var queue: [(CYPermissionPromptKind, CheckedContinuation<Bool, Never>)] = []

    func present(_ kind: CYPermissionPromptKind) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.append((kind, continuation))
            drain()
        }
    }

    private func drain() {
        guard current == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            next.1.resume(returning: true)
            drain()
            return
        }
        current = next.1
        let screen = CYPermissionPrimerScreen(kind: next.0, onPrimary: { [weak self] in self?.finish(true) }, onSecondary: { [weak self] in self?.finish(false) })
        let controller = UIHostingController(rootView: AnyView(screen))
        controller.view.backgroundColor = .black
        controller.overrideUserInterfaceStyle = .dark
        controller.view.accessibilityViewIsModal = true
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.windowLevel = .alert + 1
        window.backgroundColor = .black
        // No transition. Reduce Motion and the ordinary path both appear at once.
        window.isHidden = false
        self.window = window
        self.host = controller
    }

    private func finish(_ allowed: Bool) {
        guard let continuation = current else { return }
        current = nil
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        host = nil
        continuation.resume(returning: allowed)
        drain()
    }
}
#endif

#Preview("Permission · priming") {
    CYPermissionPrimer(step: .priming, locale: Locale(identifier: "en"), onPrimary: {}, onSecondary: {})
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("Permission · denied zh") {
    CYPermissionPrimer(step: .denied, locale: Locale(identifier: "zh-Hans"), onPrimary: {}, onSecondary: {})
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("Permission · camera") {
    CYPermissionPrimerScreen(kind: .camera, onPrimary: {}, onSecondary: {})
}
#Preview("Permission · notification zh") {
    CYPermissionPrimerScreen(kind: .notification, onPrimary: {}, onSecondary: {})
        .environment(\.locale, Locale(identifier: "zh-Hans"))
}
