import SwiftUI
import CoreImage.CIFilterBuiltins

/// Explicit owner consent UI on the existing installation. No implicit location or unsigned evidence.
@MainActor struct ModVenueOperationsView: View {
    let model: ModVenueOperations
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scene
    @Environment(\.dismiss) private var dismiss
    @State private var places: [PlaceForm] = []
    @State private var validity = ""
    @State private var prepared: ModVenueOperationDocument?
    @State private var confirmation: ModVenueOperations.Confirmation?
    @State private var revocation: ModVenueOperations.Confirmation?
    @State private var task: Task<Void, Never>?
    @State private var taskIdentity = UUID()
    @State private var reviewing = false
    @State private var revoking = false
    @State private var attested = false
    @State private var editIssue = false
    @State private var codeReceived = Date.distantPast
    private struct WindowForm: Identifiable { let id = UUID(); var from = ""; var until = "" }
    private struct PlaceForm: Identifiable {
        let binding: ModInstallationBoundResource
        var id: String { binding.key }
        var consent = "", safety = ""
        var windows: [WindowForm] = [.init()]
    }
    private func t(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    var body: some View {
        Form {
            Section {
                Text(t("地点所有权、隐私同意与本次模组运营同意不是同一授权。必须由场地有权方明确同意，并经原审核后才能运行。", "Place ownership and privacy consent do not authorize this module operation. Explicit venue authority consent and the original review are required."))
                Text(model.installation.requestId).font(.caption.monospaced())
                Button(t("只读刷新及查询原请求", "Refresh and read original receipt")) { clearReview(); run { await model.load() } }.disabled(model.busy || !model.isCurrent)
                if model.busy { ProgressView() }
                if let issue = model.issue { Text(verbatim: issue).foregroundStyle(.orange) }
                if !model.isCurrent { Text(t("会话或批准已变更；请关闭并从原安装重新打开。", "The session or approval changed. Reopen from the original installation.")) }
            }
            if let p = model.pending {
                Section(t("原请求回执", "Original request receipt")) {
                    Text(p.command.requestId).font(.caption.monospaced())
                    Text(p.command.event)
                    if model.originalUnknown {
                        Text(t("本次原请求回读未确认；下方已知回执仅为历史，不能以当前同意替代。", "The original reread is unconfirmed. Any saved receipt below is historical; current consent cannot replace it."))
                    }
                    if let r = p.receipt {
                        Text(r.status)
                        if let id = r.consentId, let version = r.version { Text("\(id) · \(version)").font(.caption.monospaced()) }
                        if let reason = r.reason { Text(reason).font(.caption) }
                        Text(t("回执不代表发布、启用或现场通关。", "A receipt does not publish, enable, or complete venue play."))
                    } else {
                        Text(t("UNKNOWN：原请求已持久保留，不会自动重发或删除。", "UNKNOWN: the exact request is durably retained, never automatically resent or deleted."))
                        Button(t("明确重试同一请求", "Retry the exact original request")) { run { await model.retryExact() } }.disabled(!model.canRetryExact)
                    }
                }
            }
            if let w = model.workspace {
                Section(t("当前原同意版本", "Current original consent version")) {
                    if !model.workspaceFresh {
                        Text(t("仅保留上次读取；当前同意尚未确认，不能提交新版本或签发动态码。", "Last-read snapshot only. Current consent is unconfirmed; new versions and live codes are disabled."))
                    }
                    Text(w.event ?? t("尚无运营同意", "No operation consent"))
                    if let version = w.version { Text(version).font(.caption.monospaced()) }
                    Text(w.ruleVersion).font(.caption.monospaced())
                    if w.event == "AGREE" {
                        Button(t("撤回本版本运营同意", "Revoke this operation consent"), role: .destructive) {
                            do { revocation = try model.review(event: "REVOKE", document: nil); revoking = true }
                            catch { editIssue = true }
                        }.disabled(!model.canWrite)
                    }
                }
                ForEach($places) { $place in
                    Section(place.binding.label + " · " + place.binding.key) {
                        Text("POI \(place.binding.resourceId)").font(.caption)
                        Text(place.binding.fingerprint).font(.caption.monospaced())
                        TextField(t("有权方同意依据引用", "Authority consent evidence reference"), text: $place.consent)
                        TextField(t("安全评估依据引用", "Safety review reference"), text: $place.safety)
                        Text(t("仅填写明确获准的营业时段；ISO 8601 时间必须包含时区，例如 2026-10-26T15:00:00Z。", "Enter explicitly approved operating windows only. ISO 8601 values must include a timezone, e.g. 2026-10-26T15:00:00Z."))
                        ForEach($place.windows) { $window in
                            TextField(t("开始（含）", "Start (inclusive)"), text: $window.from)
                            TextField(t("结束（不含）", "End (exclusive)"), text: $window.until)
                            if place.windows.count > 1 { Button(t("删除时段", "Remove window"), role: .destructive) { place.windows.removeAll { $0.id == window.id } } }
                        }
                        Button(t("添加获准时段", "Add approved window")) { place.windows.append(.init()) }.disabled(place.windows.count >= 366)
                    }.disabled(!model.canWrite)
                }
                Section {
                    TextField(t("证据有效期（毫秒，由本次规则明确确定）", "Proof validity in milliseconds, explicitly agreed for this rule"), text: $validity)
                    if editIssue { Text(t("请完整填写同意依据、安全依据、有效期和互不重叠的时段。", "Complete the evidence references, validity, and non-overlapping windows.")) }
                    Button(t("审阅新运营同意版本", "Review new operation consent version")) {
                        do {
                            let value = try document(w)
                            confirmation = try model.review(event: "AGREE", document: value)
                            prepared = value; attested = false; reviewing = true; editIssue = false
                        } catch { editIssue = true }
                    }.disabled(!model.canWrite)
                }
                if w.event == "AGREE" {
                    Section(t("现场有权方签发", "On-site authorized issuance")) {
                        Text(t("仅在真实现场确认参与者到场后出示。签发身份、签发时刻、一次性和过期校验由原服务决定。", "Present only after confirming the participant is physically present. The original service determines issuer, time, one-use consumption, and expiry."))
                        ForEach(w.nodes) { node in
                            Button(node.title + " · " + t("签发一次性动态码", "Issue one-use live code")) {
                                guard let claim = model.claimCode(node: node.nodeId) else { return }
                                run { await model.issueCode(claim) }
                            }.disabled(!model.canWrite)
                        }
                        if let code = model.issued {
                            TimelineView(.periodic(from: .now, by: 1)) { tick in
                                if tick.date.timeIntervalSince(codeReceived) * 1000 < Double(code.ttlMs), model.isCurrent, scene == .active {
                                    if let qr = qrImage(code.code) { Image(decorative: qr, scale: 1).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260).accessibilityLabel(t("原现场一次性动态码", "Original one-use on-site code")) }
                                    Text(code.nodeName ?? "#\(code.nodeId)")
                                    Text(t("仅现场展示；本地倒计时不是验证结果。", "Show on site only; this local timer is not a verification result."))
                                } else { Text(t("已隐藏；请按需重新明确签发。", "Hidden. Explicitly issue another code when needed.")) }
                            }
                            Button(t("立即隐藏", "Hide now")) { model.hideCode() }
                        }
                    }
                }
            }
        }
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .privacySensitive().navigationTitle(t("模组场地运营", "Module venue operation"))
        .toolbar { Button(t("关闭", "Close")) { suspend(); dismiss() } }
        .task(id: scene) { if scene == .active, !Task.isCancelled { await model.load(); if !Task.isCancelled { fill() } } }
        .onChange(of: model.workspace) { _, _ in clearReview(); fill() }
        .onChange(of: model.issued) { _, _ in codeReceived = Date() }
        .onChange(of: scene) { _, value in if value != .active { suspend() } }
        .onDisappear { suspend() }
        .confirmationDialog(t("撤回本版本将阻止后续运行推进；历史回执保留。", "Revoke this version and block future advancement; historical receipts remain."), isPresented: $revoking, titleVisibility: .visible) {
            Button(t("明确撤回", "Confirm revocation"), role: .destructive) {
                guard let original = revocation else { return }; revocation = nil
                run { await model.confirm(original) }
            }.disabled(revocation.map { !model.canConfirm($0) } ?? true)
        }
        .sheet(isPresented: $reviewing) {
            NavigationStack {
                Form {
                    if let d = prepared {
                        Text(d.installationRequestId).font(.caption.monospaced())
                        Text(d.bindingHash).font(.caption.monospaced())
                        Text("\(d.proofValidityMillis) ms · \(d.purpose)")
                        ForEach(d.places, id: \.slotId) { p in
                            Section(p.slotId) {
                                Text("POI \(p.poiId)"); Text(p.consentEvidenceRef); Text(p.safetyReviewRef)
                                ForEach(Array(p.operatingWindows.enumerated()), id: \.offset) { _, w in
                                    Text(Date(timeIntervalSince1970: Double(w.from)/1000).formatted() + " → " + Date(timeIntervalSince1970: Double(w.until)/1000).formatted())
                                }
                            }
                        }
                        Toggle(t("我有权代表这些场地，明确同意本安装、用途、版本、有效期及上述时段；不是个人隐私授权。", "I am authorized for these venues and explicitly consent to this installation, purpose, version, validity, and windows; this is not personal privacy consent."), isOn: $attested)
                        Button(t("提交明确运营同意", "Submit explicit operation consent")) {
                            guard let original = confirmation else { return }
                            reviewing = false; confirmation = nil; attested = false
                            run { await model.confirm(original) }
                        }.disabled(!attested || (confirmation.map { !model.canConfirm($0) } ?? true))
                    }
                }.navigationTitle(t("审阅全部场地", "Review all venues"))
                    .toolbar { Button(t("返回修改", "Back to edit")) { clearReview() } }
            }.privacySensitive()
        }
    }
    private func clearReview() {
        prepared = nil; confirmation = nil; revocation = nil; reviewing = false; revoking = false; attested = false
    }
    private func suspend() {
        taskIdentity = UUID(); task?.cancel(); task = nil
        clearReview(); places = []; validity = ""; editIssue = false; model.suspend()
    }
    private func run(_ action: @escaping @MainActor () async -> Void) {
        guard task == nil, scene == .active else { return }
        let ticket = UUID(); taskIdentity = ticket
        task = Task {
            guard !Task.isCancelled, taskIdentity == ticket, scene == .active else { return }
            await action(); if taskIdentity == ticket { task = nil }
        }
    }
    private func fill() {
        guard let w = model.workspace else { places = []; return }
        places = w.bindings.map { b in
            let p = w.document?.places.first { $0.slotId == b.key }
            return PlaceForm(binding: b, consent: p?.consentEvidenceRef ?? "", safety: p?.safetyReviewRef ?? "", windows: p?.operatingWindows.map { .init(from: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double($0.from)/1000)), until: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double($0.until)/1000))) } ?? [.init()])
        }
        validity = w.document.map { String($0.proofValidityMillis) } ?? ""
    }
    private func document(_ w: ModVenueWorkspace) throws -> ModVenueOperationDocument {
        guard let ttl = Int64(validity) else { throw ModInstallationIssue.invalidSelection }
        let ps = try places.map { p in
            let windows = try p.windows.map { raw -> ModVenueOperationDocument.Window in
                guard let from = ISO8601DateFormatter().date(from: raw.from), let until = ISO8601DateFormatter().date(from: raw.until) else { throw ModInstallationIssue.invalidSelection }
                return .init(from: Int64(from.timeIntervalSince1970 * 1000), until: Int64(until.timeIntervalSince1970 * 1000))
            }.sorted { $0.from < $1.from }
            return ModVenueOperationDocument.Place(slotId: p.binding.key, poiId: p.binding.resourceId, fingerprint: p.binding.fingerprint, consentEvidenceRef: p.consent, safetyReviewRef: p.safety, operatingWindows: windows)
        }
        let value = ModVenueOperationDocument(schema: "mod-venue-operation-v1", installationRequestId: w.installationRequestId, bindingHash: w.bindingHash, purpose: w.purpose, ruleVersion: w.ruleVersion, proofValidityMillis: ttl, places: ps)
        try value.validate(model.installation); return value
    }
    private func qrImage(_ code: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(code.utf8)
        guard let output = filter.outputImage else { return nil }; return CIContext().createCGImage(output, from: output.extent)
    }
}
