import SwiftUI

/// R8-PC-D9-1 / R7-PC-D9-2 (MP-first): the shared report half-sheet the MP mounts in chat as
/// `<cy-report-sheet target-type="MEMBER" title="举报对方">` (`subpackageB/pages/im/chat/index.wxml:250`).
/// Same endpoints, method, body and stages as `subpackageMember/components/cy/report-sheet/index.js:56-170`:
/// GET `community-trust/reports/taxonomy` → pick a reason → 具体说明 → POST `community-trust/reports/submit`.
/// The server's own checks decide (cannot report yourself, policy version, rate limits).
@MainActor final class CommunityMemberReportContext {
    let configuration: () -> APIConfiguration?
    let transport: () -> (any HTTPTransport)?
    let token: () -> String?

    init(configuration: @escaping () -> APIConfiguration?, transport: @escaping () -> (any HTTPTransport)?, token: @escaping () -> String?) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
    }

    /// MP-first: the MP sends this report for every signed-in member, so writes are on (`writesEnabled: true`).
    func client() -> CommunityMemberReportClient? {
        guard let configuration = configuration(), let transport = transport() else { return nil }
        return CommunityMemberReportClient(configuration: configuration, transport: transport, writesEnabled: true)
    }
}

private struct CommunityMemberReportContextKey: EnvironmentKey {
    static var defaultValue: CommunityMemberReportContext? { nil }
}

extension EnvironmentValues {
    var communityMemberReportContext: CommunityMemberReportContext? {
        get { self[CommunityMemberReportContextKey.self] }
        set { self[CommunityMemberReportContextKey.self] = newValue }
    }
}

extension AppSession {
    func makeCommunityMemberReportContext() -> CommunityMemberReportContext {
        CommunityMemberReportContext(
            configuration: { [weak self] in self?.regionalConfiguration?.apiConfiguration },
            transport: { [weak self] in self?.runtimeHTTPTransport },
            token: { [weak self] in self?.token }
        )
    }
}

/// One reason from the taxonomy (`model.js:11-28` `normalizeTaxonomy`).
struct CommunityMemberReportReason: Equatable, Identifiable {
    let code: String
    let label: String
    let firstResponseMinutes: Int?
    let emergency: Bool
    var id: String { code }
}

enum CommunityMemberReportTaxonomy {
    /// `normalizeTaxonomy`: needs a non-empty `policyVersion` and at least one reason with code + label.
    static func decode(_ data: Data) -> (policyVersion: String, reasons: [CommunityMemberReportReason])? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? Int) == 200,
              let body = root["data"] as? [String: Any] else { return nil }
        let policy = (body["policyVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !policy.isEmpty, let raw = body["reasons"] as? [[String: Any]] else { return nil }
        let reasons = raw.compactMap { row -> CommunityMemberReportReason? in
            guard let code = row["code"] as? String, !code.isEmpty,
                  let label = row["label"] as? String, !label.isEmpty else { return nil }
            return CommunityMemberReportReason(code: code, label: label,
                                               firstResponseMinutes: (row["firstResponseMinutes"] as? NSNumber)?.intValue,
                                               emergency: (row["emergency"] as? Bool) == true)
        }
        return reasons.isEmpty ? nil : (policy, reasons)
    }

    /// `model.js:30-45` `minutesText` + `reasonResponseText`. Empty when the field is missing.
    static func responseText(_ reason: CommunityMemberReportReason, locale: Locale) -> String {
        guard let minutes = reason.firstResponseMinutes, minutes > 0 else { return "" }
        let minuteUnit = appLocalized("im.reportPeer.unit.minutes", locale: locale)
        let hourUnit = appLocalized("im.reportPeer.unit.hours", locale: locale)
        let span: String
        if minutes < 60 { span = "\(minutes) " + minuteUnit }
        else if minutes % 60 == 0 { span = "\(minutes / 60) " + hourUnit }
        else { span = "\(minutes / 60) " + hourUnit + " \(minutes % 60) " + minuteUnit }
        let prefix = appLocalized(reason.emergency ? "im.reportPeer.response.urgentPrefix" : "im.reportPeer.response.prefix", locale: locale)
        return prefix + span + appLocalized("im.reportPeer.response.suffix", locale: locale)
    }
}

/// `index.wxml` of the MP report sheet: loading / loadfail / pick / form / busy / ok / fail / unknown.
@MainActor struct CommunityMemberReportSheet: View {
    let memberID: Int
    @Environment(\.communityMemberReportContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private enum Stage: Equatable { case loading, loadFailed(String), pick, form, busy, ok(String), failed(String), unknown }
    @State private var stage: Stage = .loading
    @State private var policyVersion = ""
    @State private var reasons: [CommunityMemberReportReason] = []
    @State private var reason: CommunityMemberReportReason?
    @State private var detail = ""
    @State private var detailError: String?
    /// `_requestId`: kept for a replay of the same content (unknown → 再试一次), cleared when reason or text changes.
    @State private var requestID = ""
    @State private var loadSequence = 0

    // R9-PC-D9-2 (native r2): a grouped Form (reason section, 具体说明 section with the counter in its footer,
    // 提交 in the toolbar) and ContentUnavailableView for the load-failed and result states. Same request flow
    // (MP subpackageMember/components/cy/report-sheet/index.wxml).
    var body: some View {
        NavigationStack {
            Form { content }
            .navigationTitle(Text("im.chat.more.reportPeer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("im.reportPeer.cancel") }
                        .disabled(stage == .busy)
                        .accessibilityIdentifier("im.reportPeer.close")
                }
                if stage == .form || stage == .busy {
                    ToolbarItem(placement: .confirmationAction) {
                        if stage == .busy {
                            ProgressView().accessibilityLabel(Text("im.reportPeer.busy"))
                        } else {
                            Button("im.reportPeer.submit") { Task { await submit() } }
                                .accessibilityIdentifier("im.reportPeer.submit")
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(stage == .busy)
        .task { await loadTaxonomy() }
        .accessibilityIdentifier("im.reportPeer.sheet")
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .loading:
            Section {
                ProgressView { Text("im.reportPeer.loading") }
                    .frame(maxWidth: .infinity)
            }
        case .loadFailed(let why):
            result(title: "im.reportPeer.loadFailed.title", why: why, identifier: "im.reportPeer.loadFailed",
                   systemImage: "exclamationmark.triangle") {
                Button("im.reportPeer.retry") { Task { await loadTaxonomy() } }.buttonStyle(.borderedProminent)
                Button("im.reportPeer.cancel") { dismiss() }.buttonStyle(.bordered)
            }
        case .pick:
            Section {
                ForEach(reasons) { option in
                    Button { select(option) } label: {
                        Text(verbatim: option.label).foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("im.reportPeer.reason." + option.code)
                }
            } header: {
                Text("im.reportPeer.pickHeader")
            }
        case .form, .busy:
            form
        case .ok(let receipt):
            result(title: "im.reportPeer.ok.title",
                   why: (receipt.isEmpty ? "" : appLocalized("im.reportPeer.ok.receiptPrefix", locale: locale) + receipt + appLocalized("im.reportPeer.ok.receiptSuffix", locale: locale))
                        + appLocalized("im.reportPeer.ok.sub", locale: locale),
                   identifier: "im.reportPeer.ok", systemImage: "checkmark.circle") {
                Button("im.reportPeer.ok.done") { dismiss() }.buttonStyle(.borderedProminent)
            }
        case .failed(let why):
            result(title: "im.reportPeer.failed.title", why: why, identifier: "im.reportPeer.failed",
                   systemImage: "xmark.octagon") {
                Button("im.reportPeer.backToForm") { stage = .form }.buttonStyle(.borderedProminent)
                Button("im.reportPeer.cancel") { dismiss() }.buttonStyle(.bordered)
            }
        case .unknown:
            result(title: "im.reportPeer.unknown.title", why: appLocalized("im.reportPeer.unknown.why", locale: locale),
                   identifier: "im.reportPeer.unknown", systemImage: "questionmark.circle") {
                Button("im.reportPeer.unknown.retry") { Task { await submit() } }.buttonStyle(.borderedProminent)
                Button("im.reportPeer.unknown.later") { dismiss() }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder private var form: some View {
        Section {
            Text(verbatim: appLocalized("im.reportPeer.reasonPrefix", locale: locale) + (reason?.label ?? ""))
            Button("im.reportPeer.changeReason") { stage = .pick }
                .disabled(stage == .busy)
        } footer: {
            if let picked = reason, case let note = CommunityMemberReportTaxonomy.responseText(picked, locale: locale), !note.isEmpty {
                Text(verbatim: note)
            }
        }
        Section {
            TextField(text: $detail, prompt: Text("im.reportPeer.detailPlaceholder"), axis: .vertical) {
                Text("im.reportPeer.detailLabel")
            }
            .lineLimit(4...10)
            .disabled(stage == .busy)
            .onChange(of: detail) { _, _ in requestID = ""; detailError = nil }
            .accessibilityIdentifier("im.reportPeer.detail")
        } header: {
            Text("im.reportPeer.detailLabel")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let message = detailError {
                    Text(verbatim: message).foregroundStyle(.red)
                        .accessibilityIdentifier("im.reportPeer.detailError")
                }
                Text(verbatim: "\(detail.count)/\(CommunityMemberReportDraft.descriptionMax)").accessibilityLabel(Text("a11y.value.characters \(Int(detail.count)) \(Int(CommunityMemberReportDraft.descriptionMax))")).monospacedDigit()
                Text("im.reportPeer.anonymous")
            }
        }
    }

    private func result<Actions: View>(title: LocalizedStringKey, why: String, identifier: String, systemImage: String,
                                       @ViewBuilder actions: () -> Actions) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if !why.isEmpty { Text(verbatim: why) }
        } actions: {
            actions()
        }
        .accessibilityIdentifier(identifier)
    }

    private func select(_ option: CommunityMemberReportReason) {
        if option.code != reason?.code { requestID = "" }
        reason = option
        detailError = nil
        stage = .form
    }

    /// `loadTaxonomy` (index.js:56-82). A newer load wins (BL-218 sequence).
    private func loadTaxonomy() async {
        loadSequence += 1
        let sequence = loadSequence
        guard memberID > 0 else { stage = .loadFailed(appLocalized("im.reportPeer.invalidTarget", locale: locale)); return }
        guard let context, let client = context.client(), let transport = context.transport() else {
            stage = .loadFailed(appLocalized("im.reportPeer.loadFailed.network", locale: locale)); return
        }
        stage = .loading
        do {
            let request = try client.taxonomyRequest(token: context.token())
            let (data, status) = try await transport.send(request)
            guard sequence == loadSequence else { return }
            guard (200..<300).contains(status), let taxonomy = CommunityMemberReportTaxonomy.decode(data) else {
                stage = .loadFailed(appLocalized("im.reportPeer.loadFailed.taxonomy", locale: locale)); return
            }
            policyVersion = taxonomy.policyVersion
            reasons = taxonomy.reasons
            stage = .pick
        } catch {
            guard sequence == loadSequence else { return }
            stage = .loadFailed(appLocalized("im.reportPeer.loadFailed.network", locale: locale))
        }
    }

    /// `submit` (index.js:98-150): business rejection → 举报没有提交成功 with the server message and a new key;
    /// transport failure → 提交结果未知, same key so a retry replays the same report.
    private func submit() async {
        guard stage != .busy, let reason else { return }
        let text = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { detailError = appLocalized("im.reportPeer.detailRequired", locale: locale); stage = .form; return }
        guard text.count <= CommunityMemberReportDraft.descriptionMax else {
            detailError = appLocalized("im.reportPeer.detailTooLong", locale: locale); stage = .form; return
        }
        guard let context, let client = context.client(), let transport = context.transport(), let token = context.token() else {
            stage = .failed(appLocalized("im.reportPeer.signInRequired", locale: locale)); return
        }
        if requestID.isEmpty {
            requestID = CommunityMemberReportDraft.requestID(targetType: .member, targetID: memberID,
                nowMillis: Int(Date().timeIntervalSince1970 * 1000), random: String(UUID().uuidString.lowercased().filter(\.isLetter).prefix(8)))
        }
        let draft: CommunityMemberReportDraft
        do {
            draft = try CommunityMemberReportDraft(targetType: .member, targetID: memberID, reasonCode: reason.code,
                                                   policyVersion: policyVersion, description: text, requestID: requestID)
        } catch {
            requestID = ""
            stage = .failed(appLocalized("im.reportPeer.failed.default", locale: locale)); return
        }
        stage = .busy
        do {
            let request = try client.submitRequest(draft, token: token)
            // `client.submit(_:token:)` drops the receipt id and the server message the MP shows, so the sheet
            // sends the client's own request through the session transport.
            let (data, status) = try await transport.send(request)
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (200..<300).contains(status), (root?["code"] as? Int) == 200 {
                requestID = ""
                let id = (root?["data"] as? [String: Any])?["id"]
                stage = .ok(id.map { "\($0)" } ?? "")
            } else if (200..<300).contains(status) || status == 400 || status == 403 {
                requestID = ""
                let message = (root?["msg"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                stage = .failed(message ?? appLocalized("im.reportPeer.failed.default", locale: locale))
            } else {
                stage = .unknown
            }
        } catch {
            stage = .unknown
        }
    }
}
