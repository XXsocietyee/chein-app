import SwiftUI

@MainActor struct AccountCollectionCouponsView: View {
    let reader: any AccountCollectionReading
    @StateObject private var model = OwnedCouponReadScreenModel()
    @State private var viewPresentation = OwnedCouponReadViewPresentation()
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter = AccountCollectionCouponFilter.all
    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var needsReturnRefresh = false
    private var key: AccountCollectionLoadKey { AccountCollectionLoadKey(reader: reader, query: submittedQuery) }
    private var request: OwnedCouponReadRequest { .list(ownerScope: key.scope, keyword: submittedQuery.isEmpty ? nil : submittedQuery) }
    var body: some View {
        let appearance = viewPresentation
        let presentation = appearance.permit
        let offeredRequest = request
        return List {
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(AccountCollectionCouponFilter.allCases) { option in
                            OrderFilterPill(title: LocalizedStringKey("accountCollection.coupons.filter." + option.rawValue),
                                            isSelected: filter == option) { filter = option }
                        }
                    }.padding(.horizontal, CYSpacing.pageHorizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("accountCollection.coupons.filter")
                if model.isLoading || model.loadedRequest != offeredRequest { CYSkeleton().listRowBackground(Color.clear).accessibilityLabel(Text("accountCollection.loading")) }
                else if let issue = model.issue(for: offeredRequest) {
                    AccountCollectionIssueView(issue: issue, retry: { model.schedule(request: offeredRequest, reader: reader, presentation: presentation) }, couponWallet: true)
                } else if let coupons = model.rows(for: offeredRequest) {
                    let rows = coupons.filter { filter.includes($0) }
                    if rows.isEmpty {
                        if filter == .all, submittedQuery.isEmpty {
                            CYEmptyStateView(
                                systemImage: "ticket",
                                title: "accountCollection.coupons.empty",
                                description: "accountCollection.coupons.empty.detail"
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            CYEmptyStateView(
                                systemImage: "line.3.horizontal.decrease.circle",
                                title: "accountCollection.coupons.filteredEmpty",
                                description: "accountCollection.coupons.filteredEmpty.detail"
                            )
                            .listRowBackground(Color.clear)
                        }
                    }
                    let selections = model.selections(for: offeredRequest, filter: filter)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, coupon in
                        let selection = selections[index]
                        NavigationLink {
                            AccountCollectionCouponDetailView(selection: selection, reader: reader).id(selection.id)
                        } label: { AccountCollectionCouponRow(coupon: coupon) }
                        .buttonStyle(QuestifyCardButtonStyle())
                        .questifyHidesLinkIndicator()
                        .accessibilityIdentifier("accountCollection.coupon.\(coupon.id)")
                        .questifyCardListRow()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appNavigationTitle("accountCollection.coupons.title")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("accountCollection.coupons.search"))
        .onSubmit(of: .search) { submittedQuery = searchText }
        .onChange(of: searchText) { _, text in
            if text.isEmpty, !submittedQuery.isEmpty { submittedQuery = "" }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.schedule(request: offeredRequest, reader: reader, presentation: presentation) } label: { Label("accountCollection.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("accountCollection.coupons.refresh")
            }
        }
        .onAppear {
            guard let permit = appearance.begin(model: model, request: offeredRequest, foreground: scenePhase == .active) else { return }
            if needsReturnRefresh {
                model.schedule(request: offeredRequest, reader: reader, presentation: permit)
            } else {
                model.scheduleListIfNeeded(request: offeredRequest, reader: reader, presentation: permit)
            }
            if scenePhase == .active { needsReturnRefresh = false }
        }
        .onChange(of: key) { _, _ in
            guard let permit = appearance.replace(model: model, request: offeredRequest, foreground: scenePhase == .active) else { return }
            model.schedule(request: offeredRequest, reader: reader, presentation: permit)
        }
        .refreshable { await model.refresh(request: offeredRequest, reader: reader, presentation: presentation) }
        .onChange(of: scenePhase) { _, phase in
            // A hidden list must still reread after the app left the foreground.
            if phase != .active { needsReturnRefresh = true }
            model.setForeground(phase == .active, request: offeredRequest, reader: reader, presentation: presentation)
            if phase == .active, let presentation, presentation.isActive,
               model.presentation === presentation { needsReturnRefresh = false }
        }
        .onDisappear {
            appearance.end(model: model)
            if viewPresentation === appearance { viewPresentation = OwnedCouponReadViewPresentation() }
        }
    }
}

struct AccountCollectionCouponRow: View {
    let coupon: AccountCollectionCoupon
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccountCollectionCouponBadge(status: coupon.status)
            AccountCollectionTitle(value: coupon.name, fallback: "accountCollection.coupon.untitled")
                .font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let description = coupon.displayDescription, !description.isEmpty {
                Text(verbatim: description).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let day = coupon.futureStartDay(relativeTo: Date()) {
                Text("accountCollection.coupon.startsLater").font(CYTypography.meta)
                    .accessibilityIdentifier("accountCollection.coupon.futureStart")
                // Mini-program date line: {day} 起可用.
                QuestifyMetadataLine(label: "accountCollection.coupon.validFrom", value: day, systemImage: "calendar.badge.clock")
            }
            // The pill already says Invalid. Otherwise an unknown end date is an em dash, as in the mini-program.
            if coupon.status != .invalid {
                QuestifyMetadataLine(label: "accountCollection.coupon.validUntil",
                                     value: AccountCollectionCoupon.calendarDay(coupon.endTime) ?? "—", systemImage: "calendar")
            }
            if coupon.shopName != nil || coupon.shopAddress != nil {
                AccountCollectionCouponShopLine(coupon: coupon)
            }
        }.orderCardSurface()
    }
}

/// Public shop on a received coupon. Unknown name or address is left out, never an empty place.
struct AccountCollectionCouponShopLine: View {
    let coupon: AccountCollectionCoupon
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
            Image(systemName: "storefront").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let name = coupon.shopName { Text(verbatim: name).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textPrimary) }
                if let address = coupon.shopAddress {
                    Text(verbatim: address).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("accountCollection.coupon.shop")
    }
}
