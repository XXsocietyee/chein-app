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
                    if !offer.hasSupportedTerms { Text("原授权范围无法按当前合同解释；不能忽略限制后继续领取或购买。").fixedSize(horizontal: false, vertical: true) }
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
        .confirmationDialog("确认取消原未付款订单？这不会申请退款或撤销已授予的许可。", isPresented: $confirmingCancellation) {
            Button("确认提交原订单取消", role: .destructive) { Task { await controller.cancel() } }
            Button("返回", role: .cancel) { }
        }
        .sheet(isPresented: $confirming, onDismiss: { reviewedOffer = nil }) {
            Group {
                if let reviewedOffer {
                    NavigationStack {
                        Form {
                            Section {
                                Text(verbatim: reviewedOffer.title).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: price(reviewedOffer.currency, minor: reviewedOffer.priceMinor)).font(.headline).monospacedDigit()
                                CommerceFact("moduleId", reviewedOffer.moduleId)
                                CommerceFact("version", reviewedOffer.releaseId)
                                if let accountID = session.account?.id { Text(verbatim: "本次取得许可的账号：\(accountID)") }
                                Text("本次许可归属当前账号；下列可安装主体与场地范围是独立限制，不代表已取得经营、地点同意或发布权限。").font(.body).fixedSize(horizontal: false, vertical: true)
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
            if controller.licenseSnapshotLoading { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(commerceText("loadingLicense")) }
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
                Section("原已购版本当前记录") {
                    if let record = controller.ownedReleaseRecord {
                        Text(verbatim: "本次版本读取时的许可状态：" + record.licenseState).font(.headline).fixedSize(horizontal: false, vertical: true)
                        if record.licenseState != item.status { Text("两次读取之间许可状态有变化，请刷新原许可；旧 ACTIVE 不授予继续运行。") }
                        Text(verbatim: "原使用期限合同：" + record.useDuration)
                        Text(verbatim: "已购 release：" + record.releaseId)
                        Text(verbatim: "原版本记录状态：" + record.artifactStatus)
                        if !record.artifactIdentityMatched { Text("当前版本记录与原购入身份不匹配或缺失，不能用别的版本替代。") }
                        if let reason = record.blockReason, !reason.isEmpty { Text(verbatim: reason) }
                        Text("持久许可证与版本可用性分别记录。ACTIVE 不是可运行批准；安装、原运行、内容与地区仍需原服务当前检查。").font(.body).fixedSize(horizontal: false, vertical: true)
                    } else { Text("原版本记录读取未配置或暂不可用。保留原许可详情，不把它猜成已撤销或仍可运行。") }
                    Text("退款记录、会话到期或安装预留到期都不自动等于全部持久许可作废；这里不扩展更新版本或使用期限。").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Section("原退款 / 拒付记录") {
                    if let status = controller.reversalStatus {
                        Text(verbatim: "当前许可状态：" + (status.licenseState ?? "UNKNOWN"))
                        Text(verbatim: "拒付查询能力：" + (status.chargebackQueryCapability ?? "NOT_CAPTURED"))
                        Text("能力字段不是渠道观察。未实现、未配置或旧服务未提供，均不能证明没有拒付；这里不发起渠道查询。").font(.body).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: "已确认退款：\(status.currency) \(Decimal(status.refundedBuyerMinor) / Decimal(100))").monospacedDigit()
                        Text(verbatim: "已确认拒付：\(status.currency) \(Decimal(status.chargedBackBuyerMinor) / Decimal(100))").monospacedDigit()
                        ForEach(status.reversals, id: \.reversalKey) { item in
                            VStack(alignment: .leading) {
                                Text(verbatim: item.reversalKey).font(.footnote).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: item.kind + " / " + item.state).font(.headline)
                                Text(verbatim: "原查询记录：" + (item.queryObservation ?? "NOT_CAPTURED"))
                                if item.queryAttempted == true, let at = item.queryAttemptedAt {
                                    Text(verbatim: "原查询尝试时间：" + at)
                                } else {
                                    Text("没有本条已捕获的渠道查询尝试；未补造历史查询时间。")
                                }
                                Text(verbatim: "原处理金额：\(status.currency) \(Decimal(item.buyerMinor) / Decimal(100))").monospacedDigit()
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        if status.reversals.isEmpty { Text("原账暂无处理记录；不代表退款申请已获批准或渠道没有其他待同步事实。") }
                        Text("这里只读原账。处理中、UNKNOWN 和未读到结果不是退款成功；不会查询渠道或创建/执行退款。").font(.body).fixedSize(horizontal: false, vertical: true)
                    } else { Text("原退款状态读取未配置或暂不可用；不把它显示成无退款。原许可详情仍可查看。") }
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
            Text("原条款未提供组合授权。不得推断允许翻译、改编、remix、嵌入分发或任意主体/场地使用；安装仍由原许可与当前权限检查。")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
private struct CommerceCompositionScopeFacts: View {
    let rights: WorkshopCommerceCompositionRights
    var body: some View {
        Group {
            Text("原冻结组合授权范围").font(.headline)
            Text(verbatim: "合同：" + rights.profile)
            Text(verbatim: "授权摘要：" + rights.grantHash).font(.footnote).monospaced().fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "可复用作者：" + ids(rights.scope.authors))
            Text(verbatim: "可安装主体：" + ids(rights.scope.installationSubjects))
            Text(verbatim: "经营主体/门店：" + ids(rights.scope.venues))
            Text(verbatim: "地区：" + rights.scope.regions.joined(separator: ", "))
            if rights.hasExplicitPhysicalVenues, let pois = rights.scope.venuePoiIds {
                Text(verbatim: "明确许可的地点 POI：" + ids(pois))
            } else {
                Text("未提供明确地点 POI 授权；不得把经营主体 ID 当作任意地点许可。")
            }
            permission("商业使用", rights.scope.commercialUse)
            permission("翻译", rights.scope.translation)
            permission("改编", rights.scope.adaptation)
            permission("Remix", rights.scope.remix)
            permission("在已批准组合中嵌入分发", rights.scope.embeddedRedistribution)
            Text("以上只表示原冻结合同范围，不授予原始资产转售/下载、未来所有大版本、额外安装额度或当前地点同意。缺省项不扩权；当前撤权及安全条件仍由原服务检查。")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func ids(_ values: [Int64]) -> String { values.map { String($0) }.joined(separator: ", ") }
    private func permission(_ name: String, _ allowed: Bool) -> Text {
        Text(verbatim: name + "：" + (allowed ? "合同范围内允许" : "不允许"))
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
                .foregroundStyle(isError ? Color.red : Color.secondary)
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
