import SwiftUI

/// MP `pages/club/components/club-director-chapter-sheet` (topic-detail wxml:351-364, director.js:839-851, 1370-1411):
/// title 放行「章节」· N 队在等 (one releasable chapter) or 手动解锁章节 → chapter rows (title + 等待队伍) →
/// 现场原因（选填, 200 字） → one primary 放行. The reason is sent only when filled (C-04, 2026-11-02).
enum PlayDirectorChapterRelease {
    static let reasonLimit = 200

    struct Chapter: Identifiable {
        let id: Int
        let title: String?
        let waitingTeams: Int?
    }

    /// director.js:839: releasable chapters only (`PlayDirectorProjection.chapterOptions` already drops the current one).
    static func chapters(_ projection: PlayDirectorProjection) -> [Chapter] {
        projection.chapterOptions.compactMap { row in
            guard let id = row["chapterId"].integer, id > 0 else { return nil }
            let title = row["title"].text.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            return Chapter(id: id, title: title, waitingTeams: row["waitingTeams"].integer)
        }
    }

    /// director.js:850 `unlockText`.
    static func title(_ projection: PlayDirectorProjection, locale: Locale) -> String {
        let rows = chapters(projection)
        guard rows.count == 1, let only = rows.first else {
            return appLocalized("playx.director.chapter.manualTitle", locale: locale)
        }
        let name = only.title ?? appLocalized("playx.director.chapter.untitled", locale: locale)
        if let waiting = only.waitingTeams, waiting > 0 {
            return appLocalized("playx.director.chapter.releaseWaiting \(name) \(waiting)", locale: locale)
        }
        return appLocalized("playx.director.chapter.release \(name)", locale: locale)
    }

    /// director.js:1408: `{ chapterId }`, plus `reason` only when the director wrote one.
    static func payload(chapterID: Int, reason: String) -> [String: PlayWireValue] {
        var payload: [String: PlayWireValue] = ["chapterId": .int(chapterID)]
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { payload["reason"] = .string(trimmed) }
        return payload
    }
}

/// The chapter sections of `PlayDirectorCommandEditor`; the editor keeps the review → confirm → submit path.
@MainActor struct PlayDirectorChapterSections: View {
    let projection: PlayDirectorProjection
    @Binding var chapterID: Int
    @Binding var reason: String

    var body: some View {
        Section {
            ForEach(PlayDirectorChapterRelease.chapters(projection)) { chapter in
                chapterRow(chapter)
            }
        }
        .onAppear { selectFirst() }
        Section {
            TextField("playx.director.chapter.reasonPlaceholder", text: $reason, axis: .vertical)
                .lineLimit(2...5)
                .accessibilityIdentifier("playx.director.chapter.reason")
                .onChange(of: reason) { _, newValue in
                    if newValue.count > PlayDirectorChapterRelease.reasonLimit {
                        reason = String(newValue.prefix(PlayDirectorChapterRelease.reasonLimit))
                    }
                }
        } header: {
            Text("playx.director.chapter.reasonTitle")
        } footer: {
            Text("playx.director.chapter.caption")
        }
    }

    private func chapterRow(_ chapter: PlayDirectorChapterRelease.Chapter) -> some View {
        let on = chapter.id == chapterID
        return Button {
            chapterID = chapter.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    chapterTitle(chapter).foregroundStyle(.primary)
                    waitingText(chapter.waitingTeams).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if on {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playx.director.chapter.row.\(chapter.id)")
    }

    @ViewBuilder private func chapterTitle(_ chapter: PlayDirectorChapterRelease.Chapter) -> some View {
        if let title = chapter.title {
            Text(verbatim: title)
        } else {
            Text("playx.director.chapter.untitled")
        }
    }

    /// director.js:848 subtitle: nothing when the server sent no count (never a made-up 0).
    @ViewBuilder private func waitingText(_ waiting: Int?) -> some View {
        if let waiting, waiting > 0 {
            Text("playx.director.chapter.waiting \(waiting)")
        } else if waiting != nil {
            Text("playx.director.chapter.noneWaiting")
        }
    }

    /// director.js:1376 opens with the first chapter selected.
    private func selectFirst() {
        let rows = PlayDirectorChapterRelease.chapters(projection)
        if rows.contains(where: { $0.id == chapterID }) { return }
        if let first = rows.first { chapterID = first.id }
    }
}
