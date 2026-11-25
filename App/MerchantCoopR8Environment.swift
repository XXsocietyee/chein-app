import SwiftUI

// r8 merchant-coop mount hooks. The session supplies read closures; screens stay free of AppSession, and every
// closure is nil in previews and fixtures (the section then draws nothing).

private struct MerchantInsightPoolReaderKey: EnvironmentKey {
    static let defaultValue: (@MainActor () async throws -> CooperationPool)? = nil
}
extension EnvironmentValues {
    /// MC8-11-6: `api/coop/pool/list` through the session's existing cooperation reader.
    var merchantInsightPoolReader: (@MainActor () async throws -> CooperationPool)? {
        get { self[MerchantInsightPoolReaderKey.self] }
        set { self[MerchantInsightPoolReaderKey.self] = newValue }
    }
}

/// Installed once at the app root (QuestifyApp chain) so every merchant entry point gets the same hooks.
struct MerchantCoopR8SessionEnvironment: ViewModifier {
    @ObservedObject var session: AppSession
    func body(content: Content) -> some View {
        content
            .environment(\.merchantInsightPoolReader, { try await session.cooperationReader.pool() })
    }
}

/// MC8-11-6 (ai-insight/index.wxml:197, pages/merchant/components/cy/club-pool-cards): 俱乐部合作 under 为你推荐的主题 —
/// up to three `state == open` pool rows, 查看全部 → 合作中心, a card → 合作中心 focused on that topic, and an inline
/// 俱乐部合作暂时没读到，点这里重试 on a failed read.
struct MerchantInsightPoolCardsSection: View {
    @Environment(\.merchantInsightPoolReader) private var poolReader
    @Environment(\.merchantCoopCenterDestination) private var coopCenter
    @State private var rows: [CooperationPoolItem] = []
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        if let poolReader, let coopCenter {
            Group {
                if !rows.isEmpty || failed {
                    Section {
                        if failed {
                            Button { attempt += 1 } label: {
                                Text("merchantInsight.pool.retry").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            }
                            .accessibilityIdentifier("merchant.insight.pool.retry")
                        }
                        ForEach(rows, id: \.topicId) { row in
                            NavigationLink { coopCenter(.plaza, row.topicId) } label: { card(row) }
                                .accessibilityIdentifier("merchant.insight.pool.\(row.topicId)")
                        }
                    } header: {
                        HStack {
                            Text("merchantInsight.pool.title")
                            Spacer()
                            NavigationLink { coopCenter(.plaza, nil) } label: { Text("merchantInsight.pool.all") }
                                .accessibilityIdentifier("merchant.insight.pool.all")
                        }
                    }
                } else {
                    Color.clear.frame(height: 0).listRowBackground(Color.clear)
                }
            }
            .task(id: attempt) {
                do {
                    let pool = try await poolReader()
                    guard !Task.isCancelled else { return }
                    rows = Array(pool.rows.filter { $0.state == "open" }.prefix(3)); failed = false
                } catch {
                    guard !Task.isCancelled else { return }
                    rows = []; failed = true
                }
            }
        }
    }

    private func card(_ row: CooperationPoolItem) -> some View {
        HStack(spacing: CYSpacing.sm) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 10).fill(CYColor.bgRaised)
                if let raw = row.cover, let url = URL(string: raw), url.scheme?.lowercased() == "https" {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() } else { Color.clear }
                    }
                }
                Text("merchantInsight.pool.open").cyText(.caption).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(CYColor.brand))
                    .padding(4)
            }
            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: row.name ?? "").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                if let host = row.merchantNick, !host.isEmpty {
                    Text(verbatim: host).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                if let deadline = Self.deadlineText(row.recruitDeadline) {
                    Text("merchantInsight.pool.deadline \(deadline)").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// MP `deadlineText`: `yyyy-MM-dd[ HH:mm]` → `M月d日[ HH:mm]` (zh); other shapes show nothing.
    static func deadlineText(_ value: CooperationSourceTime?) -> String? {
        guard case .text(let raw) = value else { return nil }
        let parts = raw.split(whereSeparator: { $0 == " " || $0 == "T" })
        let day = parts.first?.split(separator: "-") ?? []
        guard day.count == 3, let month = Int(day[1]), let date = Int(day[2]) else { return nil }
        var text = "\(month)月\(date)日"
        if parts.count > 1, parts[1].count >= 5 { text += " " + parts[1].prefix(5) }
        return text
    }
}
