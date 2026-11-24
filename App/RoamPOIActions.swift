import SwiftUI
import CoreLocation

/// Live POI writes (mini-program scene-roam-poi-detail: toggleFavorite / completeNode), injected by the session.
/// nil in the environment hides the controls, e.g. for signed-out or preview hosts.
struct RoamPOIActions {
    var toggleFavorite: @MainActor (Int) async throws -> Bool
    /// RPOI-1: `POST api/city/nodes/{id}/complete` with the evidence the node's validationMethod asks for.
    var complete: @MainActor (Int, RoamPOICheckInEvidence) async throws -> RoamNodeCompletion
    /// RPOI-3: signed-in member id and the device store for the MP `cy_roam_poi_checkin_pending:v1` journal.
    /// nil skips the journal (previews, fixtures).
    var ownerID: String? = nil
    var pendingStore: (any RoamPendingCheckInStoring)? = nil
}

/// RPOI-3: the MP keeps the pending check-in record in wx storage; the app keeps the same record in UserDefaults.
/// The record holds only version, owner, poi and attempt ids (no coordinates, answers, photos or scan text).
final class RoamPendingCheckInDefaults: RoamPendingCheckInStoring, @unchecked Sendable {
    static let shared = RoamPendingCheckInDefaults()
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ data: Data?, forKey key: String) {
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
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
    /// RPOI-3 (MP `checkinPending`): an earlier complete POST whose result is not known yet.
    enum Pending: Equatable { case none, uncertain, storageError }
    /// MP `pendingStatusText` after a node read that did not settle the pending attempt.
    enum PendingStatus: Equatable { case notShown, unresolved }
    @Published private(set) var pending: Pending = .none
    @Published private(set) var pendingStatus: PendingStatus?
    /// MP `reverifyReady`: the fresh node read allows a new on-site check under the same attempt id.
    @Published private(set) var reverifyReady = false
    /// MP toast 已确认当前已完成 / 已确认当前待核销 after a read settled the pending attempt; the value is `needRedeem`.
    @Published private(set) var pendingRecovered: Bool?
    private var reverifyAttempt: String?
    private var reverifyRequested = false
    /// Retry resends the same answer / photo / code instead of asking again.
    private(set) var lastEvidence = RoamPOICheckInEvidence.none
    private var token = 0

    func reset() {
        favoriteOverride = nil; completedOverride = nil; needRedeemOverride = nil; favoritePhase = .idle; checkInPhase = .idle; checkInSuccess = nil; token += 1
        pending = .none; pendingStatus = nil; reverifyReady = false; reverifyAttempt = nil; reverifyRequested = false; pendingRecovered = nil
    }

    private struct JournalContext { let store: any RoamPendingCheckInStoring; let key: String; let owner: String; let poi: String }
    private func journal(_ poiID: Int, _ actions: RoamPOIActions) -> JournalContext? {
        guard let store = actions.pendingStore, let owner = actions.ownerID,
              let key = RoamPendingCheckInJournal.storageKey(ownerID: owner, poiID: String(poiID)) else { return nil }
        return JournalContext(store: store, key: key, owner: owner, poi: String(poiID))
    }

    /// MP `_load` with a pending record: a node read whose completed / needRedeem disagree settles it;
    /// otherwise the record is kept (marked uncertain) and, after 重新现场核验, a new on-site check is offered.
    func restore(node: RoamNodeDetail, actions: RoamPOIActions) {
        let wantsReverify = reverifyRequested
        reverifyRequested = false; reverifyAttempt = nil; reverifyReady = false; pendingStatus = nil
        guard let context = journal(node.poiId, actions) else { pending = .none; return }
        let record: RoamPendingCheckInRecord?
        do { record = try RoamPendingCheckInJournal.read(context.store, key: context.key, ownerID: context.owner, poiID: context.poi) }
        catch { pending = .storageError; return }
        guard let record else { pending = .none; return }
        if node.completed != node.needRedeem {
            do {
                if try RoamPendingCheckInJournal.clear(context.store, key: context.key, ownerID: context.owner, poiID: context.poi, attemptID: record.attemptID) {
                    pending = .none; pendingRecovered = node.needRedeem
                    completedOverride = node.completed; needRedeemOverride = node.needRedeem
                }
            } catch { pending = .storageError }
            return
        }
        do { _ = try RoamPendingCheckInJournal.markUncertain(context.store, key: context.key, ownerID: context.owner, poiID: context.poi) }
        catch { pending = .storageError; return }
        pending = .uncertain
        pendingStatus = !node.completed && !node.needRedeem ? .notShown : .unresolved
        if wantsReverify, !node.completed, !node.needRedeem, node.isPublished, node.canInteract != false {
            // A new check uses only this visit's photo and input: drop the old photo sibling.
            context.store.set(nil, forKey: RoamPendingCheckInJournal.photoKey(context.key))
            reverifyAttempt = record.attemptID; reverifyReady = true
        }
    }

    /// MP `reverifyOnSite`: the next node read may offer a new on-site check.
    func requestReverify() { reverifyRequested = true }

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

    func checkIn(poiID: Int, evidence: RoamPOICheckInEvidence = .none, actions: RoamPOIActions) {
        guard checkInPhase != .working else { return }
        // RPOI-3: the MP writes the pending record before the POST; a pending attempt only continues as a re-verify.
        var attempt = UUID().uuidString
        var reverify = false
        if pending != .none {
            guard pending == .uncertain, reverifyReady, let current = reverifyAttempt else { return }
            attempt = current; reverify = true
        }
        let context = journal(poiID, actions)
        if let context {
            do { _ = try RoamPendingCheckInJournal.begin(context.store, key: context.key, ownerID: context.owner, poiID: context.poi, attemptID: attempt, reverify: reverify) }
            catch { pending = .storageError; reverifyReady = false; return }
        }
        reverifyReady = false; pendingRecovered = nil
        checkInPhase = .working; checkInSuccess = nil; lastEvidence = evidence
        let mine = token
        Task {
            do {
                let receipt = try await actions.complete(poiID, evidence)
                if let context {
                    do { _ = try RoamPendingCheckInJournal.clear(context.store, key: context.key, ownerID: context.owner, poiID: context.poi, attemptID: attempt) }
                    catch { if mine == token { pending = .storageError } }
                }
                guard mine == token else { return }
                if pending != .storageError { pending = .none; pendingStatus = nil }
                completedOverride = !receipt.needRedeem; needRedeemOverride = receipt.needRedeem
                checkInSuccess = receipt; checkInPhase = .idle
            } catch {
                guard let context else {
                    if mine == token { checkInPhase = error is CancellationError ? .idle : .failed(Self.map(error)) }
                    return
                }
                switch Self.journalStep(error, unknownBefore: reverify) {
                case .clear:
                    do { _ = try RoamPendingCheckInJournal.clear(context.store, key: context.key, ownerID: context.owner, poiID: context.poi, attemptID: attempt) }
                    catch { if mine == token { pending = .storageError } }
                    guard mine == token else { return }
                    if pending != .storageError { pending = .none }
                    checkInPhase = .failed(Self.map(error))
                case .keepPreviousUnknown:
                    guard mine == token else { return }
                    pending = .uncertain; checkInPhase = .failed(Self.map(error))
                case .unknown:
                    let saved = (try? RoamPendingCheckInJournal.markUncertain(context.store, key: context.key, ownerID: context.owner, poiID: context.poi)) != nil
                    guard mine == token else { return }
                    pending = saved ? .uncertain : .storageError; pendingStatus = nil; checkInPhase = .idle
                }
            }
        }
    }

    /// MP `complete` callbacks: a known pre-write rejection clears the record (or keeps an earlier unknown one);
    /// a lost or unreadable answer leaves the attempt unknown. Location failures happen before the POST.
    static func journalStep(_ error: Error, unknownBefore: Bool) -> RoamPendingCompleteStep {
        switch error {
        case RoamActionFailure.rejected(let message):
            return RoamPendingCheckInJournal.step(code: "500", message: message, receiptAccepted: false, unknownBefore: unknownBefore)
        case APIError.unauthorized:
            return RoamPendingCheckInJournal.step(code: "500", message: "请先登录", receiptAccepted: false, unknownBefore: unknownBefore)
        case RoamActionFailure.locationDenied, RoamActionFailure.locationUnavailable:
            return unknownBefore ? .keepPreviousUnknown(message: "") : .clear
        default:
            return .unknown
        }
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
    /// RPOI-3 查询当前状态 / 重新现场核验: re-read the node (the detail screen's load).
    var reload: () -> Void = {}
    @Environment(\.openURL) private var openURL
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.dismiss) private var dismiss
    @Environment(\.challengePOIPhotoUploader) private var makePhotoUploader
    @Environment(\.locale) private var locale
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
            failureRow(failure, retry: { model.toggleFavorite(poiID: node.poiId, current: favorited, actions: actions) })
        }
        if model.pending != .none, !completed { pendingRows }
        if node.isPublished && !completed && (model.pending == .none || model.reverifyReady) {
            Button { startCheckIn() } label: {
                HStack {
                    Label(LocalizedStringKey(model.reverifyReady ? "roam.poi.pending.startReverify" : (needRedeem ? "roam.poi.action.checkIn.redeem" : "roam.poi.action.checkIn")), systemImage: "mappin.and.ellipse")
                    if model.checkInPhase == .working { Spacer(); ProgressView() }
                }.frame(minHeight: 44)
            }
            .disabled(model.checkInPhase == .working || needRedeem)
            .accessibilityIdentifier("roam.poi.checkin")
            Text("roam.poi.checkIn.footer").cyText(.bodyCompact).foregroundStyle(.secondary)
        }
        if case .failed(let failure) = model.checkInPhase {
            failureRow(failure, retry: { model.checkIn(poiID: node.poiId, evidence: model.lastEvidence, actions: actions) })
        }
        if let receipt = model.checkInSuccess {
            Label(LocalizedStringKey(receipt.needRedeem ? "roam.poi.checkIn.needRedeem" : (receipt.alreadyClaimed ? "roam.poi.checkIn.already" : "roam.poi.checkIn.success")),
                  systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                .accessibilityIdentifier("roam.poi.checkin.success")
        }
        if let redeem = model.pendingRecovered {
            Label(LocalizedStringKey(redeem ? "roam.poi.pending.recoveredRedeem" : "roam.poi.pending.recoveredDone"), systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green).accessibilityIdentifier("roam.poi.pending.recovered")
        }
        }
        .onAppear { model.restore(node: node, actions: actions) }
        .alert("roam.poi.answer.title", isPresented: $answerPrompt) {
            TextField("roam.poi.answer.placeholder", text: $answerText)
            Button("action.cancel", role: .cancel) {}
            Button("roam.poi.answer.submit") { submit(.init(answer: answerText, photoURL: challengePhoto)) }
        }
        .sheet(isPresented: $choiceSheet) {
            CYOptionSheet(title: node.questionName ?? appLocalized("roam.poi.answer.title", locale: locale),
                          items: node.quizOptions.map { CYOptionSheetItem(id: $0.id, title: $0.id + ". " + $0.text) },
                          selectedID: nil,
                          onSelect: { id in choiceSheet = false; submit(.init(answer: id, photoURL: challengePhoto)) },
                          onClose: { choiceSheet = false })
                .cyDomainSheet(detents: [.half])
        }
        .sheet(isPresented: $photoSheet) { Group {
            NavigationStack {
                ScrollView {
                    ChallengePOIPhotoCapture(lead: node.photoRequireDesc, uploader: makePhotoUploader?(node.poiId), confirmed: false) { url in
                        photoSheet = false; challengePhoto = url
                        if node.validationMethod == 2 { submit(.init(photoURL: url)) } else { startCheckIn() }
                    }
                    .padding(CYSpacing.pageHorizontal)
                }
                .cyPageTitle("roam.poi.photo.title")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { photoSheet = false } } }
            }
        }.cySheet(detents: [.large]) }
        .fullScreenCover(isPresented: $scanSheet) {
            NativeQRScanner { code in scanSheet = false; submit(.init(photoURL: challengePhoto, code: code)) }
        }
        .cyHapticEvent(.checkInSuccess, trigger: model.checkInSuccess != nil) { old, new in !old && new }
        .cyHapticEvent(.wrongAnswer, trigger: model.checkInPhase) { _, next in
            if case .failed = next { return true }
            return false
        }
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

    /// RPOI-3: MP `.poi-recovery` (结果待确认 + 查询当前状态 + 重新现场核验).
    @ViewBuilder private var pendingRows: some View {
        let storage = model.pending == .storageError
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Label(LocalizedStringKey(storage ? "roam.poi.pending.storageTitle" : "roam.poi.pending.title"), systemImage: "clock.badge.questionmark")
                .cyText(.bodyMedium)
            Text(LocalizedStringKey(storage ? "roam.poi.pending.storageMessage" : "roam.poi.pending.message")).cyText(.bodyCompact).foregroundStyle(.secondary)
            if let status = model.pendingStatus {
                Text(LocalizedStringKey(status == .notShown ? "roam.poi.pending.notShown" : "roam.poi.pending.unresolved")).cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier("roam.poi.pending")
        Button("roam.poi.pending.query") { reload() }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .disabled(model.checkInPhase == .working)
            .accessibilityIdentifier("roam.poi.pending.query")
        if !storage {
            Button { model.requestReverify(); reload() } label: {
                Text(LocalizedStringKey(model.reverifyReady ? "roam.poi.pending.reverifyReady" : "roam.poi.pending.reverify"))
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .disabled(model.reverifyReady || model.checkInPhase == .working)
            .accessibilityIdentifier("roam.poi.pending.reverify")
        }
    }

    @ViewBuilder private func failureRow(_ failure: RoamPOIActionModel.Failure, retry: @escaping () -> Void) -> some View {
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
                Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }.cyText(.bodyCompact)
                Button("action.retry", action: retry).frame(minHeight: 44)
            case .signIn:
                Label("roam.poi.signIn", systemImage: "person.crop.circle.badge.exclamationmark").cyText(.body)
                // poi-detail #20: MP ensureLoginFor → the sign-in entry. Close the place sheet first, then open 我的.
                if rootTabSwitch.isAvailable {
                    Button("auth.signIn") { dismiss(); rootTabSwitch(.mine) }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("roam.poi.signIn.action")
                }
            case .network:
                Label("roam.poi.action.failed", systemImage: "wifi.exclamationmark").cyText(.body)
                Button("action.retry", action: retry).frame(minHeight: 44)
            }
        }
        .accessibilityIdentifier("roam.poi.action.error")
    }
}
