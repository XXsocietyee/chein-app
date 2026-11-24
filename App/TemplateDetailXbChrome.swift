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
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.xl))
        layout {
            cover()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                title.cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                    .lineLimit(2).accessibilityAddTraits(.isHeader)
                if let publisher {
                    publisher.cyText(.body).foregroundStyle(CYColor.textSecondary).lineLimit(1)
                        .accessibilityIdentifier("template.xb.publisher")
                }
                if official {
                    Text("discovery.templateDetail.publisher.official").cyText(.meta)
                        .foregroundStyle(CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(CYNight.glassFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                }
                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: subtitle).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template.xb.head")
    }
}

/// Round share key beside 应用. A parsed path shares its universal link. A path the parsers do not type
/// shares the mini-program path text and no host. Both nil hides the key.
struct TemplateXbShareButton: View {
    let url: URL?
    var copyText: String? = nil
    let label: LocalizedStringKey
    var body: some View {
        if let url {
            ShareLink(item: url) { mark }
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("template.xb.share")
        } else if let copyText, !copyText.isEmpty {
            ShareLink(item: copyText) { mark }
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier("template.xb.share")
        }
    }
    private var mark: some View {
        Image(systemName: "square.and.arrow.up").font(.title3).foregroundStyle(CYColor.textPrimary)
            .frame(width: 52, height: 52)
            .background(CYNight.ink2, in: Circle())
    }
}

/// Ghost 应用 pill matching the share key (owner V-24: same fill and text colour, only wider).
struct TemplateXbApplyLabel: View {
    var body: some View {
        Text("templateAuthor.adopt").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(CYNight.ink2, in: Capsule())
    }
}

struct TemplateXbTabs: View {
    @Binding var selection: TemplateDetailTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var underline
    var body: some View {
        HStack(spacing: CYSpacing.xxl) {
            ForEach(TemplateDetailTab.allCases, id: \.self) { tab in
                let on = selection == tab
                Button {
                    if reduceMotion { selection = tab } else { withAnimation(CYMotion.standard) { selection = tab } }
                } label: {
                    VStack(spacing: CYSpacing.sm) {
                        Text(tab.title).cyText(.cardTitle)
                            .foregroundStyle(on ? CYColor.textPrimary : CYColor.textTertiary)
                        ZStack {
                            Capsule().fill(Color.clear).frame(height: 3)
                            if on {
                                Capsule().fill(CYColor.textPrimary).frame(height: 3)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
                .accessibilityIdentifier("template.xb.tab.\(tab.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
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
                // V-11 & #838: the 能力 tab always exists; with no rows it shows CYEmptyState instead of a blank page.
                CYEmptyState(systemImage: "map", "template.cap.emptyState", messageIdentifier: "template.cap.empty")
                    .padding(CYSpacing.md)
            }
            ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                if index > 0 { Rectangle().fill(CYNight.glassEdgeBottom).frame(height: 1).padding(.leading, CYSpacing.lg) }
                rowView(row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityIdentifier("template.cap.rows")
    }
    private func rowView(_ row: TemplateCapabilityRow) -> some View {
        let open = expanded.contains(row.key)
        let visible = row.collapsible && !open ? Array(row.chips.prefix(TemplateCapabilityRow.inlineMax)) : row.chips
        return HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Text(row.label).cyText(.bodyCompact).foregroundStyle(CYColor.textTertiary)
                .frame(minWidth: 40, alignment: .leading)
            TemplateFlowChips(chips: visible, onAction: onAction)
            Spacer(minLength: 0)
            if row.collapsible {
                Button { if open { expanded.remove(row.key) } else { expanded.insert(row.key) } } label: {
                    Group { if open { Text("u10.template.cap.collapse") } else { Text("u10.template.cap.expand") } }
                        .cyText(.label).foregroundStyle(CYColor.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("template.cap.\(row.key).toggle")
            }
        }
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template.cap.\(row.key)")
    }
}

/// Chips that wrap onto further lines.
private struct TemplateFlowChips: View {
    let chips: [TemplateCapabilityRow.Chip]
    let onAction: (String) -> Void
    var body: some View {
        TemplateChipFlow(spacing: CYSpacing.sm) {
            ForEach(chips, id: \.self) { chip in
                if let action = chip.action {
                    Button { onAction(action) } label: {
                        HStack(spacing: CYSpacing.xs) {
                            Text(verbatim: chip.text)
                            Image(systemName: "arrow.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
                        }
                        .modifier(TemplateChipStyle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
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
        content.cyText(.label).foregroundStyle(CYColor.textPrimary)
            .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs + CYSpacing.xxs)
            .background(CYNight.ink2, in: Capsule())
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

/// Section title with a leading glyph, as the mini-program `xb-section-title` (3D icon + label).
struct TemplateXbSectionTitle: View {
    let title: LocalizedStringKey
    let systemImage: String
    var note: Text? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Image(systemName: systemImage).foregroundStyle(CYNight.lantern).accessibilityHidden(true)
            Text(title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
            if let note { note.cyText(.meta).foregroundStyle(CYColor.textTertiary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
