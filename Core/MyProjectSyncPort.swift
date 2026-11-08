import Foundation

/// Port of `subpackageA/pages/myproject` `mp-refreshing`: while a reload runs over an already
/// loaded list for the SAME filter, the rows stay on screen (read-only) under a
/// "正在同步最新项目…" line instead of being replaced by a spinner. A different filter or
/// account scope never reuses another list's rows.
public enum MyProjectSyncPort {
    public static func keepsStaleRows(isLoading: Bool, previousQuery: CreatorContentQuery?, currentQuery: CreatorContentQuery,
                                      previousScope: UUID?, currentScope: UUID) -> Bool {
        isLoading && previousQuery == currentQuery && previousScope == currentScope
    }
}
