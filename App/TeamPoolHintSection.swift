import SwiftUI

/// Team run section of the hint dialog (contract §4). Hints, skips and the timer belong to the whole team, so the
/// counters are server facts and the hint text is the server's `hint{level, type, content}`. No points are charged here.
@MainActor struct TeamPoolHintSection: View {
    @Bindable var model: TeamPoolHintModel

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("teamPool.title").font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let pool = model.pool {
                HStack(spacing: CYSpacing.md) {
                    if let left = pool.hintsLeft, let total = pool.hintsTotal {
                        Text("teamPool.hintsLeft \(left) \(total)").accessibilityIdentifier("teamPool.hintsLeft")
                    }
                    if let left = pool.skipsLeft, let total = pool.skipsTotal {
                        Text("teamPool.skipsLeft \(left) \(total)").accessibilityIdentifier("teamPool.skipsLeft")
                    }
                    if let score = pool.teamScore {
                        Text("teamPool.score \(score)").accessibilityIdentifier("teamPool.score")
                    }
                }
                .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                if pool.timerExpired == true {
                    Text("teamPool.timerExpired").font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
                }
            }
            if let hint = model.hint {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("teamPool.hintLevel \(hint.level)").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: hint.content)
                        .font(hint.type == "LETTER" || hint.type == "DIGIT" ? CYTypography.pageTitle : CYTypography.body)
                        .foregroundStyle(CYColor.textPrimary).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("teamPool.hint")
                    if model.coveredByTeam {
                        Text("teamPool.coveredByTeam").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    }
                }
            } else if model.canRecover && model.notice == .unknown {
                Button { Task { await model.recover() } } label: { Text("teamPool.keepChecking") }
                    .accessibilityIdentifier("teamPool.recover")
            } else {
                Button { Task { await model.requestHint() } } label: { Text("teamPool.useHint") }
                    .disabled(!model.canRequestHint)
                    .accessibilityIdentifier("teamPool.useHint")
            }
            if let notice = model.notice { noticeText(notice) }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("teamPool.section")
    }

    private func noticeText(_ notice: TeamPoolHintModel.Notice) -> some View {
        Group {
            switch notice {
            case .exhausted: Text("teamPool.exhausted")
            case .timerExpired: Text("teamPool.timerExpired")
            case .disabled, .unavailable: Text("teamPool.unavailable")
            case .hintUnavailable: Text("teamPool.hintUnavailable")
            case .notMember: Text("teamPool.notMember")
            case .unknown: Text("teamPool.unknown")
            case .failed: Text("teamPool.failed")
            }
        }
        .font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
        .accessibilityIdentifier("teamPool.notice")
    }
}

extension AppSession {
    /// The team pool for one stop of a run. The team is the run's `teamId` from `/api/play/nodes` (contract §5, item 17);
    /// only when the server omits it does this fall back to the viewer's own active topic team (`/api/team/my`, owner type 1),
    /// which misses activity-owned teams. Without a team there is no pool. Writes go through the reviewed player-write grant.
    func teamPoolHint(topicID: Int?, nodeID: Int, runTeamID: Int? = nil) -> TeamPoolHintModel? {
        guard let topicID, topicID > 0, nodeID > 0, let configuration = regionalConfiguration?.apiConfiguration,
              let context = currentRuntimeDependencyContext, composition.playerWriteGrant(context) != nil else { return nil }
        let service = TeamPoolService(configuration: configuration, transport: runtimeHTTPTransport, token: { [weak self] in
            guard let self, self.currentRuntimeDependencyContext == context else { return nil }
            return self.token
        })
        let teams = makeTeamCoordinator()
        return TeamPoolHintModel(service: service, nodeID: Int64(nodeID)) { [weak self] in
            guard self?.currentRuntimeDependencyContext == context else { return nil }
            if let runTeamID, runTeamID > 0 { return Int64(runTeamID) }
            await teams.loadTeams()
            let live: [TeamStatus] = [.recruiting, .full, .inProgress]
            return teams.teams.first { $0.ownerType == 1 && $0.ownerID == topicID && live.contains($0.status) }.map { Int64($0.id) }
        }
    }
}
