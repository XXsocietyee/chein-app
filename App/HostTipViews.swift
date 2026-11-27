import SwiftUI

/// Host tip settings and the player intent screen. Neither screen reports a payment success.
/// A 501 `CHANNEL_NOT_ENABLED` stays the unavailable sentence.

struct HostTipConfigScreen: View {
    let session: AppSession

    @State private var load: MPLoad<[HostTipConfigFact]> = .loading
    @State private var signedOut = false
    @State private var enabled = false
    @State private var channelClosed = false
    @State private var clubID = "0"
    @State private var minAmount = ""
    @State private var currency = ""
    @State private var bearer = 0
    @State private var saving = false
    @State private var notice: HostTipNotice = .none

    // Native restyle (native-ios-r1 §3.2): a settings page is a grouped Form; the explanation is the section footer.
    var body: some View {
        Form {
            Section {
                if channelClosed { Text("hostTip.config.unavailable").foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("hostTip.config.unavailable") }
            } header: {
                Text("hostTip.config.share")
            } footer: {
                Text("hostTip.config.shareNote")
            }
            Section {
                if signedOut {
                    CYEmptyState(systemImage: "person.crop.circle", "hostTip.signedOut", messageIdentifier: "hostTip.signedOut")
                } else {
                    MPLoadSwitch(load: load, errorTitle: "hostTip.config.error", identifier: "hostTip.config", onRetry: { Task { await reload() } }) { rows in
                        form(rows)
                    }
                }
            }
            if notice != .none {
                Section { noticeText }
            }
        }
        .cyScreenStyle()
        .navigationTitle(Text("hostTip.config.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    @ViewBuilder private var noticeText: some View {
        switch notice {
        case .none: EmptyView()
        case .saved: Text("hostTip.config.saved")
        case .invalid: MPInlineError(text: Text("hostTip.config.invalid"))
        case .pending: Text("hostTip.config.pending")
        case .unavailable: Text("hostTip.config.unavailable")
        }
    }

    /// One Form row per control (the Form lays the rows out; no hand-built stack).
    @ViewBuilder private func form(_ rows: [HostTipConfigFact]) -> some View {
        Group {
            if rows.isEmpty {
                CYEmptyState(systemImage: "heart", "hostTip.config.empty", messageIdentifier: "hostTip.config.empty")
            }
            Toggle("hostTip.config.enabled", isOn: $enabled)
                .disabled(channelClosed)
                .accessibilityIdentifier("hostTip.config.enabled")
            TextField("hostTip.config.club", text: $clubID)
                .accessibilityIdentifier("hostTip.config.club")
            TextField("hostTip.config.minAmount", text: $minAmount)
                .accessibilityIdentifier("hostTip.config.minAmount")
            TextField("hostTip.config.currency", text: $currency)
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("hostTip.config.currency")
            Picker("hostTip.config.feeBearer", selection: $bearer) {
                Text("hostTip.config.feeHost").tag(0)
                Text("hostTip.config.feePlatform").tag(1)
            }
            .accessibilityIdentifier("hostTip.config.feeBearer")
            CYMorphButton("hostTip.config.save", state: saving ? .working : .idle) { Task { await save() } }
                .disabled(channelClosed || saving)
                .accessibilityIdentifier("hostTip.config.save")
        }
    }

    private func reload() async {
        signedOut = false
        notice = .none
        load = .loading
        guard let source = source(), let token = token() else {
            signedOut = true
            load = .ready([])
            return
        }
        do {
            let envelope = try await source.configs(token: token)
            guard let rows = HostTipSource.configs(in: envelope) else {
                load = .failed(nil)
                return
            }
            load = .ready(rows)
            if let first = rows.first { apply(first) }
            channelClosed = rows.contains(where: \.channelClosed)
        } catch {
            load = .failed(nil)
        }
    }

    private func apply(_ row: HostTipConfigFact) {
        enabled = row.enabled
        clubID = row.clubID
        if row.minAmountText != HostTipPrepareFact.unknownMark { minAmount = row.minAmountText.replacingOccurrences(of: "¥", with: "") }
        if row.currency != HostTipPrepareFact.unknownMark { currency = row.currency }
        if let bearer = row.channelFeeBearer { self.bearer = bearer }
        channelClosed = row.channelClosed
    }

    private func save() async {
        guard !saving, let source = source(), let token = token() else {
            signedOut = true
            return
        }
        saving = true
        defer { saving = false }
        do {
            let envelope = try await source.saveConfig(clubID: clubID, enabled: enabled, minAmount: minAmount,
                                                       currency: currency.uppercased(), channelFeeBearer: bearer, token: token)
            if envelope.reasonCode == "CHANNEL_NOT_ENABLED" || envelope.httpStatus == 501 {
                channelClosed = true
                enabled = false
                notice = .unavailable
                return
            }
            guard envelope.ok else {
                notice = envelope.confirmed ? .invalid : .pending
                return
            }
            notice = .saved
            await reload()
            if notice != .unavailable { notice = .saved }
        } catch HostTipRefusal.invalidRequest {
            notice = .invalid
        } catch {
            notice = .pending
        }
    }

    private func source() -> HostTipSource? {
        guard let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return HostTipSource(configuration: configuration, transport: session.composition.makeTransport())
    }

    private func token() -> String? {
        guard let token = session.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return token
    }
}

private enum HostTipNotice { case none, saved, invalid, pending, unavailable }

struct HostTipPlayerScreen: View {
    let session: AppSession
    @Environment(\.locale) private var locale

    @State private var load: MPLoad<[HostTipIntentFact]> = .loading
    @State private var signedOut = false
    @State private var hostID = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var working = false
    @State private var banner: HostTipPlayerBanner = .none
    private let shortcuts = ["5", "10", "20", "50"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text("hostTip.config.share").cyText(.bodyMedium)
                TextField("hostTip.player.host", text: $hostID)
                    .accessibilityIdentifier("hostTip.player.host")
                Text("hostTip.player.amount").cyText(.label)
                HStack(spacing: CYSpacing.sm) {
                    ForEach(shortcuts, id: \.self) { value in
                        Button(action: { amount = value }) { Text(verbatim: value) }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("hostTip.player.amount.\(value)")
                    }
                }
                TextField("hostTip.player.amount", text: $amount)
                    .accessibilityIdentifier("hostTip.player.amount")
                TextField("hostTip.player.note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("hostTip.player.note")
                CYMorphButton("hostTip.player.prepare", state: working ? .working : .idle) { Task { await prepare() } }
                    .disabled(working)
                    .accessibilityIdentifier("hostTip.player.prepare")
                bannerText
                if signedOut {
                    CYEmptyState(systemImage: "person.crop.circle", "hostTip.signedOut", messageIdentifier: "hostTip.player.signedOut")
                } else {
                    MPLoadSwitch(load: load, errorTitle: "hostTip.player.error", identifier: "hostTip.player", onRetry: { Task { await reload() } }) { rows in
                        if rows.isEmpty {
                            CYEmptyState(systemImage: "heart", "hostTip.player.empty", messageIdentifier: "hostTip.player.empty")
                        } else {
                            ForEach(rows, id: \.id) { row in intentRow(row) }
                        }
                    }
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .background { MPNightGround() }
        .navigationTitle(Text("hostTip.player.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    @ViewBuilder private var bannerText: some View {
        switch banner {
        case .none: EmptyView()
        case .unavailable:
            Text("hostTip.player.unavailable").accessibilityIdentifier("hostTip.player.unavailable")
        case .paymentClosed:
            Text("hostTip.player.paymentClosed").accessibilityIdentifier("hostTip.player.paymentClosed")
        case .invalid: MPInlineError(text: Text("hostTip.player.invalid"))
        case .pending: Text("hostTip.config.pending")
        case .cancelDenied: MPInlineError(text: Text("hostTip.player.cancelDenied"))
        }
    }

    private func intentRow(_ row: HostTipIntentFact) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack {
                statusText(row.status)
                Spacer()
                Text(verbatim: LocaleDisplay.yuanAmounts(in: row.amountText, locale: locale))
            }
            .cyText(.bodyMedium)
            .accessibilityIdentifier("hostTip.intent.\(row.id)")
            if row.canCancel {
                Button("hostTip.player.cancel") { Task { await cancel(row.id) } }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("hostTip.player.cancel.\(row.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func statusText(_ status: String) -> some View {
        switch status {
        case "CREATED": Text("hostTip.intent.created")
        case "AWAITING_PAYMENT": Text("hostTip.intent.awaiting")
        case "PAID": Text("hostTip.intent.paid")
        case "CANCELLED": Text("hostTip.intent.cancelled")
        case "REFUNDED": Text("hostTip.intent.refunded")
        case "CHANNEL_UNSUPPORTED": Text("hostTip.intent.unsupported")
        default: Text("hostTip.intent.unknown")
        }
    }

    private func reload() async {
        signedOut = false
        load = .loading
        guard let source = source(), let token = token() else {
            signedOut = true
            load = .ready([])
            return
        }
        do {
            let envelope = try await source.intents(token: token)
            guard let rows = HostTipSource.intents(in: envelope) else {
                load = .failed(nil)
                return
            }
            load = .ready(rows)
        } catch {
            load = .failed(nil)
        }
    }

    private func prepare() async {
        guard !working else { return }
        working = true
        defer { working = false }
        guard let source = source(), let token = token() else {
            signedOut = true
            return
        }
        do {
            let envelope = try await source.prepare(hostMemberID: hostID, clubID: "", amount: amount, note: note, token: token)
            guard let fact = HostTipSource.prepareFact(envelope) else {
                banner = .pending
                return
            }
            if fact.paymentSucceeded { banner = .paymentClosed }
            else if fact.unavailable { banner = .unavailable }
            else if fact.payable { banner = paymentsOpen ? .paymentClosed : .paymentClosed }
            else { banner = .unavailable }
            await reload()
        } catch HostTipRefusal.invalidRequest {
            banner = .invalid
        } catch {
            banner = .pending
        }
    }

    private func cancel(_ id: String) async {
        guard let source = source(), let token = token() else {
            signedOut = true
            return
        }
        do {
            let envelope = try await source.cancel(intentID: id, token: token)
            if envelope.reasonCode == "CANCEL_NOT_ALLOWED" { banner = .cancelDenied }
            await reload()
        } catch {
            banner = .pending
        }
    }

    private var paymentsOpen: Bool {
        ReviewedAreaSwitch.moneyPayments(apiHost: session.currentRuntimeDependencyContext?.baseURL.host)
    }

    private func source() -> HostTipSource? {
        guard let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return HostTipSource(configuration: configuration, transport: session.composition.makeTransport())
    }

    private func token() -> String? {
        guard let token = session.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return token
    }
}

private enum HostTipPlayerBanner { case none, unavailable, paymentClosed, invalid, pending, cancelDenied }
