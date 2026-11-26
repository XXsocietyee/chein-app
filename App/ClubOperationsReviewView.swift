import SwiftUI

struct ClubOperationsReviewView: View {
    let review: ClubOperationsReview
    let canSubmit: Bool
    let isExample: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var submitted = false
    var body: some View {
        Form {
            Section {
                if let club = review.snapshot.profile?.club {
                    LabeledContent("club.ops.club") { ClubName(value: club.name) }
                        .accessibilityIdentifier("club.ops.reviewSheet")
                } else {
                    Text("club.ops.newClub")
                        .font(.headline)
                        .accessibilityIdentifier("club.ops.reviewSheet")
                }
            }
            details
            Section {
                if canSubmit {
                    Button {
                        submitted = true
                        onConfirm()
                    } label: {
                        Text(LocalizedStringKey(isExample ? "club.ops.confirmFixture" : "club.ops.confirmLive"))
                    }
                    .disabled(submitted)
                    .accessibilityIdentifier("club.ops.confirm")
                    .cyHaptic(.impactMedium, trigger: submitted) { old, new in !old && new }
                } else {
                    Text("club.ops.writeGated")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                if canSubmit, isExample {
                    Text("club.ops.fixtureOnly")
                }
            }
        }
        .navigationTitle(Text("club.ops.review"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("club.ops.cancel", action: onCancel)
                    .disabled(submitted)
                    .accessibilityIdentifier("club.ops.cancelReview")
            }
        }
        // CLB-r10-nat-shared-01: Form draws the system grouped background; only the player domain tokens remain.
        .themeDomain(.player)
    }
    @ViewBuilder private var details: some View {
        switch review.command {
        case .create(let draft): profile(draft, original: nil)
        case .update(let draft, _): profile(draft, original: review.snapshot.profile)
        case .openSetting(let setting, let enabled, let previous):
            Section(LocalizedStringKey("club.ops." + setting.rawValue)) {
                LabeledContent("club.ops.current") { Text(previous ? "club.ops.enabled" : "club.ops.disabled") }
                LabeledContent("club.ops.requested") { Text(enabled ? "club.ops.enabled" : "club.ops.disabled") }
                Text(LocalizedStringKey("club.ops.settingConsequences." + setting.rawValue))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .memberRole(let id, let admin, _):
            Section("club.ops.memberRoles") {
                let name = review.snapshot.members.first { $0.id == id }?.trimmedNickname ?? "—"
                LabeledContent("club.ops.member") { Text(verbatim: name.isEmpty ? "—" : name) }
                Text(admin ? "club.ops.makeAdmin" : "club.ops.removeAdmin")
                Text("club.ops.roleConsequences")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    private func profile(_ draft: ClubOperationsDraft, original: ClubOperationsProfile?) -> some View {
        Section("club.ops.profile") {
            row("name", draft.name); row("city", draft.city)
            LabeledContent("club.ops.clubType") { canonical(draft.clubType) }
            row("description", draft.description); row("keywords", draft.keywords); row("style", draft.style)
            LabeledContent("club.ops.directions") {
                if draft.activityPrefs.isEmpty {
                    Text(verbatim: "—").foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing) { ForEach(draft.activityPrefs, id: \.self) { canonical($0) } }
                }
            }
            if let original, original.club.isOwner {
                LabeledContent("club.ops.prioritySignup") { Text(draft.prioritySignupEnabled ? "club.ops.enabled" : "club.ops.disabled") }
                    .accessibilityIdentifier("club.ops.reviewSheet.prioritySignup")
                // An empty draft quota is submitted as 0, so the review shows that 0.
                row("quota", draft.memberReservedQuota.isEmpty ? "0" : draft.memberReservedQuota, numeric: true)
                    .accessibilityIdentifier("club.ops.reviewSheet.quota")
                if original.club.joinPolicySupported {
                    LabeledContent("club.ops.joinPolicy") { Text(draft.joinPolicy == 1 ? "club.ops.joinReview" : "club.ops.joinDirect") }
                        .accessibilityIdentifier("club.ops.reviewSheet.joinPolicy")
                }
            }
        }
    }
    @ViewBuilder private func canonical(_ value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { Text(verbatim: "—").foregroundStyle(.secondary) }
        else if ClubOperationsCatalog.types.contains(trimmed) || ClubOperationsCatalog.directions.contains(trimmed) { Text(LocalizedStringKey("club.ops.value." + trimmed)) }
        else { Text(verbatim: trimmed) }
    }
    /// Blank draft text is unknown. A typed 0 stays 0.
    private func row(_ key: String, _ value: String, numeric: Bool = false) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return LabeledContent(LocalizedStringKey("club.ops." + key)) {
            Text(verbatim: trimmed.isEmpty ? "—" : trimmed)
                .font(numeric ? Font.body.monospacedDigit() : .body)
                .textSelection(.enabled)
        }
    }
}
