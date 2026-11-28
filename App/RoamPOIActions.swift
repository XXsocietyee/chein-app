import SwiftUI
import CoreLocation

/// Live POI writes (mini-program scene-roam-poi-detail: toggleFavorite / completeNode), injected by the session.
/// nil in the environment hides the controls, e.g. for signed-out or preview hosts.
struct RoamPOIActions {
    var toggleFavorite: @MainActor (Int) async throws -> Bool
    /// RPOI-1: `POST api/city/nodes/{id}/complete` with the evidence the node's validationMethod asks for.
    var complete: @MainActor (Int, RoamPOICheckInEvidence) async throws -> RoamNodeCompletion
}

/// Body fields of the MP `completeNode(answer, photoUrl, code)`; empty strings when a method does not use them.
struct RoamPOICheckInEvidence: Equatable {
    var answer = ""
    var photoURL = ""
    var code = ""
    static let none = RoamPOICheckInEvidence()
}

private struct RoamPOIActionsKey: EnvironmentKey { static let defaultValue: RoamPOIActions? = nil }
extension EnvironmentValues {
    var roamPOIActions: RoamPOIActions? {
        get { self[RoamPOIActionsKey.self] }
        set { self[RoamPOIActionsKey.self] = newValue }
    }
}

enum RoamDeviceFixGCJ {
    /// Location already allowed (no prompt would appear); callers may locate on open.
    @MainActor static var isAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(CLLocationManager().authorizationStatus)
    }
    /// One foreground fix through the standard iOS permission flow, converted to GCJ-02 exactly once (backend datum).
    @MainActor static func currentGCJ02Fix(provider: any RoamDeviceLocationProviding) async throws -> RoamDeviceFix {
        let raw: RoamDeviceFix
        do { raw = try await provider.currentFix() }
        catch is CancellationError { throw CancellationError() }
        catch {
            if let denied = error as? CLError, denied.code == .denied { throw RoamActionFailure.locationDenied }
            if CLLocationManager().authorizationStatus == .denied || CLLocationManager().authorizationStatus == .restricted { throw RoamActionFailure.locationDenied }
            throw RoamActionFailure.locationUnavailable
        }
        guard raw.datum == .wgs84 else { return raw }
        let center = try RuntimeLocationProjection.gcj02MapCenter(.init(coordinate: raw.coordinate, datum: .wgs84))
        return try RoamDeviceFix(coordinate: center.coordinate, accuracyMeters: raw.accuracyMeters, measuredAt: raw.measuredAt, datum: .gcj02)
    }
}

/// State for one POI detail: favorite toggle and check-in with loading / success / error-retry, double-tap safe.
@MainActor final class RoamPOIActionModel: ObservableObject {
    enum Phase: Equatable { case idle, working, failed(Failure) }
    enum Failure: Equatable { case locationDenied, locationUnavailable, rejected(String), network, signIn }
    @Published var favoriteOverride: Bool?
    @Published var completedOverride: Bool?
    @Published var needRedeemOverride: Bool?
    @Published private(set) var favoritePhase: Phase = .idle
    @Published private(set) var checkInPhase: Phase = .idle
    @Published private(set) var checkInSuccess: RoamNodeCompletion?
    /// Retry resends the same answer / photo / code instead of asking again.
    private(set) var lastEvidence = RoamPOICheckInEvidence.none
    /// RPOI-3: the signed-in owner. Empty skips the journal so a check-in with no account still reports the location failure.
    var ownerID: String?
    @Published private(set) var pending: RoamPendingCheckInRecord?
    /// MP 本地存储异常: the journal could not be read or written, so no check-in is sent.
    @Published private(set) var storageFailed = false
    /// MP toast 已确认当前已完成 / 已确认当前待核销 after a read settled the attempt; the value is `needRedeem`.
    @Published private(set) var pendingRecovered: Bool?
    /// MP `pendingStatusText` after a node read that left the attempt open: true = 尚未显示完成或待核销.
    @Published private(set) var pendingNotShown: Bool?
    private let journal = RoamPendingCheckInDefaults()
    private var nextReverify = false
    private var token = 0

    func reset() {
        favoriteOverride = nil; completedOverride = nil; needRedeemOverride = nil
        favoritePhase = .idle; checkInPhase = .idle; checkInSuccess = nil; pending = nil; nextReverify = false; token += 1
        storageFailed = false; pendingRecovered = nil; pendingNotShown = nil
    }

    func adopt(ownerID: String?, poiID: Int) {
        self.ownerID = ownerID.flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
        storageFailed = false
        refreshPending(poiID: poiID)
    }

    func armReverify() { nextReverify = true }
    func disarmReverify() { nextReverify = false }

    func refreshPending(poiID: Int) { pending = stored(poiID: poiID) }

    /// 查询当前状态 (MP `_load` with a pending record): a read whose completed / needRedeem disagree settles the
    /// attempt (已确认当前已完成 / 待核销); otherwise the record stays with the MP status line.
    func noteReloaded(poiID: Int, completed: Bool, needRedeem: Bool = false) {
        pendingRecovered = nil; pendingNotShown = nil
        if let record = stored(poiID: poiID), record.poiID == String(poiID), let slot = slot(poiID: poiID) {
            if completed != needRedeem {
                do {
                    _ = try RoamPendingCheckInJournal.clear(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID, attemptID: record.attemptID)
                    pendingRecovered = needRedeem
                } catch { storageFailed = true }
            } else {
                pendingNotShown = !completed && !needRedeem
            }
        }
        refreshPending(poiID: poiID)
    }

    func toggleFavorite(poiID: Int, current: Bool, actions: RoamPOIActions) {
        guard favoritePhase != .working else { return }
        favoritePhase = .working
        let mine = token
        Task {
            do {
                let value = try await actions.toggleFavorite(poiID)
                guard mine == token else { return }
                favoriteOverride = value; favoritePhase = .idle
            } catch is CancellationError { if mine == token { favoritePhase = .idle } }
            catch { if mine == token { favoritePhase = .failed(Self.map(error)) } }
        }
    }

    func checkIn(poiID: Int, evidence: RoamPOICheckInEvidence = .none, actions: RoamPOIActions, reverify: Bool = false) {
        guard checkInPhase != .working else { return }
        let again = reverify || nextReverify
        nextReverify = false
        checkInPhase = .working; checkInSuccess = nil; lastEvidence = evidence
        let mine = token
        let opened = openAttempt(poiID: poiID, reverify: again)
        if case .blocked = opened {
            guard mine == token else { return }
            refreshPending(poiID: poiID)
            checkInPhase = .idle
            return
        }
        Task {
            do {
                let receipt = try await actions.complete(poiID, evidence)
                guard mine == token else { return }
                applyReceipt(opened, poiID: poiID, receipt: receipt)
                completedOverride = !receipt.needRedeem; needRedeemOverride = receipt.needRedeem
                checkInSuccess = receipt; checkInPhase = .idle
            } catch is CancellationError {
                if mine == token { rollbackFresh(opened, poiID: poiID); checkInPhase = .idle }
            } catch {
                if mine == token {
                    let failure = Self.map(error)
                    applyFailure(opened, poiID: poiID, failure: failure)
                    checkInPhase = .failed(failure)
                }
            }
        }
    }

    private struct Slot { let ownerID: String; let poiID: String; let key: String }
    private enum Opened { case skipped, blocked, begun(Slot, attemptID: String, unknownBefore: Bool, fresh: Bool) }

    private func slot(poiID: Int) -> Slot? {
        guard let ownerID else { return nil }
        let poi = String(poiID)
        guard let key = RoamPendingCheckInJournal.storageKey(ownerID: ownerID, poiID: poi) else { return nil }
        return Slot(ownerID: ownerID, poiID: poi, key: key)
    }

    private func stored(poiID: Int) -> RoamPendingCheckInRecord? {
        guard let slot = slot(poiID: poiID) else { return nil }
        do { return try RoamPendingCheckInJournal.read(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID) }
        catch { storageFailed = true; return nil }
    }

    /// A fresh begin needs an empty slot. Re-verify reuses the same attempt. No owner means no journal.
    private func openAttempt(poiID: Int, reverify: Bool) -> Opened {
        guard let slot = slot(poiID: poiID) else { return .skipped }
        let existing: RoamPendingCheckInRecord?
        do { existing = try RoamPendingCheckInJournal.read(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID) }
        catch { storageFailed = true; return .blocked }
        let attemptID: String
        if reverify {
            guard let existing else { return .blocked }
            attemptID = existing.attemptID
        } else if existing != nil {
            return .blocked
        } else {
            attemptID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let unknownBefore = reverify || existing?.uncertain == true
        do {
            _ = try RoamPendingCheckInJournal.begin(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID,
                                                    attemptID: attemptID, reverify: reverify)
        } catch { storageFailed = true; return .blocked }
        storageFailed = false; pendingRecovered = nil
        return .begun(slot, attemptID: attemptID, unknownBefore: unknownBefore, fresh: !reverify)
    }

    private func applyReceipt(_ opened: Opened, poiID: Int, receipt: RoamNodeCompletion) {
        guard case .begun(let slot, let attemptID, let unknownBefore, _) = opened else { return }
        var data: [String: Any] = [
            "needRedeem": receipt.needRedeem,
            "alreadyClaimed": receipt.alreadyClaimed,
            "completed": !receipt.needRedeem
        ]
        if let id = receipt.poiID { data["poiId"] = id }
        let accepted = RoamPendingCheckInJournal.receiptAccepted(code: "200", poiID: slot.poiID, data: data)
        apply(opened, code: "200", message: nil, accepted: accepted, unknownBefore: unknownBefore, attemptID: attemptID, slot: slot, poiID: poiID)
    }

    /// Location and sign-in fail before the POST, so a fresh begin is removed. A sent failure is classified by `step`.
    private func applyFailure(_ opened: Opened, poiID: Int, failure: Failure) {
        switch failure {
        case .locationDenied, .locationUnavailable, .signIn:
            rollbackFresh(opened, poiID: poiID)
        case .rejected(let message):
            guard case .begun(let slot, let attemptID, let unknownBefore, _) = opened else { return }
            apply(opened, code: "500", message: message, accepted: false, unknownBefore: unknownBefore, attemptID: attemptID, slot: slot, poiID: poiID)
        case .network:
            guard case .begun(let slot, let attemptID, let unknownBefore, _) = opened else { return }
            apply(opened, code: "fail", message: nil, accepted: false, unknownBefore: unknownBefore, attemptID: attemptID, slot: slot, poiID: poiID)
        }
    }

    private func apply(_ opened: Opened, code: String, message: String?, accepted: Bool, unknownBefore: Bool,
                       attemptID: String, slot: Slot, poiID: Int) {
        _ = opened
        let decision = RoamPendingCheckInJournal.step(code: code, message: message, receiptAccepted: accepted, unknownBefore: unknownBefore)
        switch decision {
        case .clear:
            _ = try? RoamPendingCheckInJournal.clear(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID, attemptID: attemptID)
        case .keepPreviousUnknown:
            break
        case .unknown:
            _ = try? RoamPendingCheckInJournal.markUncertain(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID)
        }
        refreshPending(poiID: poiID)
    }

    private func rollbackFresh(_ opened: Opened, poiID: Int) {
        guard case .begun(let slot, let attemptID, _, let fresh) = opened, fresh else {
            refreshPending(poiID: poiID)
            return
        }
        _ = try? RoamPendingCheckInJournal.clear(journal, key: slot.key, ownerID: slot.ownerID, poiID: slot.poiID, attemptID: attemptID)
        refreshPending(poiID: poiID)
    }

    static func map(_ error: Error) -> Failure {
        switch error {
        case RoamActionFailure.locationDenied: return .locationDenied
        case RoamActionFailure.locationUnavailable: return .locationUnavailable
        case RoamActionFailure.rejected(let message): return .rejected(message)
        case APIError.unauthorized: return .signIn
        default: return .network
        }
    }
}

/// Favorite + check-in controls for the 你的状态 section.
struct RoamPOIActionRows: View {
    let node: RoamNodeDetail
    let actions: RoamPOIActions
    @ObservedObject var model: RoamPOIActionModel
    var ownerID: String? = nil
    var onReload: () -> Void = {}
    @Environment(\.openURL) private var openURL
    @Environment(\.challengePOIPhotoUploader) private var makePhotoUploader
    @Environment(\.locale) private var locale
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.dismiss) private var dismiss
    @State private var answerPrompt = false
    @State private var answerText = ""
    @State private var choiceSheet = false
    @State private var photoSheet = false
    @State private var scanSheet = false
    /// MP `challengePhoto`: a photoRequired node shoots first, then continues with its method.
    @State private var challengePhoto = ""

    private var favorited: Bool { model.favoriteOverride ?? node.favorited }
    private var completed: Bool { model.completedOverride ?? node.completed }
    private var needRedeem: Bool { model.needRedeemOverride ?? node.needRedeem }

    var body: some View {
        Group {
            Button { model.toggleFavorite(poiID: node.poiId, current: favorited, actions: actions) } label: {
            HStack {
                Label(LocalizedStringKey(favorited ? "roam.poi.action.unfavorite" : "roam.poi.action.favorite"),
                      systemImage: favorited ? "heart.fill" : "heart")
                if model.favoritePhase == .working { Spacer(); ProgressView() }
            }.frame(minHeight: 44)
        }
        .disabled(model.favoritePhase == .working)
        .accessibilityIdentifier("roam.poi.favorite")
        if case .failed(let failure) = model.favoritePhase {
            // mp-states r3: MP scene-roam-poi-detail.wxml:46 cy-error 收藏状态没有更新 · sub · 重试.
            failureRow(failure, title: "roam.poi.favorite.failed", retry: { model.toggleFavorite(poiID: node.poiId, current: favorited, actions: actions) })
        }
        // RPOI-3: while an attempt is pending (or storage is broken) the MP only offers 查询 / 重新现场核验.
        if (model.pending != nil || model.storageFailed) && !completed { pendingRows }
        if node.isPublished && !completed && model.pending == nil && !model.storageFailed {
            Button { startCheckIn() } label: {
                HStack {
                    Label(LocalizedStringKey(needRedeem ? "roam.poi.action.checkIn.redeem" : "roam.poi.action.checkIn"), systemImage: "mappin.and.ellipse")
                    if model.checkInPhase == .working { Spacer(); ProgressView() }
                }.frame(minHeight: 44)
            }
            .disabled(model.checkInPhase == .working || needRedeem)
            .accessibilityIdentifier("roam.poi.checkin")
            Text("roam.poi.checkIn.footer").cyText(.bodyCompact).foregroundStyle(.secondary)
        }
        if let redeem = model.pendingRecovered {
            Label(LocalizedStringKey(redeem ? "roam.poi.pending.recoveredRedeem" : "roam.poi.pending.recoveredDone"), systemImage: "checkmark.seal.fill")
                .foregroundStyle(CYColor.successText).accessibilityIdentifier("roam.poi.pending.recovered")
        }
        if case .failed(let failure) = model.checkInPhase {
            failureRow(failure, retry: { model.checkIn(poiID: node.poiId, evidence: model.lastEvidence, actions: actions) })
        }
        if let receipt = model.checkInSuccess {
            Label(LocalizedStringKey(receipt.needRedeem ? "roam.poi.checkIn.needRedeem" : (receipt.alreadyClaimed ? "roam.poi.checkIn.already" : "roam.poi.checkIn.success")),
                  systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                .accessibilityIdentifier("roam.poi.checkin.success")
        }
        }
        .alert("roam.poi.answer.title", isPresented: $answerPrompt) {
            TextField("roam.poi.answer.placeholder", text: $answerText)
            Button("action.cancel", role: .cancel) { model.disarmReverify() }
            Button("roam.poi.answer.submit") { submit(.init(answer: answerText, photoURL: challengePhoto)) }
        }
        // N-RPOI (r10): the quiz choice is a system confirmation dialog (MP subpackageRoam/poi-detail action sheet).
        .confirmationDialog(Text(verbatim: node.questionName ?? appLocalized("roam.poi.answer.title", locale: locale)),
                            isPresented: $choiceSheet, titleVisibility: .visible) {
            ForEach(node.quizOptions, id: \.id) { option in
                Button { submit(.init(answer: option.id, photoURL: challengePhoto)) } label: {
                    Text(verbatim: option.id + ". " + option.text)
                }
            }
            Button("action.cancel", role: .cancel) { model.disarmReverify() }
        }
        .cySheet(isPresented: $photoSheet) { Group {
            NavigationStack {
                ScrollView {
                    ChallengePOIPhotoCapture(lead: node.photoRequireDesc, uploader: makePhotoUploader?(node.poiId), confirmed: false) { url in
                        photoSheet = false; challengePhoto = url
                        if node.validationMethod == 2 { submit(.init(photoURL: url)) } else { startCheckIn() }
                    }
                    .padding(CYSpacing.pageHorizontal)
                }
                .cyPageTitle("roam.poi.photo.title")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { photoSheet = false; model.disarmReverify() } } }
            }
        }.cySheet(detents: [.large]) }
        .cyFullScreenCover(isPresented: $scanSheet) {
            NativeQRScanner { code in scanSheet = false; submit(.init(photoURL: challengePhoto, code: code)) }
        }
        .cyHapticEvent(.checkInSuccess, trigger: model.checkInSuccess != nil) { old, new in !old && new }
        .cyHapticEvent(.wrongAnswer, trigger: model.checkInPhase) { _, next in
            if case .failed = next { return true }
            return false
        }
        .onAppear { model.adopt(ownerID: ownerID, poiID: node.poiId) }
        .onChange(of: ownerID) { _, value in model.adopt(ownerID: value, poiID: node.poiId) }
    }

    /// RPOI-1: route the check-in by `validationMethod`, as scene-roam-poi-detail `startInteraction` does:
    /// photoRequired shoots first; 1 answer / 暗号, 3 A–D choice (sends the letter), 2 photo, 4 QR code, else plain.
    private func startCheckIn() {
        guard model.checkInPhase != .working else { return }
        if node.photoRequired && challengePhoto.isEmpty { photoSheet = true; return }
        switch node.validationMethod {
        case 1: answerText = ""; answerPrompt = true
        case 3 where !node.quizOptions.isEmpty: choiceSheet = true
        case 2: if challengePhoto.isEmpty { photoSheet = true } else { submit(.init(photoURL: challengePhoto)) }
        case 4: scanSheet = true
        default: submit(.init(photoURL: challengePhoto))
        }
    }
    private func submit(_ evidence: RoamPOICheckInEvidence) {
        model.checkIn(poiID: node.poiId, evidence: evidence, actions: actions)
    }

    /// RPOI-3 pending card: MP 打卡结果待确认 / 本地存储异常, the status line from the last read, 查询当前状态 and 重新现场核验.
    @ViewBuilder private var pendingRows: some View {
        let storage = model.storageFailed
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Label(LocalizedStringKey(storage ? "roam.poi.pending.storageTitle" : "roam.poi.pending.title"), systemImage: "clock.badge.questionmark")
                .cyText(.bodyMedium)
            Text(LocalizedStringKey(storage ? "roam.poi.pending.storageMessage" : "roam.poi.pending.message")).cyText(.bodyCompact).foregroundStyle(.secondary)
            if !storage, let notShown = model.pendingNotShown {
                Text(LocalizedStringKey(notShown ? "roam.poi.pending.notShown" : "roam.poi.pending.unresolved")).cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier("roam.poi.pending")
        Button("roam.poi.pending.query") { onReload() }
            .frame(minHeight: 44)
            .accessibilityIdentifier("roam.poi.pending.query")
        if !storage && node.isPublished {
            Button("roam.poi.pending.reverify") { model.armReverify(); startCheckIn() }
                .frame(minHeight: 44)
                .disabled(model.checkInPhase == .working)
                .accessibilityIdentifier("roam.poi.pending.reverify")
        }
    }

    @ViewBuilder private func failureRow(_ failure: RoamPOIActionModel.Failure, title: LocalizedStringKey? = nil, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch failure {
            case .locationDenied:
                Label("roam.poi.location.denied.title", systemImage: "location.slash").cyText(.bodyMedium)
                Text("roam.poi.location.denied.message").cyText(.bodyCompact).foregroundStyle(.secondary)
                Button("roam.poi.location.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.frame(minHeight: 44)
            case .locationUnavailable:
                Label("roam.poi.location.unavailable", systemImage: "location.slash").cyText(.body)
                Button("action.retry", action: retry).frame(minHeight: 44)
            case .rejected(let message):
                if let title {
                    Label { Text(title) } icon: { Image(systemName: "exclamationmark.triangle") }.cyText(.bodyMedium)
                    Text(verbatim: message).cyText(.bodyCompact).foregroundStyle(.secondary)
                } else {
                    Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }.cyText(.bodyCompact)
                }
                Button("action.retry", action: retry).frame(minHeight: 44)
            case .signIn:
                Label("roam.poi.signIn", systemImage: "person.crop.circle.badge.exclamationmark").cyText(.body)
                // poi-detail #20: 登录 closes the place sheet, then opens 我的 (only where the root tab switch exists).
                if rootTabSwitch.isAvailable {
                    Button("auth.signIn") { dismiss(); rootTabSwitch(.mine) }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("roam.poi.signIn.action")
                }
            case .network:
                if let title {
                    Label { Text(title) } icon: { Image(systemName: "wifi.exclamationmark") }.cyText(.bodyMedium)
                    Text("roam.poi.action.failed").cyText(.bodyCompact).foregroundStyle(.secondary)
                } else {
                    Label("roam.poi.action.failed", systemImage: "wifi.exclamationmark").cyText(.body)
                }
                Button("action.retry", action: retry).frame(minHeight: 44)
            }
        }
        .accessibilityIdentifier("roam.poi.action.error")
    }
}

/// UserDefaults behind `RoamPendingCheckInJournal`. The `:photo` sibling is never written here.
final class RoamPendingCheckInDefaults: RoamPendingCheckInStoring {
    func data(forKey key: String) -> Data? { UserDefaults.standard.data(forKey: key) }
    func set(_ data: Data?, forKey key: String) { UserDefaults.standard.set(data, forKey: key) }
}
