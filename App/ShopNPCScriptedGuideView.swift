import SwiftUI

@MainActor enum ShopNPCScriptedGuidePresentation {
    static func state(source: ShopNPCScriptedGuideSource, coordinator: ShopNPCCoordinator) -> ShopNPCScriptedGuideState? {
        guard coordinator.active, !coordinator.isSuspended else { return nil }
        return source.state(for: coordinator.scope)
    }
}
@MainActor struct ShopNPCScriptedGuideView: View {
    let source: ShopNPCScriptedGuideSource
    let coordinator: ShopNPCCoordinator
    let returnToNode: () -> Void
    @State private var expanded = false
    private var fallbackNeeded: Bool { !coordinator.grants.textAllowed || coordinator.failure != nil }
    var body: some View {
        if let state = ShopNPCScriptedGuidePresentation.state(source: source, coordinator: coordinator) {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if fallbackNeeded { Text("shopNPCGuide.fallback").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                DisclosureGroup("shopNPCGuide.title", isExpanded: $expanded) {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        switch state {
                        case .available(let guide):
                            Text("shopNPCGuide.source").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                            if let rules = guide.rules { Text(verbatim: rules).font(CYTypography.body).lineSpacing(4).textSelection(.enabled).accessibilityIdentifier("shopNPCGuide.rules") }
                            else { Text("shopNPCGuide.noRules").accessibilityIdentifier("shopNPCGuide.noRules") }
                            if let materials = guide.materials {
                                Text("shopNPCGuide.materials").font(CYTypography.cardTitle).accessibilityAddTraits(.isHeader)
                                Text(verbatim: materials).font(CYTypography.body).lineSpacing(4).textSelection(.enabled).accessibilityIdentifier("shopNPCGuide.materials")
                            }
                            Text("shopNPCGuide.noProgress").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        case .unavailable: Text("shopNPCGuide.unavailable").accessibilityIdentifier("shopNPCGuide.unavailable")
                        case .tooLarge: Text("shopNPCGuide.tooLarge").accessibilityIdentifier("shopNPCGuide.tooLarge")
                        }
                    }.padding(.top, CYSpacing.sm)
                }
                CYPillButton("shopNPCGuide.return", style: .secondary, systemImage: "arrow.uturn.backward") { returnToNode() }
                    .accessibilityIdentifier("shopNPCGuide.return")
            }
            .accessibilityIdentifier("shopNPCGuide.panel")
            .onAppear { expanded = fallbackNeeded }
            .onChange(of: fallbackNeeded) { _, needed in if needed { expanded = true } }
            .onChange(of: coordinator.active) { _, active in if !active { expanded = false } }
        }
    }
}
