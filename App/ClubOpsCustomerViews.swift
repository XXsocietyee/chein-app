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
            ContentUnavailableView {
                if let literal = copy.literalTitle {
                    Text(verbatim: literal)
                        .accessibilityIdentifier("clubOps.failure.title")
                } else {
                    Label {
                        Text(LocalizedStringKey(copy.titleKey), tableName: "ClubOpsCustomer")
                            .accessibilityIdentifier("clubOps.failure.title")
                    } icon: { Image(systemName: "exclamationmark.triangle") }
                }
            } description: {
                if let detail = copy.detailKey {
                    Text(LocalizedStringKey(detail), tableName: "ClubOpsCustomer")
                        .accessibilityIdentifier("club.gov.error")
                } else if let reason {
                    reason
                        .accessibilityIdentifier("club.gov.error")
                }
            } actions: {
                if let back = copy.backTitle {
                    Button { dismiss() } label: { Text(verbatim: locale.pick(back, "Back")) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clubOps.failure.back")
                } else if let key = copy.retryKey {
                    Button(action: retry) {
                        Label { Text(LocalizedStringKey(key), tableName: "ClubOpsCustomer") } icon: { Image(systemName: "arrow.clockwise") }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("clubOps.failure.retry")
                }
            }
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
                Group {
                    if filtered {
                        ContentUnavailableView {
                            Label { Text("clubOps.customers.filteredEmpty", tableName: "ClubOpsCustomer") } icon: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                        } description: {
                            Text("clubOps.customers.filteredEmptyDetail", tableName: "ClubOpsCustomer")
                        }
                    } else {
                        // Round 2 MP asset: 还没有客户 is cy-empty kind="empty", the MP two-layer illustration.
                        ClubMPEmptyState(title: Text("clubOps.customers.empty", tableName: "ClubOpsCustomer"))
                    }
                }
                .accessibilityIdentifier("clubOps.customers.empty")
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
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity).accessibilityIdentifier("clubOps.customers.loadingMore")
            } else if pager.failed {
                Button { Task { await pager.loadMore(readPage) } } label: {
                    Text("clubOps.customers.loadMoreFailed", tableName: "ClubOpsCustomer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("clubOps.customers.loadMoreRetry")
            }
        } header: {
            // CLB-customers-06 (fix-r3-club-b): MP .cus-count is a label-size meta line.
            Text("clubOps.customers.count \(list.total) \(list.monthNew)", tableName: "ClubOpsCustomer")
                .monospacedDigit()
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
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        stack {
            // CLB-customers-02 (parity r2): CYAvatarView with the customer's avatar and an initial fallback (MP cy-avatar).
            // Round 2 MP asset: cy-avatar falls back to images/d_profile.png only when there is no name.
            ClubMPAvatar(url: row.avatar.flatMap(URL.init(string:)), name: row.displayName ?? "", size: .md, usesDefaultFace: false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let name = row.displayName {
                        Text(verbatim: name)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.gov.fact.displayName")
                    } else {
                        Text("clubOps.customers.noName", tableName: "ClubOpsCustomer")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // CLB-customers-03: MP puts the 备注 tag after the name.
                    if row.hasRemark {
                        Label {
                            Text(verbatim: String(localized: LocalizedStringResource("clubOps.customers.remarkBadge", table: "ClubOpsCustomer", locale: locale)))
                        } icon: { Image(systemName: "note.text") }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                meta
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = row.subText {
                    Text(verbatim: sub)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    /// CLB-customer-detail-04 (MP wxml:82-118): owns the 标签与备注 section when the viewer can edit, so the editor can
    /// replace the card in place and the heading can read 编辑标签与备注 with 取消 beside it. Receives the read-only rows.
    let editSection: ((AnyView) -> AnyView)?
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
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            stack {
                if typeSize.isAccessibilitySize { avatarView }
                VStack(alignment: .leading, spacing: 4) {
                    // CLB-customer-detail-03 (fix-r3-club-b): MP — the customer's name is the page title (29 bold),
                    // the avatar sits at the top right; the bar keeps the short page-type title.
                    if let name = detail.displayName {
                        Text(verbatim: name)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("club.gov.fact.displayName")
                    } else {
                        Text("clubOps.customers.noName", tableName: "ClubOpsCustomer")
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    interaction
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        .cyText(.numericTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("clubOps.customer.amountHidden", tableName: "ClubOpsCustomer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } label: {
                Text("clubOps.customer.paidAmount", tableName: "ClubOpsCustomer")
            }
            .accessibilityIdentifier("clubOps.customer.paidAmount")
            if let phone = detail.phoneText {
                HStack(spacing: 8) {
                    Text(verbatim: phone)
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
            // Mini-program customer-detail: three metrics (到店 / 待核销 / 已退款), one value row each.
            ClubOpsCustomerMetricTile(value: page?.metrics?.arrived ?? .known(detail.arrivedCount), label: "clubOps.customer.arrived")
            ClubOpsCustomerMetricTile(value: page?.metrics?.pending ?? .known(detail.pendingCount), label: "clubOps.customer.pending")
            ClubOpsCustomerMetricTile(value: page?.metrics?.refunded ?? .known(detail.refundedCount), label: "clubOps.customer.refunded")
        } header: { ClubOpsCustomerHeading("clubOps.customer.overview") }
        Section {
            if detail.records.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("clubOps.customer.recordsEmpty", tableName: "ClubOpsCustomer")
                            .accessibilityIdentifier("clubOps.customer.recordsEmpty")
                    } icon: { Image(systemName: "clock.arrow.circlepath") }
                }
            }
            ForEach(detail.records) { record in
                if let action = topicAction(record) {
                    Button(action: action.open) { ClubOpsCustomerRecordRow(record: record, linked: true) }
                        .accessibilityIdentifier("club.gov.customer.topic.\(action.id)")
                } else { ClubOpsCustomerRecordRow(record: record, linked: false) }
            }
        } header: { ClubOpsCustomerHeading("clubOps.customer.records") }
        if detail.canEdit, let editSection {
            editSection(AnyView(tagsAndRemarkRows))
        } else {
            Section {
                tagsAndRemarkRows
            } header: { ClubOpsCustomerHeading("clubOps.customer.tagsAndRemark") }
        }
    }
    @ViewBuilder private var tagsAndRemarkRows: some View {
        if !detail.tags.isEmpty {
            ClubOpsTagFlow(tags: detail.tags)
        }
        if let remark = detail.remark {
            Text("clubOps.customer.remark \(remark)", tableName: "ClubOpsCustomer")
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("clubOps.customer.noRemark", tableName: "ClubOpsCustomer")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

struct ClubOpsCustomerHeading: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        Text(LocalizedStringKey(key), tableName: "ClubOpsCustomer")
            .accessibilityAddTraits(.isHeader)
    }
}

struct ClubOpsCustomerMetricTile: View {
    let value: ClubCustomerDetailCount
    let label: LocalizedStringKey
    var body: some View {
        LabeledContent {
            Text(verbatim: value.displayText)
                .monospacedDigit()
        } label: {
            Text(label, tableName: "ClubOpsCustomer")
        }
        .accessibilityElement(children: .combine)
    }
}

struct ClubOpsCustomerRecordRow: View {
    let record: ClubOpsCustomerRecord
    let linked: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let stack = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        stack {
            VStack(alignment: .leading, spacing: 2) {
                if let day {
                    Text(day, format: .number)
                        .cyText(.numericTitle)
                } else {
                    Text(verbatim: "—")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                if let month = record.month {
                    Text("clubOps.customer.month \(month)", tableName: "ClubOpsCustomer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                if let title = record.title {
                    Text(verbatim: title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("clubOps.customer.untitled", tableName: "ClubOpsCustomer")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label {
                    Text(verbatim: String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: record.status.localizationKey), table: "ClubOpsCustomer")))
                } icon: {
                    Image(systemName: symbol).foregroundStyle(tint)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if linked {
                    Text("clubOps.customer.viewTopic", tableName: "ClubOpsCustomer")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if linked, !typeSize.isAccessibilitySize {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(Color.primary)
    }
    private var day: Int? { record.day }
    private var tint: Color {
        switch record.status {
        case .verified: return .green
        case .pending, .contacted: return .orange
        case .refunded: return .red
        case .cancelled, .registered: return .secondary
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
        ClubR1WrapLayout(spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if let removable {
                    Button { removable(index) } label: {
                        Label { Text(verbatim: tag.isEmpty ? "—" : tag) } icon: { Image(systemName: "xmark") }
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityLabel(Text("clubOps.customer.removeTag \(tag)", tableName: "ClubOpsCustomer"))
                    .accessibilityIdentifier("clubOps.customer.removeTag.\(index)")
                } else {
                    Label { Text(verbatim: tag.isEmpty ? "—" : tag) } icon: { Image(systemName: "tag") }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .ignore)
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
        // CLB-customer-detail-04 (MP customer-detail/index.wxml:83-118): each tag is a plain row; swipe to delete
        // (the MP chip's ×). The add field submits on Return; the remark is a multi-line field; 保存 sits on the form.
        ForEach(Array(draft.tags.enumerated()), id: \.offset) { index, tag in
            Label { Text(verbatim: tag.isEmpty ? "—" : tag) } icon: { Image(systemName: "tag").accessibilityHidden(true) }
                .accessibilityIdentifier("clubOps.customer.tag.\(index)")
        }
        .onDelete { offsets in
            var next = ClubOpsCustomerTagRemarkDraft(tagsText: tagsText)
            for index in offsets.sorted(by: >) { next.remove(at: index) }
            tagsText = next.tagsText; issue = nil
        }
        let composer = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        composer {
            TextField(text: $input) { Text("clubOps.customer.tagPlaceholder", tableName: "ClubOpsCustomer") }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(add)
                .submitLabel(.done)
                .accessibilityIdentifier("club.gov.input.tags")
            Button(action: add) {
                Label { Text("clubOps.customer.addTag", tableName: "ClubOpsCustomer") } icon: { Image(systemName: "plus") }
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
            }
                .buttonStyle(.bordered)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("clubOps.customer.addTag")
        }
        TextField(text: $remark, axis: .vertical) { Text("clubOps.customer.remarkPlaceholder", tableName: "ClubOpsCustomer") }
            .accessibilityIdentifier("club.gov.input.remark")
        if let current = issue ?? ClubOpsCustomerTagRemarkDraft.issue(tagsText: tagsText, remark: remark) {
            Text(LocalizedStringKey(current.localizationKey), tableName: "ClubOpsCustomer")
                .font(.footnote)
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
        .accessibilityLabel(Text("club.phoneCall.label \(name ?? "—")"))
        .accessibilityIdentifier("club.phoneCall")
    }
}
