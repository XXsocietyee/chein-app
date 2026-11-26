import SwiftUI

/// Native r2 story flow, S4/S5: the route page as Apple Books "Now Reading".
/// Cover and title, a ProgressView, one prominent Continue, the chapter list with
/// done / current / locked states, then the cast row. Reads only the snapshot the
/// play coordinator already holds; it makes no request of its own.
@MainActor struct NR2StoryRouteSections: View {
    let snapshot: PlaySnapshot
    var coverURL: URL? = nil
    var aiGenerated = false
    var cast: [CastMember] = []
    /// Chapters that have a story document and an unlocked stop (the reader can open them).
    let readableChapterIDs: Set<Int>
    let openChapter: (Int) -> Void
    var openCast: (() -> Void)? = nil

    private var rows: [PlayChapterPickRow] { PlayChapterPickRow.rows(snapshot) }
    private var currentChapterID: Int? { NR2StoryRoute.currentChapterID(rows: rows, readable: readableChapterIDs) }

    var body: some View {
        let rows = self.rows
        let current = self.currentChapterID
        let done = rows.filter { $0.state == .completed }.count
        Section {
            if let coverURL {
                AsyncImage(url: coverURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(uiColor: .secondarySystemFill)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipped()
                .listRowInsets(EdgeInsets())
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: NR2StoryRoute.title(snapshot.result.topicName))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("play.titleCard")
                let line = PlayThemeIntro.line(snapshot.result.topicDescription)
                if !line.isEmpty {
                    Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary)
                }
                if aiGenerated {
                    Label("play.nr2.route.aigc", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("play.titleCard.aigc")
                }
            }
            if !rows.isEmpty {
                ProgressView(value: Double(done), total: Double(rows.count)) {
                    Text("play.nr2.route.progress")
                } currentValueLabel: {
                    Text("play.nr2.route.progressValue \(done) \(rows.count)").monospacedDigit()
                }
                .accessibilityIdentifier("play.nr2.route.progress")
            }
            if let current {
                Button { openChapter(current) } label: {
                    Text(done == 0 ? "play.nr2.route.start" : "play.nr2.route.continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("play.titleCard.start")
            }
        }
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    let readable = readableChapterIDs.contains(row.id)
                    Button { openChapter(row.id) } label: {
                        LabeledContent {
                            Text("play.nr2.route.stops \(row.nodeCount)").monospacedDigit()
                        } label: {
                            Label {
                                Text(verbatim: NR2StoryRoute.title(row.title))
                            } icon: {
                                Image(systemName: NR2StoryRoute.symbol(row.state, current: row.id == current))
                                    .foregroundStyle(row.state == .locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                            }
                        }
                    }
                    .foregroundStyle(row.state == .locked || !readable ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                    .disabled(row.state == .locked || !readable)
                    .accessibilityValue(Text(LocalizedStringKey(NR2StoryRoute.stateKey(row.state, current: row.id == current))))
                    .accessibilityIdentifier("chapterStory.open.\(row.id)")
                }
            } header: {
                Text("play.nr2.route.chapters")
            }
        }
        if !cast.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(cast) { member in
                            VStack(spacing: 6) {
                                NR2CastAvatar(member: member, size: 44)
                                Text(verbatim: member.name).font(.caption).lineLimit(1)
                            }
                            .frame(width: 64)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let openCast {
                    Button("play.nr2.route.castAll", action: openCast)
                        .accessibilityIdentifier("play.nr2.route.castAll")
                }
            } header: {
                Text("play.nr2.route.cast")
            }
        }
    }
}

/// Pure rules for the route page. Same chapter states as the r1 chapter picker.
enum NR2StoryRoute {
    /// The first chapter that is neither done nor locked and can be read; else the last readable one.
    static func currentChapterID(rows: [PlayChapterPickRow], readable: Set<Int>) -> Int? {
        if let open = rows.first(where: { $0.state == .open && readable.contains($0.id) }) { return open.id }
        return rows.last(where: { $0.state != .locked && readable.contains($0.id) })?.id
    }
    static func symbol(_ state: PlayChapterPickRow.State, current: Bool) -> String {
        switch state {
        case .completed: return "checkmark.circle.fill"
        case .locked: return "lock"
        case .open: return current ? "circle.inset.filled" : "circle"
        }
    }
    static func stateKey(_ state: PlayChapterPickRow.State, current: Bool) -> String {
        switch state {
        case .completed: return "play.nr2.route.state.done"
        case .locked: return "play.nr2.route.state.locked"
        case .open: return current ? "play.nr2.route.state.current" : "play.nr2.route.state.open"
        }
    }
    static func title(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
}

/// Cast avatar on system chrome: the member's https picture, else the system person glyph.
/// `media-asset:N` avatars need the retained reader; the r1 `CastAvatar` keeps doing that inside the cast card.
@MainActor struct NR2CastAvatar: View {
    let member: CastMember
    var size: CGFloat = 32
    private var url: URL? {
        guard let raw = member.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.lowercased().hasPrefix("https://") else { return nil }
        return URL(string: raw)
    }
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable().scaledToFit()
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
