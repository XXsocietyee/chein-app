import Foundation

/// MP `pages/square/components/cy/post-compose/index.js:87-98` (`draftIdentity(memberId, clubId)`): one local draft per
/// signed-in member and club, restored when the composer opens again. Text and already-uploaded image references only;
/// guests (no account id) never keep a draft.
struct ClubPostDraft: Codable, Equatable {
    var content: String
    var images: [String]

    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty
    }
}

enum ClubPostDraftStore {
    static func key(accountID: Int, clubID: Int) -> String {
        "club.post.draft.\(accountID).\(clubID)"
    }

    static func load(accountID: Int?, clubID: Int, defaults: UserDefaults = .standard) -> ClubPostDraft? {
        guard let accountID, accountID > 0, clubID > 0,
              let data = defaults.data(forKey: key(accountID: accountID, clubID: clubID)),
              let draft = try? JSONDecoder().decode(ClubPostDraft.self, from: data),
              !draft.isEmpty else { return nil }
        return draft
    }

    static func save(_ draft: ClubPostDraft, accountID: Int?, clubID: Int, defaults: UserDefaults = .standard) {
        guard let accountID, accountID > 0, clubID > 0 else { return }
        if draft.isEmpty {
            clear(accountID: accountID, clubID: clubID, defaults: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key(accountID: accountID, clubID: clubID))
    }

    static func clear(accountID: Int?, clubID: Int, defaults: UserDefaults = .standard) {
        guard let accountID, accountID > 0, clubID > 0 else { return }
        defaults.removeObject(forKey: key(accountID: accountID, clubID: clubID))
    }
}
