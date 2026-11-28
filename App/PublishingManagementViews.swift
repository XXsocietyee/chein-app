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
    private static let typeFilters = ["all", "topic", "activity", "template"]
    private static let stateFilters = ["all", "draft", "pending", "rejected", "running", "notStarted", "offline", "completed"]
    private static let ownerFilters = ["all", "member", "club", "merchant"]
    var body: some View {
        // Mini-program subpackageA/pages/myproject: page title, type tabs (topic / activity / template),
        // then the project list or an empty state. State and owner filters sit in quiet menu chips.
        List {
            Section {
                Picker("publishModes.type", selection: $type) { ForEach(Self.typeFilters, id: \.self) { Text(LocalizedStringKey("publishModes.filter." + $0)).tag($0) } }
                    .cyAdaptiveSegmented()
                filterPicker("publishModes.state", selection: $state, options: Self.stateFilters)
                filterPicker("publishModes.owner", selection: $owner, options: Self.ownerFilters)
            }.disabled(busy)
            if busy {
                Section { CYLoadingState() }
            }
            if failed {
                ContentUnavailableView {
                    Label("publishModes.readFailed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("publishModes.retry") { Task { await load() } }.buttonStyle(.bordered)
                }
            }
            if rows.isEmpty && !busy && !failed { ContentUnavailableView("publishModes.empty", systemImage: "square.stack") }
            if requestAccount == account, service?.currentSession == account, !requests.isEmpty {
                Section {
                    ForEach(requests) { saved in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(saved.title).font(.headline)
                            Text(saved.action == .remove ? (chinese ? "已确认的原移除请求" : "Original confirmed removal request") : (saved.submit.command?.expectedOnline == true ? (chinese ? "已确认的原下架请求" : "Original confirmed offline request") : (chinese ? "已确认的原上架请求" : "Original confirmed online request")))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(saved.id).font(.footnote).foregroundStyle(.tertiary).textSelection(.enabled)
                            if let receipt = saved.receipt {
                                Text(receipt.applied ? (chinese ? "原 writer 已执行本次操作" : "The original writer applied this request") : receipt.terminal ? (chinese ? "原请求已结束，目标操作未执行" : "The original request ended without applying the action") : (chinese ? "结果仍未知，保持原请求锁" : "Outcome remains unknown; the original request stays locked"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if let reason = receipt.originalResult?.object?["msg"]?.text { Text(reason).font(.subheadline).foregroundStyle(.secondary) }
                            } else { Text((chinese ? "尚未读回原请求结果" : "The original outcome has not been read back")).font(.subheadline).foregroundStyle(.secondary) }
                            Button((chinese ? "回读这次操作" : "Read this request’s outcome")) { Task { await readOutcome(saved) } }
                                .buttonStyle(.bordered)
                                .disabled(busy || service?.canReadStateReceipt != true)
                        }
                    }
                } header: {
                    Text(verbatim: chinese ? "原状态操作记录" : "Original status requests")
                } footer: {
                    Text((chinese ? "列表消失不代表删除成功；只读取原请求回执，不翻转重放。" : "A missing list row does not confirm deletion. Read the original receipt without replaying the request."))
                }
            }
            if !rows.isEmpty {
                Section {
                    ForEach(rows) { project in
                        VStack(alignment: .leading, spacing: 8) {
                            if readOnly { projectHeader(project) }
                            else { Button { openProject(project.resource) } label: { projectHeader(project) }.buttonStyle(.plain) }
                            if project.signupCount > 0 {
                                Text(appLocalized("publishModes.signupCount \(project.signupCount)", locale: locale)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                            }
                            if !readOnly && (project.canToggle || project.canDelete) {
                                HStack(spacing: 8) {
                                    if project.canToggle { Button(LocalizedStringKey(project.online ? "publishModes.takeOffline" : "publishModes.putOnline")) { Task { await prepare(project, action: .toggle) } }.buttonStyle(.bordered).disabled(busy || hasPendingRequest(project.resource)) }
                                    if project.canDelete { Button("publishModes.remove", role: .destructive) { Task { await prepare(project, action: .remove) } }.buttonStyle(.bordered).disabled(busy || hasPendingRequest(project.resource)) }
                                }
                            }
                            if !readOnly && project.canCancelWithRefund { Text("publishModes.refundHandoff").font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if total > rows.count + unknown { Text("publishModes.truncated") }
                        if unknown > 0 { Text("publishModes.unknownTypes") }
                    }
                }
            }
            if !message.isEmpty { Section { Text(message).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("publishModes.management.message") } }
        }
        .navigationBarTitleDisplayMode(.inline)
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
        .confirmationDialog(reviewQuestion(review), isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil } }),
                            titleVisibility: .visible, presenting: review) { snapshot in
            Button(LocalizedStringKey(snapshot.action == .remove ? "publishModes.remove" : snapshot.baseline?.online == true ? "publishModes.takeOffline" : "publishModes.putOnline"),
                   role: snapshot.action == .remove ? .destructive : nil) { Task { await submit(snapshot) } }
                .disabled(service?.mutationsConfigured != true || busy)
            Button("publishModes.cancel", role: .cancel) { service?.cancel(snapshot); review = nil }
        }
    }
    private func reviewQuestion(_ snapshot: PublishingReview?) -> Text {
        guard let snapshot else { return Text(verbatim: "") }
        if snapshot.action == .remove { return Text("publishModes.removeQuestion \(snapshot.baseline?.title ?? "")") }
        if snapshot.baseline?.online == true { return Text("publishModes.offlineQuestion \(snapshot.baseline?.title ?? "")") }
        return Text("publishModes.onlineQuestion \(snapshot.baseline?.title ?? "")")
    }
    private func filterPicker(_ title: LocalizedStringKey, selection: Binding<String>, options: [String]) -> some View {
        Picker(title, selection: selection) { ForEach(options, id: \.self) { Text(LocalizedStringKey("publishModes.filter." + $0)).tag($0) } }
            .pickerStyle(.menu)
    }
    private func projectHeader(_ project: PublishingProject) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if let state = project.stateText {
                    Text(state).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !readOnly { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true) }
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
@MainActor struct PublishingIdentityStatusView: View {
    let service: PublishingService?
    let account: PublishingSession?
    private enum Status { case unconfigured, loading, failed, registered, notRegistered }
    @State private var status: Status = .unconfigured
    @State private var reloadToken = 0
    var body: some View {
        List {
            if account?.region == .unitedStates { Text("publishModes.identityUSUnsupported") }
            else {
                switch status {
                case .unconfigured: Text("publishModes.offlineNotice")
                case .loading:
                    // mp-states-b r3: the status read says what it is reading (P10), never a silent spinner.
                    ProgressView { Text("publishModes.identityLoading") }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("publishModes.identity.loading")
                case .failed:
                    // mp-states-b r3 (MP cy-error load-failure · 重试): one titled state with a retry, not a "list" sentence.
                    ContentUnavailableView {
                        Label("publishModes.identityReadFailed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("cy.kit.offline.body")
                    } actions: {
                        Button("publishModes.retry") { reloadToken += 1 }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("publishModes.identity.retry")
                    }
                    .accessibilityIdentifier("publishModes.identity.failed")
                case .registered:
                    Text("publishModes.registered")
                    Text("publishModes.identityChange").foregroundStyle(.secondary)
                case .notRegistered:
                    Text("publishModes.notRegistered")
                    Text("publishModes.identityHandoff").foregroundStyle(.secondary)
                }
                Text("publishModes.identityPrivacy").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(Text("publishModes.identity")).navigationBarTitleDisplayMode(.inline)
        .task(id: "\(account?.epoch.uuidString ?? "")-\(reloadToken)") {
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
    @Environment(\.rewardCouponSource) private var couponSource
    @State private var couponName = ""
    private var couponText: Binding<String> {
        Binding(get: { rewards.couponID > 0 ? String(rewards.couponID) : "" },
                set: { rewards.couponID = Int($0) ?? 0 })
    }
    var body: some View {
        Section("publishModes.rewards") {
            Toggle("publishModes.selfPlay", isOn: $rewards.selfPlay)
            if rewards.selfPlay {
                TextField("publishModes.price", text: $rewards.selfPlayPrice).keyboardType(.decimalPad)
                TextField("publishModes.quota", text: $rewards.selfPlayQuota).keyboardType(.numberPad)
            }
            TextField("publishModes.medalName", text: $rewards.medalName)
            TextField("publishModes.medalImage", text: $rewards.medalImage).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text("publishModes.uploadDisabled").font(.footnote).foregroundStyle(.secondary)
            if let couponSource {
                // MP runtime-editor.wxml:28 主题通关奖励: cy-reward-selector, occasion topic, placeholder 选择优惠券.
                RewardCouponSelectorRow(source: couponSource, couponID: couponText, couponName: $couponName,
                                        label: "rewardCoupon.label.default", occasion: "rewardCoupon.occasion.topic")
            } else {
                TextField("publishModes.coupon", value: $rewards.couponID, format: .number).keyboardType(.numberPad)
                Text("publishModes.couponNotice").font(.footnote).foregroundStyle(.secondary)
            }
        }.disabled(!fullEdit)
    }
}
