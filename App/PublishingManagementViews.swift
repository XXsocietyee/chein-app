import SwiftUI

@MainActor struct PublishingProjectsView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    let service: PublishingService?
    let account: PublishingSession?
    var openResource: (PublishedResource) -> Void
    var readOnly = false
    /// MP `myproject/index?type=club_activity` lands on one type tab. Applied once, on first appearance.
    var initialType: String? = nil
    #if DEBUG
    /// Design fixture only (DEBUG): "rows" | "empty" | "loading" bypasses the service read with synthetic projects.
    var designPreview: String? = nil
    #endif
    @State private var type = "all"
    @State private var appliedInitialType = false
    @State private var state = "all"
    @State private var owner = "all"
    @State private var rows: [PublishingProject] = []
    @State private var requests: [ProjectStateRequestContract.Saved] = []
    @State private var requestAccount: PublishingSession?
    @State private var total = 0
    @State private var unknown = 0
    @State private var busy = false
    @State private var failed = false
    @State private var review: PublishingReview?
    @State private var message = ""
    @State private var generation = 0
    private var query: PublishingRead { .projects(type: type, state: state, ownerType: owner, scope: "", pageSize: 200) }
    @Environment(\.cyPalette) private var palette
    private static let typeFilters = ["all", "topic", "activity", "template"]
    private static let stateFilters = ["all", "draft", "pending", "rejected", "running", "notStarted", "offline", "completed"]
    private static let ownerFilters = ["all", "member", "club", "merchant"]
    var body: some View {
        // Mini-program subpackageA/pages/myproject: page title, type tabs (topic / activity / template),
        // then the project list or an empty state. State and owner filters sit in quiet menu chips.
        List {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Picker("publishModes.type", selection: $type) { ForEach(Self.typeFilters, id: \.self) { Text(LocalizedStringKey("publishModes.filter." + $0)).tag($0) } }
                        .pickerStyle(.segmented)
                    HStack(spacing: CYSpacing.sm) {
                        filterMenu("publishModes.state", selection: $state, options: Self.stateFilters)
                        filterMenu("publishModes.owner", selection: $owner, options: Self.ownerFilters)
                    }
                }.disabled(busy)
            }.listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            if busy {
                ForEach(0..<3, id: \.self) { _ in CYSkeleton().cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg).projectRow() }
            }
            if failed { CYErrorState("publishModes.readFailed", retryTitle: "publishModes.retry") { Task { await load() } }.projectRow() }
            if rows.isEmpty && !busy && !failed { CYEmptyState(systemImage: "square.stack", "publishModes.empty").projectRow() }
            if total > rows.count + unknown { Text("publishModes.truncated").cyText(.meta).foregroundStyle(palette.textTertiary).projectRow() }
            if unknown > 0 { Text("publishModes.unknownTypes").cyText(.meta).foregroundStyle(palette.textTertiary).projectRow() }
            if requestAccount == account, service?.currentSession == account, !requests.isEmpty {
                Section {
                    CYSectionHeader(LocalizedStringKey(chinese ? "原状态操作记录" : "Original status requests")).projectRow()
                    Text((chinese ? "列表消失不代表删除成功；只读取原请求回执，不翻转重放。" : "A missing list row does not confirm deletion. Read the original receipt without replaying the request."))
                        .cyText(.meta).foregroundStyle(palette.textTertiary).projectRow()
                    ForEach(requests) { saved in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(saved.title).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                            Text(saved.action == .remove ? (chinese ? "已确认的原移除请求" : "Original confirmed removal request") : (saved.submit.command?.expectedOnline == true ? (chinese ? "已确认的原下架请求" : "Original confirmed offline request") : (chinese ? "已确认的原上架请求" : "Original confirmed online request")))
                                .cyText(.meta).foregroundStyle(palette.textSecondary)
                            Text(saved.id).cyText(.meta).foregroundStyle(palette.textTertiary).textSelection(.enabled)
                            if let receipt = saved.receipt {
                                Text(receipt.applied ? (chinese ? "原 writer 已执行本次操作" : "The original writer applied this request") : receipt.terminal ? (chinese ? "原请求已结束，目标操作未执行" : "The original request ended without applying the action") : (chinese ? "结果仍未知，保持原请求锁" : "Outcome remains unknown; the original request stays locked"))
                                    .cyText(.meta).foregroundStyle(palette.textSecondary)
                                if let reason = receipt.originalResult?.object?["msg"]?.text { Text(reason).cyText(.meta).foregroundStyle(palette.textSecondary) }
                            } else { Text((chinese ? "尚未读回原请求结果" : "The original outcome has not been read back")).cyText(.meta).foregroundStyle(palette.textSecondary) }
                            Button((chinese ? "回读这次操作" : "Read this request’s outcome")) { Task { await readOutcome(saved) } }
                                .buttonStyle(.bordered)
                                .disabled(busy || service?.canReadStateReceipt != true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg).projectRow()
                    }
                }
            }
            ForEach(rows) { project in
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if readOnly { projectHeader(project) }
                    else { Button { openProject(project.resource) } label: { projectHeader(project) }.buttonStyle(.plain) }
                    if project.signupCount > 0 {
                        Text("\(project.signupCount) " + appLocalized("publishModes.signups", locale: locale)).cyText(.numericBody).foregroundStyle(palette.textSecondary)
                    }
                    if !readOnly && (project.canToggle || project.canDelete) {
                        HStack(spacing: CYSpacing.sm) {
                            if project.canToggle { Button(LocalizedStringKey(project.online ? "publishModes.takeOffline" : "publishModes.putOnline")) { Task { await prepare(project, action: .toggle) } }.buttonStyle(.bordered).disabled(busy || hasPendingRequest(project.resource)) }
                            if project.canDelete { Button("publishModes.remove", role: .destructive) { Task { await prepare(project, action: .remove) } }.buttonStyle(.bordered).foregroundStyle(palette.danger).disabled(busy || hasPendingRequest(project.resource)) }
                        }
                    }
                    if !readOnly && project.canCancelWithRefund { Text("publishModes.refundHandoff").cyText(.meta).foregroundStyle(palette.textTertiary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg).projectRow()
            }
            if !message.isEmpty { Text(message).cyText(.meta).foregroundStyle(palette.textSecondary).projectRow().accessibilityIdentifier("publishModes.management.message") }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).cyDomainPageBackground()
        .navigationBarTitleDisplayMode(.large)
.navigationTitle(Text("publishModes.projects"))
        .task {
            if !appliedInitialType, let initialType, Self.typeFilters.contains(initialType) {
                appliedInitialType = true
                // The type change reloads through onChange(of: type).
                if type != initialType { type = initialType; return }
            }
            await load()
        }.refreshable { await load() }
        .onChange(of: type) { _, _ in Task { await load() } }
        .onChange(of: state) { _, _ in Task { await load() } }
        .onChange(of: owner) { _, _ in Task { await load() } }
        .onChange(of: account) { _, _ in generation += 1; service?.invalidateReviews(); review = nil; rows = []; requests = []; requestAccount = nil; total = 0; message = ""; Task { await load() } }
        .onDisappear { generation += 1; if let review { service?.cancel(review) }; review = nil; busy = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { generation += 1; if let review { service?.cancel(review) }; review = nil; busy = false }
        }
        .sheet(item: $review) { snapshot in
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                Group {
                    if snapshot.action == .remove {
                        Text("publishModes.removeQuestion \(snapshot.baseline?.title ?? "")")
                    } else if snapshot.baseline?.online == true {
                        Text("publishModes.offlineQuestion \(snapshot.baseline?.title ?? "")")
                    } else {
                        Text("publishModes.onlineQuestion \(snapshot.baseline?.title ?? "")")
                    }
                }.cyText(.sectionTitle).foregroundStyle(palette.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: CYSpacing.sm) {
                    Button { Task { await submit(snapshot) } } label: {
                        Text(LocalizedStringKey(snapshot.action == .remove ? "publishModes.remove" : snapshot.baseline?.online == true ? "publishModes.takeOffline" : "publishModes.putOnline")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(snapshot.action == .remove ? AnyButtonStyle(CYDestructiveButtonStyle(isFullWidth: true)) : AnyButtonStyle(CYPillButtonStyle(style: .primary)))
                    .disabled(service?.mutationsConfigured != true || busy)
                    CYPillButton("publishModes.cancel", style: .tertiary) { service?.cancel(snapshot); review = nil }
                }
                Spacer(minLength: 0)
            }
            .padding(CYSpacing.pageHorizontal).padding(.top, CYSpacing.xl)
            .background(palette.bgPage.ignoresSafeArea())
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    private func filterMenu(_ title: LocalizedStringKey, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            Picker(title, selection: selection) { ForEach(options, id: \.self) { Text(LocalizedStringKey("publishModes.filter." + $0)).tag($0) } }
        } label: {
            HStack(spacing: CYSpacing.xs) {
                (Text(title) + Text(verbatim: " · ") + Text(LocalizedStringKey("publishModes.filter." + selection.wrappedValue))).cyText(.label).cyWrapText()
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, CYSpacing.md).frame(minHeight: CYSpacing.minTouchTarget)
            .background(Capsule(style: .continuous).fill(palette.bgRaised))
        }
        .accessibilityLabel(Text(title))
    }
    private func projectHeader(_ project: PublishingProject) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(project.title).cyText(.cardTitle).foregroundStyle(palette.textPrimary).multilineTextAlignment(.leading)
                if let state = project.stateText {
                    Text(state).cyText(.meta).foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(Capsule(style: .continuous).fill(palette.bgRaised))
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if !readOnly { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true) }
        }
        .contentShape(Rectangle())
    }
    /// The result destination must not escape into detail editors or lifecycle actions.
    func openProject(_ resource: PublishedResource) { guard !readOnly else { return }; openResource(resource) }
    private func load() async {
        generation += 1; let stamp = generation; if let review { service?.cancel(review) }; review = nil; busy = true; failed = false; rows = []
        #if DEBUG
        if let designPreview {
            if designPreview == "rows" { rows = PublishDesignFixtures.sampleProjects; total = rows.count }
            busy = designPreview == "loading"; return
        }
        #endif
        guard let service, let account else { busy = false; failed = true; return }
        do { requests = try service.stateRequests(session: account); requestAccount = account; let page = try PublishingContracts.decodeProjects(await service.read(query, session: account)); guard stamp == generation else { return }; rows = page.rows; total = page.total; unknown = page.unknownRows.count; busy = false }
        catch { guard stamp == generation else { return }; busy = false; failed = true }
    }
    private func hasPendingRequest(_ resource: PublishedResource) -> Bool {
        guard let account, let service else { return true }
        return (try? service.hasUncertainOutcome(targetKey: "publishModes:\(resource.kind.rawValue):\(resource.value)", session: account)) ?? true
    }
    private func prepare(_ project: PublishingProject, action: PublishingProjectAction) async {
        guard !readOnly, !busy, !hasPendingRequest(project.resource), let service, let account else { return }; let stamp = generation; busy = true
        do { let value = try await service.prepareProject(project, action: action, query: query, session: account); guard stamp == generation else { service.cancel(value); return }; review = value; busy = false }
        catch { guard stamp == generation else { return }; busy = false; message = appLocalized("publishModes.conflict", locale: locale) }
    }
    private func readOutcome(_ saved: ProjectStateRequestContract.Saved) async {
        guard !busy, let service, let account else { return }
        let stamp = generation; busy = true
        do {
            _ = try await service.readStateOutcome(saved, session: account)
            guard stamp == generation, service.currentSession == account else { return }
            requests = try service.stateRequests(session: account); busy = false
            message = (chinese ? "已回读原请求；没有重新执行状态操作。" : "The original receipt was read without replaying the action.")
        } catch {
            guard stamp == generation else { return }; busy = false
            message = (chinese ? "原请求回读暂不可用，保留原记录和未知锁。" : "Readback is unavailable. The original record and uncertainty lock remain.")
        }
    }
    private func submit(_ snapshot: PublishingReview) async {
        guard !readOnly, !busy, let service else { return }; let stamp = generation; busy = true; review = nil
        let outcome = await service.submit(snapshot); guard stamp == generation, service.currentSession == account else { return }; busy = false
        if let account { requests = (try? service.stateRequests(session: account)) ?? requests; requestAccount = account }
        switch outcome {
        case .acknowledged: message = appLocalized("publishModes.acknowledged", locale: locale); await load()
        case .rejected(let text): message = text.isEmpty ? appLocalized("publishModes.rejected", locale: locale) : text
        case .notSent: message = appLocalized("publishModes.notSent", locale: locale)
        case .unknown: message = appLocalized("publishModes.unknown", locale: locale)
        }
    }
}
private struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
private extension View {
    /// Plain card row inside the projects list: no separator, no system row background, page-margin insets.
    func projectRow() -> some View {
        listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.xs, trailing: CYSpacing.pageHorizontal))
    }
}
@MainActor struct PublishingIdentityStatusView: View {
    let service: PublishingService?
    let account: PublishingSession?
    private enum Status { case unconfigured, loading, failed, registered, notRegistered }
    @State private var status: Status = .unconfigured
    var body: some View {
        List {
            if account?.region == .unitedStates { Text("publishModes.identityUSUnsupported") }
            else {
                switch status {
                case .unconfigured: Text("publishModes.offlineNotice")
                case .loading: ProgressView()
                case .failed: Text("publishModes.readFailed")
                case .registered:
                    Text("publishModes.registered")
                    Text("publishModes.identityChange").foregroundStyle(.secondary)
                case .notRegistered:
                    Text("publishModes.notRegistered")
                    Text("publishModes.identityHandoff").foregroundStyle(.secondary)
                }
                Text("publishModes.identityPrivacy").cyText(.meta)
            }
        }.navigationTitle(Text("publishModes.identity")).navigationBarTitleDisplayMode(.inline)
        .task(id: account?.epoch) {
            status = .unconfigured
            guard let account, let service, account.region == .china else { return }
            status = .loading
            do {
                let registered = try await service.identityRegistered(session: account)
                guard !Task.isCancelled, service.currentSession == account else { return }
                status = registered ? .registered : .notRegistered
            } catch {
                guard !Task.isCancelled, service.currentSession == account else { return }
                status = .failed
            }
        }
    }
}
/// Embed in full-scope ProjectEdit forms only. Existing whitelist locks remain authoritative.
struct PublishingTopicRewardsForm: View {
    @Binding var rewards: PublishingTopicRewards
    var fullEdit: Bool
    var body: some View {
        Section("publishModes.rewards") {
            Toggle("publishModes.selfPlay", isOn: $rewards.selfPlay)
            if rewards.selfPlay {
                TextField("publishModes.price", text: $rewards.selfPlayPrice).keyboardType(.decimalPad)
                TextField("publishModes.quota", text: $rewards.selfPlayQuota).keyboardType(.numberPad)
            }
            TextField("publishModes.medalName", text: $rewards.medalName)
            TextField("publishModes.medalImage", text: $rewards.medalImage).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text("publishModes.uploadDisabled").cyText(.meta)
            TextField("publishModes.coupon", value: $rewards.couponID, format: .number).keyboardType(.numberPad)
            Text("publishModes.couponNotice").cyText(.meta).foregroundStyle(.secondary)
        }.disabled(!fullEdit)
    }
}
