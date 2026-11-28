import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Presentation row modeling a cross-city roaming & city-switch isolation invariant:
/// - `cityCode` + account cache partitioning
/// - In-flight request generation fencing & cancellation on city switch
/// - Map viewport & `CityDeltaStream` sequence reset on city transition
public struct CityIsolationSurfaceRow: Sendable, Equatable, Identifiable {
    public enum SurfaceID: String, CaseIterable, Sendable, Equatable {
        case cityAndAccountCachePartition = "city_account_cache_partition"
        case inFlightRequestCancellation = "inflight_request_cancellation"
        case mapViewportAndDeltaReset = "map_viewport_delta_reset"
    }

    public let id: String
    public let surface: SurfaceID
    public let title: String
    public let detail: String
    public let statusBadgeText: String
    public let isIsolated: Bool

    public init(
        surface: SurfaceID,
        title: String,
        detail: String,
        statusBadgeText: String,
        isIsolated: Bool = true
    ) {
        self.id = surface.rawValue
        self.surface = surface
        self.title = title
        self.detail = detail
        self.statusBadgeText = statusBadgeText
        self.isIsolated = isIsolated
    }
}

/// Self-contained snapshot for `CitySwitchAndCrossCityRoamingSectionView`.
public struct CitySwitchIsolationSnapshot: Sendable, Equatable {
    public let activeCityCode: String
    public let previousCityCode: String?
    public let rows: [CityIsolationSurfaceRow]
    public let cancelsInFlightReadsOnCityChange: Bool
    public let resetsViewportAndDeltaCursorOnSwitch: Bool
    public let simulationLoopState: CitySimulationLoopState
    public let locale: Locale

    public var isCrossCityIsolationSafe: Bool {
        !activeCityCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rows.count == 3
            && rows.allSatisfy(\.isIsolated)
            && cancelsInFlightReadsOnCityChange
            && resetsViewportAndDeltaCursorOnSwitch
    }

    public init(
        activeCityCode: String = "310100",
        previousCityCode: String? = "110100",
        rows: [CityIsolationSurfaceRow],
        cancelsInFlightReadsOnCityChange: Bool = true,
        resetsViewportAndDeltaCursorOnSwitch: Bool = true,
        simulationLoopState: CitySimulationLoopState = CitySimulationLoopState(),
        locale: Locale = .current
    ) {
        self.locale = locale
        self.activeCityCode = activeCityCode
        self.previousCityCode = previousCityCode
        self.rows = rows
        self.cancelsInFlightReadsOnCityChange = cancelsInFlightReadsOnCityChange
        self.resetsViewportAndDeltaCursorOnSwitch = resetsViewportAndDeltaCursorOnSwitch
        self.simulationLoopState = simulationLoopState
    }

    public static var defaultReady: CitySwitchIsolationSnapshot { ready(locale: .current) }

    public static func ready(locale: Locale) -> CitySwitchIsolationSnapshot {
        CitySwitchIsolationSnapshot(
            activeCityCode: "310100",
            previousCityCode: "110100",
            rows: [
                CityIsolationSurfaceRow(
                    surface: .cityAndAccountCachePartition,
                    title: bilingualCopy("cityCode + 账户双维缓存分区", "cityCode + account cache partition", locale: locale),
                    detail: bilingualCopy("漫游瓦片、同城俱乐部与城市节点缓存均绑定 (accountID, epoch, cityCode)，严禁跨城串读。",
                                          "Roam tiles, same-city clubs and city-node caches are all keyed by (accountID, epoch, cityCode); cross-city reads are forbidden.", locale: locale),
                    statusBadgeText: "PARTITIONED",
                    isIsolated: true
                ),
                CityIsolationSurfaceRow(
                    surface: .inFlightRequestCancellation,
                    title: bilingualCopy("切城在途请求代际取消 (Generation Fence)", "In-flight request cancellation on city switch (generation fence)", locale: locale),
                    detail: bilingualCopy("切换城市时递增查询代际并取消旧城市在途请求，迟到的上一城响应一律丢弃。",
                                          "Switching city bumps the query generation and cancels the previous city's requests; late responses are discarded.", locale: locale),
                    statusBadgeText: "FENCED",
                    isIsolated: true
                ),
                CityIsolationSurfaceRow(
                    surface: .mapViewportAndDeltaReset,
                    title: bilingualCopy("地图视口与增量流游标重置", "Map viewport and delta-stream cursor reset", locale: locale),
                    detail: bilingualCopy("跨城切换后重置地图 bbox 游标与 CityDeltaStream 序列号，从新城市快照重新同步。",
                                          "After a city switch the map bbox cursor and CityDeltaStream sequence reset and resync from the new city snapshot.", locale: locale),
                    statusBadgeText: "CURSOR_RESET",
                    isIsolated: true
                )
            ],
            cancelsInFlightReadsOnCityChange: true,
            resetsViewportAndDeltaCursorOnSwitch: true,
            locale: locale
        )
    }
}

/// SwiftUI section view displaying `cityCode` + account cache partitioning, in-flight request cancellation
/// on city switch, and map viewport delta reset with inline bilingual (zh-Hans / en) copy.
@MainActor
public struct CitySwitchAndCrossCityRoamingSectionView: View {
    public let snapshot: CitySwitchIsolationSnapshot

    public init(snapshot: CitySwitchIsolationSnapshot = .defaultReady) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Section {
            HStack {
                Text(
                    verbatim: snapshot.isCrossCityIsolationSafe
                        ? bilingualCopy("跨城漫游与切城隔离：3/3 项已启用代际围栏与缓存分区", "Cross-city roaming isolation: 3/3 generation fences and cache partitions active", locale: snapshot.locale)
                        : bilingualCopy("跨城漫游与切城隔离：检测到跨城缓存污染或在途请求串读风险", "Cross-city roaming isolation: cache bleed or stale in-flight request risk detected", locale: snapshot.locale)
                )
                .cyText(.bodyMedium)
                Spacer()
                Text(verbatim: snapshot.isCrossCityIsolationSafe ? "ISOLATED" : "BLEED_RISK")
                    .font(.caption.monospaced())
                    .foregroundStyle(snapshot.isCrossCityIsolationSafe ? .green : .red)
            }
            .accessibilityIdentifier("citySwitchIsolation.summary")

            HStack {
                Text(verbatim: bilingualCopy("当前生效城市代码 (cityCode)", "Active city code (cityCode)", locale: snapshot.locale))
                    .cyText(.meta)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(
                    verbatim: snapshot.previousCityCode != nil
                        ? "\(snapshot.previousCityCode ?? "") → \(snapshot.activeCityCode)"
                        : snapshot.activeCityCode
                )
                .font(.caption.monospaced())
            }
            .accessibilityIdentifier("citySwitchIsolation.cityCode")

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    verbatim: bilingualCopy(
                        "同城沙盘闭环 (DESIGNED)：行动力 \(snapshot.simulationLoopState.actionsRemaining)/\(snapshot.simulationLoopState.actionsPerRound) · 持仓 \(snapshot.simulationLoopState.activeHoldCount)/\(snapshot.simulationLoopState.holdingLimit) · 公平分群 \(snapshot.simulationLoopState.fairnessCohortState.rawValue)",
                        "City sandbox loop (DESIGNED): actions \(snapshot.simulationLoopState.actionsRemaining)/\(snapshot.simulationLoopState.actionsPerRound) · holdings \(snapshot.simulationLoopState.activeHoldCount)/\(snapshot.simulationLoopState.holdingLimit) · fairness cohort \(snapshot.simulationLoopState.fairnessCohortState.rawValue)",
                        locale: snapshot.locale)
                )
                .cyText(.caption, weight: .medium)
                Text(
                    verbatim: bilingualCopy(
                        "状态机阶段：\(snapshot.simulationLoopState.phase.rawValue) · 门店积分服务费：\(snapshot.simulationLoopState.memberPointsFee)",
                        "Phase: \(snapshot.simulationLoopState.phase.rawValue) · store points service fee: \(snapshot.simulationLoopState.memberPointsFee)",
                        locale: snapshot.locale)
                )
                .cyText(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("citySwitchIsolation.simulationLoop")

            ForEach(snapshot.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: row.title)
                            .cyText(.bodyMedium)
                        Spacer()
                        Text(verbatim: row.statusBadgeText)
                            .font(.caption.monospaced())
                            .foregroundStyle(row.isIsolated ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                            .accessibilityIdentifier("citySwitchIsolation.row.\(row.id).status")
                    }
                    Text(verbatim: row.detail)
                        .cyText(.bodyCompact)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .accessibilityIdentifier("citySwitchIsolation.row.\(row.id)")
            }

            if !snapshot.isCrossCityIsolationSafe {
                Text(verbatim: bilingualCopy("告警：检测到切换城市后未取消旧城市在途请求或未重置地图增量流游标，存在跨城数据串读风险。", "Warning: after the city switch the old city's in-flight requests were not cancelled or the map delta cursor was not reset, so cross-city data may bleed.", locale: snapshot.locale))
                    .cyText(.label)
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("citySwitchIsolation.warningBanner")
            }
        } header: {
            Text(verbatim: bilingualCopy("城市切换与跨城漫游状态隔离", "City switch and cross-city roaming isolation", locale: snapshot.locale))
        }
        .accessibilityIdentifier("citySwitchIsolation.section")
    }
}
