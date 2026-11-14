import SwiftUI

// Card-language building blocks shared by the city / play-kit pages (cards, step progress, collapsed technical details).
// Presentation only; no behaviour lives here.

/// Elevated continuous-corner card with an optional leading-icon title. The play-guide card language.
struct CYInfoCard<Content: View>: View {
    @Environment(\.cyPalette) private var palette
    var title: Text? = nil
    var symbol: String? = nil
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let title {
                HStack(spacing: CYSpacing.sm) {
                    if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(tint ?? palette.textSecondary).accessibilityHidden(true) }
                    title.font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }
}

/// Label + value on one line that wraps under Dynamic Type instead of truncating.
struct CYFactRow: View {
    @Environment(\.cyPalette) private var palette
    let label: Text
    let value: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                label.font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                Text(verbatim: value).font(CYTypography.bodyCompact).foregroundStyle(palette.textPrimary).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 2) {
                label.font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                Text(verbatim: value).font(CYTypography.bodyCompact).foregroundStyle(palette.textPrimary).textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Technical identifiers (release, request, hash) stay reachable but collapsed so the page leads with what the player needs.
struct CYDetailsDisclosure<Content: View>: View {
    @Environment(\.cyPalette) private var palette
    let title: Text
    @ViewBuilder let content: () -> Content
    @State private var open = false
    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) { content() }.padding(.top, CYSpacing.sm)
        } label: {
            title.font(CYTypography.meta.weight(.semibold)).foregroundStyle(palette.textSecondary)
        }
        .tint(palette.textSecondary)
        .frame(minHeight: 44)
    }
}

/// Multi-step progress: numbered capsule segments + "Step n of m". The current step is announced to VoiceOver.
struct CYStepIndicator: View {
    @Environment(\.cyPalette) private var palette
    let titles: [String]
    let current: Int
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(titles.indices, id: \.self) { index in
                    Capsule().fill(index <= current ? palette.textPrimary : palette.bgRaised).frame(height: 4)
                }
            }
            HStack {
                Text(verbatim: ChannelCopy.text("第 \(current + 1) 步 / 共 \(titles.count) 步", "Step \(current + 1) of \(titles.count)", locale: locale))
                    .font(CYTypography.meta.monospacedDigit()).foregroundStyle(palette.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                if titles.indices.contains(current) {
                    Text(verbatim: titles[current]).font(CYTypography.meta.weight(.semibold)).foregroundStyle(palette.textPrimary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One-line status banner (icon + message) with a tone, never colour alone.
struct CYNoteBanner: View {
    @Environment(\.cyPalette) private var palette
    let text: Text
    var symbol = "info.circle"
    var tone: CYStatusTone = .neutral
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: symbol).font(.body.weight(.semibold)).accessibilityHidden(true)
            text.font(CYTypography.bodyCompact).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.textPrimary)
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Page scaffold for the card-based city pages: dark ground, art cover first (it carries its own gutter), 20pt gutters for the cards.
struct CYCardPage<Header: View, Content: View>: View {
    @Environment(\.cyPalette) private var palette
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.md) {
                header()
                VStack(spacing: CYSpacing.md) { content() }.padding(.horizontal, CYSpacing.pageHorizontal)
            }.padding(.bottom, CYSpacing.xl)
        }
        .background(palette.bgPage.ignoresSafeArea())
    }
}

/// Honest collection summary: how many are collected and how many are still locked. The API exposes no per-item progress, so there is no ring or percentage.
struct CYCollectedLockedSummary: View {
    @Environment(\.cyPalette) private var palette
    let collected: Int
    let locked: Int
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            tile(collected, ChannelCopy.text("已收集", "Collected", locale: locale), symbol: "checkmark.seal.fill", on: true)
            tile(locked, ChannelCopy.text("未解锁", "Locked", locale: locale), symbol: "lock.fill", on: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ChannelCopy.text("已收集 \(collected) 枚，未解锁 \(locked) 枚", "\(collected) collected, \(locked) locked", locale: locale)))
    }
    private func tile(_ n: Int, _ label: String, symbol: String, on: Bool) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: symbol).font(.title3).foregroundStyle(on ? palette.textPrimary : palette.textTertiary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: String(n)).font(CYTypography.dataXL).monospacedDigit().foregroundStyle(palette.textPrimary)
                Text(verbatim: label).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

/// Tappable single/multi choice row: leading radio/check, wrapping label, 48pt minimum, selected = raised fill + 1.5pt stroke.
struct CYChoiceRow: View {
    @Environment(\.cyPalette) private var palette
    let label: String
    let selected: Bool
    var multi = false
    var enabled = true
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: selected ? (multi ? "checkmark.square.fill" : "largecircle.fill.circle") : (multi ? "square" : "circle"))
                    .foregroundStyle(selected ? palette.textPrimary : palette.textTertiary)
                    .symbolEffect(.bounce, value: reduceMotion ? false : selected)
                Text(verbatim: label).font(CYTypography.body).foregroundStyle(palette.textPrimary).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? palette.bgRaised : Color.clear, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).stroke(selected ? palette.textPrimary : palette.bgRaised, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private struct CYFieldSurfaceModifier: ViewModifier {
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content
            .padding(CYSpacing.md).frame(minHeight: 48)
            .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
    }
}

extension View {
    /// Filled text-field surface used by the city / play-kit forms (replaces the system rounded border).
    func cyField() -> some View {
        modifier(CYFieldSurfaceModifier())
    }
}

/// One grid for every collection (stamp album, badge wall, passport): adaptive 160pt cells, 12pt gutters, a single column at accessibility sizes.
enum CYCollectionGrid {
    static func columns(accessibility: Bool) -> [GridItem] {
        accessibility ? [GridItem(.flexible(), alignment: .topLeading)] : [GridItem(.adaptive(minimum: 160), spacing: CYSpacing.md, alignment: .topLeading)]
    }
    static let spacing = CYSpacing.md
}

/// Collapsible rule card: icon tile + title + chevron header; content slides open. Header is one 56pt button that announces its expanded state.
struct CYCollapsibleCard<Content: View>: View {
    @Environment(\.cyPalette) private var palette
    let title: Text
    let symbol: String
    @Binding var expanded: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private var tile: CGFloat { typeSize.isAccessibilitySize ? 52 : 36 }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
            } label: {
                HStack(spacing: CYSpacing.md) {
                    Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(palette.textPrimary)
                        .frame(width: tile, height: tile)
                        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    title.font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: CYSpacing.sm)
                    Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0)).accessibilityHidden(true)
                }
                .padding(CYSpacing.lg).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(Text(verbatim: expanded ? "expanded" : "collapsed"))
            .sensoryFeedback(.selection, trigger: expanded)
            if expanded {
                VStack(alignment: .leading, spacing: CYSpacing.md) { content() }
                    .padding([.horizontal, .bottom], CYSpacing.lg)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }
}

/// Timeline spine: a status dot on a connector line with the row content on the right. `first`/`last` trim the line at both ends.
/// Day grouping is only used where the source supplies dates; undated lists use the spine alone (never an invented date).
struct CYTimelineItem<Content: View>: View {
    @Environment(\.cyPalette) private var palette
    var first = false
    var last = false
    var symbol = "circle.fill"
    var tint: Color? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    private var rail: CGFloat { typeSize.isAccessibilitySize ? 40 : 28 }
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(spacing: 0) {
                Rectangle().fill(first ? Color.clear : palette.borderStrong).frame(width: 2, height: 10)
                Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(tint ?? palette.textPrimary)
                    .frame(width: rail, height: rail).background(palette.bgRaised, in: Circle()).accessibilityHidden(true)
                Rectangle().fill(last ? Color.clear : palette.borderStrong).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: rail)
            content().padding(.bottom, last ? 0 : CYSpacing.md)
        }
    }
}
