import Foundation

/// The next chapter opens only after arrival at a stop in that chapter, and only when the server has not locked it.
/// A missing lock with no arrival stays closed.
public enum ChapterArrivalLock {
    public static func opens(arrivedAtStop: Bool, chapterLocked: Bool?) -> Bool {
        arrivedAtStop && chapterLocked != true
    }
}
