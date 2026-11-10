import SwiftUI

/// Explicit host only. No production factory/navigation registration is added.
/// revision must be the actual composition-viewer/permission revision captured by the owning AppSession factory.
@MainActor struct CityParticipationRuntimeHostView: View {
    @EnvironmentObject private var session: AppSession
    @Bindable var owner: CityParticipationRuntimeOwner
    let revision: UInt64
    private var showsForm: Bool {
        owner.isCurrent && owner.matches(session.currentRuntimeDependencyContext, revision: revision) && owner.form != nil
    }
    var body: some View {
        Group {
            if owner.isCurrent, owner.matches(session.currentRuntimeDependencyContext, revision: revision), let form = owner.form {
                CityParticipationFormView(model: form, identityVersion: revision).id(owner.id)
            } else {
                CityParticipationUnavailable()
            }
        }
        .themeDomain(.player)
        .cyAnimation(value: showsForm)
        .onChange(of: session.currentRuntimeDependencyContext) { _, context in
            if !owner.matches(context, revision: revision) { owner.retire() }
        }
        .onChange(of: revision) { _, value in
            if !owner.matches(session.currentRuntimeDependencyContext, revision: value) { owner.retire() }
        }
        .onDisappear { owner.retire() }
    }
}

/// Unavailable branch only. The form owns its own title; this state has exactly one, in the hero.
@MainActor private struct CityParticipationUnavailable: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader(
                    LocalizedStringKey("参与暂不可用"),
                    subtitle: LocalizedStringKey("请保留原请求记录。此入口不会重新提交。"),
                    titleIdentifier: "city.participation.unavailable"
                ) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.largeTitle)
                        .foregroundStyle(palette.textSecondary)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyDomainPageBackground()
    }
}
