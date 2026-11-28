import SwiftUI

@MainActor struct NativeChannelOnboardingEntry: View {
    @ObservedObject var session: AppSession
    let channels: NativeChannelManagementCoordinator
    var parentRouteIsActive: () -> Bool = { false }
    @State private var flow: NativeChannelOnboardingFlow?
    @StateObject private var welcomeRoute = NativeChannelManagementRouteState()
    @Environment(\.scenePhase) private var scene
    var body: some View {
        let welcomeVisit = NativeChannelManagementRouteState.child(welcomeRoute.binding, parentCurrent: parentRouteIsActive)
        Group {
            if let flow {
                NativeChannelOnboardingView(flow: flow, openWelcome: { welcomeVisit.wrappedValue = true })
            } else {
                ContentUnavailableView {
                    Label("d7.channelOnboarding.unavailable", systemImage: "list.bullet.clipboard")
                } actions: {
                    Button("d7.channelOnboarding.skip") { welcomeVisit.wrappedValue = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!parentRouteIsActive() || !channels.isCurrent)
                }
            }
        }
        .task { reopen() }
        .onDisappear { close() }
        .onChange(of: scene) { _, value in if value == .active { reopen() } else { close() } }
        .onChange(of: channels.isCurrent) { _, current in if !current { close() } }
        .nativeChannelFlowPage()
        .navigationTitle(Text("d7.channelOnboarding.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: parentRouteIsActive()) { _, current in if !current { welcomeRoute.isPresented = false; close() } }
        .navigationDestination(isPresented: welcomeVisit) {
            NativeChannelWelcomeEntry(session: session, channels: channels, parentRouteIsActive: { welcomeVisit.wrappedValue }).id(welcomeRoute.visitID)
        }
    }
    private func close() { flow?.deactivate(); flow = nil }
    private func reopen() {
        close()
        let parent = parentRouteIsActive, owner = channels
        guard scene == .active, parent(), owner.isCurrent else { return }
        flow = session.makeNativeChannelOnboarding(scope: owner.scope, sourceCurrent: { [weak owner] in parent() && owner?.isCurrent == true })
    }
}

@MainActor struct NativeChannelOnboardingView: View {
    let flow: NativeChannelOnboardingFlow
    let openWelcome: () -> Void
    @State private var selections: [String: Set<String>] = [:]
    var body: some View {
        Form {
            if flow.isCurrent {
                if flow.confirmed != nil || flow.issue != nil || flow.busy {
                    Section {
                        if let confirmed = flow.confirmed { notice(confirmed, symbol: "checkmark.circle.fill", tone: .green) }
                        if let issue = flow.issue { notice(issue, symbol: "exclamationmark.circle", tone: .red) }
                        if flow.busy { CYLoadingState() }
                    }
                }
                if flow.pending != nil {
                    Section {
                        NativeChannelFlowNotice(title: Text("d7.channelOnboarding.pending"), symbol: "clock.arrow.circlepath")
                        Button("d7.channelOnboarding.checkStatus") { Task { await flow.refresh() } }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.checkStatus"))
                    }
                } else if let review = flow.review {
                    Section {
                        ForEach(review.answers, id: \.promptID) { answer in
                            reviewAnswer(answer, review: review)
                        }
                    } header: {
                        Text("d7.channelOnboarding.yourAnswers")
                    }
                    Section {
                        Button("d7.channelOnboarding.confirm") { selections = [:]; Task { await flow.confirm() } }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.confirm"))
                        Button("d7.channelOnboarding.edit") { flow.cancelReview(); selections = [:] }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.edit"))
                    }
                } else if let snapshot = flow.snapshot {
                    Section {
                        LabeledContent("d7.channelOnboarding.status") {
                            Label(
                                LocalizedStringKey(snapshot.submitted == 1 ? "d7.channelOnboarding.done" : "d7.channelOnboarding.notDone"),
                                systemImage: snapshot.submitted == 1 ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        if snapshot.answerState == "SOURCE_CHANGED" {
                            Text("d7.channelOnboarding.changed")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(snapshot.prompts) { prompt in
                        Section {
                            ForEach(prompt.options) { option in
                                optionRow(prompt, option)
                            }
                        } header: {
                            promptHeader(prompt)
                        }
                    }
                    if flow.canPrepare {
                        Section {
                            Button("d7.channelOnboarding.review") { flow.prepare(selections) }
                                .accessibilityLabel(Text("d7.channelOnboarding.review"))
                        }
                    }
                }
                Section {
                    Button("d7.channelOnboarding.skip", action: openWelcome)
                        .accessibilityLabel(Text("d7.channelOnboarding.skip"))
                }
            } else {
                Section { ContentUnavailableView("d7.channelOnboarding.expired", systemImage: "lock.shield") }
            }
        }
        .refreshable { selections = [:]; await flow.refresh() }
        .nativeChannelFlowPage()
        .navigationTitle(Text("d7.channelOnboarding.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task { await flow.activate() }
        .onDisappear { selections = [:]; flow.deactivate() }
    }
    private func optionRow(_ prompt: NativeOnboardingSnapshot.Prompt, _ option: NativeOnboardingSnapshot.Option) -> some View {
        let selected = selections[prompt.id]?.contains(option.id) == true
        let saved = prompt.selected.contains(option.id)
        return VStack(alignment: .leading, spacing: 4) {
            Button { choose(prompt, option.id, !selected) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: optionHead(option)).foregroundStyle(.primary)
                        if !option.description.isEmpty {
                            Text(verbatim: option.description).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if prompt.singleSelect {
                        if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    } else {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!flow.canPrepare)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityLabel(Text(verbatim: optionLabel(option)))
            .accessibilityValue(Text(selected ? LocalizedStringKey("d7.channelOnboarding.selected") : LocalizedStringKey("d7.channelOnboarding.notSelected")))
            if saved {
                Label("d7.channelOnboarding.saved", systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("d7.channelOnboarding.saved"))
            }
        }
    }
    private func optionHead(_ option: NativeOnboardingSnapshot.Option) -> String {
        let titled = option.emoji.isEmpty ? option.label : option.emoji + " " + option.label
        return titled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : titled
    }
    private func optionLabel(_ option: NativeOnboardingSnapshot.Option) -> String {
        let titled = option.emoji.isEmpty ? option.label : option.emoji + " " + option.label
        let head = titled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : titled
        return option.description.isEmpty ? head : head + "\n" + option.description
    }
    private func promptHeader(_ prompt: NativeOnboardingSnapshot.Prompt) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: prompt.title.isEmpty ? "—" : prompt.title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if prompt.required {
                Text("d7.channelOnboarding.required").foregroundStyle(CYColor.warningText)
            }
        }
    }
    @ViewBuilder private func reviewAnswer(_ answer: NativeOnboardingAnswer, review: NativeChannelOnboardingFlow.Command) -> some View {
        if let snapshot = flow.snapshot, snapshot.configurationHash == review.configurationHash,
           let prompt = snapshot.prompts.first(where: { $0.id == answer.promptID }) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: prompt.title)
                    ForEach(prompt.options.filter { answer.optionIDs.contains($0.id) }) { option in
                        Text(verbatim: option.label.isEmpty ? "—" : option.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } icon: { Image(systemName: "text.quote") }
        } else {
            Label { Text(verbatim: "—") } icon: { Image(systemName: "questionmark") }
        }
    }
    private func notice(_ text: String, symbol: String, tone: Color) -> some View {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
        return Label {
            Text(verbatim: shown)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tone).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: shown))
    }
    private func choose(_ prompt: NativeOnboardingSnapshot.Prompt, _ option: String, _ selected: Bool) {
        guard flow.canPrepare else { return }
        if prompt.singleSelect { selections[prompt.id] = selected ? [option] : [] }
        else {
            var values = selections[prompt.id] ?? []
            if selected { values.insert(option) } else { values.remove(option) }
            selections[prompt.id] = values
        }
    }
}
