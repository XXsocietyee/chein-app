import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The signed-in author's coupon list for the MP `publishkit/components/reward-selector`.
/// Supplied by the screens that hold the session (发布 tab, 我的 → 创作), like `TemplateCoverSource`.
struct RewardCouponSource {
    let load: @MainActor () async throws -> [RewardCouponOption]
}
private struct RewardCouponSourceKey: EnvironmentKey { static let defaultValue: RewardCouponSource? = nil }
extension EnvironmentValues {
    var rewardCouponSource: RewardCouponSource? {
        get { self[RewardCouponSourceKey.self] }
        set { self[RewardCouponSourceKey.self] = newValue }
    }
}

extension RewardCouponSource {
    /// `POST /api/coupon/mypublishlist` with `is_select=1` and no scope (player authoring), through the reviewed
    /// production transport. Signed out or without a deployment it throws `.signedOut`.
    @MainActor static func session(_ session: AppSession) -> RewardCouponSource {
        RewardCouponSource(load: { [weak session] in
            guard let session, let context = session.currentRuntimeDependencyContext else {
                throw RewardCouponSelectionError.signedOut
            }
            var request = URLRequest(url: context.baseURL.appendingPathComponent(RewardCouponSelectionContract.path))
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(context.session.token, forHTTPHeaderField: "Authorization")
            request.httpBody = Data(RewardCouponSource.formBody(RewardCouponSelectionContract.fields).utf8)
            let (data, status) = try await ChinaReviewedProductionTransport(underlying: RewardCouponURLSessionTransport()).send(request)
            return try RewardCouponSelectionContract.decode(data, status: status)
        })
    }
    static func formBody(_ fields: [String: String]) -> String {
        fields.keys.sorted().map { key in
            let value = fields[key] ?? ""
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return encodedKey + "=" + encodedValue
        }.joined(separator: "&")
    }
}

private struct RewardCouponURLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// MP reward-selector field: label + occasion on the left, the chosen coupon (or the placeholder) and a chevron.
/// Tapping opens the 选择奖励 sheet. Level C (form row).
@MainActor struct RewardCouponSelectorRow: View {
    let source: RewardCouponSource
    @Binding var couponID: String
    @Binding var couponName: String
    var label: LocalizedStringKey = "rewardCoupon.label.node"
    var occasion: LocalizedStringKey = "rewardCoupon.occasion.node"
    var placeholder: LocalizedStringKey = "rewardCoupon.placeholder"
    @State private var presented = false

    private var selectedID: Int? {
        guard let value = Int(couponID.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        return value
    }

    var body: some View {
        Button {
            presented = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(label).foregroundStyle(.primary)
                    Text(occasion).cyText(.meta).foregroundStyle(.secondary)
                }
                Spacer(minLength: CYSpacing.sm)
                selectedText
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rewardCoupon.field")
        .task(id: couponID) { await resolveName() }
        .sheet(isPresented: $presented) {
            RewardCouponSelectorSheet(source: source, selectedID: selectedID, choose: choose)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var selectedText: some View {
        let name = couponName.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedID != nil, !name.isEmpty {
            Text(verbatim: name).foregroundStyle(.secondary)
        } else if let id = selectedID {
            Text("rewardCoupon.selectedID \(id)").foregroundStyle(.secondary)
        } else {
            Text(placeholder).foregroundStyle(.tertiary)
        }
    }

    /// A saved template carries only `couponId`; read the author's list once so the row shows the coupon's name.
    private func resolveName() async {
        guard let id = selectedID else {
            if !couponName.isEmpty { couponName = "" }
            return
        }
        guard couponName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let options = try? await source.load(),
              let match = options.first(where: { $0.id == id }), selectedID == id else { return }
        couponName = match.name
    }

    private func choose(_ option: RewardCouponOption?) {
        if let option {
            couponID = String(option.id)
            couponName = option.name
        } else {
            couponID = ""
            couponName = ""
        }
        presented = false
    }
}

/// 选择奖励 sheet: 优惠券 / 体验卡 segmented tabs, 不发奖励, then the list (loading / error + 重试 / empty).
/// 新建 stays off, as in the MP (`couponForm.CREATION_ENABLED = false`).
@MainActor struct RewardCouponSelectorSheet: View {
    let source: RewardCouponSource
    let selectedID: Int?
    let choose: (RewardCouponOption?) -> Void
    private enum Phase: Equatable { case loading, failed, loaded([RewardCouponOption]) }
    @State private var phase: Phase = .loading
    @State private var kind: RewardCouponKind = .coupon
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("rewardCoupon.kind", selection: $kind) {
                        Text("rewardCoupon.kind.coupon").tag(RewardCouponKind.coupon)
                        Text("rewardCoupon.kind.pass").tag(RewardCouponKind.pass)
                    }
                    .cyAdaptiveSegmented()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    optionRow(title: Text("rewardCoupon.none"), detail: nil, checked: selectedID == nil) { choose(nil) }
                        .accessibilityIdentifier("rewardCoupon.none")
                }
                Section { content }
            }
            .navigationTitle("rewardCoupon.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("rewardCoupon.close") { dismiss() }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
        .sensoryFeedback(.selection, trigger: kind)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYLoadingState("rewardCoupon.loading", messageIdentifier: "rewardCoupon.loading")
                .listRowBackground(Color.clear)
        case .failed:
            ContentUnavailableView {
                Label(errorTitle, systemImage: "exclamationmark.triangle")
            } actions: {
                Button("rewardCoupon.retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("rewardCoupon.error")
        case .loaded(let options):
            let visible = RewardCouponSelectionContract.visible(options, kind: kind)
            if visible.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: kind == .pass ? "ticket" : "tag")
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("rewardCoupon.empty")
            } else {
                ForEach(visible) { option in
                    optionRow(title: optionTitle(option), detail: optionDetail(option), checked: selectedID == option.id) {
                        choose(option)
                    }
                }
            }
        }
    }

    private var errorTitle: LocalizedStringKey {
        kind == .pass ? LocalizedStringKey("rewardCoupon.error.pass") : LocalizedStringKey("rewardCoupon.error.coupon")
    }

    private var emptyTitle: LocalizedStringKey {
        kind == .pass ? LocalizedStringKey("rewardCoupon.empty.pass") : LocalizedStringKey("rewardCoupon.empty.coupon")
    }

    private func optionTitle(_ option: RewardCouponOption) -> Text {
        option.name.isEmpty ? Text("rewardCoupon.selectedID \(option.id)") : Text(verbatim: option.name)
    }

    private func optionDetail(_ option: RewardCouponOption) -> Text {
        if let detail = option.detail { return Text(verbatim: detail) }
        return option.kind == .pass ? Text("rewardCoupon.sub.pass") : Text("rewardCoupon.sub.coupon")
    }

    private func optionRow(title: Text, detail: Text?, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    title.foregroundStyle(.primary)
                    if let detail { detail.cyText(.meta).foregroundStyle(.secondary) }
                }
                Spacer(minLength: CYSpacing.sm)
                if checked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? [.isSelected] : [])
    }

    private func load() async {
        if case .loaded = phase {} else { phase = .loading }
        do {
            let options = try await source.load()
            kind = RewardCouponSelectionContract.initialKind(options, selected: selectedID, current: kind)
            phase = .loaded(options)
        } catch {
            phase = .failed
        }
    }
}
