import SwiftUI

// Mini-program `subpackageMember/market/gift/index?mode=code` (平台兑换码). The entry is one row on 通行证, shown only
// when `GET /api/channel/redeem/status` says `platformCodeEnabled === true` (`MPParityBindings.passRedeemEnabled`,
// filled by `AppSession.mpParityPassBindings()` from `ChannelRedeemSource.status(token:)`).
//
// MP results (gift/index.js CODE_REASON): 兑换码无效 / 兑换码已过期 / 兑换码已被他人使用 / 该兑换码不属于当前账号 /
// 兑换码暂不可用, success 兑换成功 or 你已兑换过这个码 with 去玩. 去玩 opens the one topic, or the theme library for
// a bundle. A network-unknown answer keeps the same request id, so tapping 兑换 again resends the original request.

enum PassRedeemCodeOutcome: Equatable {
    case redeemed(replayed: Bool, topicID: Int?)
    case refused(LocalizedStringKey)
    case unknown

    /// MP `CODE_REASON`; anything else is 兑换码暂不可用.
    static func reasonKey(_ code: String?) -> LocalizedStringKey {
        switch code {
        case "CODE_REQUIRED", "INVALID_CODE": "mp.redeem.invalid"
        case "CODE_EXPIRED": "mp.redeem.expired"
        case "ALREADY_REDEEMED_BY_OTHER": "mp.redeem.usedByOther"
        case "SUBJECT_MISMATCH": "mp.redeem.mismatch"
        default: "mp.redeem.unavailable"
        }
    }

    /// MP `isBizOk(res) && res.data`: `topicIds` with exactly one id → that topic; `replayed === true` → 你已兑换过这个码.
    static func from(_ envelope: ChannelRedeemEnvelope) -> PassRedeemCodeOutcome {
        guard envelope.confirmed || envelope.ok else { return .unknown }
        if envelope.ok, let data = envelope.dataJSON,
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let ids = (object["topicIds"] as? [Any]) ?? []
            var topicID: Int?
            if ids.count == 1 {
                if let number = ids[0] as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() { topicID = number.intValue }
                else if let text = ids[0] as? String { topicID = Int(text) }
            }
            return .redeemed(replayed: (object["replayed"] as? Bool) == true, topicID: topicID.flatMap { $0 > 0 ? $0 : nil })
        }
        return .refused(reasonKey(envelope.reasonCode))
    }
}

@MainActor struct PassRedeemCodeView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.mpParity) private var bindings
    @State private var code = ""
    @State private var codeOn: Bool?
    @State private var working = false
    @State private var outcome: PassRedeemCodeOutcome?
    /// One source per code: its request store keeps the original body until the server confirms (MP `_reqId`).
    @State private var source: (code: String, value: ChannelRedeemSource)?
    @State private var openTopic: Int?
    @State private var openLibrary = false

    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                Image(systemName: claimed ? "checkmark" : "gift.fill")
                    .cyText(.display)
                    .foregroundStyle(CYNight.lanternHot)
                    .frame(width: 96, height: 96)
                    .background { Circle().fill(CYNight.glow(radius: 48)) }
                    .accessibilityHidden(true)
                    .padding(.top, CYSpacing.xl)
                if let title = resultTitle {
                    title.cyText(.sectionTitle)
                        .foregroundStyle(isError ? CYColor.dangerText : CYColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("passRedeem.result")
                }
                if codeOn == nil {
                    ProgressView().frame(minHeight: CYSpacing.minTouchTarget)
                } else if codeOn == true, !claimed {
                    TextField("mp.redeem.placeholder", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { Task { await redeem() } }
                        .onChange(of: code) { _, value in
                            if value.count > 64 { code = String(value.prefix(64)) }
                            outcome = nil
                        }
                        .padding(CYSpacing.md)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityLabel(Text("mp.redeem.title"))
                        .accessibilityIdentifier("passRedeem.code")
                    CYMorphButton("mp.redeem.submit", state: working ? .working : .idle) { Task { await redeem() } }
                        .disabled(working || trimmed.isEmpty)
                        .accessibilityIdentifier("passRedeem.submit")
                } else if claimed {
                    CYPillButton("mp.redeem.play", action: play)
                        .accessibilityIdentifier("passRedeem.play")
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity)
        }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.redeem.title")
        .navigationDestination(item: $openTopic) { id in SessionTopicDetailView(id: id, session: session) }
        .navigationDestination(isPresented: $openLibrary) { MPParityDestination(route: .library(kind: .all)) }
        .task {
            guard codeOn == nil else { return }
            // MP loadCodeStatus: closed or unreadable → 兑换码暂不可用 and no input.
            if let read = bindings.passRedeemEnabled { codeOn = await read() } else { codeOn = false }
        }
    }

    private var trimmed: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var claimed: Bool { if case .redeemed = outcome { true } else { false } }
    private var isError: Bool {
        if codeOn == false { return true }
        if case .refused = outcome { return true }
        return false
    }

    private var resultTitle: Text? {
        if codeOn == false { return Text("mp.redeem.unavailable") }
        switch outcome {
        case .redeemed(let replayed, _): return Text(replayed ? "mp.redeem.replayed" : "mp.redeem.success")
        case .refused(let key): return Text(key)
        case .unknown: return Text("mp.gift.unknown")
        case nil: return nil
        }
    }

    private func play() {
        guard case .redeemed(_, let topicID) = outcome else { return }
        if let topicID { openTopic = topicID } else if bindings.passLibrary != nil { openLibrary = true }
    }

    private func redeem() async {
        let value = trimmed
        guard !working, !value.isEmpty, codeOn == true else { return }
        guard let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base),
              let token = session.token, AuthRequestBuilder.isValidToken(token) else {
            // MP ensureLoginFor('登录后即可兑换'): sign in, then tap 兑换 again.
            PlayerJourneySignInBridge.shared.request()
            return
        }
        let redeemer: ChannelRedeemSource
        if let source, source.code == value { redeemer = source.value } else {
            // MP gift/index.js:70-80: `_reqId = 'code_' + Date.now() + '_' + 8 chars`, kept until the code changes.
            // Pinning the clock and entropy per code makes `redeemPlatformCode` resend the same request id.
            let millis = Int64(Date().timeIntervalSince1970 * 1000)
            let tail = JourneyLoopSource.randomEntropy()
            redeemer = ChannelRedeemSource(configuration: configuration, transport: session.composition.makeTransport(),
                                           nowMillis: { millis }, entropy: { tail })
            source = (value, redeemer)
        }
        working = true
        defer { working = false }
        do {
            let envelope = try await redeemer.redeemPlatformCode(code: value, token: token)
            outcome = PassRedeemCodeOutcome.from(envelope)
            if case .redeemed = outcome { source = nil }
        } catch ChannelRedeemRefusal.invalidRequest {
            outcome = .refused("mp.redeem.invalid")
        } catch ChannelRedeemRefusal.notAdmitted {
            outcome = .refused("mp.redeem.unavailable")
        } catch {
            outcome = .unknown
        }
    }
}
