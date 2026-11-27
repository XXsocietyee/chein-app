import SwiftUI

@MainActor struct CooperationPoolView: View {
    let reader: any CooperationReading
    var body: some View {
        CooperationReadScreen(reader: reader, resource: "pool", operation: { try await reader.pool() }) { pool in
            // One readable title in the list. The bar title stays so CooperationFlowTests can
            // tap navigationBars["Cooperation pool"]; the inline label is clipped to a point.
            Section {
                Text("cooperation.pool.title")
                    .cyText(.pageTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !pool.hasClub {
                Section {
                    CYEmptyState(systemImage: "person.3", "cooperation.pool.clubRequired", detail: "cooperation.pool.clubHint",
                                 messageIdentifier: "cooperation.pool.clubRequired")
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    if pool.rows.isEmpty {
                        CYEmptyState(systemImage: "tray", "cooperation.pool.empty").listRowBackground(Color.clear)
                    }
                    ForEach(Array(pool.rows.enumerated()), id: \.offset) { index, row in
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            if index == 0 {
                                CoopCloudCoverBanner(url: TemplateBrowserPort.coverURL(row.cover), seed: poolSeed(row))
                            }
                            HStack(alignment: .top, spacing: CYSpacing.md) {
                                if index != 0 {
                                    CoopCloudCoverThumb(url: TemplateBrowserPort.coverURL(row.cover), seed: poolSeed(row))
                                }
                                CooperationName(name: row.name, fallback: "cooperation.unnamedTopic")
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            CooperationStatus(key: row.stateKey)
                            CooperationField(key: "cooperation.about", value: row.subtitle)
                            CooperationTopicReference(id: row.topicId)
                            CooperationField(key: "cooperation.publisher", value: row.merchantNick)
                            CooperationTimeField(key: "cooperation.start", value: row.startDate)
                            CooperationTimeField(key: "cooperation.end", value: row.endDate)
                            CooperationTimeField(key: "cooperation.expires", value: row.recruitDeadline)
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                }
                Section { CooperationReadOnlyNotice() }
            }
        }
        .appNavigationTitle("cooperation.pool.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("cooperation.pool.title")
                    .cyText(.cardTitle)
                    .frame(width: 0, height: 0)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
        .cyDomainScreen(.merchant)
        .environment(\.cooperationListIssues, false)
    }

    private func poolSeed(_ row: CooperationPoolItem) -> String {
        if let name = row.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return "pool-\(row.topicId)"
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
            Section {
                CYSectionHeader("cooperation.candidates.clubs")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if directory.clubApplies.isEmpty {
                    CYEmptyState(systemImage: "person.3", "cooperation.applications.empty").listRowBackground(Color.clear)
                }
                ForEach(Array(directory.clubApplies.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "person.2")
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                CooperationName(name: row.clubName, fallback: "cooperation.unnamedClub")
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                CooperationStatus(key: row.statusKey)
                            }
                        }
                        CooperationField(key: "cooperation.message", value: row.message)
                        CooperationField(key: "cooperation.inviteState", value: row.inviteStatus)
                        CooperationTimeField(key: "cooperation.created", value: row.createTime)
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            }
            Section {
                CYSectionHeader("cooperation.candidates.merchants")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if directory.registrations.isEmpty {
                    CYEmptyState(systemImage: "storefront", "cooperation.registrations.empty").listRowBackground(Color.clear)
                }
                ForEach(Array(directory.registrations.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "bag")
                            CooperationName(name: row.name, fallback: "cooperation.unnamedMerchant")
                                .cyText(.cardTitle)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // CandidateRegistration.status has no audited presentation mapping; do not borrow auditStatus semantics.
                        if let status = row.status { CooperationField(key: "cooperation.sourceStatus", value: String(status)) }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            }
            Section { CooperationReadOnlyNotice() }
        }
        .cyHeroScreen()
        .environment(\.cooperationListIssues, false)
    }
}
