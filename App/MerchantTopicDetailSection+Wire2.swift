import SwiftUI

/// WIRE-2: merchantinfo stat bar + 节点介绍 template shelf (detail tab) and the 任务向导 chapters
/// (meta line + node gallery). Render-only over `MerchantTopicDetailFacts`; no reads, writes or routes.
struct MerchantTopicStatBarView: View {
    let cells: [MerchantTopicStatCell]
    private func label(_ kind: MerchantTopicStatCell.Kind) -> LocalizedStringKey {
        switch kind {
        case .hours: return "merchant.wire2.stat.hours"
        case .openRange: return "merchant.wire2.stat.open"
        case .mileage: return "merchant.wire2.stat.mileage"
        }
    }
    private func sub(_ kind: MerchantTopicStatCell.Kind) -> LocalizedStringKey? {
        switch kind {
        case .hours: return "merchant.wire2.stat.hoursUnit"
        case .openRange: return nil
        case .mileage: return "merchant.wire2.stat.mileageUnit"
        }
    }
    var body: some View {
        if !cells.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        if index > 0 { Divider().frame(height: 36).padding(.horizontal, 14) }
                        VStack(spacing: 2) {
                            Text(label(cell.kind)).cyText(.meta).foregroundStyle(.secondary)
                            Text(verbatim: cell.value).cyText(.sectionTitle, monospacedDigit: true)
                            if let sub = sub(cell.kind) { Text(sub).cyText(.meta).foregroundStyle(.secondary) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .accessibilityIdentifier("merchant.wire2.statBar")
        }
    }
}

struct MerchantTopicTemplateShelfView: View {
    let templates: [MerchantTopicNodeTemplate]
    var body: some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("merchant.wire2.templates.title").cyText(.cardTitle)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(templates.enumerated()), id: \.offset) { _, template in
                            VStack(alignment: .leading, spacing: 6) {
                                MerchantTopicRemoteImage(url: template.imageURL)
                                    .frame(width: 140, height: 100).clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                                Text(verbatim: template.title).cyText(.bodyMedium).lineLimit(2)
                                HStack(spacing: 8) {
                                    if let players = template.players { Text(verbatim: players) }
                                    if let minutes = template.durationMinutes { Text("merchant.wire2.template.minutes \(minutes)") }
                                }.cyText(.meta).foregroundStyle(.secondary)
                            }.frame(width: 140, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }.accessibilityIdentifier("merchant.wire2.templates")
        }
    }
}

struct MerchantTopicRemoteImage: View {
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else if phase.error != nil { placeholder }
                    else { ProgressView() }
                }
            } else { placeholder }
        }.clipped().accessibilityHidden(true)
    }
    private var placeholder: some View {
        ZStack { Color(uiColor: .tertiarySystemFill); Image(systemName: "photo").accessibilityHidden(true).foregroundStyle(.secondary) }
    }
}

/// 任务向导: chapter title, its time / node / play meta line, then numbered nodes with a swipeable photo gallery.
struct MerchantTopicGuideChaptersView: View {
    let chapters: [MerchantTopicChapterFacts]
    private func timeText(_ seconds: Int) -> Text {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        if hours == 0 { return minutes == 0 ? Text("merchant.wire2.meta.underMinute") : Text("merchant.wire2.meta.minutes \(minutes)") }
        return minutes == 0 ? Text("merchant.wire2.meta.hours \(hours)") : Text("merchant.wire2.meta.hoursMinutes \(hours) \(minutes)")
    }
    var body: some View {
        if !chapters.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("merchant.wire2.guide.title").cyText(.cardTitle)
                ForEach(Array(chapters.enumerated()), id: \.offset) { _, chapter in
                    VStack(alignment: .leading, spacing: 8) {
                        if let name = chapter.name { Text(verbatim: name).cyText(.bodyMedium) }
                        if chapter.hasMeta {
                            HStack(spacing: 12) {
                                if let seconds = chapter.totalSeconds { Label { timeText(seconds) } icon: { Image(systemName: "clock") } }
                                if chapter.nodeCount > 0 { Label { Text("merchant.wire2.meta.nodes \(chapter.nodeCount)") } icon: { Image(systemName: "mappin.and.ellipse") } }
                                if chapter.playCount > 0 { Label { Text("merchant.wire2.meta.plays \(chapter.playCount)") } icon: { Image(systemName: "person.2") } }
                            }.cyText(.meta).foregroundStyle(.secondary).accessibilityIdentifier("merchant.wire2.chapterMeta")
                        }
                        ForEach(Array(chapter.nodes.enumerated()), id: \.offset) { _, node in
                            VStack(alignment: .leading, spacing: 6) {
                                if !node.title.isEmpty { Text(verbatim: "\(node.step). \(node.title)").font(.subheadline) }
                                if !node.images.isEmpty {
                                    TabView {
                                        ForEach(Array(node.images.enumerated()), id: \.offset) { _, url in
                                            MerchantTopicRemoteImage(url: url)
                                        }
                                    }
                                    .tabViewStyle(.page).frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                                    .accessibilityIdentifier("merchant.wire2.gallery")
                                }
                                if !node.description.isEmpty { Text(verbatim: node.description).cyText(.bodyCompact).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                    }
                }
            }
        }
    }
}
