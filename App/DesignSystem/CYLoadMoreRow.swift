import SwiftUI

/// ADA 11-28 §3 **Refresh / paging**: the one "next page" row for player lists.
/// The next page loads when this row scrolls into view (the MP `onReachBottom`), so a player never has to find a button;
/// the full-width borderless button stays for VoiceOver, Switch Control and a failed automatic read.
/// Callers show the row only while another page exists and no page error is on screen, and keep their own identifier.
struct CYLoadMoreRow: View {
    private let titleKey: LocalizedStringKey
    private let isLoading: Bool
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey = "common.loadMore", isLoading: Bool = false, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CYBusyLabel(busy: isLoading) { Text(titleKey) }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .disabled(isLoading)
        .onAppear(perform: loadIfIdle)
    }

    private func loadIfIdle() {
        if !isLoading { action() }
    }
}
