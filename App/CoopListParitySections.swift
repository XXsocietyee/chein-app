import SwiftUI

/// Source `pages/coop/list` chapter-application block, shown above both tabs. Owner leg always; the
/// merchant-only `mine` leg is skipped silently when the account is not a merchant (permission failure).
@MainActor struct CoopChapterApplicationSection: View {
    let reader: any CoopFlowReading
    let direction: CooperationDirection
    var operationScope: String? = nil
    var topicFilter: CoopTopicFilterSeed = .init()
    @State private var rows: [CoopChapterApplication] = []
    @State private var failed = false
    @State private var loading = false
    @State private var loadedSession: CoopFlowSession?
    @State private var refresh = UUID()
    var body: some View {
        let visible = loadedSession == reader.session ? topicFilter.filter(rows.filter { $0.direction == direction }, topic: \.topicID) : []
        Group {
            if loading || failed || !visible.isEmpty {
                Section("cooperation.list.chapter.title") {
                    if loading { Text("cooperation.list.chapter.loading").cyText(.label).foregroundStyle(CYColor.textSecondary) }
                    if failed {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("cooperation.list.chapter.failed").cyText(.label, weight: .semibold).foregroundStyle(CYColor.dangerText)
                            Button("cooperation.refresh") { refresh = UUID() }.accessibilityIdentifier("cooperation.list.chapter.retry")
                        }.accessibilityIdentifier("cooperation.list.chapter.failed")
                    }
                    ForEach(visible) { row in
                        // Mini `.inv` (chapter variant): status line, title, "chapter · merchant", secondary action label.
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text(LocalizedStringKey("cooperation.list.chapter.status." + row.status.rawValue)).cyText(.label).foregroundStyle(CYColor.textTertiary)
                            Text(verbatim: row.topicName ?? "#" + String(row.topicID ?? 0)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            if let chapter = row.chapterName {
                                Text(verbatim: row.leg == .owner && row.merchantName != nil ? chapter + " · " + (row.merchantName ?? "") : chapter).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                            // MC7-30-3: the row has no destination here, so no info-coloured action label that reads as a link.
                        }.padding(.vertical, CYSpacing.xs).accessibilityElement(children: .combine)
                            .accessibilityIdentifier("cooperation.list.chapter.\(row.id)")
                    }
                }
            }
        }
        .task(id: "\(reader.session?.accountID ?? 0):\(reader.session?.epoch ?? 0):\(refresh)") { await load() }
    }
    private func load() async {
        rows = []; failed = false; loadedSession = nil
        guard let session = reader.session else { return }
        loading = true
        defer { if reader.session == session { loading = false } }
        var collected: [CoopChapterApplication] = [], legFailed = false
        do { let owned = try await reader.read(.chapterApplicationsOwned(scope: operationScope)); collected += try CoopChapterApplication.rows(owned, leg: .owner) }
        catch { guard !Task.isCancelled, reader.session == session else { return }; legFailed = true }
        do { let mine = try await reader.read(.chapterApplicationsMine); collected += try CoopChapterApplication.rows(mine, leg: .mine) }
        catch {
            guard !Task.isCancelled, reader.session == session else { return }
            if !CoopListReadFailure.isPermission(error) { legFailed = true }
        }
        guard !Task.isCancelled, reader.session == session else { return }
        rows = collected; failed = legFailed; loadedSession = session
    }
}

/// Source `pages/coop/list` official merchant invites (received tab). Accept/decline open dormant reviews only.
@MainActor struct CoopOfficialInviteSection: View {
    let reader: any CoopFlowReading
    @Environment(\.locale) private var locale
    @State private var rows: [CoopOfficialInvite] = []
    @State private var failed = false
    @State private var loadedSession: CoopFlowSession?
    @State private var refresh = UUID()
    var body: some View {
        Group {
            if failed || (loadedSession == reader.session && !rows.isEmpty) {
                Section("cooperation.list.official.title") {
                    if failed {
                        Text("cooperation.list.official.failed").accessibilityIdentifier("cooperation.list.official.failed")
                        Button("cooperation.refresh") { refresh = UUID() }
                    }
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("cooperation.list.official.stage." + row.stage.rawValue)).cyText(.meta, weight: .semibold).foregroundStyle(row.actionable ? CYColor.warningText : CYColor.textSecondary)
                            Text("cooperation.list.official.from").cyText(.bodyCompact).foregroundStyle(.secondary)
                            Text(verbatim: row.title).cyText(.cardTitle)
                            Text(verbatim: deadline(row.deadline)).font(.subheadline)
                            Text(verbatim: reward(row.reward)).font(.subheadline)
                            if row.actionable {
                                NavigationLink { CoopFlowRequestPreview(operation: .handle(inviteID: row.id, action: .accept, reason: "")) } label: { Text("cooperation.detail.accept") }
                                    .accessibilityIdentifier("cooperation.list.official.accept.\(row.id)")
                                NavigationLink { CoopFlowHandleEditor(inviteID: row.id, action: .reject, currentStatus: 0) } label: { Text("cooperation.detail.reject") }
                                    .accessibilityIdentifier("cooperation.list.official.reject.\(row.id)")
                            }
                        }.padding(.vertical, 4).opacity(row.actionable ? 1 : 0.6)
                            .accessibilityIdentifier("cooperation.list.official.\(row.id)")
                    }
                }
            }
        }
        .task(id: "\(reader.session?.accountID ?? 0):\(reader.session?.epoch ?? 0):\(refresh)") {
            rows = []; failed = false; loadedSession = nil
            guard let session = reader.session else { return }
            do {
                let value = try await reader.read(.officialMerchantInvites)
                guard !Task.isCancelled, reader.session == session else { return }
                rows = CoopOfficialInvite.rows(value); loadedSession = session
            } catch { guard !Task.isCancelled, reader.session == session else { return }; failed = true; loadedSession = session }
        }
    }
    private func deadline(_ value: CoopOfficialInvite.Deadline) -> String {
        switch value {
        case .unconfirmed: return appLocalized("cooperation.list.official.deadline.unconfirmed", locale: locale)
        case .monthDay(let month, let day): return appLocalized("cooperation.list.official.deadline \(month) \(day)", locale: locale)
        case .verbatim(let text): return text
        }
    }
    private func reward(_ value: CoopOfficialInvite.Reward) -> String {
        switch value {
        case .share(let rate): return appLocalized("cooperation.list.official.reward.share \(rate)", locale: locale)
        case .fixed(let fee): return appLocalized("cooperation.list.official.reward.fixed \(fee)", locale: locale)
        case .resources: return appLocalized("cooperation.list.official.reward.resources", locale: locale)
        case .unconfirmed: return appLocalized("cooperation.list.official.reward.unconfirmed", locale: locale)
        }
    }
}

/// Source list card summary lines: party direction, terms, viewer party, deposit due and an incomplete-decision notice.
struct CooperationInviteCardDetails: View {
    let view: CooperationInvitePresentation
    var body: some View {
        let invite = view.invite
        // Mini `.inv-main` / `.inv-terms` / `.deposit-due`: title, sub line, terms, then the owed strip.
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let name = invite.topicName { Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
            CooperationInvitePartyText(view: view).cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if let party = invite.viewerPartyName {
                Text(verbatim: party).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .accessibilityLabel(Text(LocalizedStringKey(view.direction == .received ? "cooperation.detail.receivingClub" : "cooperation.detail.sendingClub")) + Text(verbatim: " " + party))
            }
            CooperationInviteTermsText(terms: view.terms).cyText(.label).foregroundStyle(CYColor.textSecondary)
            if case .owed = view.deposit {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(CYColor.warningText).accessibilityHidden(true)
                    CooperationInviteDepositText(deposit: view.deposit).cyText(.label).foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.warningSoft))
            }
            if view.direction == .sent && invite.status == 2 { Text("cooperation.list.sent.declinedHint").cyText(.meta).foregroundStyle(CYColor.textTertiary) }
            if invite.status == 0 && view.direction == .received && !invite.legacyReadonly && !view.decisionReady {
                Label("cooperation.list.incomplete", systemImage: "exclamationmark.triangle").cyText(.meta).foregroundStyle(CYColor.warningText)
            }
        }
    }
}
