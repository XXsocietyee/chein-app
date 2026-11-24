import SwiftUI

struct ClubOpsFailureSection: View {
    let copy: ClubOpsFailureCopy
    /// X3 (parity r2): the one reason line under the page title when the page copy has no detail of its own.
    var reason: Text? = nil
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let literal = copy.literalTitle {
                    Text(verbatim: literal)
                        .cyText(.cardTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("clubOps.failure.title")
                } else {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        LocalizedStringKey(copy.titleKey),
                        tableName: "ClubOpsCustomer",
                        messageIdentifier: "clubOps.failure.title",
                        kind: .failure
                    )
                }
                if let detail = copy.detailKey {
                    Text(LocalizedStringKey(detail), tableName: "ClubOpsCustomer")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("club.gov.error")
                } else if let reason {
                    reason
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("club.gov.error")
                }
                if let back = copy.backTitle {
                    CYPillButton(verbatim: locale.pick(back, "Back"), style: .secondary, action: { dismiss() })
                        .accessibilityIdentifier("clubOps.failure.back")
                } else if let key = copy.retryKey {
                    CYPillButton(LocalizedStringKey(key), style: .secondary, systemImage: "arrow.clockwise", tableName: "ClubOpsCustomer", action: retry)
                        .accessibilityIdentifier("clubOps.failure.retry")
                }
            }
            .e1ActionRow()
        }
    }
}

/// CLB-customers-01: appends server pages under the first read (MP customers onReachBottom).
/// The first page stays owned by the read view; the pager only holds what came after it.
@MainActor final class ClubOpsCustomerPager: ObservableObject {
    @Published private(set) var list: ClubOpsCustomerListPresentation?
    @Published private(set) var loadingMore = false
    @Published private(set) var failed = false
    private(set) var hasMore = false
    private var base: ClubOpsCustomerListPresentation?
    private var page = 1
    private var epoch = 0
    func adopt(_ first: ClubOpsCustomerListPresentation) {
        guard first != base else { return }
        epoch &+= 1; base = first; list = first; page = 1; hasMore = first.hasMoreAfterFirstPage; loadingMore = false; failed = false
    }
    func loadMore(_ read: @escaping (Int) async throws -> ClubGovernanceValue) async {
        guard hasMore, !loadingMore, let current = list else { return }
        let ticket = epoch, next = page + 1
        loadingMore = true; failed = false
        defer { if ticket == epoch { loadingMore = false } }
        do {
            let value = try await read(next)
            guard ticket == epoch else { return }
            let result = current.appending(try ClubOpsCustomerListPresentation(value: value))
            list = result.list; hasMore = result.hasMore; page = next
        } catch {
            guard ticket == epoch, !(error is CancellationError) else { return }
            failed = true
        }
    }
}

@MainActor struct ClubOpsCustomerListContent: View {
    let first: ClubOpsCustomerListPresentation
    let filtered: Bool
    @ObservedObject var pager: ClubOpsCustomerPager
    let readPage: (Int) async throws -> ClubGovernanceValue
    let destination: (Int) -> AnyView
    private var list: ClubOpsCustomerListPresentation { pager.list ?? first }
    var body: some View {
        content
            .onAppear { pager.adopt(first) }
            .onChange(of: first) { _, value in pager.adopt(value) }
    }
    @ViewBuilder private var content: some View {
        // The count is data (it follows the filter), so it heads the list rather than sitting alone.
        Section {
            if list.rows.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    if filtered {
                        // MP 没有符合条件的客户 has no kind, so no illustration (cy-empty legacy default).
                        CYEmptyState(systemImage: "line.3.horizontal.decrease.circle", "clubOps.customers.filteredEmpty",
                                     tableName: "ClubOpsCustomer", kind: .search)
                    } else {
                        // Round 2 MP asset: 还没有客户 is cy-empty kind="empty", the MP two-layer illustration.
                        ClubMPEmptyState(title: Text("clubOps.customers.empty", tableName: "ClubOpsCustomer"))
                    }
                    if filtered {
                        Text("clubOps.customers.filteredEmptyDetail", tableName: "ClubOpsCustomer")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityIdentifier("clubOps.customers.empty")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(list.rows) { row in
                NavigationLink { destination(row.id) } label: { ClubOpsCustomerRowView(row: row) }
                    .accessibilityIdentifier("club.gov.route.customer")
                    .onAppear {
                        guard row.id == list.rows.last?.id, pager.hasMore, !pager.failed else { return }
                        Task { await pager.loadMore(readPage) }
                    }
            }
            if pager.loadingMore {
                ProgressView().frame(maxWidth: .infinity).accessibilityIdentifier("clubOps.customers.loadingMore")
            } else if pager.failed {
                Button { Task { await pager.loadMore(readPage) } } label: {
                    Text("clubOps.customers.loadMoreFailed", tableName: "ClubOpsCustomer").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("clubOps.customers.loadMoreRetry")
            }
        } header: {
            // CLB-customers-06 (fix-r3-club-b): MP .cus-count is a label-size meta line.
            Text("clubOps.customers.count \(list.total) \(list.monthNew)", tableName: "ClubOpsCustomer")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .monospacedDigit()
                .textCase(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("clubOps.customers.count")
        }
    }
}

struct ClubOpsCustomerRowView: View {
    @Environment(\.locale) private var locale
    let row: ClubOpsCustomerRow
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // Mini-program .cus-row: round initial avatar, then name (+ 备注 tag), meta, sub text.
        let stack = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.md))
        stack {
            // CLB-customers-02 (parity r2): CYAvatarView with the customer's avatar and an initial fallback (MP cy-avatar).
            // Round 2 MP asset: cy-avatar falls back to images/d_profile.png only when there is no name.
            ClubMPAvatar(url: row.avatar.flatMap(URL.init(string:)), name: row.displayName ?? "", size: .md, usesDefaultFace: false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    if let name = row.displayName {
                        Text(verbatim: name)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.gov.fact.displayName")
                    } else {
                        Text("clubOps.customers.noName", tableName: "ClubOpsCustomer")
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // CLB-customers-03: MP puts the 备注 tag after the name.
                    if row.hasRemark {
                        CYStatusChip(
                            verbatim: String(localized: LocalizedStringResource("clubOps.customers.remarkBadge", table: "ClubOpsCustomer", locale: locale)),
                            tone: .neutral,
                            systemImage: "note.text"
                        )
                    }
                }
                meta
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = row.subText {
                    Text(verbatim: sub)
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textTertiary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .padding(.vertical, CYSpacing.xs)
    }
    private var initial: String {
        guard let first = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "—" }
        return String(first)
    }
    @ViewBuilder private var meta: some View {
        switch row.meta {
        case .pending(let count, let topic):
            if let topic { Text("clubOps.customers.metaPendingTopic \(count) \(topic)", tableName: "ClubOpsCustomer") }
            else { Text("clubOps.customers.metaPending \(count)", tableName: "ClubOpsCustomer") }
        case .verified(let count, let day):
            if let day { Text("clubOps.customers.metaVerifiedDay \(count) \(day)", tableName: "ClubOpsCustomer") }
            else { Text("clubOps.customers.metaVerified \(count)", tableName: "ClubOpsCustomer") }
        }
    }
}

@MainActor struct ClubOpsCustomerDetailContent: View {
    let detail: ClubOpsCustomerDetailPresentation
    /// Core page projection. Nil keeps the presentation integers. Unknown counts are an em dash.
    var page: ClubCustomerDetailPage? = nil
    /// Non-nil only when the existing history-topic route accepts this exact returned record.
    let topicAction: (ClubOpsCustomerRecord) -> (id: Int, open: () -> Void)?
    let editButton: AnyView?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var avatarSide: CGFloat = 56
    @ViewBuilder private var avatarView: some View {
        // CLB-customer-detail-02 (parity r2): the customer's own avatar; the generated art is only the fallback.
        if let url = detail.avatar.flatMap(URL.init(string:)), url.scheme?.lowercased() == "https" {
            CYAvatarView(url: url, name: detail.displayName ?? "—", size: .lg)
                .accessibilityHidden(true)
        } else {
            // Round 2 MP asset: MP cy-avatar shows the initial for a named customer and images/d_profile.png
            // otherwise; the generated cover art is gone.
            ClubMPAvatar(url: nil, name: detail.displayName ?? "", size: .lg, usesDefaultFace: false)
                .accessibilityHidden(true)
        }
    }
    var body: some View {
        Section {
            let stack = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
                : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.md))
            stack {
                if typeSize.isAccessibilitySize { avatarView }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    // CLB-customer-detail-03 (fix-r3-club-b): MP — the customer's name is the page title (29 bold),
                    // the avatar sits at the top right; the bar keeps the short page-type title.
                    if let name = detail.displayName {
                        Text(verbatim: name)
                            .cyText(.pageTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.gov.fact.displayName")
                    } else {
                        Text("clubOps.customers.noName", tableName: "ClubOpsCustomer")
                            .cyText(.pageTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    interaction
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { avatarView }
            }
            LabeledContent {
                if let text = paidText {
                    // CLB-customer-detail-08: MP 累计实付 is data-xl.
                    Text(verbatim: text)
                        .cyText(.dataXL)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("clubOps.customer.amountHidden", tableName: "ClubOpsCustomer")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } label: {
                Text("clubOps.customer.paidAmount", tableName: "ClubOpsCustomer")
            }
            .accessibilityIdentifier("clubOps.customer.paidAmount")
            if let phone = detail.phoneText {
                HStack(spacing: CYSpacing.sm) {
                    Text(verbatim: phone)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // CLB-customer-detail-01: call button only when the server grants phoneCallable.
                    if let url = ClubPhoneCall.url(phoneText: phone, callable: detail.phoneCallable) {
                        ClubPhoneCallButton(url: url, name: detail.displayName)
                    }
                }
            }
        }
        Section {
            // Mini-program customer-detail: three metric tiles (到店 / 待核销 / 已退款), numerals first.
            let metrics = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
                : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.sm))
            metrics {
                ClubOpsCustomerMetricTile(value: page?.metrics?.arrived ?? .known(detail.arrivedCount), label: "clubOps.customer.arrived")
                ClubOpsCustomerMetricTile(value: page?.metrics?.pending ?? .known(detail.pendingCount), label: "clubOps.customer.pending")
                ClubOpsCustomerMetricTile(value: page?.metrics?.refunded ?? .known(detail.refundedCount), label: "clubOps.customer.refunded")
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
        } header: { ClubOpsCustomerHeading("clubOps.customer.overview") }
        Section {
            if detail.records.isEmpty {
                CYEmptyState(systemImage: "clock.arrow.circlepath", "clubOps.customer.recordsEmpty", tableName: "ClubOpsCustomer", messageIdentifier: "clubOps.customer.recordsEmpty")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(detail.records) { record in
                if let action = topicAction(record) {
                    Button(action: action.open) { ClubOpsCustomerRecordRow(record: record, linked: true) }
                        .accessibilityIdentifier("club.gov.customer.topic.\(action.id)")
                } else { ClubOpsCustomerRecordRow(record: record, linked: false) }
            }
        } header: { ClubOpsCustomerHeading("clubOps.customer.records") }
        Section {
            if !detail.tags.isEmpty {
                ClubOpsTagFlow(tags: detail.tags)
            }
            if let remark = detail.remark {
                Text("clubOps.customer.remark \(remark)", tableName: "ClubOpsCustomer")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("clubOps.customer.noRemark", tableName: "ClubOpsCustomer")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if detail.canEdit, let editButton { editButton }
        } header: { ClubOpsCustomerHeading("clubOps.customer.tagsAndRemark") }
    }
    /// Withheld stays the permission sentence. Unknown is the page model's em dash, never 0.
    private var paidText: String? {
        if let paid = page?.paidAmount { return paid.displayText }
        // Owner decision 9: server amount text reads with two decimals (¥12.50).
        return detail.paidAmountText.map(ClubMoneyText.display)
    }
    @ViewBuilder private var interaction: some View {
        // CLB-customer-detail-06 (parity r2): the remark already has its own card, so it is not repeated here.
        if let day = detail.lastInteraction {
            Text("clubOps.customer.interaction \(day.month) \(day.day)", tableName: "ClubOpsCustomer")
        } else { Text("clubOps.customer.noInteraction", tableName: "ClubOpsCustomer") }
    }
}

private struct ClubOpsCustomerHeading: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        Text(LocalizedStringKey(key), tableName: "ClubOpsCustomer")
            .cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ClubOpsCustomerMetricTile: View {
    let value: ClubCustomerDetailCount
    let label: LocalizedStringKey
    var body: some View {
        VStack(spacing: CYSpacing.xs) {
            // CLB-customer-detail-08: MP stat numerals are sheet-title size.
            Text(verbatim: value.displayText)
                .cyText(.sheetTitle)
                .monospacedDigit()
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(label, tableName: "ClubOpsCustomer")
                .cyText(.caption)
                .foregroundStyle(CYColor.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

struct ClubOpsCustomerRecordRow: View {
    let record: ClubOpsCustomerRecord
    let linked: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let stack = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.md))
        stack {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let day {
                    Text(day, format: .number)
                        .cyText(.sectionTitle)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.textPrimary)
                } else {
                    Text(verbatim: "—")
                        .cyText(.sectionTitle)
                        .foregroundStyle(CYColor.textTertiary)
                }
                if let month = record.month {
                    Text("clubOps.customer.month \(month)", tableName: "ClubOpsCustomer")
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: CYSpacing.minTouchTarget, alignment: .leading)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let title = record.title {
                    Text(verbatim: title)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("clubOps.customer.untitled", tableName: "ClubOpsCustomer")
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                CYStatusChip(
                    verbatim: String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: record.status.localizationKey), table: "ClubOpsCustomer")),
                    tone: tone,
                    systemImage: symbol
                )
                if linked {
                    Text("clubOps.customer.viewTopic", tableName: "ClubOpsCustomer")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if linked, !typeSize.isAccessibilitySize {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CYColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
    }
    private var day: Int? { record.day }
    private var tone: CYStatusTone {
        switch record.status {
        case .verified: return .success
        case .pending, .contacted: return .warning
        case .refunded: return .danger
        case .cancelled, .registered: return .neutral
        }
    }
    private var symbol: String {
        switch record.status {
        case .verified: return "checkmark.circle"
        case .pending, .contacted: return "clock"
        case .refunded: return "arrow.uturn.backward.circle"
        case .cancelled: return "xmark.circle"
        case .registered: return "person"
        }
    }
}

struct ClubOpsTagFlow: View {
    let tags: [String]
    var removable: ((Int) -> Void)? = nil
    var body: some View {
        // CLB-customer-detail-09 (fix-r3-club-b): tags wrap onto new lines like the MP .cd-tags; none are hidden off-edge.
        ClubR1WrapLayout(spacing: CYSpacing.sm) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if let removable {
                    Button { removable(index) } label: {
                        CYStatusChip(verbatim: tag.isEmpty ? "—" : tag, tone: .neutral, systemImage: "xmark")
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityLabel(Text("clubOps.customer.removeTag \(tag)", tableName: "ClubOpsCustomer"))
                    .accessibilityIdentifier("clubOps.customer.removeTag.\(index)")
                } else {
                    CYStatusChip(verbatim: tag.isEmpty ? "—" : tag, tone: .neutral)
                        .accessibilityLabel(Text(verbatim: tag.isEmpty ? "—" : tag))
                }
            }
        }
    }
}

/// Inline chip editor for saveCustomer. It edits the existing draft text fields only.
struct ClubOpsCustomerTagRemarkEditor: View {
    @Binding var tagsText: String
    @Binding var remark: String
    @State private var input = ""
    @State private var issue: ClubOpsCustomerTagRemarkDraft.Issue?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let draft = ClubOpsCustomerTagRemarkDraft(tagsText: tagsText)
        if !draft.tags.isEmpty {
            ClubOpsTagFlow(tags: draft.tags) { index in
                var next = draft; next.remove(at: index); tagsText = next.tagsText; issue = nil
            }
        }
        let composer = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.sm))
        composer {
            TextField(text: $input) { Text("clubOps.customer.tagPlaceholder", tableName: "ClubOpsCustomer") }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(add)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("club.gov.input.tags")
            CYPillButton("clubOps.customer.addTag", style: .secondary, systemImage: "plus", fullWidth: typeSize.isAccessibilitySize, tableName: "ClubOpsCustomer", action: add)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("clubOps.customer.addTag")
        }
        TextField(text: $remark, axis: .vertical) { Text("clubOps.customer.remarkPlaceholder", tableName: "ClubOpsCustomer") }
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .accessibilityIdentifier("club.gov.input.remark")
        if let current = issue ?? ClubOpsCustomerTagRemarkDraft.issue(tagsText: tagsText, remark: remark) {
            Text(LocalizedStringKey(current.localizationKey), tableName: "ClubOpsCustomer")
                .cyText(.caption)
                .foregroundStyle(CYColor.dangerText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clubOps.customer.draftIssue")
        }
    }
    private func add() {
        var draft = ClubOpsCustomerTagRemarkDraft(tagsText: tagsText)
        if let problem = draft.add(input) { issue = problem; return }
        tagsText = draft.tagsText; input = ""; issue = nil
    }
}

/// 44 pt tel: link shared by customer and check-in detail (CLB-customer-detail-01, CLB-checkin-detail-02).
struct ClubPhoneCallButton: View {
    let url: URL
    let name: String?
    var body: some View {
        Link(destination: url) {
            Image(systemName: "phone.fill")
                .imageScale(.medium)
                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(CYColor.brand)
        .accessibilityLabel(Text("club.phoneCall.label \(name ?? "—")"))
        .accessibilityIdentifier("club.phoneCall")
    }
}
