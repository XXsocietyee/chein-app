import SwiftUI

/// Mini-program object-cards empty copy: 还没有收过东西 for 全部, 这一类还没收过东西 for a category.
/// The message stays a static text so `objects.empty` remains the identifier.
struct ObjectCardsEmptyTitle: View {
    let isAllCategories: Bool
    var body: some View {
        CYEmptyState(
            systemImage: "rectangle.stack",
            isAllCategories ? "objectCards.emptyAll" : "objects.empty",
            messageIdentifier: "objects.empty"
        )
    }
}
