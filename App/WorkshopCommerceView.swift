import SwiftUI

@MainActor struct WorkshopCommerceAccountLink: View {
    let makeController: () -> WorkshopCommerceController?
    var makeInstallationController: (ModInstallationIdentity) -> ModInstallationController? = { _ in nil }
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    var initialOfferId: String? = nil
    var body: some View { NavigationLink { WorkshopCommerceEntry(makeController: makeController, makeInstallationController: makeInstallationController, makeOriginalReader: makeOriginalReader, makeInstallationPair: makeInstallationPair, initialOfferId: initialOfferId) } label: { commerceText("title") } }
}
@MainActor private struct WorkshopCommerceEntry: View {
    let makeController: () -> WorkshopCommerceController?
    var makeInstallationController: (ModInstallationIdentity) -> ModInstallationController? = { _ in nil }
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    var initialOfferId: String? = nil
    @State private var controller: WorkshopCommerceController?
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    var body: some View {
        Group {
            if let controller, controller.isCurrent { WorkshopCommerceView(controller: controller, makeInstallationController: makeInstallationController, makeOriginalReader: makeOriginalReader, makeInstallationPair: makeInstallationPair, initialOfferId: initialOfferId).id(ObjectIdentifier(controller)) }
            else {
                ContentUnavailableView {
                    Label { commerceText("title") } icon: { Image(systemName: "storefront") }
                } description: { commerceText("unavailable") }
            }
        }
        .modifier(WorkshopLibrarySurface())
        .navigationTitle(commerceString("title", locale: locale)).navigationBarTitleDisplayMode(.inline)
        .onAppear { if controller?.isCurrent != true { reopen() } }
        .onChange(of: session.sessionRevision) { _, _ in reopen() }
        .onChange(of: session.account?.id) { _, _ in reopen() }
        .onChange(of: session.account?.effectiveRole) { _, _ in reopen() }
        // Pushing installation is not logout. The captured lease rejects identity/realm/approval
        // changes; returning to this screen reopens a stale controller instead of leaving it dead.
    }
    private func reopen() { controller?.invalidate(); controller = makeController() }
}
@MainActor private struct WorkshopCommerceView: View {
    @State var controller: WorkshopCommerceController
    var makeInstallationController: (ModInstallationIdentity) -> ModInstallationController? = { _ in nil }
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    var initialOfferId: String? = nil
    @State private var confirming = false
    @State private var reviewedOffer: WorkshopCommerceOffer?
    @State private var confirmingCancellation = false
    @State private var initialOfferOpened = false
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Form {
            Section {
                ForEach(controller.offers, id: \.offerId) { item in
                    Button {
                        Task { await controller.preview(item.offerId) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s3) {
                            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                Text(verbatim: item.title).font(.headline).foregroundStyle(.primary)
                                Text(verbatim: price(item.currency, minor: item.priceMinor)).font(.body).monospacedDigit().foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if controller.offer?.offerId == item.offerId {
                                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                            } else {
                                Image(systemName: "chevron.forward").foregroundStyle(.secondary).accessibilityHidden(true)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Theme.Space.s2)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                    }
                    .accessibilityAddTraits(controller.offer?.offerId == item.offerId ? .isSelected : [])
                    .disabled(controller.busy)
                }
                if controller.offers.isEmpty { WorkshopCommerceLibraryNotice(text: commerceText("catalogEmpty"), symbol: "square.grid.2x2") }
                if let message = controller.messageKey, ["error.catalogUnavailable", "error.offerUnavailable"].contains(message) {
                    WorkshopCommerceLibraryNotice(text: commerceText(message), symbol: "exclamationmark.triangle", isError: true)
                }
                Button { Task { await controller.loadOffers() } } label: { Text("workshopCommerce.refreshCatalog", tableName: "WorkshopCommerce") }.disabled(controller.busy)
                if controller.hasMoreOffers {
                    Button { Task { await controller.loadOffers(more: true) } } label: { Text("workshopCommerce.moreOffers", tableName: "WorkshopCommerce") }.disabled(controller.busy)
                }
            } header: { commerceText("approvedOffer") }
            if let offer = controller.offer {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.s3) {
                        Text(verbatim: offer.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: price(offer.currency, minor: offer.priceMinor)).font(.title3.weight(.semibold)).monospacedDigit()
                    }.padding(.vertical, Theme.Space.s2)
                    CommerceFact("version", offer.releaseId)
                    CommerceTermsFacts(terms: offer.terms)
                    commerceText("purchaseBoundary").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !offer.hasSupportedTerms { Text("workshopCommerce.r2.unsupportedTerms").fixedSize(horizontal: false, vertical: true) }
                    Button { reviewedOffer = offer; confirming = true } label: { commerceText(offer.priceMinor == 0 ? "claimFree" : "confirmIntent").frame(maxWidth: .infinity) }.disabled(!controller.canAcquire)
                        .modifier(WorkshopLibraryPrimaryAction())
                }
            }
            if let order = controller.order {
                Section {
                    CommerceState(raw: order.state.rawValue)
                    CommerceFact("originalAmount", commerceAmount(order.currency, minor: order.amountMinor, locale: locale, includesCurrencyCode: true)).monospacedDigit()
                    CommerceFact("originalOrder", order.orderKey)
                    if let acquired = controller.acquiredLicense, acquired.order.orderKey == order.orderKey {
                        commerceText("grantConfirmed")
                        NavigationLink {
                            WorkshopCommerceLicenseDetailView(controller: controller, licenseId: acquired.license.licenseId)
                        } label: { commerceText("viewOriginalLicense") }
                        .accessibilityIdentifier("workshopCommerce.resultLicense")
                        .disabled(controller.busy)
                    }
                    if controller.canPay { Button { Task { await controller.pay() } } label: { commerceText("continuePayment").frame(maxWidth: .infinity) }.modifier(WorkshopLibraryPrimaryAction()) }
                    if controller.canCancel { Button { confirmingCancellation = true } label: { Text("workshopCommerce.requestCancellation", tableName: "WorkshopCommerce") }.disabled(controller.busy) }
                } header: { commerceText("serverOrder") }
            }
            if controller.order == nil && controller.canCancel {
                Button { Task { await controller.cancel() } } label: { Text("workshopCommerce.requestCancellation", tableName: "WorkshopCommerce") }
            }
            if let message = controller.messageKey, !["error.catalogUnavailable", "error.offerUnavailable"].contains(message) { WorkshopCommerceLibraryNotice(text: commerceText(message), symbol: "exclamationmark.circle", isError: true) }
            Section {
                Button { Task { await controller.recover() } } label: {
                    Label { commerceText("recover") } icon: { Image(systemName: "arrow.clockwise") }
                }.disabled(controller.busy)
                if let notice = controller.cancellationNotice { Text(verbatim: notice).fixedSize(horizontal: false, vertical: true) }
                WorkshopCommerceLibraryNotice(text: commerceText("digitalChannelBoundary"), symbol: "info.circle")
            }
            Section {
                ForEach(controller.licenses) { item in
                    Group {
                        VStack(alignment: .leading, spacing: Theme.Space.s2) {
                            Text(verbatim: item.moduleId).font(.headline)
                            Text(verbatim: item.purchasedVersionId).font(.body).foregroundStyle(.secondary)
                            CommerceState(raw: item.status)
                            Text(verbatim: item.licenseId).font(.footnote).monospaced().foregroundStyle(.secondary)
                        }.fixedSize(horizontal: false, vertical: true).padding(.vertical, Theme.Space.s2)
                        NavigationLink {
                            WorkshopCommerceLicenseDetailView(controller: controller, licenseId: item.licenseId)
                        } label: { commerceText("viewOriginalLicense") }
                        .accessibilityIdentifier("workshopCommerce.license." + item.licenseId)
                        .disabled(controller.busy)
                        let original = ModInstallationIdentity(licenseId: item.licenseId, moduleId: item.moduleId,
                            releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash)
                        ModInstallationOriginalRecoveryLink(reference: original, makeController: { reference in
                            if let makeInstallationPair { return makeInstallationPair(reference)?.controller }
                            return makeInstallationController(reference)
                        })
                        ModUpgradeOriginalRecoveryLink(reference: original)
                        if item.status == "ACTIVE" {
                            ModUpgradeLicenseLink(reference: .init(licenseId: item.licenseId, moduleId: item.moduleId,
                                releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash))
                            ModInstallationLicenseLink(reference: .init(licenseId: item.licenseId, moduleId: item.moduleId,
                                releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash),
                                makeController: makeInstallationController, makeOriginalReader: makeOriginalReader, makeInstallationPair: makeInstallationPair)
                        }
                    }
                }
                if controller.licenses.isEmpty { WorkshopCommerceLibraryNotice(text: commerceText("licensesEmpty"), symbol: "tray") }
                if let message = controller.licensesMessageKey { WorkshopCommerceLibraryNotice(text: commerceText(message), symbol: "exclamationmark.triangle", isError: true) }
                Button { Task { await controller.loadLicenses() } } label: { Text("workshopCommerce.refreshLicenses", tableName: "WorkshopCommerce") }.disabled(controller.busy)
                if controller.hasMoreLicenses {
                    Button { Task { await controller.loadLicenses(more: true) } } label: { Text("workshopCommerce.moreLicenses", tableName: "WorkshopCommerce") }.disabled(controller.busy)
                }
            } header: { commerceText("ownedLicenses") }

        }
        .modifier(WorkshopLibrarySurface())
        .navigationTitle(commerceString("title", locale: locale)).navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshOnEntry()
        }
        .onChange(of: scenePhase) { _, phase in
            // Backgrounding revokes only this unsubmitted confirmation, not the durable original
            // request. Foreground observation never creates/replays a purchase or dispatches payment.
            confirming = false; reviewedOffer = nil; confirmingCancellation = false
            if phase == .active { Task { await controller.recover(allowOriginalRequestReplay: false) } }
        }
        .confirmationDialog("workshopCommerce.r2.cancelOrder.title", isPresented: $confirmingCancellation) {
            Button("workshopCommerce.r2.cancelOrder.confirm", role: .destructive) { Task { await controller.cancel() } }
            Button("返回", role: .cancel) { }
        }
        .cySheet(isPresented: $confirming, onDismiss: { reviewedOffer = nil }) {
            Group {
                if let reviewedOffer {
                    NavigationStack {
                        Form {
                            Section {
                                Text(verbatim: reviewedOffer.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: price(reviewedOffer.currency, minor: reviewedOffer.priceMinor)).font(.headline).monospacedDigit()
                                CommerceFact("moduleId", reviewedOffer.moduleId)
                                CommerceFact("version", reviewedOffer.releaseId)
                                if let accountID = session.account?.id { Text("workshopCommerce.r2.licenseAccount \(String(accountID))") }
                                Text("workshopCommerce.r2.licenseScope").font(.body).fixedSize(horizontal: false, vertical: true)
                            }
                            Section { CommerceTermsFacts(terms: reviewedOffer.terms) }
                            commerceText("purchaseBoundary")
                            Button {
                                let confirmed = reviewedOffer
                                confirming = false
                                Task { await controller.confirmPurchase(reviewedOffer: confirmed) }
                            } label: { commerceText("confirm").frame(maxWidth: .infinity) }
                            .disabled(!controller.canAcquire || controller.offer != reviewedOffer)
                            .modifier(WorkshopLibraryPrimaryAction())
                        }
                        .modifier(WorkshopLibrarySurface())
                        .navigationTitle(commerceString("confirmationQuestion", locale: locale)).navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(role: .cancel) { confirming = false } label: { commerceText("cancel") }
                            }
                        }
                        .privacySensitive()
                    }
                }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }
    private func refreshOnEntry() async {
        await controller.recover(allowOriginalRequestReplay: false)
        guard !Task.isCancelled, controller.isCurrent else { return }
        await controller.loadOffers()
        if !initialOfferOpened, let initialOfferId { await controller.preview(initialOfferId) }
        if !Task.isCancelled { initialOfferOpened = true }
    }
    private func price(_ currency: String, minor: Int64) -> String {
        commerceAmount(currency, minor: minor, locale: locale)
    }
}
/// Back/close returns to the same catalog and owned-list state. No purchase, install or
/// publication is triggered by opening or refreshing this original-license receipt.
@MainActor struct WorkshopCommerceLicenseDetailView: View {
    let controller: WorkshopCommerceController
    let licenseId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Form {
            if controller.licenseSnapshotLoading { ProgressView { commerceText("loadingLicense") }.frame(maxWidth: .infinity) }
            else if let snapshot = controller.licenseSnapshot, snapshot.license.licenseId == licenseId, controller.isCurrent {
                let item = snapshot.license
                Section {
                    Text(verbatim: snapshot.offer.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    CommerceFact("originalAmount", commerceAmount(snapshot.order.currency, minor: snapshot.order.amountMinor, locale: locale, includesCurrencyCode: true)).monospacedDigit()
                    CommerceFact("moduleId", item.moduleId); CommerceFact("version", item.purchasedVersionId)
                    CommerceFact("acquisition", commerceString("acquisition." + item.acquisition, locale: locale))
                    CommerceFact("acquiredAt", item.acquiredAt)
                } header: { commerceText("originalLicense") }
                Section {
                    CommerceState(raw: item.status)
                    CommerceFact("usedInstallations", String(item.usedInstallations)).monospacedDigit()
                    if let reason = item.suspensionReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        CommerceFact("statusReason", reason)
                    } else if item.status != "ACTIVE" { commerceText("statusReasonUnavailable") }
                    commerceText("licenseIsNotPublication").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { commerceText("currentLicenseStatus") }
                Section {
                    CommerceFact("licenseId", item.licenseId); CommerceFact("originalOrder", item.orderKey)
                    CommerceFact("originalRequest", snapshot.order.requestId)
                    commerceText("originalLicenseBoundary").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Section { CommerceTermsFacts(terms: item.terms) } header: { commerceText("frozenTerms") }
                Section {
                    ModOwnedContentReportLink(reference: .init(licenseId: item.licenseId, moduleId: item.moduleId,
                        releaseId: item.purchasedVersionId, contentHash: item.terms.contentHash, termsHash: item.terms.hash))
                }
                Section("workshopCommerce.r2.release.section") {
                    if let record = controller.ownedReleaseRecord {
                        Text("workshopCommerce.r2.release.licenseState \(record.licenseState)").font(.headline).fixedSize(horizontal: false, vertical: true)
                        if record.licenseState != item.status { Text("workshopCommerce.r2.release.stateChanged") }
                        Text("workshopCommerce.r2.release.duration \(record.useDuration)")
                        Text("workshopCommerce.r2.release.id \(record.releaseId)")
                        Text("workshopCommerce.r2.release.status \(record.artifactStatus)")
                        if !record.artifactIdentityMatched { Text("workshopCommerce.r2.release.mismatch") }
                        if let reason = record.blockReason, !reason.isEmpty { Text(verbatim: reason) }
                        Text("workshopCommerce.r2.release.note").font(.body).fixedSize(horizontal: false, vertical: true)
                    } else { Text("workshopCommerce.r2.release.unavailable") }
                    Text("workshopCommerce.r2.release.footnote").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Section("workshopCommerce.r2.reversal.section") {
                    if let status = controller.reversalStatus {
                        Text("workshopCommerce.r2.reversal.licenseState \(status.licenseState ?? "UNKNOWN")")
                        Text("workshopCommerce.r2.reversal.capability \(status.chargebackQueryCapability ?? "NOT_CAPTURED")")
                        Text("workshopCommerce.r2.reversal.capabilityNote").font(.body).fixedSize(horizontal: false, vertical: true)
                        Text("workshopCommerce.r2.reversal.refunded \(reversalAmount(status.currency, status.refundedBuyerMinor))").monospacedDigit()
                        Text("workshopCommerce.r2.reversal.chargedBack \(reversalAmount(status.currency, status.chargedBackBuyerMinor))").monospacedDigit()
                        ForEach(status.reversals, id: \.reversalKey) { item in
                            VStack(alignment: .leading) {
                                Text(verbatim: item.reversalKey).font(.footnote).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: item.kind + " / " + item.state).font(.headline)
                                Text("workshopCommerce.r2.reversal.query \(item.queryObservation ?? "NOT_CAPTURED")")
                                if item.queryAttempted == true, let at = item.queryAttemptedAt {
                                    Text("workshopCommerce.r2.reversal.queryAt \(at)")
                                } else {
                                    Text("workshopCommerce.r2.reversal.noQuery")
                                }
                                Text("workshopCommerce.r2.reversal.amount \(reversalAmount(status.currency, item.buyerMinor))").monospacedDigit()
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        if status.reversals.isEmpty { Text("workshopCommerce.r2.reversal.empty") }
                        Text("workshopCommerce.r2.reversal.note").font(.body).fixedSize(horizontal: false, vertical: true)
                    } else { Text("workshopCommerce.r2.reversal.unavailable") }
                }

            } else { WorkshopCommerceLibraryNotice(text: commerceText(controller.licenseSnapshotMessageKey ?? "error.licenseUnavailable"), symbol: "exclamationmark.triangle", isError: true) }
            Button { Task { await controller.loadLicenseSnapshot(licenseId) } } label: { Text("workshopCommerce.refreshLicense", tableName: "WorkshopCommerce") }
                .disabled(controller.licenseSnapshotLoading || !controller.isCurrent)
            Button { dismiss() } label: { Text("workshopCommerce.returnToCatalog", tableName: "WorkshopCommerce") }
        }
        .modifier(WorkshopLibrarySurface())
        .navigationTitle(commerceString("originalLicense", locale: locale)).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task(id: licenseId) { await controller.loadLicenseSnapshot(licenseId) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await controller.loadLicenseSnapshot(licenseId) } }
        }
        .onDisappear { controller.closeLicenseSnapshot() }
    }
}
/// Refund/chargeback amounts as the ledger states them (currency code + major units); never re-labelled by locale.
private func reversalAmount(_ currency: String, _ minor: Int64) -> String { "\(currency) \(Decimal(minor) / Decimal(100))" }
private struct CommerceTermsFacts: View {
    let terms: WorkshopCommerceTerms
    @Environment(\.locale) private var locale
    var body: some View {
        CommerceFact("commercialUse", commerceString(terms.commercialUse ? "allowed" : "notAllowed", locale: locale))
        CommerceFact("duration", commerceString("policy." + terms.useDuration, locale: locale)); Text(verbatim: terms.useDuration).font(.footnote)
        CommerceFact("updates", commerceString("policy." + terms.updatePolicy, locale: locale)); Text(verbatim: terms.updatePolicy).font(.footnote)
        CommerceFact("redistribution", commerceString("policy." + terms.redistribution, locale: locale)); Text(verbatim: terms.redistribution).font(.footnote)
        CommerceFact("installationLimit", String(terms.installationLimit)); CommerceFact("regions", terms.allowedRegions.joined(separator: ", "))
        CommerceFact("termsVersion", terms.version); CommerceFact("termsHash", terms.hash)
        CommerceFact("contentHash", terms.contentHash); CommerceFact("refundPolicy", terms.refundPolicyReference)
        if let rights = terms.compositionRights {
            CommerceCompositionScopeFacts(rights: rights)
        } else {
            Text("workshopCommerce.r2.noComposition")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
private struct CommerceCompositionScopeFacts: View {
    let rights: WorkshopCommerceCompositionRights
    var body: some View {
        Group {
            Text("workshopCommerce.r2.composition.title").font(.headline)
            Text("workshopCommerce.r2.composition.profile \(rights.profile)")
            Text("workshopCommerce.r2.composition.grantHash \(rights.grantHash)").font(.footnote).monospaced().fixedSize(horizontal: false, vertical: true)
            Text("workshopCommerce.r2.composition.authors \(ids(rights.scope.authors))")
            Text("workshopCommerce.r2.composition.subjects \(ids(rights.scope.installationSubjects))")
            Text("workshopCommerce.r2.composition.venues \(ids(rights.scope.venues))")
            Text("workshopCommerce.r2.composition.regions \(rights.scope.regions.joined(separator: ", "))")
            if rights.hasExplicitPhysicalVenues, let pois = rights.scope.venuePoiIds {
                Text("workshopCommerce.r2.composition.pois \(ids(pois))")
            } else {
                Text("workshopCommerce.r2.composition.noPois")
            }
            permission("commercial", rights.scope.commercialUse)
            permission("translation", rights.scope.translation)
            permission("adaptation", rights.scope.adaptation)
            permission("remix", rights.scope.remix)
            permission("embedded", rights.scope.embeddedRedistribution)
            Text("workshopCommerce.r2.composition.note")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func ids(_ values: [Int64]) -> String { values.map { String($0) }.joined(separator: ", ") }
    private func permission(_ name: String, _ allowed: Bool) -> Text {
        Text(LocalizedStringKey("workshopCommerce.r2.permission." + name + (allowed ? ".allowed" : ".denied")))
    }
}
private struct CommerceFact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        WorkshopLibraryFact(label: commerceText(key), value: value)
    }
}
private struct CommerceState: View {
    let raw: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            WorkshopCommerceLibraryState(label: commerceText("state." + raw), raw: raw)
            Text(verbatim: raw).font(.footnote).monospaced().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, Theme.Space.s1)
    }
}
private func commerceText(_ key: String) -> Text { Text(LocalizedStringKey("workshopCommerce." + key), tableName: "WorkshopCommerce") }
private func commerceAmount(_ currency: String, minor: Int64, locale: Locale, includesCurrencyCode: Bool = false) -> String {
    let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = currency; formatter.locale = locale
    if includesCurrencyCode { formatter.currencySymbol = currency }
    formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
    return formatter.string(from: NSDecimalNumber(decimal: Decimal(minor) / Decimal(100))) ?? "\(currency) \(Decimal(minor) / Decimal(100))"
}
private func commerceString(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "workshopCommerce." + key), table: "WorkshopCommerce", locale: locale))
}


struct WorkshopLibrarySurface: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content
            .themeDomain(domain)
    }
}
struct WorkshopLibraryPrimaryAction: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent).controlSize(.large)
    }
}
struct WorkshopLibraryFact: View {
    let label: Text
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            label.font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: value).font(.body)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.s2)
        .accessibilityElement(children: .combine)
    }
}
struct WorkshopCommerceLibraryNotice: View {
    let text: Text
    let symbol: String
    var isError = false
    @Environment(\.themeDomain) private var domain
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.s3) {
            Image(systemName: symbol)
                .foregroundStyle(isError ? CYColor.dangerText : Color.secondary)
                .accessibilityHidden(true)
            text.foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.s3)
        .accessibilityElement(children: .combine)
    }
}
struct WorkshopCommerceLibraryState: View {
    let label: Text
    let raw: String
    private var symbol: String {
        switch raw {
        case "ACTIVE", "PAID", "ACQUIRED_FREE": return "checkmark.circle"
        case "REVOKED", "CANCELLED": return "xmark.circle"
        case "SUSPENDED", "EXPIRED", "UNAVAILABLE", "UNKNOWN": return "exclamationmark.circle"
        default: return "clock"
        }
    }
    var body: some View {
        Label { label.font(.headline).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: symbol).accessibilityHidden(true) }
            .accessibilityElement(children: .combine)
    }
}
