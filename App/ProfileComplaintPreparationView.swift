import SwiftUI

/// A normal personal link using the existing, authenticated read composition. This
/// does not construct a service, issue a grant, or inherit cooperation write access.
@MainActor struct ProfileComplaintPreparationLink: View {
    @ObservedObject var session: AppSession
    /// Host hook (composition root, once the complaint report route is approved): return a submitter
    /// built from the gated `CoopFlowCoordinator`. nil (the default) keeps the honest "not available yet" state.
    @MainActor static var submitterFactory: (@MainActor (AppSession) -> (any ProfileComplaintSubmitting)?)?
    var body: some View {
        let _ = WP06ComplaintWrite.install()
        let revision = session.sessionRevision
        let owner = session.cooperationFlowReader.session
        NavigationLink {
            ProfileComplaintPreparationView(reader: session.cooperationFlowReader,
                isCurrent: { session.sessionRevision == revision && session.cooperationFlowReader.session == owner },
                submitter: Self.submitterFactory?(session))
                .id(revision)
        } label: { Label("profile.complaint.title", systemImage: "text.bubble") }
            .accessibilityIdentifier("profile.complaint.open")
    }
}

/// `subpackageMember/complaint/index` for the page router (PLY-27-1): the same screen the 我的 row pushes.
@MainActor struct ProfileComplaintDeepLinkScreen: View {
    @ObservedObject var session: AppSession
    var body: some View {
        let _ = WP06ComplaintWrite.install()
        let revision = session.sessionRevision
        let owner = session.cooperationFlowReader.session
        ProfileComplaintPreparationView(reader: session.cooperationFlowReader,
            isCurrent: { session.sessionRevision == revision && session.cooperationFlowReader.session == owner },
            submitter: ProfileComplaintPreparationLink.submitterFactory?(session))
            .id(revision)
    }
}

private struct ProfileComplaintPresentationKey: Hashable {
    let reader: ObjectIdentifier
    let accountID: Int?
    let epoch: UInt64?
    @MainActor init(_ reader: any CoopFlowReading) {
        self.reader = ObjectIdentifier(reader); accountID = reader.session?.accountID; epoch = reader.session?.epoch
    }
}
@MainActor struct ProfileComplaintPreparationView: View {
    let reader: any CoopFlowReading
    let isCurrent: @MainActor () -> Bool
    /// nil = the report route is not approved in this build; the review screen then says so honestly.
    let submitter: (any ProfileComplaintSubmitting)?
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool) {
        self.reader = reader; self.isCurrent = isCurrent; submitter = nil
    }
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool, submitter: (any ProfileComplaintSubmitting)?) {
        self.reader = reader; self.isCurrent = isCurrent; self.submitter = submitter
    }
    var body: some View {
        ProfileComplaintPreparationScreen(reader: reader, isCurrent: isCurrent, submitter: submitter)
            .id(ProfileComplaintPresentationKey(reader))
    }
}
@MainActor private struct ProfileComplaintPreparationScreen: View {
    let reader: any CoopFlowReading
    @State private var model: ProfileComplaintPreparationController
    @State private var progress: ProfileComplaintProgressController
    @State private var confirmingSend = false
    @State private var submittedToast: LocalizedStringKey?
    @State private var sending: ProfileComplaintSubmissionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: Field?
    private enum Field: Hashable { case reason, contact }
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool, submitter: (any ProfileComplaintSubmitting)?) {
        self.reader = reader
        _model = State(initialValue: .init(reader: reader, isCurrent: isCurrent))
        _sending = State(initialValue: .init(submitter: submitter))
        _progress = State(initialValue: .init(reader: reader, isCurrent: isCurrent))
    }
    var body: some View {
        Form {
            // PLY-27-2: the page title is the bar's inline title (投诉与建议); only the subtitle stays in the content.
            Section {
                EmptyView()
            } footer: {
                Text("profile.complaint.pageSubtitle").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.complaint.pageSubtitle")
            }
            if !model.contextMatches {
                Text("profile.complaint.retired").accessibilityIdentifier("profile.complaint.retired")
            } else if let review = model.review {
                reviewSection(review)
            } else {
                if model.isLoading {
                    // Source copy: 正在加载可投诉的活动.
                    CYLoadingState("profile.complaint.loadingTopics", messageIdentifier: "profile.complaint.loading")
                        .listRowBackground(Color.clear)
                }
                if let issue = model.issue {
                    Section {
                        Text(LocalizedStringKey(issue.sourceTitleKey)).cyText(.cardTitle)
                            .accessibilityIdentifier("profile.complaint.issueTitle")
                        if issue != .unavailable {
                            if model.isNetworkFailure && issue == .failed {
                                Text("profile.complaint.read.network").font(.subheadline)
                                    .accessibilityIdentifier("profile.complaint.issueDetail")
                            } else {
                                Text(LocalizedStringKey(issue.sourceDetailKey)).font(.subheadline)
                                    .accessibilityIdentifier("profile.complaint.issueDetail")
                            }
                        }
                        Text(LocalizedStringKey(issue.titleKey)).accessibilityIdentifier("profile.complaint.issue")
                        if issue == .failed {
                            Button("action.retry") { Task { await model.load() } }
                                .disabled(model.isLoading).accessibilityIdentifier("profile.complaint.retry")
                        }
                    }
                }
                if let topics = model.topics {
                    if topics.isEmpty && model.issue == nil && !model.isLoading {
                        Section {
                            // Native restyle r1 (spec §3.5): empty source list as a ContentUnavailableView.
                            ContentUnavailableView {
                                Label { Text("profile.complaint.sourceEmpty").accessibilityIdentifier("profile.complaint.empty") } icon: {
                                    Image(systemName: "tray")
                                }
                            } description: {
                                Text("profile.complaint.sourceEmptyHint")
                                    .accessibilityIdentifier("profile.complaint.emptyHint")
                            }
                        }
                        .cyCardRow()
                    } else if !topics.isEmpty {
                        editor(topics).disabled(!model.canEdit)
                    }
                }
                if model.contextMatches { ProfileComplaintProgressSection(model: progress) }
            }
        }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("profile.complaint.pageTitle")
        // PLY-27-2 / X12: pushed page keeps the system back only; pull-down refresh replaces the toolbar ↻.
        .refreshable {
            guard model.review == nil, model.contextMatches, !model.isLoading else { return }
            focused = nil
            await model.load()
            await progress.load()
        }
        .task { await model.load() }
        .task { await progress.load() }
        .onChange(of: reader.session) { _, _ in model.retire(); sending.reset() }
        .onChange(of: reader.session) { _, _ in progress.retire() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { focused = nil; model.retire() }
        }
        .onDisappear { model.retire() }
        .onDisappear { progress.retire() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { progress.retire() } }
        .privacySensitive()
        // PLY-27-4: mini-program toasts 投诉已提交, refreshes 我的处理进展 and goes back after 1.2 s.
        .onChange(of: sending.state == .succeeded) { _, succeeded in
            guard succeeded else { return }
            submittedToast = "profile.complaint.submit.done"
            Task {
                await progress.load()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard sending.state == .succeeded else { return }
                model.retire(); sending.reset(); dismiss()
            }
        }
        .cyToast(message: $submittedToast, tone: .success)
        .sheet(isPresented: $confirmingSend) {
            MemberComplaintSubmitConfirmSheet {
                confirmingSend = false
                if let review = model.review { Task { await sending.send(review: review, isCurrent: { model.contextMatches }) } }
            }
            .themeDomain(.player)
        }
    }
    private func editor(_ topics: [ProfileComplaintTopic]) -> some View {
        Group {
            Section("profile.complaint.topic") {
                Picker("profile.complaint.topic", selection: Binding<Int?>(
                    get: { model.draft.topicID }, set: { value in model.change { $0.topicID = value } })) {
                    Text("profile.complaint.chooseTopicPrompt").tag(Optional<Int>.none)
                    ForEach(topics) { topic in
                        topicLabel(topic).tag(Optional(topic.id))
                    }
                }.accessibilityIdentifier("profile.complaint.topic")
                Picker("profile.complaint.kind", selection: Binding<ProfileComplaintKind?>(
                    get: { model.draft.kind }, set: { value in model.change { $0.kind = value } })) {
                    Text("profile.complaint.chooseKindPrompt").tag(Optional<ProfileComplaintKind>.none)
                    ForEach(ProfileComplaintKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.titleKey)).tag(Optional(kind))
                    }
                }.accessibilityIdentifier("profile.complaint.kind")
            }
            Section {
                TextEditor(text: Binding(get: { model.draft.reason }, set: { value in model.change { $0.reason = value } }))
                    .frame(minHeight: 140).focused($focused, equals: .reason)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        // Source placeholder: 请详细描述遇到的问题…
                        if model.draft.reason.isEmpty {
                            Text("profile.complaint.reasonPlaceholder").foregroundStyle(CYColor.textTertiary)
                                .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(Text("profile.complaint.reason"))
                    .accessibilityIdentifier("profile.complaint.reason")
            } header: {
                Text("profile.complaint.reason")
            } footer: {
                // Counter mirrors the 500 UTF-16 unit rule enforced by the draft validation.
                let used = model.draft.reason.utf16.count
                Text(verbatim: "\(used)/500").monospacedDigit()
                    .foregroundStyle(used > 500 ? CYColor.dangerText : CYColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("profile.complaint.reasonCount")
            }
            Section("profile.complaint.contact") {
                TextField("profile.complaint.optional", text: Binding(get: { model.draft.contact },
                    set: { value in model.change { $0.contact = value } }), prompt: Text("profile.complaint.contactPlaceholder"))
                    .focused($focused, equals: .contact).textInputAutocapitalization(.never)
                    .accessibilityLabel(Text("profile.complaint.contact"))
                    .accessibilityIdentifier("profile.complaint.contact")
            }
            Section {
                if let validation = model.validation {
                    Text(LocalizedStringKey(validation.titleKey)).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("profile.complaint.validation")
                }
                // PLY-27-3: one primary 提交投诉 (complaint/index.wxml:75-76). A valid draft goes straight to the
                // confirm sheet; the review section below only remains as the fallback after a cancel or failure.
                CYPillButton(sending.isConfigured ? "profile.complaint.submit.action" : "profile.complaint.review") {
                    focused = nil
                    if !model.beginReview() {
                        switch model.validation {
                        case .reasonShort, .reasonLong: focused = .reason
                        case .contactLong: focused = .contact
                        default: break
                        }
                    } else if sending.isConfigured, sending.canSend(review: model.review) {
                        confirmingSend = true
                    }
                }.accessibilityIdentifier("profile.complaint.review")
            }
        }
    }
    private func reviewSection(_ review: ProfileComplaintReview) -> some View {
        Group {
            Section("profile.complaint.reviewTitle") {
                topicLabel(review.topic).cyText(.cardTitle)
                Text(verbatim: review.reason).accessibilityIdentifier("profile.complaint.reviewText")
                if sending.state == .succeeded {
                    CYStatusChip("profile.complaint.submit.done", tone: .success, systemImage: "checkmark")
                        .accessibilityIdentifier("profile.complaint.submit.done")
                } else if !sending.isConfigured {
                    Text("profile.complaint.notSubmitted").cyText(.bodyCompact)
                        .accessibilityIdentifier("profile.complaint.notSubmitted")
                }
            }
            if case .failed(let failure) = sending.state {
                Section {
                    Text(LocalizedStringKey(failure.titleKey)).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("profile.complaint.submit.failure")
                    if case .rejected(let message?) = failure {
                        Text(verbatim: message).cyText(.bodyCompact).accessibilityIdentifier("profile.complaint.submit.serverMessage")
                    }
                }
            }
            Section {
                if sending.state == .succeeded {
                    Button("action.close") { model.retire(); sending.reset(); dismiss() }
                        .accessibilityIdentifier("profile.complaint.submit.close")
                } else {
                    if sending.isConfigured {
                        CYPillButton(LocalizedStringKey(sending.state == .sending ? "profile.complaint.submit.sending" : "profile.complaint.submit.action")) {
                            confirmingSend = true
                        }
                        .disabled(!sending.canSend(review: model.review))
                        .accessibilityIdentifier("profile.complaint.submit.action")
                    }
                    CYPillButton("profile.complaint.continueEditing", style: .secondary) { model.continueEditing() }
                        .disabled(sending.state == .sending)
                        .accessibilityIdentifier("profile.complaint.continueEditing")
                }
            }
        }
    }
    private func topicLabel(_ topic: ProfileComplaintTopic) -> Text {
        if let name = topic.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return Text(verbatim: name) }
        return Text("profile.complaint.unnamed") + Text(verbatim: " #\(topic.id)")
    }
}
