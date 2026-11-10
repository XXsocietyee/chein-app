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
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    CYHeroHeader("d7.channelOnboarding.title") { ChannelOnboardingCover() }
                    CYEmptyState(
                        systemImage: "list.bullet.clipboard",
                        "d7.channelOnboarding.unavailable",
                        actionTitle: "d7.channelOnboarding.skip",
                        actionStyle: .primary
                    ) { welcomeVisit.wrappedValue = true }
                    .disabled(!parentRouteIsActive() || !channels.isCurrent)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(CYColor.bgPage.ignoresSafeArea())
            }
        }
        .task { reopen() }
        .onDisappear { close() }
        .onChange(of: scene) { _, value in if value == .active { reopen() } else { close() } }
        .onChange(of: channels.isCurrent) { _, current in if !current { close() } }
        .nativeChannelFlowPage()
        .cyHeroScreen()
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
    /// The commit control (check, confirm, or review) is the one primary. Skip takes that role only when no commit is on screen.
    private var hasCommit: Bool {
        if flow.pending != nil { return true }
        if flow.review != nil { return true }
        if flow.snapshot != nil && flow.canPrepare { return true }
        return false
    }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("d7.channelOnboarding.title") { ChannelOnboardingCover() }
                    .channelKitInset(clear: true)
            }
            if flow.isCurrent {
                if flow.confirmed != nil || flow.issue != nil || flow.busy {
                    Section {
                        if let confirmed = flow.confirmed { notice(confirmed, symbol: "checkmark.circle", tone: CYColor.successText) }
                        if let issue = flow.issue { notice(issue, symbol: "exclamationmark.circle", tone: CYColor.dangerText) }
                        if flow.busy { CYSkeleton().channelKitInset(clear: true) }
                    }
                }
                if flow.pending != nil {
                    Section {
                        NativeChannelFlowNotice(title: Text("d7.channelOnboarding.pending"), symbol: "clock.arrow.circlepath")
                        CYPillButton("d7.channelOnboarding.checkStatus") { Task { await flow.refresh() } }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.checkStatus"))
                            .channelKitInset(clear: true)
                    }
                } else if let review = flow.review {
                    Section {
                        ForEach(review.answers, id: \.promptID) { answer in
                            reviewAnswer(answer, review: review)
                        }
                    } header: {
                        CYSectionHeader("d7.channelOnboarding.yourAnswers")
                    }
                    Section {
                        CYPillButton("d7.channelOnboarding.confirm") { selections = [:]; Task { await flow.confirm() } }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.confirm"))
                            .channelKitInset(clear: true)
                        CYPillButton("d7.channelOnboarding.edit", style: .secondary) { flow.cancelReview(); selections = [:] }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelOnboarding.edit"))
                            .channelKitInset(clear: true)
                    }
                } else if let snapshot = flow.snapshot {
                    Section {
                        LabeledContent("d7.channelOnboarding.status") {
                            CYStatusChip(
                                snapshot.submitted == 1 ? "d7.channelOnboarding.done" : "d7.channelOnboarding.notDone",
                                tone: snapshot.submitted == 1 ? .success : .neutral,
                                systemImage: snapshot.submitted == 1 ? "checkmark.circle" : "circle"
                            )
                        }
                        if snapshot.answerState == "SOURCE_CHANGED" {
                            Text("d7.channelOnboarding.changed")
                                .font(CYTypography.meta)
                                .foregroundStyle(CYColor.textSecondary)
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
                            CYPillButton("d7.channelOnboarding.review") { flow.prepare(selections) }
                                .accessibilityLabel(Text("d7.channelOnboarding.review"))
                                .channelKitInset(clear: true)
                        }
                    }
                }
                Section {
                    CYPillButton("d7.channelOnboarding.skip", style: hasCommit ? .tertiary : .primary, action: openWelcome)
                        .accessibilityLabel(Text("d7.channelOnboarding.skip"))
                        .channelKitInset(clear: true)
                }
            } else {
                CYEmptyState(systemImage: "lock.shield", "d7.channelOnboarding.expired")
                    .channelKitInset(clear: true)
            }
        }
        .refreshable { selections = [:]; await flow.refresh() }
        .nativeChannelFlowPage()
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .task { await flow.activate() }
        .onDisappear { selections = [:]; flow.deactivate() }
    }
    private func optionRow(_ prompt: NativeOnboardingSnapshot.Prompt, _ option: NativeOnboardingSnapshot.Option) -> some View {
        let selected = selections[prompt.id]?.contains(option.id) == true
        let saved = prompt.selected.contains(option.id)
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYChoiceRow(
                label: optionLabel(option),
                selected: selected,
                multi: !prompt.singleSelect,
                enabled: flow.canPrepare
            ) { choose(prompt, option.id, !selected) }
            .accessibilityLabel(Text(verbatim: optionLabel(option)))
            .accessibilityValue(Text(selected ? LocalizedStringKey("d7.channelOnboarding.selected") : LocalizedStringKey("d7.channelOnboarding.notSelected")))
            if saved {
                CYStatusChip("d7.channelOnboarding.saved", tone: .success, systemImage: "checkmark")
                    .accessibilityLabel(Text("d7.channelOnboarding.saved"))
            }
        }
        .channelKitInset()
    }
    private func optionLabel(_ option: NativeOnboardingSnapshot.Option) -> String {
        let titled = option.emoji.isEmpty ? option.label : option.emoji + " " + option.label
        let head = titled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : titled
        return option.description.isEmpty ? head : head + "\n" + option.description
    }
    private func promptHeader(_ prompt: NativeOnboardingSnapshot.Prompt) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: prompt.title.isEmpty ? "—" : prompt.title)
                .font(CYTypography.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if prompt.required {
                CYStatusChip("d7.channelOnboarding.required", tone: .warning, systemImage: "asterisk")
            }
        }
        .textCase(nil)
    }
    @ViewBuilder private func reviewAnswer(_ answer: NativeOnboardingAnswer, review: NativeChannelOnboardingFlow.Command) -> some View {
        if let snapshot = flow.snapshot, snapshot.configurationHash == review.configurationHash,
           let prompt = snapshot.prompts.first(where: { $0.id == answer.promptID }) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYListRow(verbatim: prompt.title, trailing: CYListRowTrailing.none) {
                    CYRowIcon(systemImage: "text.quote")
                }
                ForEach(prompt.options.filter { answer.optionIDs.contains($0.id) }) { option in
                    Text(verbatim: option.label.isEmpty ? "—" : option.label)
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            CYListRow(verbatim: "—", trailing: CYListRowTrailing.none) {
                CYRowIcon(systemImage: "questionmark")
            }
        }
    }
    private func notice(_ text: String, symbol: String, tone: Color) -> some View {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
        return HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: symbol).foregroundStyle(tone).accessibilityHidden(true)
            Text(verbatim: shown)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
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

private struct ChannelOnboardingCover: View {
    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                CYCoverArt(seed: "channel-onboarding", symbol: "list.bullet.clipboard", showsDebugLabel: false, cornerRadius: CYRadius.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ChannelKitInset: ViewModifier {
    var clear = false
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(clear ? Color.clear : CYColor.bgElevated)
            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
    }
}

private extension View {
    func channelKitInset(clear: Bool = false) -> some View {
        modifier(ChannelKitInset(clear: clear))
    }
}
