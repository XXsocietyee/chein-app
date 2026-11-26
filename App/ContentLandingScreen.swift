import SwiftUI

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
