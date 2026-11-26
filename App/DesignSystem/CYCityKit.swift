import SwiftUI

// Card-language building blocks shared by the city / play-kit pages (cards, step progress, collapsed technical details).
// Presentation only; no behaviour lives here.

/// Native r2 card: a plain grouped surface (`cyDomainCard`: system grouped secondary background, no shadow) with an
/// optional `Label` header in `.headline`.
struct CYInfoCard<Content: View>: View {
    var title: Text? = nil
    var symbol: String? = nil
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let title {
                Group {
                    if let symbol {
                        Label {
                            title
                        } icon: {
                            Image(systemName: symbol).foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint))
                        }
                    } else {
                        title
                    }
                }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(padding: CYSpacing.lg)
    }
}

/// Native r2: `LabeledContent` (label left, value right in `.secondary`, wraps under Dynamic Type).
struct CYFactRow: View {
    let label: Text
    let value: String
    var body: some View {
        LabeledContent {
            Text(verbatim: value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            label
        }
        .accessibilityElement(children: .combine)
    }
}

/// Technical identifiers (release, request, hash) stay reachable but collapsed: the system `DisclosureGroup`.
struct CYDetailsDisclosure<Content: View>: View {
    let title: Text
    @ViewBuilder let content: () -> Content
    @State private var open = false
    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            content()
        } label: {
            title
        }
    }
}

/// Multi-step progress (native r2): a system linear `ProgressView` with "Step n of m" and the current step title.
struct CYStepIndicator: View {
    let titles: [String]
    let current: Int
    @Environment(\.locale) private var locale
    var body: some View {
        ProgressView(value: Double(min(current + 1, max(titles.count, 1))), total: Double(max(titles.count, 1))) {
            if titles.indices.contains(current) {
                Text(verbatim: titles[current])
            }
        } currentValueLabel: {
            Text(verbatim: ChannelCopy.text("第 \(current + 1) 步 / 共 \(titles.count) 步", "Step \(current + 1) of \(titles.count)", locale: locale))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Native r2: a `Label` footnote with an SF Symbol (default `info.circle`) in `.secondary`. No box. `tone` kept for
/// call sites; the symbol carries the meaning, never colour alone.
struct CYNoteBanner: View {
    let text: Text
    var symbol = "info.circle"
    var tone: CYStatusTone = .neutral
    var body: some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Page scaffold for the card-based city pages (native r2): a scroll view on the system grouped background.
struct CYCardPage<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.md) {
                header()
                VStack(spacing: CYSpacing.md) { content() }.padding(.horizontal)
            }.padding(.bottom, CYSpacing.xl)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}

/// Honest collection summary (native r2): two `LabeledContent` lines with SF Symbol labels. No tiles, no ring.
struct CYCollectedLockedSummary: View {
    let collected: Int
    let locked: Int
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            line(collected, ChannelCopy.text("已收集", "Collected", locale: locale), symbol: "checkmark.seal.fill")
            line(locked, ChannelCopy.text("未解锁", "Locked", locale: locale), symbol: "lock.fill")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ChannelCopy.text("已收集 \(collected) 枚，未解锁 \(locked) 枚", "\(collected) collected, \(locked) locked", locale: locale)))
    }
    private func line(_ n: Int, _ label: String, symbol: String) -> some View {
        LabeledContent {
            Text(verbatim: String(n)).monospacedDigit()
        } label: {
            Label(label, systemImage: symbol)
        }
    }
}

/// Single/multi choice row (native r2): a plain button row like a Settings picker list: text, then the system
/// checkmark when selected (multi uses `checkmark.circle.fill` / `circle`).
struct CYChoiceRow: View {
    let label: String
    let selected: Bool
    var multi = false
    var enabled = true
    /// Drawn letter for a Q&A row. Nil keeps the row as a plain choice.
    var marker: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                if let marker, !marker.isEmpty {
                    Text(verbatim: marker).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(verbatim: label).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if multi {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                } else if selected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

extension View {
    /// Native r2: the system rounded-border text field style (no surface of our own). Inside a `Form` prefer plain fields.
    func cyField() -> some View {
        textFieldStyle(.roundedBorder)
    }
}

/// One grid for every collection (stamp album, badge wall, passport): adaptive 160pt cells, 12pt gutters, a single column at accessibility sizes.
enum CYCollectionGrid {
    static func columns(accessibility: Bool) -> [GridItem] {
        accessibility ? [GridItem(.flexible(), alignment: .topLeading)] : [GridItem(.adaptive(minimum: 160), spacing: CYSpacing.md, alignment: .topLeading)]
    }
    static let spacing = CYSpacing.md
}

/// Collapsible rule section (native r2): the system `DisclosureGroup` with a `Label` title. `expanded` stays bound.
struct CYCollapsibleCard<Content: View>: View {
    let title: Text
    let symbol: String
    @Binding var expanded: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: CYSpacing.md) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label {
                title.multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: symbol)
            }
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Timeline item (native r2): a `Label`-style row with the status SF Symbol (tint or `.secondary`) and the content.
/// No drawn rail. `first`/`last` kept for call sites.
struct CYTimelineItem<Content: View>: View {
    var first = false
    var last = false
    var symbol = "circle.fill"
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
            content().padding(.bottom, last ? 0 : CYSpacing.sm)
        }
    }
}
