import SwiftUI

struct WorkshopPurchasedAccountLink: View {
    let browser: WorkshopPurchasedBrowser?
    let makeProfessional: WorkshopPaidProfessionalControllerFactory
    let makeText: WorkshopPaidInstalledTextControllerFactory
    let makeInstall: WorkshopPaidInstallControllerFactory
    let makeUpgrade: WorkshopPurchasedUpgradeFactory
    init(browser: WorkshopPurchasedBrowser?, makeInstall: @escaping WorkshopPaidInstallControllerFactory = { _ in nil }, makeText: @escaping WorkshopPaidInstalledTextControllerFactory = { _ in nil }, makeProfessional: @escaping WorkshopPaidProfessionalControllerFactory = { _ in nil }, makeUpgrade: @escaping WorkshopPurchasedUpgradeFactory = { nil }) { self.browser = browser; self.makeInstall = makeInstall; self.makeText = makeText; self.makeProfessional = makeProfessional; self.makeUpgrade = makeUpgrade }
    var body: some View {
        NavigationLink {
            if let browser { WorkshopPurchasedLibraryView(browser: browser, makeInstall: makeInstall, makeText: makeText, makeProfessional: makeProfessional, makeUpgrade: makeUpgrade).id(browser.identity) }
            else { PurchasedUnavailableView().modifier(PurchasedTitle("title")) }
        } label: { Label { purchasedText("title") } icon: { Image(systemName: "checkmark.seal") } }
            .accessibilityIdentifier("account.workshopPurchased")
    }
}
@MainActor struct WorkshopPurchasedLibraryView: View {
    @State private var routeVisibility = WorkshopVisibleRouteReturn()
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    let browser: WorkshopPurchasedBrowser
    @State private var navigation: WorkshopPurchasedNavigationState
    let makeProfessional: WorkshopPaidProfessionalControllerFactory
    let makeText: WorkshopPaidInstalledTextControllerFactory
    let makeInstall: WorkshopPaidInstallControllerFactory
    let makeUpgrade: WorkshopPurchasedUpgradeFactory
    init(browser: WorkshopPurchasedBrowser, navigation: WorkshopPurchasedNavigationState? = nil, makeInstall: @escaping WorkshopPaidInstallControllerFactory = { _ in nil }, makeText: @escaping WorkshopPaidInstalledTextControllerFactory = { _ in nil }, makeProfessional: @escaping WorkshopPaidProfessionalControllerFactory = { _ in nil }, makeUpgrade: @escaping WorkshopPurchasedUpgradeFactory = { nil }) {
        self.browser = browser; self.makeInstall = makeInstall; self.makeText = makeText; self.makeProfessional = makeProfessional; self.makeUpgrade = makeUpgrade;         _navigation = State(initialValue: navigation ?? WorkshopPurchasedNavigationState(browser: browser))
    }
    private var paymentsOpen: Bool { ReviewedAreaSwitch.moneyPayments(apiHost: session.regionalConfiguration?.apiConfiguration?.baseURL.host) }
    private var closedCopy: String {
        locale.language.languageCode?.identifier == "zh"
            ? "购买读取未开启。列表仍在，本次不请求已购接口。"
            : "Purchase reads are off. The list stays here and does not request purchased licenses."
    }
    var body: some View {
        @Bindable var navigation = navigation
        let displayed = navigation.listAppearance
        let rendered = displayed.permit
        List {
            switch browser.phase {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity).accessibilityLabel(purchasedText("loading"))
            case .notEnabled: PurchasedUnavailableView()
            case .empty: purchasedText("empty")
            case .failed, .invalidated:
                purchasedText(browser.phase == .invalidated ? "sessionChanged" : "failed")
                if browser.phase != .invalidated { Button { if paymentsOpen { navigation.scheduleList(rendered) } } label: { purchasedText("retry") } }
            case .ready:
                if browser.issue == .unavailable { purchasedText("failed") }
                ForEach(browser.rows) { item in
                    Button { navigation.select(licenseId: item.id, presentation: rendered) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.moduleId).font(.headline).foregroundStyle(.primary)
                            Text(verbatim: item.purchasedVersionId).font(.subheadline).foregroundStyle(.secondary)
                            purchasedText("status." + item.status.rawValue).foregroundStyle(.primary)
                            purchasedText("perpetual").font(.footnote).foregroundStyle(.secondary)
                        }
                    }.accessibilityIdentifier("workshopPurchased.row." + item.id)
                }
                if let cursor = browser.nextCursor {
                    Button { if paymentsOpen { navigation.scheduleList(rendered, before: cursor) } } label: { purchasedText(browser.issue == .unavailable ? "retry" : "next") }
                }
            }
            if !paymentsOpen { Section { Label(closedCopy, systemImage: "info.circle").foregroundStyle(.secondary) } }
            if let checkedAt = browser.checkedAt { Section { Text(verbatim: checkedAt) } header: { purchasedText("checkedAt") } }
        }
        .modifier(PurchasedTitle("title"))
        .privacySensitive()
        .onAppear { routeVisibility.appear(); if paymentsOpen { navigation.scheduleList(navigation.listViewAppeared(displayed)) } }
        .onDisappear { routeVisibility.disappear(); navigation.listViewDisappeared(displayed) }
        .onChange(of: navigation.selection == nil) { wasEligible, isEligible in
            routeVisibility.returned(wasEligible: wasEligible, isEligible: isEligible) {
                guard navigation.selection == nil, displayed.permit == nil else { return }
                if paymentsOpen { navigation.scheduleList(navigation.listViewAppeared(displayed)) }
            }
        }
        .refreshable { if paymentsOpen, let action = navigation.offerList(rendered) { await action() } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { if paymentsOpen { navigation.scheduleList(rendered) } } label: { Label { purchasedText("refresh") } icon: { Image(systemName: "arrow.clockwise") } }
                .disabled(browser.phase == .loading || browser.phase == .invalidated)
        } }
        .navigationDestination(item: $navigation.selection) { selection in
            WorkshopPurchasedDetailView(browser: browser, licenseId: selection.id, navigation: navigation, makeInstall: makeInstall, makeText: makeText, makeProfessional: makeProfessional, makeUpgrade: makeUpgrade).id(selection.id)
        }
    }
}
@MainActor struct WorkshopPurchasedDetailView: View {
    let browser: WorkshopPurchasedBrowser
    let licenseId: String
    let navigation: WorkshopPurchasedNavigationState
    let makeProfessional: WorkshopPaidProfessionalControllerFactory
    let makeText: WorkshopPaidInstalledTextControllerFactory
    let makeInstall: WorkshopPaidInstallControllerFactory
    let makeUpgrade: WorkshopPurchasedUpgradeFactory
    @EnvironmentObject private var session: AppSession
    init(browser: WorkshopPurchasedBrowser, licenseId: String, navigation: WorkshopPurchasedNavigationState, makeInstall: @escaping WorkshopPaidInstallControllerFactory = { _ in nil }, makeText: @escaping WorkshopPaidInstalledTextControllerFactory = { _ in nil }, makeProfessional: @escaping WorkshopPaidProfessionalControllerFactory = { _ in nil }, makeUpgrade: @escaping WorkshopPurchasedUpgradeFactory = { nil }) {
        self.browser = browser; self.licenseId = licenseId; self.navigation = navigation; self.makeInstall = makeInstall; self.makeText = makeText; self.makeProfessional = makeProfessional;         self.makeUpgrade = makeUpgrade
    }
    private var paymentsOpen: Bool { ReviewedAreaSwitch.moneyPayments(apiHost: session.regionalConfiguration?.apiConfiguration?.baseURL.host) }
    var body: some View {
        let displayed = navigation.detailAppearance
        let rendered = displayed.permit
        Form {
            if browser.detailLoading { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(purchasedText("loading")) }
            else if let detail = browser.detail, detail.item.id == licenseId {
                let item = detail.item
                Section {
                    PurchasedFact("license", item.licenseId); PurchasedFact("module", item.moduleId)
                    PurchasedFact("version", item.purchasedVersionId)
                    purchasedText("status." + item.status.rawValue).accessibilityIdentifier("workshopPurchased.status")
                    PurchasedFact("acquiredAt", item.acquiredAt); PurchasedFact("checkedAt", detail.checkedAt)
                    purchasedText("perpetual").font(.headline)
                    purchasedText("durationScope").fixedSize(horizontal: false, vertical: true)
                } header: { purchasedText("record") }
                Section {
                    PurchasedFact("termsVersion", item.termsVersion)
                    PurchasedPolicy("commercialUse", item.commercialUse.rawValue)
                    PurchasedPolicy("adaptation", item.adaptation.rawValue)
                    PurchasedPolicy("translation", item.translation.rawValue)
                    purchasedText("exactVersion"); purchasedText("redistributionProhibited")
                    ForEach(item.allowedRegions, id: \.self) { Text(verbatim: $0) }
                    PurchasedLimit("themeLimit", item.themeLimit); PurchasedLimit("merchantLimit", item.merchantLimit); PurchasedLimit("runLimit", item.runLimit)
                } header: { purchasedText("frozenTerms") }
                Section {
                    purchasedText("purchaseUnavailable").fixedSize(horizontal: false, vertical: true)
                } header: { purchasedText("currentBoundary") }
                WorkshopPaidInstallEntry(item: item, makeController: makeInstall, makeProfessional: makeProfessional, makeText: makeText)
                if let handlers = makeUpgrade() { WorkshopPurchasedUpgradeEntry(item: item, handlers: handlers) }
            } else if let issue = browser.detailIssue {
                purchasedText(issue == .staleSession ? "sessionChanged" : issue == .notFound ? "notFound" : "failed")
                if issue != .staleSession { Button { if paymentsOpen { navigation.scheduleDetail(rendered, licenseId: licenseId) } } label: { purchasedText("retry") } }
            }
        }
        .modifier(PurchasedTitle("detail"))
        .toolbar {
            if let detail = browser.detail, detail.item.id == licenseId {
                ToolbarItem(placement: .topBarTrailing) {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .mod(modID: max(1, Int(detail.item.moduleId) ?? 1)),
                            subjectTitle: detail.item.moduleId
                        )
                    )
                    .accessibilityIdentifier("workshopPurchased.safetyMenu")
                }
            }
        }
        .privacySensitive()
        .onAppear { if paymentsOpen { navigation.scheduleDetail(navigation.detailViewAppeared(displayed, licenseId: licenseId), licenseId: licenseId) } }
        .onDisappear { navigation.detailViewDisappeared(displayed) }
        .refreshable { if paymentsOpen, let action = navigation.offerDetail(rendered, licenseId: licenseId) { await action() } }
    }
}
private struct PurchasedFact: View {
    let key: String, value: String
    @Environment(\.locale) private var locale
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        LabeledContent {
            Text(verbatim: value).textSelection(.enabled)
        } label: {
            Text(verbatim: purchasedLabel(key, locale: locale))
        }
        .accessibilityElement(children: .combine)
    }
}
private struct PurchasedPolicy: View {
    let key: String, policy: String
    @Environment(\.locale) private var locale
    init(_ key: String, _ policy: String) { self.key = key; self.policy = policy }
    var body: some View {
        LabeledContent {
            Text(verbatim: purchasedLabel("policy." + policy, locale: locale)).textSelection(.enabled)
        } label: {
            Text(verbatim: purchasedLabel(key, locale: locale))
        }
        .accessibilityElement(children: .combine)
    }
}
private struct PurchasedLimit: View {
    let key: String, value: WorkshopPurchasedItem.Limit
    @Environment(\.locale) private var locale
    init(_ key: String, _ value: WorkshopPurchasedItem.Limit) { self.key = key; self.value = value }
    var body: some View {
        LabeledContent {
            Text(verbatim: value.unlimited ? purchasedLabel("explicitUnlimited", locale: locale) : String(value.maximum)).textSelection(.enabled)
        } label: {
            Text(verbatim: purchasedLabel(key, locale: locale))
        }
        .accessibilityElement(children: .combine)
    }
}
private struct PurchasedUnavailableView: View {
    var body: some View { ContentUnavailableView { Label { purchasedText("unavailable") } icon: { Image(systemName: "icloud.slash") } } description: { purchasedText("unavailableDetail") } }
}
private struct PurchasedTitle: ViewModifier {
    let key: String
    @Environment(\.locale) private var locale
    init(_ key: String) { self.key = key }
    func body(content: Content) -> some View { content.navigationTitle(String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "workshopPurchased." + key), table: "WorkshopPurchased", locale: locale))).navigationBarTitleDisplayMode(.inline) }
}
private func purchasedLabel(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "workshopPurchased." + key), table: "WorkshopPurchased", locale: locale))
}
private func purchasedText(_ key: String) -> Text { Text(LocalizedStringKey("workshopPurchased." + key), tableName: "WorkshopPurchased") }
