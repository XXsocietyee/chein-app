import SwiftUI

/// RHIST-2 (MP scene-roam-history wxml:6): when the server history page cannot be read, the local list stays and a
/// tappable notice says so (漫游记录读取失败，当前仅显示已读取记录。点此重试). It reads only the existing first
/// `GET api/roam/passport/history` page through the injected passport reader; nil / signed-out / not configured
/// readers show nothing. The rows themselves are not merged here (RHIST-1 is the separate server-history page).
@MainActor struct RoamHistoryRemoteStatusBanner: View {
    @Environment(\.roamPassportHistoryReader) private var reader
    @State private var failedOwner: RoamPassportHistoryOwner?
    @State private var attempt = 0
    private struct Key: Hashable { let owner: RoamPassportHistoryOwner?; let attempt: Int }

    var body: some View {
        let owner = reader.map { RoamPassportHistoryOwner($0) }
        Group {
            if let owner, failedOwner == owner {
                Button { failedOwner = nil; attempt += 1 } label: {
                    Label { Text("roamSub.w208.history.partialError") } icon: { Image(systemName: "exclamationmark.triangle") }
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("action.retry"))
                .accessibilityIdentifier("roam.history.remoteError")
            }
        }
        .task(id: Key(owner: owner, attempt: attempt)) { await probe() }
    }

    private func probe() async {
        guard let reader else { failedOwner = nil; return }
        let owner = RoamPassportHistoryOwner(reader)
        guard owner.configured, owner.storageKey != nil else { failedOwner = nil; return }
        do {
            _ = try await reader.page(before: nil)
            if owner == RoamPassportHistoryOwner(reader) { failedOwner = nil }
        } catch is CancellationError {
        } catch APIError.unauthorized {
            failedOwner = nil
        } catch {
            guard !Task.isCancelled, owner == RoamPassportHistoryOwner(reader) else { return }
            failedOwner = owner
        }
    }
}
