import SwiftUI

@MainActor struct AccountCollectionCouponsView: View {
    let reader: any AccountCollectionReading
    /// R7-MEM-9-1: a `coupon-qr?couponHistoryId=` link. Once the owner's list is read, an unused coupon with this
    /// history id opens its code; anything else stays on the list (the code page re-checks the owner anyway).
    var focusHistoryID: Int? = nil
    @State private var focusedCode: OwnedCouponCodeDestination?
    @State private var focusHandled = false
    @StateObject private var model = OwnedCouponReadScreenModel()
    @State private var viewPresentation = OwnedCouponReadViewPresentation()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.couponCodeFactory) private var makeCode
    @State private var filter = AccountCollectionCouponFilter.all
    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var needsReturnRefresh = false
    private var key: AccountCollectionLoadKey { AccountCollectionLoadKey(reader: reader, query: submittedQuery) }
    private var request: OwnedCouponReadRequest { .list(ownerScope: key.scope, keyword: submittedQuery.isEmpty ? nil : submittedQuery) }
    private func activePermit(foreground: Bool) -> OwnedCouponReadLifetime? {
        viewPresentation.permit ?? viewPresentation.begin(model: model, request: request, foreground: foreground)
    }

    /// The linked coupon, once the accepted list holds it unused for this owner (read once per screen).
    private var focusMatch: OwnedCouponDetailSelection? {
        guard let focusHistoryID, !focusHandled, makeCode != nil, model.loadedRequest == request,
              let coupon = model.rows(for: request)?.first(where: { $0.id == focusHistoryID }),
              coupon.status == .unused else { return nil }
        return OwnedCouponDetailSelection(historyID: coupon.id, ownerScope: request.ownerScope)
    }

    var body: some View {
        let appearance = viewPresentation
        let offeredRequest = request
        return List {
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login, couponWallet: true) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else {
                // Native r2: a menu Picker replaces the filter pills (same cases, same selection).
                Section {
                    Picker(selection: $filter) {
                        ForEach(AccountCollectionCouponFilter.allCases) { option in
                            Text(LocalizedStringKey("accountCollection.coupons.filter." + option.rawValue)).tag(option)
                        }
                    } label: {
                        Label("accountCollection.coupons.filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("accountCollection.coupons.filter")
                }
                if model.isLoading || model.loadedRequest != offeredRequest {
                    ProgressView { Text("accountCollection.loading") }.frame(maxWidth: .infinity)
                }
                else if let issue = model.issue(for: offeredRequest) {
                    AccountCollectionIssueView(issue: issue, retry: {
                        let permit = activePermit(foreground: scenePhase == .active)
                        model.schedule(request: offeredRequest, reader: reader, presentation: permit)
                    }, couponWallet: true)
                } else if let coupons = model.rows(for: offeredRequest) {
                    let rows = coupons.filter { filter.includes($0) }
                    if rows.isEmpty {
                        if filter == .all, submittedQuery.isEmpty {
                            ContentUnavailableView("accountCollection.coupons.empty", systemImage: "tray")
                                .accessibilityIdentifier("accountCollection.coupons.empty")
                        } else {
                            ContentUnavailableView("accountCollection.coupons.filteredEmpty", systemImage: "tray")
                                .accessibilityIdentifier("accountCollection.coupons.filteredEmpty")
                        }
                    }
                    let selections = model.selections(for: offeredRequest, filter: filter)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, coupon in
                        let selection = selections[index]
                        Group {
                            // MKT-8-1: as in the MP (coupon-wallet/index.js:165-170) an unused coupon opens its code in one tap.
                            if coupon.status == .unused, let makeCode {
                                let destination = OwnedCouponCodeDestination(selection: selection)
                                NavigationLink {
                                    OwnedCouponCodeDestinationView(destination: destination, reader: reader, factory: makeCode).id(destination.id)
                                } label: { AccountCollectionCouponRow(coupon: coupon, showsCodeFooter: true) }
                            } else {
                                NavigationLink {
                                    AccountCollectionCouponDetailView(selection: selection, reader: reader).id(selection.id)
                                } label: { AccountCollectionCouponRow(coupon: coupon) }
                            }
                        }
                        .overlay(alignment: Alignment(horizontal: .trailing, vertical: .couponShopLine)) { AccountCollectionCouponNavigateButton(coupon: coupon) }
                        .accessibilityIdentifier("accountCollection.coupon.\(coupon.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyDomainScreen(.player)
        .cyPageTitle("accountCollection.coupons.title")
        .cyHideTabBar()
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("accountCollection.coupons.search"))
        .onSubmit(of: .search) { submittedQuery = searchText }
        .onChange(of: searchText) { _, text in
            if text.isEmpty, !submittedQuery.isEmpty { submittedQuery = "" }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let permit = activePermit(foreground: scenePhase == .active)
                    model.schedule(request: offeredRequest, reader: reader, presentation: permit)
                } label: { Label("accountCollection.refresh", systemImage: "arrow.clockwise") }
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
        .refreshable {
            let permit = activePermit(foreground: scenePhase == .active)
            await model.refresh(request: offeredRequest, reader: reader, presentation: permit)
        }
        .onChange(of: scenePhase) { _, phase in
            // A hidden list must still reread after the app left the foreground.
            if phase != .active { needsReturnRefresh = true }
            let permit = activePermit(foreground: phase == .active)
            model.setForeground(phase == .active, request: offeredRequest, reader: reader, presentation: permit)
            if phase == .active, let permit, permit.isActive,
               model.presentation === permit { needsReturnRefresh = false }
        }
        .onChange(of: focusMatch, initial: true) { _, match in
            guard let match else { return }
            focusHandled = true
            focusedCode = OwnedCouponCodeDestination(selection: match)
        }
        .navigationDestination(isPresented: Binding(get: { focusedCode != nil }, set: { if !$0 { focusedCode = nil } })) {
            if let destination = focusedCode, let makeCode {
                OwnedCouponCodeDestinationView(destination: destination, reader: reader, factory: makeCode).id(destination.id)
            }
        }
        .onDisappear {
            appearance.end(model: model)
            if viewPresentation === appearance { viewPresentation = OwnedCouponReadViewPresentation() }
        }
    }
}

struct AccountCollectionCouponRow: View {
    let coupon: AccountCollectionCoupon
    /// MKT-8-1: list rows that open the code directly say so (出示核销码 / 查看可用时间).
    var showsCodeFooter = false
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // mp-mine r3: MP coupon card head — name, then the status badge at the end of the same line.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                AccountCollectionTitle(value: coupon.name, fallback: "accountCollection.coupon.untitled")
                    .font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                AccountCollectionCouponBadge(status: coupon.status)
            }
            if let description = coupon.displayDescription, !description.isEmpty {
                Text(verbatim: description).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // mp-mine r3: MP wallet-card order — head, description, shop address (导航 on the same line), then the date foot.
            if coupon.shopAddress != nil {
                AccountCollectionCouponShopLine(coupon: coupon)
                    .padding(.trailing, coupon.hasShopNavigation ? 96 : 0)
                    .frame(minHeight: coupon.hasShopNavigation ? 44 : 0)
                    .alignmentGuide(.couponShopLine) { d in d[VerticalAlignment.center] }
            }
            if let day = coupon.futureStartDay(relativeTo: Date()) {
                Text("accountCollection.coupon.startsLater").font(.subheadline)
                    .accessibilityIdentifier("accountCollection.coupon.futureStart")
                // Mini-program date line: {day} 起可用.
                QuestifyMetadataLine(label: "accountCollection.coupon.validFrom", value: appLocalized("couponWallet.validFrom \(day)", locale: locale),
                                     systemImage: "calendar.badge.clock")
            }
            // MP: an invalid coupon replaces the date line with 该券已被平台手动失效.
            if coupon.status == .invalid {
                Text("accountCollection.coupon.invalidHint").font(.subheadline).foregroundStyle(.secondary)
            }
            // Otherwise an unknown end date is an em dash, as in the mini-program.
            if coupon.status != .invalid {
                // MP `有效期至 {day}`; an unknown end date stays the bare em dash.
                QuestifyMetadataLine(label: "accountCollection.coupon.validUntil",
                                     value: AccountCollectionCoupon.calendarDay(coupon.endTime).map { appLocalized("couponWallet.validUntil \($0)", locale: locale) } ?? "—",
                                     systemImage: "calendar")
            }
            if showsCodeFooter {
                Label(coupon.futureStartDay(relativeTo: Date()) != nil ? "accountCollection.coupon.viewAvailability" : "couponCode.show",
                      systemImage: coupon.futureStartDay(relativeTo: Date()) != nil ? "calendar" : "qrcode")
                    .font(.subheadline).foregroundStyle(.tint)
                    .accessibilityIdentifier("accountCollection.coupon.codeFooter")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// mp-mine r3: the list's 导航 capsule sits on the shop line, as in the MP wallet card.
/// The row sets the guide to the shop line's centre; any view without it uses its own centre.
extension VerticalAlignment {
    private enum CouponShopLine: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.center] }
    }
    static let couponShopLine = VerticalAlignment(CouponShopLine.self)
}

/// Public shop on a received coupon. Unknown name or address is left out, never an empty place.
struct AccountCollectionCouponShopLine: View {
    let coupon: AccountCollectionCoupon
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "storefront").foregroundStyle(.tertiary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // MP wallet-card__shop draws the address only; the shop name is in the 导航 label.
                if let address = coupon.shopAddress {
                    Text(verbatim: address).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("accountCollection.coupon.shop")
    }
}

/// MKT-8-4: MP coupon cards open Maps from the shop line (coupon-wallet/index.wxml:12-15).
/// A separate borderless 44 pt button so the row's own push stays intact. Hidden without both coordinates.
struct AccountCollectionCouponNavigateButton: View {
    let coupon: AccountCollectionCoupon
    private var destination: PlatformMapDestination? {
        guard coupon.hasShopNavigation else { return nil }
        let value = PlatformMapDestination(name: coupon.shopName ?? coupon.shopAddress ?? "", address: coupon.shopAddress,
                                           latitude: coupon.shopLatitude, longitude: coupon.shopLongitude)
        return value.hasCoordinates ? value : nil
    }
    var body: some View {
        if let destination {
            Button {
                Task { _ = await NativePlatformMapOpener().open(destination) }
            } label: {
                Label("accountCollection.coupon.navigate", systemImage: "arrow.triangle.turn.up.right.diamond")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.vertical, 8)
            .accessibilityHint(Text("accountCollection.coupon.openInMaps"))
            .accessibilityIdentifier("accountCollection.coupon.list.navigate")
        }
    }
}
