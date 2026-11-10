import SwiftUI

@MainActor struct CityNeutralTaskResultRecoveryView: View {
    @State var controller: CityNeutralTaskResultRecoveryController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private let table = "CityNeutralTaskResultRecovery"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("cityNeutralResult.title", subtitle: "cityNeutralResult.boundary", tableName: table)
                CYNoteBanner(text: keyed(controller.messageKey), symbol: controller.busy ? "hourglass" : "info.circle")
                if controller.busy {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: ChannelCopy.text("正在读取", "Loading", locale: locale)))
                }
                if controller.current, scenePhase == .active {
                    CYFactRow(label: Text("cityNeutralResult.request", tableName: table), value: cloud06Shown(controller.requestID.uuidString))
                }
                if controller.current, scenePhase == .active, let task = controller.task {
                    taskCard(task)
                }
                CYPillButton("cityNeutralResult.refresh", style: .primary, systemImage: "arrow.clockwise", tableName: table) {
                    Task { await controller.load() }
                }
                .disabled(controller.busy || !controller.current)
                .accessibilityLabel(Text("cityNeutralResult.refresh", tableName: table))
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
        .roleTheme(.player)
        .accessibilityIdentifier("cityNeutral.result.screen")
        .task { await controller.load() }
        .onDisappear { controller.invalidate() }
        .onChange(of: controller.current) { _, current in if !current { controller.invalidate() } }
        .onChange(of: scenePhase) { _, phase in
            controller.invalidate()
            if phase == .active { Task { await controller.load() } }
        }
    }
    private func keyed(_ key: String) -> Text {
        cloud06Phrase(key, table: table, locale: locale) == "—" ? Text(verbatim: "—") : Text(LocalizedStringKey(key), tableName: table)
    }
    private func statusText(_ status: String) -> Text {
        switch status {
        case "ACTIVE": return Text("cityNeutralResult.status.ACTIVE", tableName: table)
        case "PASSED": return Text("cityNeutralResult.status.PASSED", tableName: table)
        case "EXHAUSTED": return Text("cityNeutralResult.status.EXHAUSTED", tableName: table)
        default: return Text(verbatim: "—")
        }
    }
    private func statusTone(_ status: String) -> CYStatusTone {
        switch status {
        case "PASSED": return .success
        case "EXHAUSTED": return .warning
        case "ACTIVE": return .info
        default: return .neutral
        }
    }
    @ViewBuilder private func taskCard(_ task: CityNeutralTask) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYImageCard(verbatim: cloud06Shown(task.definition.title), fallback: "—", style: .hero)
            CYNoteBanner(text: statusText(task.status), symbol: "checklist", tone: statusTone(task.status))
            CYFactRow(label: Text("cityNeutralResult.task", tableName: table), value: cloud06Shown(task.id))
            CYFactRow(label: Text("cityNeutralResult.instance", tableName: table), value: task.instanceId.map(cloud06Shown) ?? "—")
            CYFactRow(label: Text("cityNeutralResult.attempts", tableName: table), value: "\(task.attempts) / \(task.definition.maxAttempts)")
            CYNoteBanner(text: Text("cityNeutralResult.zeroEffects", tableName: table), symbol: "circle.slash")
            if let result = task.result {
                CYFactRow(label: Text("cityNeutralResult.result", tableName: table), value: cloud06Shown(result.resultId))
                CYFactRow(label: Text("cityNeutralResult.completedAt", tableName: table), value: cloud06Shown(result.createdAt))
            }
        }
    }
}

private func cloud06Phrase(_ key: String, table: String, locale: Locale) -> String {
    let value = String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: table, locale: locale))
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == key { return "—" }
    return trimmed
}

private func cloud06Shown(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "—" : trimmed
}
