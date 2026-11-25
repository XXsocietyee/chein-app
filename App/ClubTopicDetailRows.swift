import SwiftUI

/// CLB-topic-detail-10 (MP topic-detail wxml:585-629, js:46-72 flattenCustomerRows): one 报名参与者 row. An initial
/// avatar, the name with the session time and the server phone text (masked or a substitute sentence, shown as sent),
/// a 拨号 button only when the server says the viewer may call and the text is a full mainland number, then the status
/// chip with the verify time under it.
struct ClubTopicCustomerRow: View {
    let row: ClubGovernanceValue
    let sessionTime: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var name: String {
        let text = row["displayName"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text
    }
    private var phoneText: String? {
        guard let text = row["phoneText"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
    /// MP: `r.phoneCallable === true && /^1\d{10}$/.test(phoneText)`.
    private var callURL: URL? {
        guard row["phoneCallable"] == .bool(true), let phone = phoneText,
              phone.range(of: "^1[0-9]{10}$", options: .regularExpression) != nil else { return nil }
        return URL(string: "tel:" + phone)
    }
    private var verifyText: String? {
        guard let text = row["timeText"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "—" else { return nil }
        return text
    }

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Text(verbatim: name.isEmpty ? "·" : String(name.prefix(1)))
                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(CYColor.bgSurfaceStrong))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Group {
                    if name.isEmpty { Text("club.topic.customer.unnamed") } else { Text(verbatim: name) }
                }
                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                Group {
                    if let sessionTime, !sessionTime.isEmpty { Text(verbatim: sessionTime) } else { Text("club.topic.customer.timeTbd") }
                }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                if let phoneText {
                    Text(verbatim: phoneText).cyText(.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit()
                }
                if dynamicTypeSize.isAccessibilitySize { status }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let callURL {
                Button { openURL(callURL) } label: {
                    Image(systemName: "phone").frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("club.topic.customer.call \(name)"))
            }
            if !dynamicTypeSize.isAccessibilitySize { status }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
            if let text = row["statusText"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                CYStatusChip(verbatim: text, tone: Self.tone(row["statusCode"]))
            }
            if let verifyText {
                Text(verbatim: verifyText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
    }

    /// The server status code picks the chip tone.
    static func tone(_ code: ClubGovernanceValue) -> CYStatusTone {
        let key: String = code.string?.uppercased() ?? code.int.map { String($0) } ?? ""
        switch key {
        // MP wxss:267-269: VERIFIED success; PENDING and CONTACTED warning; everything else plain.
        case "VERIFIED": return .success
        case "PENDING", "CONTACTED": return .warning
        default: return .neutral
        }
    }
}

/// CLB-topic-detail-05 (MP topic-detail wxml:63-80, js:154-164 QUICK_ACTIONS): the four round actions under the header,
/// 商家 · 报名参与者 · 团码 · 更多. Each is a 44 pt+ target with its label under the circle.
struct ClubTopicQuickActionRow: View {
    struct Item: Identifiable {
        let id: String
        let titleKey: LocalizedStringKey
        let systemImage: String
        let action: () -> Void
    }
    let items: [Item]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.sm))
        layout {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(spacing: CYSpacing.xs) {
                        Image(systemName: item.systemImage)
                            .font(.title3)
                            .foregroundStyle(CYColor.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(CYColor.bgRaised))
                            .accessibilityHidden(true)
                        Text(item.titleKey)
                            .cyText(.label).foregroundStyle(CYColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("club.topic.quick." + item.id)
            }
        }
        .listRowBackground(Color.clear)
    }
}

/// CLB-topic-detail-05: which half sheet a round action opens.
enum ClubTopicQuickSheet: String, Identifiable {
    case merchants, customers, more
    var id: String { rawValue }
}

/// CLB-r8-topic-detail-01 (MP topic-detail wxml:106-125, js:749-764): the 主题 card. The cover shows only when the topic
/// has one (CU-C-147: no empty frame), then the name, 「N 章 · N 站 · 玩法」 (totalChapterCount, stats nodeCount,
/// playModeText; a missing or zero part is left out), 剧情已写 when storyReady, and 打开剧情与玩法.
struct ClubTopicStoryCard: View {
    let value: ClubGovernanceValue
    let nodeCount: Int?
    @Environment(\.locale) private var locale

    private var coverURL: URL? {
        QuestifyCardArtwork.safeURL((value["imgUrl"].string?.split(separator: ",").first.map(String.init)) ?? value["cover"].string ?? value["coverUrl"].string)
    }
    private var structureText: String {
        var parts: [String] = []
        if let chapters = value["totalChapterCount"].int, chapters > 0 { parts.append(appLocalized("club.topic.card.chapters \(chapters)", locale: locale)) }
        if let nodes = nodeCount, nodes > 0 { parts.append(appLocalized("club.story.stopCount \(nodes)", locale: locale)) }
        if let mode = value["playModeText"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !mode.isEmpty { parts.append(mode) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            if let coverURL {
                AsyncImage(url: coverURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { CYColor.bgSurfaceSubtle }
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: value["name"].string ?? value["title"].string ?? "—")
                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !structureText.isEmpty {
                    Text(verbatim: structureText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if value["storyReady"] == .bool(true) {
                    CYStatusChip("club.topic.card.storyReady", tone: .success)
                }
                Text("club.topic.card.openStory").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
