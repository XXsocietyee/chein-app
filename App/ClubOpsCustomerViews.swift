import SwiftUI

struct ClubOpsFailureSection: View {
    let copy: ClubOpsFailureCopy
    let retry: () -> Void
    var body: some View {
        Section {
            Text(LocalizedStringKey(copy.titleKey), tableName: "ClubOpsCustomer").font(.headline)
                .accessibilityIdentifier("clubOps.failure.title")
            if let detail = copy.detailKey { Text(LocalizedStringKey(detail), tableName: "ClubOpsCustomer").foregroundStyle(.secondary) }
            if let key = copy.retryKey {
                Button(action: retry) { Text(LocalizedStringKey(key), tableName: "ClubOpsCustomer") }
                    .accessibilityIdentifier("clubOps.failure.retry")
            }
        }
    }
}

@MainActor struct ClubOpsCustomerListContent: View {
    let list: ClubOpsCustomerListPresentation
    let filtered: Bool
    let destination: (Int) -> AnyView
    var body: some View {
        // The count is data (it follows the filter), so it heads the list rather than sitting alone.
        Section {
            if list.rows.isEmpty {
                Group {
                    if filtered {
                        ContentUnavailableView {
                            Label { Text("clubOps.customers.filteredEmpty", tableName: "ClubOpsCustomer") } icon: { Image(systemName: "line.3.horizontal.decrease.circle") }
                        } description: { Text("clubOps.customers.filteredEmptyDetail", tableName: "ClubOpsCustomer") }
                    } else {
                        ContentUnavailableView {
                            Label { Text("clubOps.customers.empty", tableName: "ClubOpsCustomer") } icon: { Image(systemName: "person.2") }
                        }
                    }
                }.accessibilityIdentifier("clubOps.customers.empty")
            }
            ForEach(list.rows) { row in
                NavigationLink { destination(row.id) } label: { ClubOpsCustomerRowView(row: row) }
                    .accessibilityIdentifier("club.gov.route.customer")
            }
        } header: {
            Text("clubOps.customers.count \(list.total) \(list.monthNew)", tableName: "ClubOpsCustomer")
                .accessibilityIdentifier("clubOps.customers.count")
        }
    }
}

struct ClubOpsCustomerRowView: View {
    let row: ClubOpsCustomerRow
    @ScaledMetric(relativeTo: .headline) private var avatarSide: CGFloat = 40
    var body: some View {
        // Mini-program .cus-row: round initial avatar, then name (+ 备注 tag), meta, sub text.
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Text(verbatim: initial)
                .font(CYTypography.bodyMedium).foregroundStyle(CYColor.textSecondary)
                .frame(width: avatarSide, height: avatarSide)
                .background(CYColor.bgElevated, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(spacing: CYSpacing.xs) {
                    if let name = row.displayName { Text(verbatim: name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("club.gov.fact.displayName") }
                    else { Text("clubOps.customers.noName", tableName: "ClubOpsCustomer").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                    if row.hasRemark {
                        Text("clubOps.customers.remarkBadge", tableName: "ClubOpsCustomer").font(CYTypography.micro)
                            .foregroundStyle(CYColor.textSecondary)
                            .padding(.horizontal, CYSpacing.xs + CYSpacing.xxs).padding(.vertical, CYSpacing.xxs)
                            .background(Capsule().fill(CYColor.bgRaised))
                    }
                }
                meta.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                if let sub = row.subText { Text(verbatim: sub).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary).lineLimit(1) }
            }
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
    /// Non-nil only when the existing history-topic route accepts this exact returned record.
    let topicAction: (ClubOpsCustomerRecord) -> (id: Int, open: () -> Void)?
    let editButton: AnyView?
    var body: some View {
        Section {
            if let name = detail.displayName { Text(verbatim: name).font(.title2.bold()).accessibilityIdentifier("club.gov.fact.displayName") }
            else { Text("clubOps.customers.noName", tableName: "ClubOpsCustomer").font(.title2.bold()) }
            interaction.font(.subheadline).foregroundStyle(.secondary)
            LabeledContent {
                if let amount = detail.paidAmountText { Text(verbatim: amount) }
                else { Text("clubOps.customer.amountHidden", tableName: "ClubOpsCustomer").foregroundStyle(.secondary) }
            } label: { Text("clubOps.customer.paidAmount", tableName: "ClubOpsCustomer") }
                .accessibilityIdentifier("clubOps.customer.paidAmount")
            if let phone = detail.phoneText { Text(verbatim: phone).font(.footnote).foregroundStyle(.secondary) }
        }
        Section {
            // Mini-program customer-detail: three metric tiles (到店 / 待核销 / 已退款), numerals first.
            HStack(spacing: CYSpacing.sm) {
                ClubOpsCustomerMetricTile(value: .known(detail.arrivedCount), label: "clubOps.customer.arrived")
                ClubOpsCustomerMetricTile(value: .known(detail.pendingCount), label: "clubOps.customer.pending")
                ClubOpsCustomerMetricTile(value: .known(detail.refundedCount), label: "clubOps.customer.refunded")
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
        } header: { Text("clubOps.customer.overview", tableName: "ClubOpsCustomer") }
        Section {
            if detail.records.isEmpty {
                Text("clubOps.customer.recordsEmpty", tableName: "ClubOpsCustomer").foregroundStyle(.secondary)
                    .accessibilityIdentifier("clubOps.customer.recordsEmpty")
            }
            ForEach(detail.records) { record in
                if let action = topicAction(record) {
                    Button(action: action.open) { ClubOpsCustomerRecordRow(record: record, linked: true) }
                        .accessibilityIdentifier("club.gov.customer.topic.\(action.id)")
                } else { ClubOpsCustomerRecordRow(record: record, linked: false) }
            }
        } header: { Text("clubOps.customer.records", tableName: "ClubOpsCustomer") }
        Section {
            if !detail.tags.isEmpty {
                ClubOpsTagFlow(tags: detail.tags)
            }
            if let remark = detail.remark { Text("clubOps.customer.remark \(remark)", tableName: "ClubOpsCustomer") }
            else { Text("clubOps.customer.noRemark", tableName: "ClubOpsCustomer").foregroundStyle(.secondary) }
            if detail.canEdit, let editButton { editButton }
        } header: { Text("clubOps.customer.tagsAndRemark", tableName: "ClubOpsCustomer") }
    }
    @ViewBuilder private var interaction: some View {
        if let day = detail.lastInteraction {
            if let remark = detail.remark { Text("clubOps.customer.interactionRemark \(day.month) \(day.day) \(remark)", tableName: "ClubOpsCustomer") }
            else { Text("clubOps.customer.interaction \(day.month) \(day.day)", tableName: "ClubOpsCustomer") }
        } else { Text("clubOps.customer.noInteraction", tableName: "ClubOpsCustomer") }
    }
}

struct ClubOpsCustomerMetricTile: View {
    let value: ClubCustomerDetailCount
    let label: LocalizedStringKey
    var body: some View {
        VStack(spacing: CYSpacing.xs) {
            Text(verbatim: value.displayText).font(CYTypography.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            Text(label, tableName: "ClubOpsCustomer").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.md)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct ClubOpsCustomerRecordRow: View {
    let record: ClubOpsCustomerRecord
    let linked: Bool
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                if let day = record.day { Text(day, format: .number).font(.title3.bold()) }
                if let month = record.month { Text("clubOps.customer.month \(month)", tableName: "ClubOpsCustomer").font(.caption2).foregroundStyle(.secondary) }
            }.frame(minWidth: 36)
            VStack(alignment: .leading, spacing: 2) {
                if let title = record.title { Text(verbatim: title).font(.body) }
                else { Text("clubOps.customer.untitled", tableName: "ClubOpsCustomer") }
                HStack(spacing: 0) {
                    Text(LocalizedStringKey(record.status.localizationKey), tableName: "ClubOpsCustomer").foregroundStyle(tone)
                    if linked { Text("clubOps.customer.viewTopic", tableName: "ClubOpsCustomer").foregroundStyle(.secondary) }
                }.font(.footnote)
            }
        }
    }
    private var tone: Color {
        switch record.status {
        case .verified: return CYColor.successText
        case .pending, .contacted: return CYColor.warningText
        case .refunded: return CYColor.dangerText
        case .cancelled, .registered: return CYColor.textTertiary
        }
    }
}

struct ClubOpsTagFlow: View {
    let tags: [String]
    var removable: ((Int) -> Void)? = nil
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    if let removable {
                        Button { removable(index) } label: {
                            HStack(spacing: 2) { Text(verbatim: tag); Text(verbatim: "×") }
                        }.buttonStyle(.borderless)
                            .accessibilityLabel(Text("clubOps.customer.removeTag \(tag)", tableName: "ClubOpsCustomer"))
                            .accessibilityIdentifier("clubOps.customer.removeTag.\(index)")
                            .modifier(ClubOpsChip())
                    } else { Text(verbatim: tag).modifier(ClubOpsChip()) }
                }
            }
        }
    }
}

private struct ClubOpsChip: ViewModifier {
    func body(content: Content) -> some View {
        content.font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs)
            .background(Capsule().fill(CYColor.bgRaised))
    }
}

/// Inline chip editor for saveCustomer. It edits the existing draft text fields only.
struct ClubOpsCustomerTagRemarkEditor: View {
    @Binding var tagsText: String
    @Binding var remark: String
    @State private var input = ""
    @State private var issue: ClubOpsCustomerTagRemarkDraft.Issue?
    var body: some View {
        let draft = ClubOpsCustomerTagRemarkDraft(tagsText: tagsText)
        if !draft.tags.isEmpty {
            ClubOpsTagFlow(tags: draft.tags) { index in
                var next = draft; next.remove(at: index); tagsText = next.tagsText; issue = nil
            }
        }
        HStack {
            TextField(text: $input) { Text("clubOps.customer.tagPlaceholder", tableName: "ClubOpsCustomer") }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .onSubmit(add)
                .accessibilityIdentifier("club.gov.input.tags")
            Button(action: add) { Text("clubOps.customer.addTag", tableName: "ClubOpsCustomer") }
                .buttonStyle(.borderless)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("clubOps.customer.addTag")
        }
        TextField(text: $remark, axis: .vertical) { Text("clubOps.customer.remarkPlaceholder", tableName: "ClubOpsCustomer") }
            .accessibilityIdentifier("club.gov.input.remark")
        if let current = issue ?? ClubOpsCustomerTagRemarkDraft.issue(tagsText: tagsText, remark: remark) {
            Text(LocalizedStringKey(current.localizationKey), tableName: "ClubOpsCustomer").font(CYTypography.caption).foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("clubOps.customer.draftIssue")
        }
    }
    private func add() {
        var draft = ClubOpsCustomerTagRemarkDraft(tagsText: tagsText)
        if let problem = draft.add(input) { issue = problem; return }
        tagsText = draft.tagsText; input = ""; issue = nil
    }
}
