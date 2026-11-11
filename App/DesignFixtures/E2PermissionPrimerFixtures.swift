#if DEBUG
import SwiftUI

/// Location priming and denied cards, offline and DEBUG only; mounted nowhere live.
/// `--design-fixture permission-primer | permission-primer-denied`, each with an optional `-zh` suffix.
enum E2PermissionPrimerFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        let zh = name.hasSuffix("-zh")
        let base = zh ? String(name.dropLast(3)) : name
        let locale = Locale(identifier: zh ? "zh-Hans" : "en")
        switch base {
        case "permission-primer": return wrap(E2PermissionPrimerLab(step: .priming), locale)
        case "permission-primer-denied": return wrap(E2PermissionPrimerLab(step: .denied), locale)
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V, _ locale: Locale) -> AnyView {
        AnyView(view.environment(\.locale, locale).themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
    }
}

private struct E2PermissionPrimerLab: View {
    let step: RoamLocationPrimerStep
    @Environment(\.locale) private var locale
    @State private var lastAction = "none"

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Spacer()
            CYPermissionPrimer(step: step, locale: locale, onPrimary: { lastAction = "primary" }, onSecondary: { lastAction = "secondary" })
            Text(verbatim: "Offline example · last tap: \(lastAction)").font(CYTypography.meta).foregroundStyle(.secondary)
                .accessibilityIdentifier("e2.permission.lastAction")
            Spacer()
        }
        .padding(CYSpacing.pageHorizontal)
    }
}
#endif
