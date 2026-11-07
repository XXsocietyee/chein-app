import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - POI Challenge View (Ported from pages/play/poi-challenge/index.wxml & index.js)

@available(macOS 14.0, *)
@MainActor struct ChallengePOIView: View {
    @Environment(\.locale) private var locale
    @Bindable var coordinator: ChallengePOICoordinator
    let onRefresh: () async -> Void
    let onSubmit: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch coordinator.state {
            case .loading:
                ProgressView(String(localized: LocalizedStringResource("playx.poi.loading", defaultValue: "正在加载地标挑战…", locale: locale)))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()

            case .error:
                ContentUnavailableView {
                    Label(coordinator.errorMessage.isEmpty ? "加载挑战失败" : coordinator.errorMessage, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(String(localized: LocalizedStringResource("playx.poi.retry", defaultValue: "重试", locale: locale))) {
                        Task { await onRefresh() }
                    }
                }

            case .photo, .quiz:
                if let node = coordinator.node {
                    headerCard(node)

                    if !coordinator.errorMessage.isEmpty {
                        Text(coordinator.errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if coordinator.state == .photo || node.photoRequired {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: LocalizedStringResource("playx.poi.photoStep", defaultValue: "第一步：现场拍照打卡", locale: locale)))
                                .font(.subheadline.weight(.semibold))
                            TextField(
                                String(localized: LocalizedStringResource("playx.poi.photoUrlPlaceholder", defaultValue: "已上传现场照片地址", locale: locale)),
                                text: $coordinator.uploadedPhotoUrl
                            )
                            .textFieldStyle(.roundedBorder)
                            Button(String(localized: LocalizedStringResource("playx.poi.confirmPhoto", defaultValue: "确认现场照片", locale: locale))) {
                                coordinator.confirmPhotoUploaded(coordinator.uploadedPhotoUrl)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    if coordinator.state == .quiz || !node.photoRequired {
                        quizCard(node)
                    }

                    HStack(spacing: 10) {
                        Button(String(localized: LocalizedStringResource("playx.poi.submit", defaultValue: "提交挑战", locale: locale))) {
                            Task { await onSubmit() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.submitting || coordinator.unknownSubmission)

                        if coordinator.unknownSubmission {
                            Button(String(localized: LocalizedStringResource("playx.poi.verifyReceipt", defaultValue: "刷新确认状态", locale: locale))) {
                                Task { await onRefresh() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

            case .done:
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        coordinator.alreadyClaimed
                            ? String(localized: LocalizedStringResource("playx.poi.alreadyDone", defaultValue: "已完成该地标挑战", locale: locale))
                            : String(localized: LocalizedStringResource("playx.poi.completed", defaultValue: "挑战通关！", locale: locale)),
                        systemImage: "medal.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)

                    if let medal = coordinator.medal {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medal.name)
                                .font(.subheadline.weight(.semibold))
                            if !medal.description.isEmpty {
                                Text(medal.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
        }
        .padding()
    }

    @ViewBuilder
    private func headerCard(_ node: ChallengePOINode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(node.title.isEmpty ? node.name : node.title)
                    .font(.headline)
                Spacer()
                if let dist = coordinator.distanceMeters {
                    Text(coordinator.withinRange ? "已进入打卡范围 (\(dist)m)" : "距离 \(dist)m")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(coordinator.withinRange ? .green : .orange)
                }
            }
            if !node.description.isEmpty {
                Text(node.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func quizCard(_ node: ChallengePOINode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !node.question.isEmpty {
                Text(node.question)
                    .font(.subheadline.weight(.semibold))
            }
            if !node.options.isEmpty {
                ForEach(Array(node.options.enumerated()), id: \.offset) { idx, option in
                    Button {
                        coordinator.selectedOptionIndex = idx
                    } label: {
                        HStack {
                            Image(systemName: coordinator.selectedOptionIndex == idx ? "checkmark.circle.fill" : "circle")
                            Text(option)
                            Spacer()
                        }
                        .padding(8)
                        .background(
                            coordinator.selectedOptionIndex == idx ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else if !node.question.isEmpty {
                TextField(String(localized: LocalizedStringResource("playx.poi.answerPlaceholder", defaultValue: "输入你的答案", locale: locale)), text: $coordinator.textAnswer)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
