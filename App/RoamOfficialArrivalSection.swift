import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// ROAM-r11-1: the official event a player carried into the live roam (MP `pages/roam/index.js:920-921`,
/// `onLoad` reads `eventId` / `missionCode`). Set by the 去漫游 jumps before the tab switch; read by the live roam.
@MainActor final class RoamOfficialEventHandoff: ObservableObject {
    struct Target: Equatable {
        let eventID: Int
        let missionCode: String?
    }
    static let shared = RoamOfficialEventHandoff()
    @Published private(set) var target: Target?
    func hand(eventID: Int, missionCode: String?) {
        guard eventID > 0 else { return }
        target = Target(eventID: eventID, missionCode: missionCode?.isEmpty == true ? nil : missionCode)
    }
    /// MP `closeEventOverlay`: the overlay is dismissible and ordinary roaming continues unchanged.
    func clear() { target = nil }
}

/// The official reads/commands the live roam needs; nil keeps the roam free of any official overlay (fixtures).
struct RoamOfficialArrivalDeps {
    let reader: any OfficialEventReading
    let actions: OfficialActionCoordinator?
}

private struct RoamOfficialArrivalDepsKey: EnvironmentKey {
    static let defaultValue: RoamOfficialArrivalDeps? = nil
}

/// ROAM-r11-5: `POST /api/roam/presence-visibility` for (sessionId, visible); nil result = not confirmed.
private struct RoamPresenceVisibilityKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int?, Bool) async -> Bool?)? = nil
}

/// ROAM-r11-6: wipe this device's settled roam history; false = storage refused.
private struct RoamClearLocalKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Bool)? = nil
}

extension EnvironmentValues {
    var roamClearLocal: (@MainActor () -> Bool)? {
        get { self[RoamClearLocalKey.self] }
        set { self[RoamClearLocalKey.self] = newValue }
    }
    var roamPresenceVisibility: (@MainActor (Int?, Bool) async -> Bool?)? {
        get { self[RoamPresenceVisibilityKey.self] }
        set { self[RoamPresenceVisibilityKey.self] = newValue }
    }
    var roamOfficialArrival: RoamOfficialArrivalDeps? {
        get { self[RoamOfficialArrivalDepsKey.self] }
        set { self[RoamOfficialArrivalDepsKey.self] = newValue }
    }
}

/// ROAM-r11-1: MP 官方活动 · 到达验证 overlay (`pages/roam/index.wxml:335-349`, `verifyEventArrival` index.js:1927-1975).
/// A mission is verified only when the player taps it: the live session id and a fresh GCJ-02 fix become the
/// `OfficialArrivalEvidence`, sent through the existing reviewed `OfficialParticipationActions` sheet.
/// V1 roam-bound events keep the MP "漫游结束 → complete" projection (index.js:4878-4890).
@MainActor struct RoamOfficialArrivalSection: View {
    let deps: RoamOfficialArrivalDeps
    let target: RoamOfficialEventHandoff.Target
    let sessionID: Int?
    let fix: RoamDeviceFix?
    let finished: Bool
    let explored: Bool
    let onClose: () -> Void
    @State private var event: OfficialEvent?
    @State private var loadFailed = false
    /// MP `_eventArrivalRequests`: one request id per event:mission, reused on retry.
    @State private var requestIDs: [String: String] = [:]
    @State private var evidence: OfficialArrivalEvidence?
    @State private var feedback: LocalizedStringKey?
    @State private var v1Reported = false

    var body: some View {
        Section {
            content
        } header: {
            HStack {
                Text("roam.official.overlayTitle")
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("roam.official.close"))
                .accessibilityIdentifier("roam.official.close")
            }
        }
        .task(id: target) { await load() }
        .onChange(of: finished) { _, done in
            if done { Task { await reportV1() } }
        }
    }

    @ViewBuilder private var content: some View {
        if let event {
            Text(verbatim: event.title).font(.headline)
            if event.paused {
                if let reason = event.pausedReason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                    Text("roam.official.pausedReason \(reason)").foregroundStyle(CYColor.warningText)
                } else {
                    Text("roam.official.paused").foregroundStyle(CYColor.warningText)
                }
            } else if event.signed != true {
                Text("roam.official.signupFirst").foregroundStyle(.secondary)
            }
            ForEach(event.missions, id: \.code) { mission in
                missionRow(mission)
            }
            if let feedback {
                Text(feedback).font(.footnote).foregroundStyle(.secondary)
            }
            if let evidence, let actions = deps.actions {
                OfficialParticipationActions(coordinator: actions, event: event, arrival: evidence, onReturn: {
                    self.evidence = nil
                    Task { await load() }
                })
            }
        } else if loadFailed {
            Button("roam.official.retry") { Task { await load() } }
        } else {
            ProgressView("roam.official.loading")
                .accessibilityIdentifier("roam.official.loading")
        }
    }

    @ViewBuilder private func missionRow(_ mission: OfficialMission) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: mission.title)
                if let detail = mission.description, !detail.isEmpty {
                    Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if mission.complete == true {
                Label("roam.official.verified", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon).foregroundStyle(.green)
            } else if mission.canVerifyArrival == true {
                Button(sessionID == nil ? LocalizedStringKey("roam.official.needSession") : LocalizedStringKey("roam.official.verify")) {
                    verify(mission)
                }
                .buttonStyle(.bordered)
                .disabled(evidence != nil)
                .accessibilityIdentifier("roam.official.verify.\(mission.code)")
            } else {
                Text("roam.official.autoSync").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        loadFailed = false
        do { event = try await deps.reader.detail(id: target.eventID) }
        catch { if event == nil { loadFailed = true } }
    }

    /// MP `verifyEventArrival` guards, in the same order.
    private func verify(_ mission: OfficialMission) {
        guard let event else { return }
        if event.signed != true { feedback = "roam.official.feedback.signup"; return }
        if event.paused { feedback = "roam.official.feedback.paused"; return }
        if event.status != 3 { feedback = "roam.official.feedback.notLive"; return }
        guard let sessionID, sessionID > 0 else { feedback = "roam.official.feedback.session"; return }
        guard let fix, let projected = try? RuntimeLocationProjection.gcj02(fix) else {
            feedback = "roam.official.feedback.location"; return
        }
        guard let identity = deps.actions?.identity else { feedback = "roam.official.feedback.signup"; return }
        let key = "\(event.id):\(mission.code)"
        let requestID = requestIDs[key] ?? "arrival-\(key)-\(Int(Date().timeIntervalSince1970 * 1000))"
        requestIDs[key] = requestID
        feedback = nil
        evidence = OfficialArrivalEvidence(identity: identity, eventID: event.id, sessionID: sessionID,
                                           missionCode: mission.code, requestID: requestID,
                                           latitude: projected.coordinate.latitude, longitude: projected.coordinate.longitude,
                                           accuracyM: projected.accuracyMeters,
                                           expiresAt: projected.measuredAt.addingTimeInterval(30))
    }

    /// MP `_reportEvent`: V1 only, after something was explored; V2 never completes from the session end.
    private func reportV1() async {
        guard !v1Reported, explored, let actions = deps.actions, let event,
              !event.isV2, event.roamEnabled, event.signed == true, event.status == 3, !event.paused else { return }
        v1Reported = true
        do {
            let review = try await actions.prepare(.complete(event.id))
            _ = try await actions.confirm(review)
            feedback = "roam.official.feedback.v1Done"
        } catch {
            feedback = "roam.official.feedback.v1Failed"
        }
    }
}
