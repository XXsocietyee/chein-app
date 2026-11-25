import SwiftUI

/// Add these scoped destinations to the existing PublishModes/project editor/topic hosts.
/// Default grants are dormant; UI review never changes activation policy.
@MainActor struct PublisherPricingView: View {
    let topicID: Int
    let client: PublisherLifecycleHTTP
    let coordinator: PublisherLifecycleCoordinator
    /// R7-PC-B4-6: `scope=MERCHANT` from the link; nil falls back to the topic's owner sale route (environment).
    var scope: String? = nil
    @Environment(\.topicPricingScope) private var routeScope
    private var pricingScope: String? { (scope ?? routeScope)?.uppercased() == "MERCHANT" ? "MERCHANT" : nil }
    /// PC-B-4-6: MP defaults to 有人带 (`subType: 'guided'`).
    @State private var subtype = PublisherPriceSubtype.guided
    @State private var cost = ""
    @State private var team = ""
    @State private var price = ""
    @State private var preview: PublisherPricingPreview?
    /// Source lineup names, loaded per row after the preview; missing names keep the type label.
    @State private var partnerNames: [String: String] = [:]
    @State private var review: PublisherLifecycleReview?
    @State private var message = ""
    @State private var busy = false
    @State private var loadFailed = false
    @State private var generation = UUID()
    @State private var visible = false
    @State private var resultSession: PublishingSession?
    /// R7-PC-B4-4 (MP pricing js:446-460): a confirmed price toasts and returns; a 支付资质 note is a modal first.
    @State private var successToast: String?
    @State private var paymentQualificationNote: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @Environment(\.pricingChapterProjectDestination) private var pricingChapterProjectDestination
    private func text(_ key: String) -> String { appLocalized(String.LocalizationValue(key), locale: locale) }
    /// pages/topic/pricing/index screen from the view's own read facts (TopicPricingXcx.screen).
    private var screen: TopicPricingXcx.Screen {
        let read: TopicPricingXcx.Read = topicID <= 0 ? .missingTopic : busy ? .loading : loadFailed ? .failed : .idle
        let keptPreview = resultSession == client.session ? preview : nil
        return TopicPricingXcx.screen(read: read, kept: keptPreview, subtype: subtype, teamSize: Int(team), price: Decimal(string: price))
    }
    /// Confirm stays hidden unless the existing pricing grant is present; the shipped factory keeps it dormant.
    private var showsConfirm: Bool {
        TopicPricingXcx.showsConfirm(baseURL: client.configuration.baseURL, playerFirstEntry: false,
                                     pricingGrantPresent: client.grants.pricing != nil)
    }
    var body: some View {
        Form {
            switch screen {
            case .empty:
                CYEmptyState(systemImage: "link", "publisherPricing.missingTopic", detail: "publisherPricing.missingTopicDetail",
                             messageIdentifier: "publisher.pricing.empty")
                    .listRowBackground(Color.clear)
            case .error(let failure):
                CYEmptyState(systemImage: "exclamationmark.triangle",
                             LocalizedStringKey(failure == .incomplete ? "publisherPricing.incomplete" : "publisherPricing.loadFailed"),
                             messageIdentifier: "publisher.pricing.error", actionTitle: "topic.retry",
                             actionIdentifier: "publisher.pricing.retry", action: { beginLoad() })
                    .listRowBackground(Color.clear)
            case .ready(let ready) where ready.refreshFailed:
                Label("publisherPricing.stalePreview", systemImage: "clock.arrow.circlepath")
                    .cyText(.meta).foregroundStyle(CYColor.warningText).accessibilityIdentifier("publisher.pricing.stale")
            default:
                EmptyView()
            }
            if topicID > 0 {
            Section {
                // Source chip tabs 有人带 / 无人带.
                Picker(text("publisherPricing.format"), selection: $subtype) {
                    Text(text("publisherPricing.guided")).tag(PublisherPriceSubtype.guided)
                    Text(text("publisherPricing.selfGuided")).tag(PublisherPriceSubtype.selfPlay)
                }.pickerStyle(.segmented).accessibilityIdentifier("publisher.subtype")
            }
            if subtype == .guided {
                Section(text("publisherPricing.leadCost")) {
                    // PC-B-4-5 (MP E24): each field keeps a standing label; a placeholder vanishes once typed.
                    pricingField(text("publisherPricing.totalLeadCostForThisGroup"), value: $cost, keyboard: .decimalPad)
                    pricingField(text("publisherPricing.groupSize"), value: $team, keyboard: .numberPad)
                    if (Int(team) ?? 0) <= 0 {
                        Text(text("publisherPricing.guidedPricingNeedsAGroupSize")).cyText(.meta).foregroundStyle(CYColor.dangerText)
                    }
                }
            }
            Section {
                CYPillButton(verbatim: subtype == .guided ? text("publisherPricing.recalculateFloor") : text("publisherPricing.refreshMinimumPrice"), style: .secondary) { beginLoad() }
                    .listRowBackground(Color.clear).disabled(busy).accessibilityIdentifier("publisher.preview")
                if busy { Text(text("publisherPricing.checkingTheLatestPricing")).cyText(.meta) }
            }
            if let preview, resultSession == client.session {
                Section(text("publisherPricing.costFloor")) {
                    // Floor reads TopicPricingXcx money text: two decimals, em dash when unknown, literal 0 stays 0.00.
                    Text(verbatim: "¥" + TopicPricingXcx.moneyText(decimal: preview.minimum)).cyText(.dataXL).monospacedDigit()
                        .foregroundStyle(CYColor.textPrimary)
                        .contentTransition(.numericText()).accessibilityIdentifier("publisher.floor")
                    Text("publisherPricing.floorIncludes").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    Text("publisherPricing.marginNote").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                Section(text("publisherPricing.yourFinalPrice")) {
                    TextField(text("publisherPricing.finalPrice"), text: $price).keyboardType(.decimalPad).accessibilityIdentifier("publisher.finalPrice")
                    let floorValue = TopicPricingXcx.initialPrice(floor: preview.minimum)
                    let maximum = TopicPricingXcx.sliderMax(floor: preview.minimum, reference: preview.reference)
                    Slider(value: Binding(get: { Double(price) ?? Double(floorValue) }, set: { price = String(Int($0.rounded())) }),
                           in: Double(floorValue)...Double(max(maximum, floorValue + 1)), step: 1)
                        .accessibilityLabel(Text(text("publisherPricing.finalPrice")))
                        .accessibilityValue(Text(verbatim: "¥" + (Int(price).map(String.init) ?? String(floorValue))))
                    HStack {
                        Text(verbatim: text("publisherPricing.floorShort") + " ¥" + TopicPricingXcx.moneyText(decimal: preview.minimum))
                        Spacer(); Text(verbatim: "¥\(maximum)")
                    }.cyText(.meta)
                    if let reference = preview.reference, let count = preview.sampleSize, count > 0 {
                        let area = preview.referenceLabel ?? text("publisherPricing.local")
                        let average = TopicPricingXcx.twoDecimals(NSDecimalNumber(decimal: reference).stringValue) ?? "—"
                        Text("publisherPricing.reference \(area) \(average) \(count)").cyText(.meta)
                    } else { Text(text("publisherPricing.notEnoughSamplesNoReferencePrice")).cyText(.meta) }
                    switch TopicPricingXcx.delta(price: Decimal(string: price) ?? preview.minimum, reference: preview.reference, sampleSize: preview.sampleSize) {
                    case .above(let percent)?: Text("publisherPricing.aboveReference \(percent)").cyText(.meta).foregroundStyle(CYColor.warningText)
                    case .notAbove?: Text(text("publisherPricing.notAboveTheLocalReferencePrice")).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    case nil: EmptyView()
                    }
                }
                if !preview.lineup.isEmpty {
                    Section {
                        ForEach(preview.lineup) { row in
                            NavigationLink {
                                // R7-PC-B4-7: a chapter-supply row (`chapterId`) opens the merchant 承接 page, like MP.
                                if TopicPricingXcx.opensChapterProject(row), let chapterProject = pricingChapterProjectDestination {
                                    chapterProject(topicID)
                                } else {
                                    PublisherPartnerView(topicID: topicID, row: row, client: client)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                    if let name = partnerNames[row.id] { Text(verbatim: name).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                                    else { Text(row.type == "club" ? text("publisherPricing.partnerClub") : text("publisherPricing.hostingMerchant")).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                                    Text(verbatim: termsText(row)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                            }
                        }
                    } header: { Text(text("publisherPricing.partnerLineup")) } footer: {
                        Text("publisherPricing.lineupLocked")
                    }
                }
                Section {
                    if preview.canConfirm == false {
                        Text("publisherPricing.phaseBlockedDetail").cyText(.meta).foregroundStyle(CYColor.warningText)
                            .accessibilityIdentifier("publisher.phaseBlocked")
                    }
                    if showsConfirm {
                        CYPillButton(verbatim: text("publisherPricing.confirmFinalPriceAndSubmitFor")) { beginPrepare() }
                            .listRowBackground(Color.clear).disabled(busy || preview.canConfirm == false).accessibilityIdentifier("publisher.reviewPrice")
                    } else {
                        // R7-PC-B4-1 (owner decision pending): the page is read-only without the pricing grant — say so.
                        Text("publisherPricing.confirmNotOpen").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("publisher.confirmNotOpen")
                    }
                }
            }
            }
            if let review, review.session == client.session, review.action == currentAction {
                Section(text("publisherPricing.review")) {
                    Text(text("publisherPricing.salesOpenAtThisPriceAnd"))
                    Text(price).accessibilityIdentifier("publisher.reviewedPrice")
                    Button(text("publisherPricing.confirmOpeningSales"), role: .destructive) { beginConfirm(review) }.disabled(busy).accessibilityIdentifier("publisher.confirmPrice")
                }
            }
            if !message.isEmpty, resultSession == client.session { Text(message).accessibilityIdentifier("publisher.message") }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .cyToast(verbatimMessage: $successToast, tone: .success)
        .alert(Text("publisherPricing.confirmedTitle"), isPresented: Binding(
            get: { paymentQualificationNote != nil }, set: { if !$0 { paymentQualificationNote = nil } })) {
            Button("publisherPricing.gotIt") { paymentQualificationNote = nil; dismiss() }
        } message: { Text(verbatim: paymentQualificationNote ?? "") }
        // PC-B-4-7: the page title is drawn once, inline by the bar (no in-content hero header).
        .cyPageTitle(verbatim: text("publisherPricing.confirmFinalPrice"))
        .cyPushedChrome(domain: .merchant)
        .task(id: preview?.lineup.map(\.id) ?? []) { await loadPartnerNames() }
        // Mini-program pages/topic/pricing calls preview() in onLoad: load the floor without a manual tap.
        // PC-B-4-6: load the floor on open whenever the inputs allow it (guided needs a group size).
        .task { visible = true; if preview == nil, !busy, subtype == .selfPlay || (Int(team) ?? 0) > 0 { beginLoad() } }
        .onAppear { visible = true }
        .onChange(of: topicID) { _, _ in invalidate() }
        .onChange(of: client.session) { _, _ in invalidate() }
        .onChange(of: subtype) { _, _ in invalidate() }
        .onChange(of: cost) { _, _ in invalidate() }
        .onChange(of: team) { _, _ in invalidate() }
        .onChange(of: price) { _, _ in invalidate(keepPreview: true) }
        .onChange(of: phase) { _, value in if value != .active { invalidate() } }
        .onDisappear { visible = false; invalidate() }
    }
    private func loadPartnerNames() async {
        guard let lineup = preview?.lineup else { return }
        let stamp = generation
        for row in lineup where partnerNames[row.id] == nil {
            guard let name = try? await client.partnerName(type: row.type, id: row.partnerID), generation == stamp, !Task.isCancelled else { continue }
            partnerNames[row.id] = name
        }
    }
    private func termsText(_ row: PublisherLineup) -> String {
        switch TopicPricingXcx.terms(row) {
        case .chapterPerk: return text("publisherPricing.chapterSupplyPerks")
        case .chapterTraffic: return text("publisherPricing.chapterSupplyReferral")
        case .chapterRevshare(let fee): return appLocalized("publisherPricing.terms.chapterRevshare \(fee ?? "—")", locale: locale)
        case .share(let rate): return appLocalized("publisherPricing.terms.share \(rate.map { $0 + "%" } ?? "—")", locale: locale)
        case .fixed(let fee): return fee.map { appLocalized("publisherPricing.terms.fixed \($0)", locale: locale) } ?? appLocalized("publisherPricing.terms.fixedUnknown", locale: locale)
        case .traffic: return text("publisherPricing.referral")
        }
    }
    private var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    private func input() throws -> PublisherPricingInput { try .init(topicID: topicID, subtype: subtype, leadCost: Decimal(string: cost), teamSize: Int(team), scope: pricingScope) }
    private var currentAction: PublisherLifecycleAction? {
        guard let value = Decimal(string: price), let input = try? input() else { return nil }
        return .pricing(input, value)
    }
    private var formKey: [String] { [String(topicID), String(describing: subtype), cost, team, price] }
    private func invalidate(keepPreview: Bool = false) {
        generation = UUID(); review = nil; message = ""; busy = false; loadFailed = false
        if !keepPreview { preview = nil; partnerNames = [:]; resultSession = nil }
        coordinator.invalidate()
    }
    private func isCurrent(_ stamp: UUID, _ session: PublishingSession, _ key: [String]) -> Bool {
        visible && phase == .active && generation == stamp && client.session == session && coordinator.currentSession == session && formKey == key
    }
    private func pricingField(_ label: String, value: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: label).cyText(.label).foregroundStyle(CYColor.textSecondary)
            TextField(text: value, prompt: Text(verbatim: "0")) { Text(verbatim: label) }
                .keyboardType(keyboard).cyText(.numericBody)
        }
    }
    private func beginLoad() {
        guard visible, phase == .active, !busy, let session = client.session,
              coordinator.currentSession == session else { return }
        let capturedInput: PublisherPricingInput
        do { capturedInput = try input() }
        catch { message = PublisherLifecycleCopy.error(error, zh: isChinese); resultSession = session; loadFailed = true; return }
        invalidate()
        let stamp = generation, key = formKey
        busy = true
        Task {
            guard isCurrent(stamp, session, key), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, key) { busy = false } }
            do {
                let value = try await client.pricing(capturedInput)
                guard isCurrent(stamp, session, key), !Task.isCancelled else { return }
                busy = false; preview = value; loadFailed = false; resultSession = session
                price = String(TopicPricingXcx.initialPrice(floor: value.minimum))
            } catch {
                guard isCurrent(stamp, session, key), !Task.isCancelled else { return }
                loadFailed = true; message = PublisherLifecycleCopy.error(error, zh: isChinese); resultSession = session
            }
        }
    }
    private func beginPrepare() {
        guard visible, phase == .active, !busy, let session = client.session,
              coordinator.currentSession == session else { return }
        guard let action = currentAction else {
            message = PublisherLifecycleCopy.error(PublisherLifecycleError.incomplete, zh: isChinese); resultSession = session; return
        }
        invalidate(keepPreview: true)
        let stamp = generation, key = formKey
        busy = true
        Task {
            guard isCurrent(stamp, session, key), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, key) { busy = false } }
            do {
                let value = try await coordinator.prepare(action)
                guard isCurrent(stamp, session, key), !Task.isCancelled,
                      value.session == session, value.action == action else { return }
                review = value
            } catch {
                guard isCurrent(stamp, session, key), !Task.isCancelled else { return }
                message = PublisherLifecycleCopy.error(error, zh: isChinese); resultSession = session
            }
        }
    }
    private func beginConfirm(_ value: PublisherLifecycleReview) {
        guard visible, phase == .active, !busy, let session = client.session,
              coordinator.currentSession == session, value.session == session,
              self.review == value, value.action == currentAction else { return }
        // Pricing confirm is refused by the contract while the grant flag is off. Do not call the coordinator,
        // which would build POST api/topic/pricing/confirm. Graduate, transfer, and cancel use their own methods.
        guard case .pricing = value.action else { return }
        do {
            _ = try PlayerContentMPContract.pricingConfirm(
                baseURL: client.configuration.baseURL, topicID: topicID, scope: pricingScope,
                guidedPrice: subtype == .guided ? Int(price) : nil, ticketPrices: [],
                leadCost: Int(cost), teamSize: Int(team), selfPrice: subtype == .selfPlay ? Int(price) : nil)
        } catch {
            message = PublisherLifecycleCopy.outcome(.notSent, zh: isChinese)
            resultSession = session
            review = nil
            return
        }
        message = PublisherLifecycleCopy.outcome(.notSent, zh: isChinese)
        resultSession = session
        review = nil
    }
}
@MainActor struct PublisherPartnerView: View {
    let topicID: Int; let row: PublisherLineup; let client: PublisherLifecycleHTTP
    @State private var result: PublisherPartnerInspection?
    @State private var message = ""
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var resultKey: ReadKey?
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    private struct ReadKey: Equatable {
        let client: ObjectIdentifier
        let session: PublishingSession?
        let topicID: Int
        let row: PublisherLineup
        let active: Bool
    }
    private var readKey: ReadKey {
        .init(client: ObjectIdentifier(client), session: client.session, topicID: topicID, row: row, active: phase == .active)
    }
    private var isClub: Bool { row.type == "club" }
    @Environment(\.topicLineupClubDestination) private var clubDestination
    @Environment(\.topicLineupMerchantDestination) private var merchantDestination
    var body: some View {
        List {
            if topicID <= 0 || row.partnerID <= 0 || !["club", "merchant"].contains(row.type) {
                // Source invalid-link state.
                VStack(alignment: .leading, spacing: 4) {
                    Text(text("publisherPricing.thisPartnerLinkIsNoLonger")).cyText(.cardTitle).accessibilityAddTraits(.isHeader)
                    Text(text("publisherPricing.goBackAndOpenItAgain")).cyText(.bodyCompact)
                }.accessibilityIdentifier("publisher.partner.invalid")
            } else {
                Section {
                    // pages/topic/pricing/partner/index phase (TopicPricingXcx.partnerPreviewPhase).
                    let scopedResult = resultKey == readKey ? result : nil
                    switch TopicPricingXcx.partnerPreviewPhase(loading: loading, inspection: scopedResult, failed: resultKey == readKey && failed) {
                    case .loading: CYSkeleton()
                    case .error:
                        Label("publisherPricing.loadFailed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("publisher.partner.error")
                        // PC-B-5-1: the error state offers recovery (MP 重新加载), not a dead end.
                        Button { Task { await load(readKey) } } label: { Text("topic.retry") }
                            .buttonStyle(CYPillButtonStyle(style: .secondary)).frame(minHeight: 44)
                            .accessibilityIdentifier("publisher.partner.retry")
                    case .unknown:
                        Text(verbatim: TopicPricingXcx.unknownMoney).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("publisher.partner.unknown")
                    case .empty(let inspection), .ready(let inspection):
                        let profile = inspection.profile.object ?? [:]
                        Text(profile["name"]?.text ?? "—").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        if let description = profile["description"]?.text, !description.isEmpty { Text(description).foregroundStyle(CYColor.textSecondary) }
                        let rows = profileRows(profile)
                        if rows.isEmpty { Text(text("publisherPricing.noProfileYet")).foregroundStyle(CYColor.textSecondary) }
                        ForEach(rows, id: \.0) { key, value in
                            // R7-PC-B5-2: MP address row opens the place in the map app.
                            if key == text("publisherPricing.address"), let url = HomeFeedMapsLink.url(for: value) {
                                Link(destination: url) { LabeledContent(key, value: value) }
                                    .accessibilityHint(Text("accountCollection.coupon.openInMaps"))
                                    .accessibilityIdentifier("publisher.partner.address")
                            } else {
                                LabeledContent(key, value: value)
                            }
                        }
                        // R7-PC-B5-2 (r1 PC-B-5-2): MP 查看 opens the club detail / merchant home.
                        if isClub, let clubDestination {
                            NavigationLink { clubDestination(row.partnerID) } label: { Text("publisherPricing.viewPartner") }
                                .accessibilityIdentifier("publisher.partner.view")
                        } else if !isClub, let merchantDestination {
                            NavigationLink { merchantDestination(row.partnerID) } label: { Text("publisherPricing.viewPartner") }
                                .accessibilityIdentifier("publisher.partner.view")
                        }
                    }
                } header: { Text(isClub ? text("publisherPricing.partnerClub") : text("publisherPricing.hostingMerchant")) }
                if resultKey == readKey, let terms = result?.terms {
                    Section {
                        LabeledContent(text("publisherPricing.settlement"), value: terms.mode == 1 ? text("publisherPricing.revenueShare") : terms.mode == 2 ? text("publisherPricing.fixed") : text("publisherPricing.referral"))
                        // Unknown share / fee is a bare em dash (never "—%" or "¥—"); a literal 0 stays "0".
                        if terms.mode == 1 { LabeledContent(text("publisherPricing.share"), value: partnerMoney(terms.shareRate, prefix: "", suffix: "%")) }
                        if terms.mode == 2 { LabeledContent(text("publisherPricing.fixedFee"), value: partnerMoney(terms.fixedFee, prefix: "¥", suffix: text("publisherPricing.perPerson"))) }
                        LabeledContent(text("publisherPricing.locked"), value: text("publisherPricing.whenSalesOpen"))
                        Text(terms.mode == 1 ? text("publisherPricing.termsFreezeWhenSalesOpenSettlement")
                             : terms.mode == 2 ? text("publisherPricing.termsFreezeWhenSalesOpenSettlement44")
                             : text("publisherPricing.theLineupFreezesWhenSalesOpen")).cyText(.meta)
                    } header: { Text(text("publisherPricing.partnershipTerms")) } footer: {
                        Text("publisherPricing.partnerLocked")
                    }
                }
            }
            if resultKey == readKey, !message.isEmpty { Text(message) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("publisher.partner")
        // PC-B-5-3: title once, inline by the bar.
        .cyPageTitle(verbatim: isClub ? text("publisherPricing.partnerClub") : text("publisherPricing.hostingMerchant"))
        .cyPushedChrome(domain: .merchant)
        .task(id: readKey) { await load(readKey) }
        .onDisappear { retire() }
    }
    private func retire() {
        generation = UUID(); result = nil; message = ""; resultKey = nil; failed = false; loading = false
    }
    private func load(_ key: ReadKey) async {
        guard !Task.isCancelled else { return }
        retire()
        guard key == readKey, key.active, key.session != nil, key.topicID > 0, key.row.partnerID > 0 else { return }
        let stamp = generation
        loading = true
        do {
            let value = try await client.partner(topicID: key.topicID, type: key.row.type, id: key.row.partnerID)
            guard !Task.isCancelled, generation == stamp, key == readKey else { return }
            result = value; resultKey = key; failed = false; loading = false
        } catch {
            guard !Task.isCancelled, generation == stamp, key == readKey else { return }
            failed = true; message = PublisherLifecycleCopy.error(error, zh: zh); resultKey = key; loading = false
        }
    }
    /// Source profile rows; values may be strings, numbers, arrays or objects (flattened by name/title/label).
    private func profileRows(_ profile: [String: ProjectEditJSON]) -> [(String, String)] {
        func flat(_ value: ProjectEditJSON?) -> String? {
            guard let value else { return nil }
            if case .number(let number) = value { return NSDecimalNumber(decimal: number).stringValue }
            if let array = value.array { let parts = array.compactMap { flat($0) }; return parts.isEmpty ? nil : parts.joined(separator: " · ") }
            if let object = value.object { return ["name", "title", "label", "address", "categoryName"].lazy.compactMap { object[$0]?.text }.first }
            guard let text = value.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "null" else { return nil }
            return text
        }
        var rows: [(String, String)] = []
        func add(_ label: String, _ value: String?) { if let value { rows.append((label, value)) } }
        if isClub {
            add(text("publisherPricing.leader"), flat(profile["leaderName"]))
            add(text("publisherPricing.city"), flat(profile["city"]) ?? flat(profile["address"]))
            add(text("publisherPricing.clubType"), flat(profile["clubType"]))
            add(text("publisherPricing.members"), flat(profile["memberCount"]).map { $0 + text("publisherPricing.people") })
            add(text("publisherPricing.level"), flat(profile["levelText"]))
        } else {
            add(text("publisherPricing.category"), flat(profile["sysCategoryList"]))
            add(text("publisherPricing.capacity"), flat(profile["capacity"]).map { $0 + text("publisherPricing.people") })
            add(text("publisherPricing.suitableRoutes"), flat(profile["suitActivityTypes"]))
            add(text("publisherPricing.availableTimes"), flat(profile["availableTime"]))
            if let charge = profile["chargeType"] { add(text("publisherPricing.charging"), flat(charge) == "1" ? text("publisherPricing.paidHosting") : text("publisherPricing.freeHosting")) }
            add(text("publisherPricing.partnershipNeeds"), flat(profile["demand"]))
            add(text("publisherPricing.openingHours"), flat(profile["businessTime"]))
            add(text("publisherPricing.address"), flat(profile["address"]))
        }
        return rows
    }
    private func partnerMoney(_ raw: String?, prefix: String, suffix: String) -> String {
        let value = TopicPricingXcx.partnerMoneyText(raw)
        return value == TopicPricingXcx.unknownMoney ? value : prefix + value + suffix
    }
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private func text(_ key: String) -> String { appLocalized(String.LocalizationValue(key), locale: locale) }
}
@MainActor struct PublisherCancellationView: View {
    let resource: PublishedResource; let coordinator: PublisherLifecycleCoordinator
    @State private var reason = ""; @State private var review: PublisherLifecycleReview?
    @State private var message = ""; @State private var busy = false
    @State private var generation = UUID()
    @State private var visible = false
    @State private var messageSession: PublishingSession?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Form {
            CYHeroHeader(verbatim: zh ? "取消并退款" : "Cancel and refund")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Text(zh ? "主办方取消并退款，无法撤销。原因将展示给玩家。" : "Organizer cancellation and refunds are irreversible. The reason is shown to players.")
            TextField(zh ? "取消原因" : "Cancellation reason", text: $reason, axis: .vertical).accessibilityIdentifier("publisher.cancelReason")
            CYPillButton(verbatim: zh ? "查看退款影响" : "Preview refund impact", style: .secondary) { beginPrepare() }.disabled(busy || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("publisher.refundPreview")
            if let review, review.session == coordinator.currentSession, review.action == currentAction, let count = review.paidPlayers {
                Text(zh ? "将给 \(count) 位已付款玩家全额退款。" : "Full refunds will be issued to \(count) paid players.").accessibilityIdentifier("publisher.paidPlayers")
                Text(resource.kind == .topic ? (zh ? "主题停售，名下场次一并取消；已核销票不自动退款。" : "Topic sales stop and its sessions are cancelled; redeemed tickets are not automatically refunded.") : (zh ? "活动下架，玩家无法报名或进入。" : "The activity is removed from sale; players cannot register or enter."))
                Text(reason)
                Button(zh ? "确认取消并退款" : "Confirm cancellation and refunds", role: .destructive) { beginConfirm(review) }.disabled(busy).accessibilityIdentifier("publisher.confirmRefund")
            }
            if messageSession == coordinator.currentSession { Text(message) }
        }.cyHeroScreen()
        .onAppear { visible = true }
        .onChange(of: reason) { _, _ in clear() }
        .onChange(of: resource) { _, _ in clear() }
        .onChange(of: coordinator.currentSession) { _, _ in clear() }
        .onDisappear { visible = false; clear() }
        .onChange(of: phase) { _, value in if value != .active { clear() } }
        .cyDomainScreen(.merchant)
    }
    private var currentAction: PublisherLifecycleAction { .cancel(resource, reason: reason, scope: nil) }
    private func clear() {
        generation = UUID(); review = nil; message = ""; messageSession = nil
        busy = false; coordinator.invalidate()
    }
    private func isCurrent(_ stamp: UUID, _ session: PublishingSession, _ action: PublisherLifecycleAction) -> Bool {
        visible && phase == .active && generation == stamp && coordinator.currentSession == session && currentAction == action
    }
    private func beginPrepare() {
        guard visible, phase == .active, !busy, let session = coordinator.currentSession else { return }
        let stamp = UUID(), action = currentAction
        generation = stamp; busy = true; review = nil; message = ""; messageSession = nil
        Task {
            guard isCurrent(stamp, session, action), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, action) { busy = false } }
            do {
                let value = try await coordinator.prepare(action)
                guard isCurrent(stamp, session, action), !Task.isCancelled,
                      value.session == session, value.action == action else { return }
                review = value
            } catch {
                guard isCurrent(stamp, session, action), !Task.isCancelled else { return }
                message = PublisherLifecycleCopy.error(error, zh: zh); messageSession = session
            }
        }
    }
    private func beginConfirm(_ value: PublisherLifecycleReview) {
        guard visible, phase == .active, !busy, let session = coordinator.currentSession,
              value.session == session, value.action == currentAction, review == value else { return }
        let stamp = generation, action = currentAction
        busy = true
        Task {
            guard isCurrent(stamp, session, action), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, action) { busy = false } }
            let outcome = await coordinator.confirm(value, consequentialApproval: true)
            guard isCurrent(stamp, session, action), !Task.isCancelled else { return }
            message = PublisherLifecycleCopy.outcome(outcome, zh: zh); messageSession = session; review = nil
        }
    }
}
/// Use for selected eligible club or current topic beta action. No arbitrary identity editor.
@MainActor struct PublisherOwnershipReviewView: View {
    let action: PublisherLifecycleAction; let coordinator: PublisherLifecycleCoordinator
    @State private var review: PublisherLifecycleReview?; @State private var message = ""; @State private var busy = false
    @State private var generation = UUID()
    @State private var visible = false
    @State private var messageSession: PublishingSession?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Form {
            if case .transfer(let topic, let club) = action {
                Text("#\(topic) → #\(club)")
                Text(zh ? "为俱乐部复制新草稿，原主题下架；发起人保留内容所有权，俱乐部只能组织带队。" : "Create a new club draft and take the original topic offline. The initiator retains content ownership; the club organizes only.")
            } else { Text(zh ? "永久移除 Beta 标识，无法撤销。" : "Permanently remove the Beta designation. This cannot be undone.") }
            Button(zh ? "刷新并审阅" : "Refresh and review") { beginPrepare() }.disabled(busy)
            if let review, review.session == coordinator.currentSession, review.action == action {
                Button(zh ? "确认此操作" : "Confirm this action", role: .destructive) { beginConfirm(review) }.disabled(busy).accessibilityIdentifier("publisher.confirmOwnership")
            }
            if messageSession == coordinator.currentSession { Text(message) }
        }.onAppear { visible = true }
        .onDisappear { visible = false; clear() }
        .onChange(of: action) { _, _ in clear() }
        .onChange(of: coordinator.currentSession) { _, _ in clear() }
        .onChange(of: phase) { _, value in if value != .active { clear() } }
        .cyDomainScreen(.merchant)
    }
    private func clear() {
        generation = UUID(); review = nil; message = ""; messageSession = nil
        busy = false; coordinator.invalidate()
    }
    private func isCurrent(_ stamp: UUID, _ session: PublishingSession, _ capturedAction: PublisherLifecycleAction) -> Bool {
        visible && phase == .active && generation == stamp && coordinator.currentSession == session && action == capturedAction
    }
    private func beginPrepare() {
        guard visible, phase == .active, !busy, let session = coordinator.currentSession else { return }
        let stamp = UUID(), capturedAction = action
        generation = stamp; busy = true; review = nil; message = ""; messageSession = nil
        Task {
            guard isCurrent(stamp, session, capturedAction), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, capturedAction) { busy = false } }
            do {
                let value = try await coordinator.prepare(capturedAction)
                guard isCurrent(stamp, session, capturedAction), !Task.isCancelled,
                      value.session == session, value.action == capturedAction else { return }
                review = value
            } catch {
                guard isCurrent(stamp, session, capturedAction), !Task.isCancelled else { return }
                message = PublisherLifecycleCopy.error(error, zh: zh); messageSession = session
            }
        }
    }
    private func beginConfirm(_ value: PublisherLifecycleReview) {
        guard visible, phase == .active, !busy, let session = coordinator.currentSession,
              value.session == session, value.action == action, review == value else { return }
        let stamp = generation, capturedAction = action
        busy = true
        Task {
            guard isCurrent(stamp, session, capturedAction), !Task.isCancelled else { return }
            defer { if isCurrent(stamp, session, capturedAction) { busy = false } }
            let result = await coordinator.confirm(value, consequentialApproval: true)
            guard isCurrent(stamp, session, capturedAction), !Task.isCancelled else { return }
            message = PublisherLifecycleCopy.outcome(result, zh: zh); messageSession = session; review = nil
        }
    }
}
@MainActor struct PublisherXPBudgetSection: View {
    let topicID: Int; let client: PublisherLifecycleHTTP
    @State private var budget: PublisherXPBudget?; @State private var message = ""
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Section("XP") {
            if let budget {
                Text("\(budget.totalXP.map(String.init) ?? "—") / \(budget.budget.map(String.init) ?? "—")")
                Text(zh ? "通关奖励：\(budget.remain.map(String.init) ?? "—")" : "Completion reward: \(budget.remain.map(String.init) ?? "—")")
                Text(budget.over.map { $0 ? (zh ? "服务器：超预算" : "Server: over budget") : (zh ? "服务器：未超预算" : "Server: within budget") } ?? (zh ? "预算状态未知" : "Budget status unknown"))
                ForEach(budget.nodes) { node in Text("\(node.name ?? "#\(node.id)"): \(node.xp.map(String.init) ?? "—")") }
            }
            Text(message)
        }.accessibilityIdentifier("publisher.xpBudget")
        .task(id: topicID) { do { budget = try await client.budget(topicID: topicID) } catch { message = PublisherLifecycleCopy.error(error, zh: zh) } }
    }
}
enum PublisherLifecycleCopy {
    static func error(_ error: Error, zh: Bool) -> String {
        if case PublisherLifecycleError.rejected(let message) = error, !message.isEmpty { return message }
        return zh ? "未能核实信息，操作未提交。请刷新；真实操作尚未启用。" : "Information could not be verified. No operation submitted. Refresh; live actions remain disabled."
    }
    static func outcome(_ outcome: PublisherLifecycleOutcome, zh: Bool) -> String {
        switch outcome {
        case .acknowledged(let message, let id): return (message ?? (zh ? "服务器已接收，请刷新核实。" : "Server acknowledged; refresh to verify.")) + (id.map { " #\($0)" } ?? "")
        case .rejected(let message): return message
        case .notSent: return zh ? "未发送。授权关闭或审阅已过期。" : "Not sent. Authorization is disabled or review expired."
        case .unknown: return zh ? "结果未知。请核对服务器状态，勿重复提交。" : "Outcome unknown. Check server state; do not resubmit."
        }
    }
}

private struct PricingChapterProjectDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Merchant 承接 page (`pages/topic/merchantinfo?topicId=`) for chapter-supply lineup rows. Nil keeps the partner page.
    var pricingChapterProjectDestination: ((Int) -> AnyView)? {
        get { self[PricingChapterProjectDestinationKey.self] }
        set { self[PricingChapterProjectDestinationKey.self] = newValue }
    }
}
