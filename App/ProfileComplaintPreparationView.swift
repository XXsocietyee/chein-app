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
        } label: { Label { Text("profile.complaint.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcMegaphone) } }
            .accessibilityIdentifier("profile.complaint.open")
    }
}

/// `subpackageMember/complaint/index` for the page router (PLY-27-1): the same screen the 我的 row pushes.
@MainActor struct ProfileComplaintDeepLinkScreen: View {
    @ObservedObject var session: AppSession
    /// R7-MEM-27-1: the link can open this page signed out; 登录 presents the player sign-in, and the new
    /// session revision rebuilds (and so reloads) the page.
    @State private var showsSignIn = false
    var body: some View {
        let _ = WP06ComplaintWrite.install()
        let revision = session.sessionRevision
        let owner = session.cooperationFlowReader.session
        ProfileComplaintPreparationView(reader: session.cooperationFlowReader,
            isCurrent: { session.sessionRevision == revision && session.cooperationFlowReader.session == owner },
            submitter: ProfileComplaintPreparationLink.submitterFactory?(session),
            onSignIn: { showsSignIn = true })
            .id(revision)
            .cySheet(isPresented: $showsSignIn) {
                LoginView(intent: .player).environmentObject(session)
                    .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
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
    /// MP complaint/index.wxml:19-21 登录 on the signed-out read. Nil keeps the state without a button.
    var onSignIn: (() -> Void)? = nil
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool) {
        self.reader = reader; self.isCurrent = isCurrent; submitter = nil
    }
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool, submitter: (any ProfileComplaintSubmitting)?,
         onSignIn: (() -> Void)? = nil) {
        self.reader = reader; self.isCurrent = isCurrent; self.submitter = submitter; self.onSignIn = onSignIn
    }
    var body: some View {
        ProfileComplaintPreparationScreen(reader: reader, isCurrent: isCurrent, submitter: submitter, onSignIn: onSignIn)
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
    private let onSignIn: (() -> Void)?
    init(reader: any CoopFlowReading, isCurrent: @escaping @MainActor () -> Bool, submitter: (any ProfileComplaintSubmitting)?,
         onSignIn: (() -> Void)? = nil) {
        self.reader = reader
        self.onSignIn = onSignIn
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
                Text("profile.complaint.pageSubtitle").fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.complaint.pageSubtitle")
            }
            if !model.contextMatches {
                Text("profile.complaint.retired").accessibilityIdentifier("profile.complaint.retired")
            } else if let review = model.review {
                reviewSection(review)
            } else {
                if model.isLoading {
                    // Source copy: 正在加载可投诉的活动.
                    ProgressView { Text("profile.complaint.loadingTopics") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("profile.complaint.loading")
                }
                if let issue = model.issue {
                    Section {
                        // mp-states r3 (MP complaint wxml:19-31): 登录后发起投诉与查看进展 · 登录, or 可投诉活动加载失败 with the
                        // reason under it and 重试 — the one state pattern (ContentUnavailableView, one system button).
                        ContentUnavailableView {
                            Label { Text(LocalizedStringKey(complaintStateTitleKey(issue))).accessibilityIdentifier("profile.complaint.issueTitle") } icon: {
                                Image(systemName: issue == .signIn ? "person.crop.circle.badge.exclamationmark" : issue == .denied ? "lock" : "exclamationmark.triangle")
                            }
                        } description: {
                            if issue == .failed {
                                Text(LocalizedStringKey(model.isNetworkFailure ? "profile.complaint.read.network" : issue.titleKey))
                                    .accessibilityIdentifier("profile.complaint.issue")
                            }
                        } actions: {
                            if issue == .failed || issue == .denied {
                                Button("action.retry") { Task { await model.load() } }
                                    .buttonStyle(.bordered)
                                    .disabled(model.isLoading).accessibilityIdentifier("profile.complaint.retry")
                            } else if issue == .signIn, let onSignIn {
                                Button("auth.signIn", action: onSignIn)
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("profile.complaint.signIn")
                            }
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
                            }
                        }
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
        .cySheet(isPresented: $confirmingSend) {
            MemberComplaintSubmitConfirmSheet {
                confirmingSend = false
                if let review = model.review { Task { await sending.send(review: review, isCurrent: { model.contextMatches }) } }
            }
            .themeDomain(.player)
        }
    }
    private func complaintStateTitleKey(_ issue: ProfileComplaintReadIssue) -> String {
        switch issue {
        case .signIn: return "profile.complaint.state.signIn"
        case .failed: return "profile.complaint.state.failed"
        case .unavailable: return issue.titleKey
        case .denied: return "profile.complaint.state.denied"
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
                // Source placeholder: 请详细描述遇到的问题… (the system prompt of a multi-line TextField).
                TextField("profile.complaint.reason", text: Binding(get: { model.draft.reason }, set: { value in model.change { $0.reason = value } }),
                          prompt: Text("profile.complaint.reasonPlaceholder"), axis: .vertical)
                    .lineLimit(6...12)
                    .focused($focused, equals: .reason)
                    .accessibilityLabel(Text("profile.complaint.reason"))
                    .accessibilityIdentifier("profile.complaint.reason")
            } header: {
                Text("profile.complaint.reason")
            } footer: {
                // Counter mirrors the 500 UTF-16 unit rule enforced by the draft validation.
                let used = model.draft.reason.utf16.count
                Text(verbatim: "\(used)/500").monospacedDigit()
                    .foregroundStyle(used > 500 ? CYColor.dangerText : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("profile.complaint.reasonCount")
            }
            Section("profile.complaint.contact") {
                TextField("profile.complaint.optional", text: Binding(get: { model.draft.contact },
                    set: { value in model.change { $0.contact = value } }), prompt: Text("profile.complaint.contactPlaceholder"))
                    .focused($focused, equals: .contact).textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .accessibilityLabel(Text("profile.complaint.contact"))
                    .accessibilityIdentifier("profile.complaint.contact")
            }
            Section {
                if let validation = model.validation {
                    Text(LocalizedStringKey(validation.titleKey)).font(.subheadline).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("profile.complaint.validation")
                }
                // PLY-27-3: one primary 提交投诉 (complaint/index.wxml:75-76). A valid draft goes straight to the
                // confirm sheet; the review section below only remains as the fallback after a cancel or failure.
                Button {
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
                } label: {
                    Text(LocalizedStringKey(sending.isConfigured ? "profile.complaint.submit.action" : "profile.complaint.review"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                // PLY-27-6: MP complaint/index.js:283-287 keeps 提交投诉 disabled until a topic is chosen and the reason
                // has 5 characters; over-limit text still reaches the inline message on tap.
                .disabled({
                    let blocking = model.draft.validation(topics: model.topics ?? [])
                    return blocking == .topic || blocking == .reasonShort
                }())
                .accessibilityIdentifier("profile.complaint.review")
            }
        }
    }
    private func reviewSection(_ review: ProfileComplaintReview) -> some View {
        Group {
            Section("profile.complaint.reviewTitle") {
                topicLabel(review.topic).font(.headline)
                Text(verbatim: review.reason).accessibilityIdentifier("profile.complaint.reviewText")
                if sending.state == .succeeded {
                    Label("profile.complaint.submit.done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(CYColor.successText)
                        .accessibilityIdentifier("profile.complaint.submit.done")
                } else if !sending.isConfigured {
                    Text("profile.complaint.notSubmitted").font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.complaint.notSubmitted")
                }
            }
            if case .failed(let failure) = sending.state {
                Section {
                    Text(LocalizedStringKey(failure.titleKey)).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("profile.complaint.submit.failure")
                    if case .rejected(let message?) = failure {
                        Text(verbatim: message).font(.subheadline).accessibilityIdentifier("profile.complaint.submit.serverMessage")
                    }
                }
            }
            Section {
                if sending.state == .succeeded {
                    Button("action.close") { model.retire(); sending.reset(); dismiss() }
                        .accessibilityIdentifier("profile.complaint.submit.close")
                } else {
                    if sending.isConfigured {
                        Button {
                            confirmingSend = true
                        } label: {
                            Text(LocalizedStringKey(sending.state == .sending ? "profile.complaint.submit.sending" : "profile.complaint.submit.action"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!sending.canSend(review: model.review))
                        .accessibilityIdentifier("profile.complaint.submit.action")
                    }
                    Button { model.continueEditing() } label: {
                        Text("profile.complaint.continueEditing").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.bordered).controlSize(.large)
                        .disabled(sending.state == .sending)
                        .accessibilityIdentifier("profile.complaint.continueEditing")
                }
            }
        }
    }
    private func topicLabel(_ topic: ProfileComplaintTopic) -> Text {
        if let name = topic.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return Text(verbatim: name) }
        return Text("profile.complaint.unnamed")
    }
}
