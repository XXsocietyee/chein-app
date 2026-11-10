import SwiftUI

@MainActor struct CooperationPoolView: View {
    let reader: any CooperationReading
    var body: some View {
        CooperationReadScreen(reader: reader, resource: "pool", operation: { try await reader.pool() }) { pool in
            Section { CYHeroHeader("cooperation.pool.title").listRowBackground(Color.clear) }
            if !pool.hasClub {
                Section {
                    CYEmptyState(systemImage: "person.3", "cooperation.pool.clubRequired", detail: "cooperation.pool.clubHint",
                                 messageIdentifier: "cooperation.pool.clubRequired")
                }
            } else {
                Section {
                    if pool.rows.isEmpty { CYEmptyState(systemImage: "tray", "cooperation.pool.empty").listRowBackground(Color.clear) }
                    ForEach(Array(pool.rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 8) {
                            CooperationName(name: row.name, fallback: "cooperation.unnamedTopic").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                            CooperationStatus(key: row.stateKey)
                            CooperationField(key: "cooperation.about", value: row.subtitle)
                            CooperationTopicReference(id: row.topicId)
                            CooperationField(key: "cooperation.publisher", value: row.merchantNick)
                            CooperationTimeField(key: "cooperation.start", value: row.startDate)
                            CooperationTimeField(key: "cooperation.end", value: row.endDate)
                            CooperationTimeField(key: "cooperation.expires", value: row.recruitDeadline)
                        }.padding(.vertical, 4)
                    }
                }
                Section { CooperationReadOnlyNotice() }
            }
        }.cyHeroScreen()
    }
}
@MainActor struct CooperationCandidatesView: View {
    let topicID: Int
    let reader: any CooperationReading
    var body: some View {
        CooperationReadScreen(reader: reader, resource: "candidates.\(topicID)", operation: {
            guard topicID > 0 else { throw CooperationReadFailure.unavailable }
            return try await reader.candidates(topicID: topicID)
        }) { directory in
            Section {
                CYHeroHeader("cooperation.candidates.title").listRowBackground(Color.clear)
                CooperationTopicReference(id: topicID)
                CYStatusChip("cooperation.candidates.ownerOnly", tone: .neutral, systemImage: "lock")
            }
            Section("cooperation.candidates.clubs") {
                if directory.clubApplies.isEmpty { CYEmptyState(systemImage: "person.3", "cooperation.applications.empty").listRowBackground(Color.clear) }
                ForEach(Array(directory.clubApplies.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 8) {
                        CooperationName(name: row.clubName, fallback: "cooperation.unnamedClub").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        CooperationStatus(key: row.statusKey)
                        CooperationField(key: "cooperation.message", value: row.message)
                        CooperationField(key: "cooperation.inviteState", value: row.inviteStatus)
                        CooperationTimeField(key: "cooperation.created", value: row.createTime)
                    }.padding(.vertical, 4)
                }
            }
            Section("cooperation.candidates.merchants") {
                if directory.registrations.isEmpty { CYEmptyState(systemImage: "storefront", "cooperation.registrations.empty").listRowBackground(Color.clear) }
                ForEach(Array(directory.registrations.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 8) {
                        CooperationName(name: row.name, fallback: "cooperation.unnamedMerchant").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        // CandidateRegistration.status has no audited presentation mapping; do not borrow auditStatus semantics.
                        if let status = row.status { CooperationField(key: "cooperation.sourceStatus", value: String(status)) }
                    }.padding(.vertical, 4)
                }
            }
            Section { CooperationReadOnlyNotice() }
        }.cyHeroScreen()
    }
}
