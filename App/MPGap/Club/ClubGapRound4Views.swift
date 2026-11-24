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
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: project.title)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                        HStack(spacing: CYSpacing.sm) {
                            if project.gameModuleEnabled {
                                Button(ClubRound4Copy.directorRowTitle) {
                                    if project.sessions.count == 1, let only = project.sessions.first {
                                        onOpenDirector(project.id, only.id)
                                    } else {
                                        pickingProject = project
                                    }
                                }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                            }
                            if let firstSession = project.sessions.first {
                                Button(ClubRound4Copy.sessionToolsTitle) {
                                    toolSessionTarget = (project.id, firstSession)
                                }
                                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            }
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            } header: {
                Text(verbatim: "管理中的项目").cyText(.sectionTitle)
            }
            .sheet(item: $pickingProject) { project in
                NavigationStack {
                    List {
                        if project.sessions.isEmpty {
                            CYEmptyState(systemImage: "calendar.badge.exclamationmark", verbatimTitle: ClubRound4Copy.noSessionsToast)
                        } else {
                            ForEach(project.sessions) { session in
                                Button {
                                    pickingProject = nil
                                    onOpenDirector(project.id, session.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                            Text(verbatim: session.title).cyText(.body).foregroundStyle(CYColor.textPrimary)
                                            if let timeLabel = session.timeLabel, !timeLabel.isEmpty {
                                                Text(verbatim: timeLabel).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .cyPageTitle(verbatim: ClubTopicDirectorCopy.selectSessionTitle)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { pickingProject = nil }
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

    public init(stop: ClubStoryStopLocation) {
        self.stop = stop
    }

    public var body: some View {
        Button(action: openInMaps) {
            HStack {
                MPAsset.FeatureIcon.pin
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: stop.address)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    if stop.hasCoordinates {
                        Text(verbatim: stop.mapActionTitle)
                            .cyText(.meta)
                            .foregroundStyle(CYColor.brand)
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
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    if draft.failedIndices.contains(index) {
                        Button("重试") { onRetryIndex(index) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                    } else {
                        Text(verbatim: urlString.isEmpty ? "上传中…" : "已上传")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                    Button(role: .destructive) {
                        draft.uploadedURLs.remove(at: index)
                        draft.failedIndices.remove(index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityLabel(Text(verbatim: "删除凭证图片 \(index + 1)"))
                }
            }
            if draft.remainingCapacity > 0 {
                Button("添加资质 / 案例图片（还可传 \(draft.remainingCapacity) 张）", action: onAddImages)
                    .cyText(.body)
            }
        } header: {
            Text(verbatim: "\(ClubRound4Copy.certSectionTitle)（\(draft.uploadedURLs.count)/\(ClubApplyCertImagesDraft.maxCount)）")
                .cyText(.sectionTitle)
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
            TextField(ClubRound4Copy.rangeStartPlaceholder, text: $range.fromDate).cyText(.body)
            TextField(ClubRound4Copy.rangeEndPlaceholder, text: $range.toDate).cyText(.body)
            HStack(spacing: CYSpacing.sm) {
                if range.isActive {
                    Button(ClubRound4Copy.rangeClear) { range.clear() }
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                }
                Spacer()
                Button(ClubRound4Copy.rangeExport, action: onExport)
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                    .disabled(isExporting)
            }
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
                            Text(verbatim: session.title).cyText(.body).foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
            case .empty:
                CYEmptyState(systemImage: "calendar", verbatimTitle: ClubRound4Copy.groupCodeEmptyTitle)
            case .invalid:
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    LocalizedStringKey(ClubRound4Copy.groupCodeInvalidTitle),
                    actionTitle: LocalizedStringKey(ClubRound4Copy.groupCodeEnterManage),
                    action: onOpenManage
                )
            case .noPermission:
                CYEmptyState(
                    systemImage: "lock",
                    LocalizedStringKey(ClubRound4Copy.groupCodeNoPermission),
                    actionTitle: LocalizedStringKey(ClubRound4Copy.groupCodeEnterManage),
                    action: onOpenManage
                )
            }
        }
        .cyPageTitle(verbatim: ClubRound4Copy.groupCodeSelectTitle)
    }
}
