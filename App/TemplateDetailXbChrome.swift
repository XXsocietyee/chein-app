import SwiftUI

/// Mini-program `pages/templatedetail` and `topic-detail` chrome (B57 / B78): the `xb-head` (square cover left,
/// title + publisher right, 官方 tag), the `xb-cta` row (应用 + round share), the left-aligned 详情 / 能力 tabs and the
/// 能力 rows (label + chips, folded past three chips). Display only: no row here sends a request.
enum TemplateDetailTab: String, CaseIterable, Hashable {
    case details, capabilities
    var title: LocalizedStringKey {
        switch self {
        case .details: return "u10.template.tab.details"
        case .capabilities: return "u10.template.tab.capabilities"
        }
    }
}

struct TemplateXbHead<Cover: View>: View {
    let title: Text
    let publisher: Text?
    var official = false
    var subtitle: String? = nil
    @ViewBuilder let cover: () -> Cover
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.lg))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.lg))
        layout {
            // Image crop only (App Store-style artwork tile); no card chrome.
            cover()
                .frame(width: 120, height: 120)
                .clipShape(.rect(cornerRadius: CYRadius.lg, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                title.font(.title2.bold())
                    .lineLimit(2).accessibilityAddTraits(.isHeader)
                if let publisher {
                    publisher.font(.body).foregroundStyle(.secondary).lineLimit(1)
                        .accessibilityIdentifier("template.xb.publisher")
                }
                if official {
                    Label("discovery.templateDetail.publisher.official", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: subtitle).font(.footnote).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template.xb.head")
    }
}

/// Share key beside 应用. A parsed path shares its universal link. A path the parsers do not type
/// shares the mini-program path text and no host. Both nil hides the key.
struct TemplateXbShareButton: View {
    let url: URL?
    var copyText: String? = nil
    let label: LocalizedStringKey
    var body: some View {
        if let url {
            ShareLink(item: url) { mark }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("template.xb.share")
        } else if let copyText, !copyText.isEmpty {
            ShareLink(item: copyText) { mark }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("template.xb.share")
        }
    }
    private var mark: some View {
        Image(systemName: "square.and.arrow.up").accessibilityHidden(true)
    }
}

/// 应用 label. The caller wraps it in a plain-style Button, so it carries the system bordered fill
/// (secondary system fill + tint text) rather than any custom colour.
struct TemplateXbApplyLabel: View {
    var body: some View {
        Text("templateAuthor.adopt").font(.body.weight(.semibold)).foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .contentShape(Capsule())
    }
}

struct TemplateXbTabs: View {
    @Binding var selection: TemplateDetailTab
    var body: some View {
        Picker(selection: $selection) {
            ForEach(TemplateDetailTab.allCases, id: \.self) { tab in
                Text(tab.title)
                    .tag(tab)
                    .accessibilityIdentifier("template.xb.tab.\(tab.rawValue)")
            }
        } label: {
            Text("u10.template.tab.details")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityIdentifier("template.xb.tabs")
    }
}

/// One 能力 row: 方式 / 场景 / 来源 and its chips. A chip with an action (节点预览) is a button.
struct TemplateCapabilityRow: Identifiable, Equatable {
    struct Chip: Equatable, Hashable { let text: String; var action: String? = nil }
    let key: String
    let label: LocalizedStringKey
    let chips: [Chip]
    var id: String { key }
    static let inlineMax = 3
    var collapsible: Bool { chips.count > Self.inlineMax }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key && lhs.chips == rhs.chips }
}

struct TemplateCapabilityRows: View {
    let rows: [TemplateCapabilityRow]
    var onAction: (String) -> Void = { _ in }
    @State private var expanded: Set<String> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                // V-11 & #838: the 能力 tab always exists; with no rows it shows an empty state instead of a blank page.
                ContentUnavailableView {
                    Label("template.cap.emptyState", systemImage: "map")
                }
                .accessibilityIdentifier("template.cap.empty")
            }
            ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                if index > 0 { Divider() }
                rowView(row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("template.cap.rows")
    }
    private func rowView(_ row: TemplateCapabilityRow) -> some View {
        let open = expanded.contains(row.key)
        let visible = row.collapsible && !open ? Array(row.chips.prefix(TemplateCapabilityRow.inlineMax)) : row.chips
        return HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Text(row.label).font(.subheadline).foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .leading)
            TemplateFlowChips(chips: visible, onAction: onAction)
            Spacer(minLength: 0)
            if row.collapsible {
                Button { if open { expanded.remove(row.key) } else { expanded.insert(row.key) } } label: {
                    if open { Text("u10.template.cap.collapse") } else { Text("u10.template.cap.expand") }
                }
                .buttonStyle(.borderless)
                .font(.footnote)
                .accessibilityIdentifier("template.cap.\(row.key).toggle")
            }
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template.cap.\(row.key)")
    }
}

/// Chips that wrap onto further lines. A chip with an action is a small bordered button; a plain chip is text.
private struct TemplateFlowChips: View {
    let chips: [TemplateCapabilityRow.Chip]
    let onAction: (String) -> Void
    var body: some View {
        TemplateChipFlow(spacing: CYSpacing.sm) {
            ForEach(chips, id: \.self) { chip in
                if let action = chip.action {
                    Button { onAction(action) } label: {
                        Label(chip.text, systemImage: "arrow.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("template.cap.chip.\(action)")
                } else {
                    Text(verbatim: chip.text).modifier(TemplateChipStyle())
                }
            }
        }
    }
}

struct TemplateChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.subheadline)
    }
}

/// Minimal wrapping row layout for chips.
struct TemplateChipFlow: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { y += line + spacing; x = 0; line = 0 }
            x += size.width + spacing; line = max(line, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { y += line + spacing; x = bounds.minX; line = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; line = max(line, size.height)
        }
    }
}

/// Section title with a leading glyph, as the mini-program `xb-section-title` (MP icon art or SF Symbol + label).
struct TemplateXbSectionTitle: View {
    let title: LocalizedStringKey
    let systemImage: String
    var note: Text? = nil
    /// MP `xb-section-ico` art; when set it replaces the SF Symbol.
    var art: Image? = nil
    var body: some View {
        HStack(alignment: art == nil ? .firstTextBaseline : .center, spacing: CYSpacing.sm) {
            if let art { art.resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true) }
            else { Image(systemName: systemImage).foregroundStyle(.tint).accessibilityHidden(true) }
            Text(title)
            if let note { note.foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
