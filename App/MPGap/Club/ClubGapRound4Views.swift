import SwiftUI
#if canImport(MapKit)
import MapKit
#endif

/// Mount hook for `ClubDetailView` (管理 tab) — `CLB-detail-09` & `CLB-r7-A-04`:
/// Managed projects list with `活动导演台` (gated by `gameModuleEnabled`), `选择导演场次`, and `场次工具`.
public struct ClubGapManagedProjectsDirectorSection: View {
    public let projects: [ClubManagedProjectDirectorItem]
    public let onOpenDirector: (_ topicID: Int, _ activityID: Int) -> Void
    public let onSelectSessionTool: (_ topicID: Int, _ activityID: Int, _ tool: ClubSessionToolChoice) -> Void

    @State private var pickingProject: ClubManagedProjectDirectorItem?
    @State private var toolSessionTarget: (topicID: Int, session: ClubManagedDirectorSession)?

    public init(
        projects: [ClubManagedProjectDirectorItem],
        onOpenDirector: @escaping (_ topicID: Int, _ activityID: Int) -> Void,
        onSelectSessionTool: @escaping (_ topicID: Int, _ activityID: Int, _ tool: ClubSessionToolChoice) -> Void
    ) {
        self.projects = projects
        self.onOpenDirector = onOpenDirector
        self.onSelectSessionTool = onSelectSessionTool
    }

    public var body: some View {
        if !projects.isEmpty {
            Section {
                ForEach(projects) { project in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: project.title)
                            .font(.headline)
                        HStack(spacing: 8) {
                            if project.gameModuleEnabled {
                                Button(ClubRound4Copy.directorRowTitle) {
                                    if project.sessions.count == 1, let only = project.sessions.first {
                                        onOpenDirector(project.id, only.id)
                                    } else {
                                        pickingProject = project
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            if let firstSession = project.sessions.first {
                                Button(ClubRound4Copy.sessionToolsTitle) {
                                    toolSessionTarget = (project.id, firstSession)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            } header: {
                Text(verbatim: "管理中的项目")
            }
            .cySheet(item: $pickingProject) { project in
                NavigationStack {
                    List {
                        if project.sessions.isEmpty {
                            ContentUnavailableView(ClubRound4Copy.noSessionsToast, systemImage: "calendar.badge.exclamationmark")
                        } else {
                            ForEach(project.sessions) { session in
                                Button {
                                    pickingProject = nil
                                    onOpenDirector(project.id, session.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(verbatim: session.title).foregroundStyle(.primary)
                                            if let timeLabel = session.timeLabel, !timeLabel.isEmpty {
                                                Text(verbatim: timeLabel).font(.subheadline).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                        }
                    }
                    .cyPageTitle(verbatim: ClubTopicDirectorCopy.selectSessionTitle)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.close") { pickingProject = nil }
                        }
                    }
                }
            }
            .confirmationDialog(
                ClubRound4Copy.sessionToolsTitle,
                isPresented: Binding(
                    get: { toolSessionTarget != nil },
                    set: { if !$0 { toolSessionTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let target = toolSessionTarget {
                    ForEach(ClubSessionToolChoice.allCases) { choice in
                        Button(choice.title) {
                            onSelectSessionTool(target.topicID, target.session.id, choice)
                            toolSessionTarget = nil
                        }
                    }
                }
            }
        }
    }
}

/// Mount hook for `ClubStoryViews` (`CLB-topic-story-04`):
/// Tappable address row that opens Apple Maps (`MKMapItem`) when coordinates are present.
public struct ClubGapStoryMapAddressRow: View {
    public let stop: ClubStoryStopLocation
    /// CLB-r9-native-05: the pin follows Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var pinSide: CGFloat = 16

    public init(stop: ClubStoryStopLocation) {
        self.stop = stop
    }

    public var body: some View {
        Button(action: openInMaps) {
            HStack {
                MPAsset.FeatureIcon.pin
                    .resizable()
                    .scaledToFit()
                    .frame(width: pinSide, height: pinSide)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: stop.address)
                        .foregroundStyle(.primary)
                    if stop.hasCoordinates {
                        Text("club.story.openInMaps")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
                Spacer()
            }
        }
        .disabled(!stop.hasCoordinates)
    }

    private func openInMaps() {
        #if canImport(MapKit)
        guard let lat = stop.latitude, let lng = stop.longitude, stop.hasCoordinates else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)))
        item.name = stop.name.isEmpty ? stop.address : stop.name
        item.openInMaps()
        #endif
    }
}

/// Mount hook for `ClubGovernanceCommandForm` / `ClubHostApplicationMaterials` (`CLB-apply-05`):
/// Up to 9 `certImages` upload slots with add/remove/retry actions.
public struct ClubGapApplyCertImagesSection: View {
    @Binding public var draft: ClubApplyCertImagesDraft
    public let onAddImages: () -> Void
    public let onRetryIndex: (Int) -> Void

    public init(
        draft: Binding<ClubApplyCertImagesDraft>,
        onAddImages: @escaping () -> Void,
        onRetryIndex: @escaping (Int) -> Void
    ) {
        self._draft = draft
        self.onAddImages = onAddImages
        self.onRetryIndex = onRetryIndex
    }

    public var body: some View {
        Section {
            ForEach(Array(draft.uploadedURLs.enumerated()), id: \.offset) { index, urlString in
                HStack {
                    Text(verbatim: "凭证图片 \(index + 1)")
                    Spacer()
                    if draft.failedIndices.contains(index) {
                        Button("重试") { onRetryIndex(index) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Text(verbatim: urlString.isEmpty ? "上传中…" : "已上传")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        draft.uploadedURLs.remove(at: index)
                        draft.failedIndices.remove(index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(verbatim: "删除凭证图片 \(index + 1)"))
                }
            }
            if draft.remainingCapacity > 0 {
                Button("添加资质 / 案例图片（还可传 \(draft.remainingCapacity) 张）", action: onAddImages)
            }
        } header: {
            Text(verbatim: "\(ClubRound4Copy.certSectionTitle)（\(draft.uploadedURLs.count)/\(ClubApplyCertImagesDraft.maxCount)）")
        }
    }
}

/// Mount hook for `ClubFEReferenceSettlementSection` (`CLB-r7-D-01`):
/// Date range filter (`from` / `to`, `清除`) + `导出` button.
public struct ClubGapFEReferenceRangeBar: View {
    @Binding public var range: FEReferenceRangeFilter
    public let isExporting: Bool
    public let onExport: () -> Void

    public init(range: Binding<FEReferenceRangeFilter>, isExporting: Bool, onExport: @escaping () -> Void) {
        self._range = range
        self.isExporting = isExporting
        self.onExport = onExport
    }

    public var body: some View {
        Section {
            // CLB-r10-nat-detail-12: system date pickers (MP `picker mode="date"`), not typed date strings.
            dateRow(ClubRound4Copy.rangeStartPlaceholder, text: $range.fromDate)
            dateRow(ClubRound4Copy.rangeEndPlaceholder, text: $range.toDate)
            HStack(spacing: 8) {
                if range.isActive {
                    Button(ClubRound4Copy.rangeClear) { range.clear() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Spacer()
                Button(ClubRound4Copy.rangeExport, action: onExport)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isExporting)
            }
        }
    }
}

extension ClubGapFEReferenceRangeBar {
    /// An unset bound reads 未设置 and a tap sets it to today; a set bound is a compact `DatePicker`.
    @ViewBuilder fileprivate func dateRow(_ title: String, text: Binding<String>) -> some View {
        if let date = FEReferenceRangeFilter.date(text.wrappedValue) {
            DatePicker(title, selection: Binding(get: { date }, set: { text.wrappedValue = FEReferenceRangeFilter.text($0) }),
                       displayedComponents: .date)
        } else {
            Button { text.wrappedValue = FEReferenceRangeFilter.text(Date()) } label: {
                LabeledContent(title) { Text(verbatim: ClubRound4Copy.rangeUnset) }
            }
            .foregroundStyle(Color.primary)
        }
    }
}

/// Mount hook for `ClubGroupCodePresentation` (`CLB-group-code-05`):
/// Session picker step (`选择场次`, `暂无可带队的场次`, `缺少路线或场次信息` + `进入俱乐部管理`).
public struct ClubGapGroupCodeSessionPickerView: View {
    public let state: ClubGroupCodeStepState
    public let onSelectSession: (ClubManagedDirectorSession) -> Void
    public let onOpenManage: () -> Void

    public init(
        state: ClubGroupCodeStepState,
        onSelectSession: @escaping (ClubManagedDirectorSession) -> Void,
        onOpenManage: @escaping () -> Void
    ) {
        self.state = state
        self.onSelectSession = onSelectSession
        self.onOpenManage = onOpenManage
    }

    public var body: some View {
        List {
            switch state {
            case .selecting(let sessions):
                ForEach(sessions) { session in
                    Button {
                        onSelectSession(session)
                    } label: {
                        HStack {
                            Text(verbatim: session.title).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                }
            case .empty:
                ContentUnavailableView(ClubRound4Copy.groupCodeEmptyTitle, systemImage: "calendar")
            case .invalid:
                ContentUnavailableView {
                    Label(LocalizedStringKey(ClubRound4Copy.groupCodeInvalidTitle), systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(LocalizedStringKey(ClubRound4Copy.groupCodeEnterManage), action: onOpenManage)
                        .buttonStyle(.bordered)
                }
            case .noPermission:
                ContentUnavailableView {
                    Label(LocalizedStringKey(ClubRound4Copy.groupCodeNoPermission), systemImage: "lock")
                } actions: {
                    Button(LocalizedStringKey(ClubRound4Copy.groupCodeEnterManage), action: onOpenManage)
                        .buttonStyle(.bordered)
                }
            }
        }
        .cyPageTitle(verbatim: ClubRound4Copy.groupCodeSelectTitle)
    }
}
