import SwiftUI

/// CLB-topic-detail-06 (MP pages/club/topic-detail/index.wxml:503-530, index.js:1253-1281 `onSettingToggle`):
/// 开放商家承接 / 置顶在俱乐部主页 / 只对成员可见 are inline switches. Each change sends all three values to
/// `api/club/topic-setting/save` (the server rejects a missing one), the switches lock while saving, and a failed
/// save flips the switch back and shows the server sentence.
@MainActor struct ClubTopicSettingsInlineToggles: View {
    let value: ClubGovernanceValue
    let scope: ClubGovernanceScope
    let coordinator: ClubGovernanceCoordinator
    @State private var flags: [String: Bool] = [:]
    @State private var saving = false
    @State private var failureText: String?
    @State private var failureKey: LocalizedStringKey?

    private static let keys = ["coopOpen", "pinned", "memberOnly"]

    var body: some View {
        Section {
            toggle("coopOpen", "club.topicSetting.coopOpen")
            toggle("pinned", "club.topicSetting.pinned")
            toggle("memberOnly", "club.topicSetting.memberOnly")
        } footer: { footer }
        .onAppear { if !saving { flags = Self.flags(from: value) } }
        .onChange(of: value) { _, next in if !saving { flags = Self.flags(from: next) } }
    }

    @ViewBuilder private var footer: some View {
        if let failureText { Text(verbatim: failureText).foregroundStyle(.red) }
        else if let failureKey { Text(failureKey).foregroundStyle(.red) }
    }

    private func toggle(_ key: String, _ title: LocalizedStringKey) -> some View {
        Toggle(title, isOn: Binding(
            get: { flags[key] ?? false },
            set: { next in save(key, next) }))
            .disabled(saving)
            .accessibilityIdentifier("club.topicSetting." + key)
    }

    private static func flags(from value: ClubGovernanceValue) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for key in keys { result[key] = value[key].bool ?? false }
        return result
    }

    private func save(_ key: String, _ next: Bool) {
        guard !saving, flags[key] != next else { return }
        let before = flags
        var updated = flags
        updated[key] = next
        flags = updated
        saving = true; failureText = nil; failureKey = nil
        Task {
            defer { saving = false }
            do {
                var values: [String: ClubGovernanceValue] = [:]
                for name in Self.keys { values[name] = .bool(updated[name] ?? false) }
                let command = try ClubGovernanceCommand(operation: .saveTopicSettings, scope: scope, values: values)
                let review = try await coordinator.prepare(command)
                let result = try await coordinator.confirm(review)
                flags = Self.flags(from: result)
            } catch {
                // MP index.js:1271-1279: roll back; the server sentence, or 没能保存，请重试.
                flags = before
                if let failure = error as? ClubGovernanceFailure, let message = failure.message, !message.isEmpty {
                    failureText = message
                } else {
                    failureKey = "club.topicSetting.saveFailed"
                }
            }
        }
    }
}
