import SwiftUI

/// Layout for mini-program `pages/topic/catalog/index` (city catalog / theme collection) and `catalog/detail`.
/// Data in, intents out. `PublicCatalogViews` feeds these types from the list, filters, and info reads.
/// An absent capability does not present them. Unknown prices stay an em dash.
enum PublicCatalogPhase: Equatable {
    case loading
    case failed
    case empty
    case content
}

struct PublicCatalogView: View {
    let phase: PublicCatalogPhase
    let cards: [PWaveCatalogCard]
    /// Empty hides the city title chevron and sheet (mini-program: unreadable cities => non-tappable title).
    let cities: [PWaveCatalogCity]
    let activeCityCode: String?
    let loadingMore: Bool
    let moreFailed: Bool
    let onSelectCity: (String?) -> Void
    let onOpen: (PWaveCatalogCard) -> Void
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    @State private var cityPickerShown = false

    private var title: String {
        cities.first(where: { $0.cityCode == activeCityCode })?.cityName ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                if phase == .failed && !cards.isEmpty {
                    CYErrorStateView(title: "publicCatalog.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                }
                switch phase {
                case .loading where cards.isEmpty:
                    CYLoadingStateView(rows: 3).accessibilityIdentifier("publicCatalog.loading")
                case .failed where cards.isEmpty:
                    CYErrorStateView(title: "publicCatalog.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                        .accessibilityIdentifier("publicCatalog.error")
                case .empty:
                    CYEmptyStateView(systemImage: "map", title: "publicCatalog.empty")
                        .accessibilityIdentifier("publicCatalog.empty")
                default:
                    ForEach(cards, id: \.id) { card in
                        Button { onOpen(card) } label: { PublicCatalogCardRow(card: card) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("publicCatalog.card.\(card.id ?? "unknown")")
                    }
                    if loadingMore {
                        ProgressView("publicCatalog.loadingMore").frame(maxWidth: .infinity)
                    } else if moreFailed {
                        Button("publicCatalog.moreRetry", action: onLoadMore)
                            .buttonStyle(.cySecondary(fullWidth: true))
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("publicCatalog.moreRetry")
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background { CYExploreGround() }
        .navigationTitle(cities.isEmpty || title.isEmpty ? Text("publicCatalog.title") : Text(verbatim: title)).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !cities.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { cityPickerShown = true } label: { Label("publicCatalog.city", systemImage: "chevron.down.circle") }
                        .accessibilityIdentifier("publicCatalog.city")
                }
            }
        }
        .sheet(isPresented: $cityPickerShown) { citySheet }
        .refreshable { onRetry() }
    }

    private var citySheet: some View {
        NavigationStack {
            List {
                cityRow(name: nil, code: nil)
                ForEach(cities, id: \.cityCode) { city in cityRow(name: city.cityName, code: city.cityCode) }
            }
            .navigationTitle("publicCatalog.pickCity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { cityPickerShown = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func cityRow(name: String?, code: String?) -> some View {
        Button {
            onSelectCity(code)
            cityPickerShown = false
        } label: {
            HStack {
                if let name { Text(verbatim: name) } else { Text("publicCatalog.allCities") }
                Spacer()
                if code == activeCityCode { Image(systemName: "checkmark").foregroundStyle(CYColor.brand) }
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityAddTraits(code == activeCityCode ? .isSelected : [])
    }
}

/// Photo card: full-bleed cover with the kind pill, then title / duration meta / eligibility tags below (mini-program `topic-result-card`).
struct PublicCatalogCardRow: View {
    let card: PWaveCatalogCard

    private var meta: String {
        [card.sampleCountText, card.priceText].joined(separator: " · ")
    }

    private var tags: [LocalizedStringKey] {
        var out: [LocalizedStringKey] = []
        if card.freeSelfPlay == true { out.append("publicCatalog.tag.freeSelfPlay") }
        if card.groupEligible == true { out.append("publicCatalog.tag.group") }
        if card.schoolEligible == true { out.append("publicCatalog.tag.school") }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYImageCard(verbatim: card.name ?? "", fallback: "publicCatalog.untitled", meta: meta,
                        imageURL: card.imageURL.flatMap(URL.init(string:)))
            if !tags.isEmpty {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag).cyText(.caption)
                            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs)
                            .background(CYColor.bgSurface, in: Capsule())
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum PublicCatalogDetailState: Equatable {
    case loading
    case gone
    case failed
    case ok(PWaveCatalogCard)
}

/// Mini-program `pages/topic/catalog/detail`: hero, tags, summary, chapters, more-from-city link, and the sticky "view work" footer.
struct PublicCatalogDetailView: View {
    let state: PublicCatalogDetailState
    let onRetry: () -> Void
    let onOpenWork: (PWaveCatalogCard) -> Void
    let onOpenCity: (PWaveCatalogCity) -> Void
    let onEditLanding: (String) -> Void

    var body: some View {
        Group {
            switch state {
            case .loading:
                CYLoadingStateView(rows: 2).padding(CYSpacing.pageHorizontal).accessibilityIdentifier("publicCatalog.detail.loading")
            case .gone:
                CYEmptyStateView(systemImage: "map", title: "publicCatalog.detail.gone").accessibilityIdentifier("publicCatalog.detail.gone")
            case .failed:
                CYErrorStateView(title: "publicCatalog.detail.error", message: "publicCatalog.errorHint", retryTitle: "homeFeed.retry", onRetry: onRetry)
                    .accessibilityIdentifier("publicCatalog.detail.error")
            case .ok(let card):
                content(card)
            }
        }
        .background { CYExploreGround() }
        .navigationTitle("publicCatalog.detail.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ card: PWaveCatalogCard) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                PublicCatalogCardRow(card: card)
                if let summary = card.summary, !summary.isEmpty {
                    Text(verbatim: summary).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                seo(card)
                Button("publicCatalog.seo.open") {
                    if let id = card.id { onEditLanding(id) }
                }
                .disabled(card.id == nil || card.id?.isEmpty == true)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("publicCatalog.seo.open")
                if let chapters = card.chapterNames, !chapters.isEmpty {
                    Text("publicCatalog.detail.chapters").cyText(.sectionTitle).accessibilityAddTraits(.isHeader)
                }
                if let chapters = card.chapterNames, !chapters.isEmpty {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { _, name in
                        Text(verbatim: name).padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                            .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                }
                if let code = card.cityCode, let name = card.cityName {
                    Button { onOpenCity(PWaveCatalogCity(cityCode: code, cityName: name)) } label: {
                        HStack { Text("publicCatalog.detail.moreInCity \(name)"); Spacer(); Image(systemName: "arrow.right") }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("publicCatalog.detail.city")
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .safeAreaInset(edge: .bottom) {
            Button("publicCatalog.detail.open") { onOpenWork(card) }
                .buttonStyle(.cyPrimary)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .padding(CYSpacing.pageHorizontal)
                .background(.bar)
                .accessibilityIdentifier("publicCatalog.detail.open")
        }
    }

    private func seo(_ card: PWaveCatalogCard) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("publicCatalog.seo.notLive").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            labeled("publicCatalog.seo.canonical", card.canonicalPath)
            labeled("publicCatalog.seo.translation", card.translationState)
        }
        .accessibilityIdentifier("publicCatalog.seo")
    }

    private func labeled(_ title: LocalizedStringKey, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: MPText.orDash(value))
        }
        .cyText(.body)
        .frame(minHeight: CYSpacing.minTouchTarget)
    }
}

/// Installed by a host that already holds a non-production reader.
/// The shipped session leaves `host` nil, so this screen sends nothing and cannot pay.
enum PublicCatalogHostWiring {
    static let moneyEnabled = false
    static var host: PublicCatalogHost?
    static var scope: PWaveSessionScope?
    static var token: String?
}

/// List, filters, and info on the existing catalog views. Quote, order, and pay stay off.
@MainActor
struct PublicCatalogViews: View {
    static let moneyEnabled = false

    let link: PublicCatalogLink
    let host: PublicCatalogHost?
    let scope: () -> PWaveSessionScope?
    let token: () -> String?
    var session: AppSession? = nil

    @State private var hidden = true
    @State private var landingTopic: String?
    @State private var phase: PublicCatalogPhase = .loading
    @State private var detail: PublicCatalogDetailState = .loading
    @State private var cards: [PWaveCatalogCard] = []
    @State private var cities: [PWaveCatalogCity] = []
    @State private var query: Query?

    private struct Query {
        var screen: PublicCatalogLink.Screen
        var fields: [String: String]
    }

    private var active: PublicCatalogLink {
        if let query, let built = PublicCatalogLink(screen: query.screen, fields: query.fields) {
            return built
        }
        return link
    }

    private var loadID: String {
        let fields = active.fields.keys.sorted().map { "\($0)=\(active.fields[$0] ?? "")" }.joined(separator: "\n")
        return "\(active.screen.rawValue)\n\(fields)"
    }

    var body: some View {
        Group {
            if hidden {
                EmptyView()
            } else if active.screen == .info {
                PublicCatalogDetailView(state: detail, onRetry: { retry() }, onOpenWork: { openWork($0) }, onOpenCity: { openCity($0) },
                                        onEditLanding: { landingTopic = $0 })
            } else {
                PublicCatalogView(phase: phase, cards: cards, cities: cities, activeCityCode: active.fields["city_code"],
                                  loadingMore: false, moreFailed: false, onSelectCity: { selectCity($0) }, onOpen: { openCard($0) },
                                  onRetry: { retry() }, onLoadMore: {})
            }
        }
        .task(id: loadID) { await reload() }
        .navigationDestination(item: $landingTopic) { topic in
            ContentLandingScreen(session: session, topicID: topic)
        }
    }

    private func retry() { Task { await reload() } }

    /// A city choice reloads list or filters. It does not quote, order, or pay.
    private func selectCity(_ code: String?) {
        var fields = active.fields
        if let code, !code.isEmpty { fields["city_code"] = code } else { fields.removeValue(forKey: "city_code") }
        let screen: PublicCatalogLink.Screen = active.screen == .info ? .list : active.screen
        if screen != .info { fields.removeValue(forKey: "id") }
        adopt(screen: screen, fields: fields)
    }

    /// Opening a card reads info. It does not start a charge.
    private func openCard(_ card: PWaveCatalogCard) {
        guard let id = card.id, !id.isEmpty else { return }
        adopt(screen: .info, fields: ["id": id])
    }

    private func openCity(_ city: PWaveCatalogCity) {
        var fields: [String: String] = [:]
        if let code = city.cityCode, !code.isEmpty { fields["city_code"] = code }
        adopt(screen: .list, fields: fields)
    }

    /// The existing detail footer stays. This host does not quote, order, or pay.
    private func openWork(_ card: PWaveCatalogCard) {
        _ = card
    }

    private func adopt(screen: PublicCatalogLink.Screen, fields: [String: String]) {
        guard PublicCatalogLink(screen: screen, fields: fields) != nil else { return }
        query = Query(screen: screen, fields: fields)
    }

    private func reload() async {
        guard let host, let scope = scope() else {
            conceal()
            return
        }
        let credential = token()
        let requested = active
        if !hidden { revealLoading() }
        do {
            let presented = try await host.load(requested, token: credential, scope: scope, currentScope: { scope })
            guard !Task.isCancelled else { return }
            apply(presented)
        } catch {
            guard !Task.isCancelled else { return }
            showFailure()
        }
    }

    private func apply(_ presented: PWavePresentation<PWaveThemeCollectionFact>) {
        switch PublicCatalogScreen.state(presented) {
        case .unavailable:
            conceal()
        case .loading:
            revealLoading()
        case .empty:
            show(cards: [], cities: [], phase: .empty, detail: .gone)
        case .failed, .unrecognized:
            showFailure()
        case .ready:
            guard case .ready(let fact)? = presented.phase else {
                conceal()
                return
            }
            let nextPhase: PublicCatalogPhase = fact.cards.isEmpty ? .empty : .content
            let nextDetail: PublicCatalogDetailState
            if let card = matchingCard(in: fact) {
                nextDetail = .ok(card)
            } else {
                nextDetail = .gone
            }
            show(cards: fact.cards, cities: fact.cities, phase: nextPhase, detail: nextDetail)
        }
    }

    private func matchingCard(in fact: PWaveThemeCollectionFact) -> PWaveCatalogCard? {
        if let id = active.fields["id"], let match = fact.cards.first(where: { $0.id == id }) {
            return match
        }
        return fact.cards.first
    }

    private func revealLoading() {
        hidden = false
        cards = []
        cities = []
        phase = .loading
        detail = .loading
    }

    private func showFailure() {
        show(cards: [], cities: [], phase: .failed, detail: .failed)
    }

    private func show(cards: [PWaveCatalogCard], cities: [PWaveCatalogCity], phase: PublicCatalogPhase, detail: PublicCatalogDetailState) {
        hidden = false
        self.cards = cards
        self.cities = cities
        self.phase = phase
        self.detail = detail
    }

    /// No host, or a presentation the capability does not reveal: show none of the catalog UI.
    private func conceal() {
        hidden = true
        cards = []
        cities = []
        phase = .empty
        detail = .gone
    }
}

/// Author landing editor. Sitemap, hreflang, and robots stay not live. Price and sale fields are not on this screen.
struct ContentLandingScreen: View {
    let session: AppSession?
    var topicID: String = ""

    @State private var topic = ""
    @State private var phase: ContentLandingPhase = .empty
    @State private var fact: ContentLandingFact?
    @State private var summary = ""
    @State private var group: ContentLandingTri = .undeclared
    @State private var school: ContentLandingTri = .undeclared
    @State private var groupMin = ""
    @State private var groupMax = ""
    @State private var ageMin = ""
    @State private var ageMax = ""
    @State private var access = ""
    @State private var version = ""
    @State private var locale = ""
    @State private var title = ""
    @State private var subtitle = ""
    @State private var translationSummary = ""
    @State private var wasApproved = false
    @State private var notice: ContentLandingNotice = .none
    @State private var saving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text("contentLanding.seoNote").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("contentLanding.seoNote")
                TextField("contentLanding.topic", text: $topic)
                    .accessibilityIdentifier("contentLanding.topic")
                Button("contentLanding.load") { Task { await load() } }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("contentLanding.load")
                switch phase {
                case .empty:
                    CYEmptyState(systemImage: "doc.text", "contentLanding.empty", messageIdentifier: "contentLanding.empty")
                case .loading:
                    CYLoadingStateView(rows: 3).accessibilityIdentifier("contentLanding.loading")
                case .failed:
                    CYEmptyState(systemImage: "exclamationmark.triangle", "contentLanding.error", messageIdentifier: "contentLanding.error",
                                 actionTitle: "action.retry", action: { Task { await load() } })
                case .signedOut:
                    CYEmptyState(systemImage: "person.crop.circle", "contentLanding.signedOut", messageIdentifier: "contentLanding.signedOut")
                case .ready:
                    editor
                }
                noticeText
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background { MPNightGround() }
        .navigationTitle(Text("contentLanding.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if topic.isEmpty { topic = topicID } }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            labeled("contentLanding.canonical", fact?.canonicalPath ?? ContentLandingFact.unknownMark)
            labeled("contentLanding.version", version.isEmpty ? ContentLandingFact.unknownMark : version)
            TextField("contentLanding.summary", text: $summary, axis: .vertical).lineLimit(3...6)
                .accessibilityIdentifier("contentLanding.summary")
            Picker("contentLanding.group", selection: $group) {
                Text("contentLanding.undeclared").tag(ContentLandingTri.undeclared)
                Text("contentLanding.yes").tag(ContentLandingTri.yes)
                Text("contentLanding.no").tag(ContentLandingTri.no)
            }
            Picker("contentLanding.school", selection: $school) {
                Text("contentLanding.undeclared").tag(ContentLandingTri.undeclared)
                Text("contentLanding.yes").tag(ContentLandingTri.yes)
                Text("contentLanding.no").tag(ContentLandingTri.no)
            }
            TextField("contentLanding.groupMin", text: $groupMin).accessibilityIdentifier("contentLanding.groupMin")
            TextField("contentLanding.groupMax", text: $groupMax).accessibilityIdentifier("contentLanding.groupMax")
            TextField("contentLanding.ageMin", text: $ageMin).accessibilityIdentifier("contentLanding.ageMin")
            TextField("contentLanding.ageMax", text: $ageMax).accessibilityIdentifier("contentLanding.ageMax")
            TextField("contentLanding.access", text: $access, axis: .vertical).lineLimit(2...4)
                .accessibilityIdentifier("contentLanding.access")
            CYMorphButton("contentLanding.save", state: saving ? .working : .idle) { Task { await save() } }
                .disabled(saving)
                .accessibilityIdentifier("contentLanding.save")
            Text("contentLanding.pending").cyText(.label).accessibilityIdentifier("contentLanding.pending")
            TextField("contentLanding.locale", text: $locale).accessibilityIdentifier("contentLanding.locale")
            TextField("contentLanding.translationTitle", text: $title).accessibilityIdentifier("contentLanding.translationTitle")
            TextField("contentLanding.translationSubtitle", text: $subtitle).accessibilityIdentifier("contentLanding.translationSubtitle")
            TextField("contentLanding.translationSummary", text: $translationSummary, axis: .vertical).lineLimit(2...4)
                .accessibilityIdentifier("contentLanding.translationSummary")
            CYMorphButton("contentLanding.translationSave", state: saving ? .working : .idle) { Task { await saveTranslation() } }
                .disabled(saving)
                .accessibilityIdentifier("contentLanding.translationSave")
        }
    }

    @ViewBuilder private var noticeText: some View {
        switch notice {
        case .none: EmptyView()
        case .saved: Text("contentLanding.saved")
        case .invalid: MPInlineError(text: Text("contentLanding.invalid"))
        case .conflict: Text("contentLanding.conflict").accessibilityIdentifier("contentLanding.conflict")
        case .revised: Text("contentLanding.revised").accessibilityIdentifier("contentLanding.revised")
        case .approvedRefused: Text("contentLanding.approvedRefused")
        case .pending: Text("hostTip.config.pending")
        }
    }

    private func labeled(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value.isEmpty ? ContentLandingFact.unknownMark : value)
        }
        .cyText(.body)
        .frame(minHeight: CYSpacing.minTouchTarget)
    }

    private func load() async {
        let id = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            phase = .empty
            return
        }
        phase = .loading
        notice = .none
        guard let source = source(), let token = token() else {
            phase = .signedOut
            return
        }
        do {
            let envelope = try await source.info(topicID: id, token: token)
            guard let next = ContentLandingSource.fact(topicID: id, in: envelope) else {
                phase = envelope.confirmed ? .empty : .failed
                return
            }
            apply(next)
            phase = .ready
        } catch ContentLandingRefusal.invalidRequest {
            notice = .invalid
            phase = .empty
        } catch {
            phase = .failed
        }
    }

    private func apply(_ next: ContentLandingFact) {
        fact = next
        summary = next.summary
        group = next.groupEligible
        school = next.schoolEligible
        groupMin = next.groupMin
        groupMax = next.groupMax
        ageMin = next.ageMin
        ageMax = next.ageMax
        access = next.accessibilityNote
        version = next.versionText == ContentLandingFact.unknownMark ? "" : next.versionText
        title = next.title
        subtitle = next.subtitle
        translationSummary = next.translationSummary
        if !next.locale.isEmpty { locale = next.locale }
        wasApproved = next.needsReviewAgain
    }

    private func save() async {
        guard !saving, let source = source(), let token = token() else {
            phase = .signedOut
            return
        }
        saving = true
        defer { saving = false }
        do {
            let envelope = try await source.save(topicID: topic.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 expectedVersion: version, summary: summary, group: group, school: school,
                                                 groupMin: groupMin, groupMax: groupMax, ageMin: ageMin, ageMax: ageMax,
                                                 accessibility: access, token: token)
            if envelope.versionConflict {
                notice = .conflict
                return
            }
            guard envelope.ok else {
                notice = envelope.confirmed ? .invalid : .pending
                return
            }
            notice = .saved
            await load()
            if notice != .conflict { notice = .saved }
        } catch ContentLandingRefusal.invalidRequest {
            notice = .invalid
        } catch {
            notice = .pending
        }
    }

    private func saveTranslation() async {
        guard !saving, let source = source(), let token = token() else {
            phase = .signedOut
            return
        }
        saving = true
        defer { saving = false }
        let approvedBefore = wasApproved
        do {
            let envelope = try await source.saveTranslation(topicID: topic.trimmingCharacters(in: .whitespacesAndNewlines),
                                                            locale: locale, title: title, subtitle: subtitle,
                                                            summary: translationSummary, token: token)
            if envelope.httpStatus == 403 {
                notice = .approvedRefused
                return
            }
            guard envelope.ok else {
                notice = envelope.confirmed ? .invalid : .pending
                return
            }
            notice = approvedBefore ? .revised : .saved
            wasApproved = false
        } catch ContentLandingRefusal.approvedRefused {
            notice = .approvedRefused
        } catch ContentLandingRefusal.invalidRequest {
            notice = .invalid
        } catch {
            notice = .pending
        }
    }

    private func source() -> ContentLandingSource? {
        guard let session, let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return ContentLandingSource(configuration: configuration, transport: session.composition.makeTransport())
    }

    private func token() -> String? {
        guard let token = session?.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return token
    }
}

private enum ContentLandingPhase { case empty, loading, failed, signedOut, ready }
private enum ContentLandingNotice { case none, saved, invalid, conflict, revised, approvedRefused, pending }
