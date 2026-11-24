import SwiftUI

/// Merchant staff approve or reject a pending chapter application. The list stays empty until
/// `MerchantStaffApproval.allows` is true, and a reject requires a remark.
@MainActor struct MerchantStaffApprovalView: View {
    let client: MerchantStaffApprovalClient
    let access: MerchantAccess
    let topicID: Int
    @State private var rows: [MerchantStaffApplication] = []
    @State private var denied = false
    @State private var reason = ""
    @State private var rejecting: Int?

    var body: some View {
        List {
            Section {
                Text("merchant.approvals.title")
                    .font(.largeTitle)
            }
            if denied {
                Section {
                    Text("merchant.approvals.denied")
                        .font(.body)
                }
            } else if rows.isEmpty {
                Section {
                    Text("merchant.approvals.empty")
                        .font(.body)
                }
            } else {
                Section {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title.isEmpty ? row.applicant : row.title)
                                .font(.headline)
                            if !row.applicant.isEmpty {
                                Text(row.applicant)
                                    .font(.subheadline)
                            }
                            Text("merchant.approvals.id \(row.id)")
                                .font(.caption)
                            Button("merchant.approvals.approve") {
                                Task { await decide(row.id, approved: true) }
                            }
                            .font(.body)
                            Button("merchant.approvals.reject") { rejecting = row.id }
                                .font(.callout)
                        }
                    }
                }
            }
            if rejecting != nil {
                Section {
                    Text("merchant.approvals.reason")
                        .font(.footnote)
                    TextField("merchant.approvals.reason", text: $reason)
                        .font(.body)
                    Button("merchant.approvals.confirmReject") {
                        guard let id = rejecting else { return }
                        Task { await decide(id, approved: false) }
                    }
                    .font(.body)
                }
            }
        }
        .navigationTitle("merchant.approvals.title")
        .task { await load() }
    }

    private func load() async {
        do {
            rows = try await client.pending(topicID: topicID, access: access)
            denied = false
        } catch MerchantStaffApprovalFailure.denied {
            denied = true
            rows = []
        } catch {
            rows = []
        }
    }

    private func decide(_ id: Int, approved: Bool) async {
        do {
            try await client.decide(applicationID: id, approved: approved, remark: reason, access: access)
            reason = ""
            rejecting = nil
            await load()
        } catch MerchantStaffApprovalFailure.denied {
            denied = true
        } catch {
            return
        }
    }
}
