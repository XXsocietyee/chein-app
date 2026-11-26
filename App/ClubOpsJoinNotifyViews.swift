import SwiftUI

/// Mini pages/club/join-requests and pages/club/notify copy. Display only: every action stays the
/// existing review/claim flow and every retry is the existing read refresh.
struct ClubOpsJoinRequestActionLabel: View {
    let action: ClubManagementAction
    let progressKey: String?
    var body: some View {
        Group {
            if let progressKey {
                Text(LocalizedStringKey(progressKey), tableName: "ClubOpsJoinNotify")
                    .accessibilityIdentifier("clubOpsJoin.progress." + action.rawValue)
            } else {
                Text(LocalizedStringKey("club.management." + action.rawValue))
            }
        }
        .cyText(.label)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
    }
}

struct ClubOpsJoinRequestLoadIssue: View {
    let issue: ClubOpsJoinRequestCopy.LoadIssue
    /// CLB-join-requests-06 (fix-r3-club-b round 2): Core's classifier sentence, 网络连接失败 or 入会申请加载失败.
    var literalTitle: String? = nil
    let disabled: Bool
    let retry: () -> Void
    var body: some View {
        Group {
            if issue == .failed {
                ContentUnavailableView {
                    Label {
                        if let literalTitle { Text(verbatim: literalTitle) }
                        else { Text("clubOpsJoin.failed", tableName: "ClubOpsJoinNotify") }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } actions: {
                    retryButton
                }
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Label {
                        Text("clubOpsJoin.stale", tableName: "ClubOpsJoinNotify")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    retryButton
                }
            }
        }
        .accessibilityIdentifier(issue == .failed ? "clubOpsJoin.failed" : "clubOpsJoin.stale")
    }

    private var retryButton: some View {
        Button(action: retry) {
            Label {
                Text(LocalizedStringKey(issue == .failed ? "clubOpsJoin.retry" : "clubOpsJoin.retryStale"), tableName: "ClubOpsJoinNotify")
            } icon: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .accessibilityIdentifier(issue == .failed ? "clubOpsJoin.retry" : "clubOpsJoin.retryStale")
    }
}

/// Mini notify `no-permission` state: no retry, because repeating the read cannot grant access.
struct ClubOpsNotifyDeniedText: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("clubOpsNotify.denied.title", tableName: "ClubOpsJoinNotify")
            } icon: {
                Image(systemName: "lock")
            }
        } description: {
            Text("clubOpsNotify.denied.body", tableName: "ClubOpsJoinNotify")
        }
        .accessibilityIdentifier("clubOpsNotify.denied")
    }
}

/// Page-level failure title for notify / governance / roles reads; the retry is the read view's own `load()`.
struct ClubOpsPageFailureSection: View {
    let copy: ClubOpsPageFailureCopy
    /// X3 (parity r2): the one reason line under the page title (server sentence or generic key).
    var reason: Text? = nil
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            ContentUnavailableView {
                Label {
                    if let literal = copy.literalTitle {
                        Text(verbatim: literal)
                            .accessibilityIdentifier("clubOps.pageFailure.title")
                    } else {
                        Text(LocalizedStringKey(copy.titleKey), tableName: copy.table)
                            .accessibilityIdentifier("clubOps.pageFailure.title")
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                if let reason {
                    reason
                        .accessibilityIdentifier("club.gov.error")
                }
            } actions: {
                if copy.prefersBack {
                    Button { dismiss() } label: { Text(verbatim: locale.pick("返回", "Back")) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clubOps.pageFailure.back")
                } else {
                    Button(action: retry) {
                        Label {
                            Text(LocalizedStringKey(copy.retryKey), tableName: copy.table)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("clubOps.pageFailure.retry")
                }
            }
        }
    }
}

#if DEBUG
/// Offline-only switches for the club-ops states (no network, no account). Each one only edits the synthetic access.
@MainActor struct ClubOpsFixtureControls: View {
    let access: ClubGovernanceFixtureAccess
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            fixture("Fixture: next write returns 409", id: "clubOps.fixture.conflict") { access.writeFailure = .conflict(message: nil) }
            fixture("Fixture: no notify permission", id: "clubOps.fixture.notifyDenied") {
                access.permissionValue = Self.permissions(removing: ["club:notify:send", "club:event:operate"])
            }
            fixture("Fixture: reads fail", id: "clubOps.fixture.readFailure") { access.readFailure = .malformed }
            fixture("Fixture: banned viewer appeals", id: "clubOps.fixture.bannedAppeal") {
                access.permissionValue = ClubGovernanceFixtures.json(#"{"active":false,"club":{"id":81},"roleCodes":[],"permissions":[]}"#)
                access.overrideValue[.cases] = ClubGovernanceFixtures.json(#"{"data":[{"id":172,"clubId":81,"caseType":"APPEAL","targetType":"BAN","targetId":161,"status":"PENDING","version":0,"reason":"Fixture appeal"}],"activeBan":{"id":161,"clubId":81,"status":"ACTIVE","sourceType":"CLUB","banReason":"Fixture reason","bannedAt":"2026-10-01 09:00:00","expiresAt":"2026-10-31 09:00:00"}}"#)
            }
            fixture("Fixture: reset club-ops states", id: "clubOps.fixture.reset") {
                access.permissionValue = ClubGovernanceFixtures.permissions; access.overrideValue[.cases] = nil
                access.readFailure = nil; access.writeFailure = nil
            }
        }
        .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
    }
    private func fixture(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(verbatim: title).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(id)
    }
    static func permissions(removing removed: Set<String>) -> ClubGovernanceValue {
        guard var object = ClubGovernanceFixtures.permissions.object else { return ClubGovernanceFixtures.permissions }
        object["permissions"] = .array((object["permissions"]?.array ?? []).filter { !removed.contains($0.string ?? "") })
        return .object(object)
    }
}
#endif
