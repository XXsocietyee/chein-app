import SwiftUI

/// Same-account immutable receipt only. Does not need current detail or authorize joining.
/// Embedded under club detail, which already owns the screen title. No second hero here.
@MainActor struct ClubActionOriginalRecoveryView: View {
    let clubID: Int
    let identity: ClubReadIdentity
    let coordinator: ClubActionCoordinator
    @QuestifyReduceMotion private var reduceMotion
    @State private var revision: UInt64 = 0
    @State private var working = false
    @State private var checked = false
    @State private var task: Task<Void, Never>?
    var body: some View {
        let _ = revision
        let state = coordinator.state(clubID: clubID)
        if coordinator.identity == identity, identity.isSignedIn {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if case .outcomeUnknown = state {
                    Text("club.action.unknown")
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        recover()
                    } label: {
                        Label {
                            Text("club.admission.original.read", tableName: "ClubAdmissionRecovery")
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(working || !coordinator.canRecoverOriginal(clubID: clubID))
                    .accessibilityIdentifier("club.admission.original.read")
                    .accessibilityLabel(Text("club.admission.original.read", tableName: "ClubAdmissionRecovery"))
                    if !coordinator.canRecoverOriginal(clubID: clubID) {
                        Text("club.action.unavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if checked, case .acknowledged = state {
                    Label {
                        Text("club.admission.original.applied", tableName: "ClubAdmissionRecovery")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").accessibilityHidden(true)
                    }
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("club.admission.original.applied")
                }
                if working { ProgressView() }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, showsChrome(state) ? CYSpacing.md : CGFloat(0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if showsChrome(state) { Rectangle().fill(.bar).ignoresSafeArea(edges: .bottom) }
            }
            .onDisappear { revision &+= 1; task?.cancel(); task = nil; working = false }
            .onChange(of: checked) { _, now in
                if now, !reduceMotion { CYHaptics.success.play() }
            }
            .cyAnimation(value: checked)
            .cyAnimation(value: working)
        }
    }
    private func showsChrome(_ state: ClubActionState) -> Bool {
        if case .outcomeUnknown = state { return true }
        if working { return true }
        if checked, case .acknowledged = state { return true }
        return false
    }
    private func recover() {
        guard !working, coordinator.identity == identity,
              coordinator.canRecoverOriginal(clubID: clubID) else { return }
        revision &+= 1
        let generation = revision, snapshot = identity
        working = true
        task = Task {
            _ = await coordinator.recoverOriginal(clubID: clubID, expectedIdentity: snapshot)
            guard !Task.isCancelled, revision == generation, coordinator.identity == snapshot else { return }
            working = false; checked = true; revision &+= 1
        }
    }
}
