#if DEBUG
import SwiftUI

/// App Store 1.2 safety fixtures. Each named surface that exists on this tip has one normal
/// DEBUG screen and one non-happy screen. Launch with `--design-fixture ugc-<id>`.
/// The safety service answers in process. It does not open www.chengyinhub.com.
enum UGCSafetyFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        guard let spec = UGCSafetyFixtureCatalog.spec(name) else { return nil }
        return AnyView(UGCSafetyFixtureScreen(model: UGCFixtureModelStore.model(for: spec)))
    }
}

@MainActor
private enum UGCFixtureModelStore {
    private static var cache: [String: UGCFixtureModel] = [:]

    static func model(for spec: UGCSafetyFixtureSpec) -> UGCFixtureModel {
        if let existing = cache[spec.id] {
            return existing
        }
        let created = UGCFixtureModel(spec: spec)
        cache[spec.id] = created
        return created
    }
}

private enum UGCSafetyFixtureKind {
    case normal
    case hidden
    case signedOut
    case precheckDenied
    case moneyClosed
    case unknownAuthor
}

private enum UGCSafetyFixtureControl {
    case footer
    case menu
    case profile
}

private struct UGCSafetyFixtureSpec {
    let id: String
    let title: String
    let body: String
    let target: UGCSafetyReportTarget
    let authorID: Int
    let authorName: String?
    let clubID: Int?
    let control: UGCSafetyFixtureControl
    let kind: UGCSafetyFixtureKind
    let merchant: Bool
    let showsMoney: Bool
}

private enum UGCSafetyFixtureCatalog {
    static func spec(_ name: String) -> UGCSafetyFixtureSpec? {
        switch name {
        case "ugc-square": return row(name, "Square", "西湖夜航的一张路线图", .creativeSquarePost(id: 501), .footer)
        case "ugc-square-hidden": return row(name, "Square · hidden", "西湖夜航的一张路线图", .creativeSquarePost(id: 501), .footer, .hidden)
        case "ugc-club-post": return row(name, "Club post", "周五夜跑集合帖", .clubPost(clubID: 70, postID: 501), .menu, clubID: 70)
        case "ugc-club-post-signed-out": return row(name, "Club post · signed out", "周五夜跑集合帖", .clubPost(clubID: 70, postID: 501), .menu, .signedOut, clubID: 70)
        case "ugc-club-comment": return row(name, "Club comment", "这条评论跑偏了", .clubPostComment(commentID: 501), .menu, clubID: 70)
        case "ugc-club-comment-hidden": return row(name, "Club comment · hidden", "这条评论跑偏了", .clubPostComment(commentID: 501), .menu, .hidden, clubID: 70)
        case "ugc-club-channel": return row(name, "Club channel", "频道里的一条消息", .community(targetType: .club, targetID: 70), .menu, clubID: 70)
        case "ugc-club-channel-precheck": return row(name, "Club channel · precheck refused", "频道里的一条消息", .community(targetType: .club, targetID: 70), .menu, .precheckDenied, clubID: 70)
        case "ugc-im-dm": return row(name, "IM DM", "私信里的一句话", .member(memberID: 880201), .menu)
        case "ugc-im-dm-hidden": return row(name, "IM DM · hidden", "私信里的一句话", .member(memberID: 880201), .menu, .hidden)
        case "ugc-profile": return row(name, "Profile", "公开主页上的一条动态", .member(memberID: 880201), .profile)
        case "ugc-profile-blocked": return row(name, "Profile · blocked", "公开主页上的一条动态", .member(memberID: 880201), .profile, .hidden)
        case "ugc-topic-review": return row(name, "Topic review", "路线评价：夜航很好走", .topic(id: 501), .footer)
        case "ugc-topic-review-unknown": return row(name, "Topic review · unknown author", "路线评价：夜航很好走", .topic(id: 501), .footer, .unknownAuthor, authorID: 0, authorName: nil)
        case "ugc-template": return row(name, "Template", "个人模板：城市散步", .template(id: 501, personal: false), .menu)
        case "ugc-template-precheck": return row(name, "Template · precheck refused", "个人模板：城市散步", .template(id: 501, personal: false), .menu, .precheckDenied)
        case "ugc-merchant-review": return row(name, "Merchant review", "到店评价：出餐很快", .community(targetType: .merchant, targetID: 501), .menu, merchant: true)
        case "ugc-merchant-review-hidden": return row(name, "Merchant review · hidden", "到店评价：出餐很快", .community(targetType: .merchant, targetID: 501), .menu, .hidden, merchant: true)
        case "ugc-workshop-mod": return row(name, "Workshop mod", "已购模组说明", .mod(modID: 501), .menu, showsMoney: true)
        case "ugc-workshop-mod-closed": return row(name, "Workshop mod · money closed", "已购模组说明", .mod(modID: 501), .menu, .moneyClosed, showsMoney: true)
        default: return nil
        }
    }

    private static func row(
        _ id: String,
        _ title: String,
        _ body: String,
        _ target: UGCSafetyReportTarget,
        _ control: UGCSafetyFixtureControl,
        _ kind: UGCSafetyFixtureKind = .normal,
        clubID: Int? = nil,
        authorID: Int = 880201,
        authorName: String? = "阿青",
        merchant: Bool = false,
        showsMoney: Bool = false
    ) -> UGCSafetyFixtureSpec {
        UGCSafetyFixtureSpec(
            id: id,
            title: title,
            body: body,
            target: target,
            authorID: authorID,
            authorName: authorName,
            clubID: clubID,
            control: control,
            kind: kind,
            merchant: merchant,
            showsMoney: showsMoney
        )
    }
}

/// In-process safety service. No URL, no transport, no production host.
private struct UGCFixtureSafetyService: UGCContentSafetyServing {
    let precheckDenied: Bool

    func fetchCapabilities(token: String) async throws -> UGCContentSafetyCapabilities {
        _ = token
        return UGCContentSafetyCapabilities(
            policyVersion: UGCReportReasonOption.fallbackPolicyVersion,
            reasons: UGCReportReasonOption.fallbackTaxonomy
        )
    }

    func submitReport(
        target: UGCSafetyReportTarget,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String,
        token: String
    ) async throws -> String? {
        _ = (target, reason, details, policyVersion, token)
        return ""
    }

    func blockUser(targetMemberID: Int, token: String) async throws {
        _ = (targetMemberID, token)
    }

    func unblockUser(targetMemberID: Int, token: String) async throws {
        _ = (targetMemberID, token)
    }

    func fetchBlockedMemberIDs(cursor: Int64, token: String) async throws -> [Int] {
        _ = (cursor, token)
        return []
    }

    func precheckContent(text: String, scene: String, token: String) async throws -> UGCPrecheckResult {
        _ = (text, scene, token)
        if precheckDenied {
            return UGCPrecheckResult(allowed: false, message: nil)
        }
        return UGCPrecheckResult(allowed: true, message: nil)
    }
}

@MainActor
private final class UGCFixtureModel: ObservableObject {
    let spec: UGCSafetyFixtureSpec
    let context: UGCSafetyContext

    init(spec: UGCSafetyFixtureSpec) {
        self.spec = spec
        let suite = "questify.ugc.fixture.\(spec.id)"
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: suite) {
            suiteDefaults.removePersistentDomain(forName: suite)
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }
        let store = UGCBlockedUsersStore(defaults: defaults)
        let service = UGCFixtureSafetyService(precheckDenied: spec.kind == .precheckDenied)
        let signedOut = spec.kind == .signedOut
        let context = UGCSafetyContext(
            blockedStore: store,
            serviceProvider: { service },
            tokenProvider: { signedOut ? nil : "synthetic-fixture-token" },
            accountIDProvider: { 990001 },
            realmProvider: { suite }
        )
        if spec.kind == .hidden {
            store.recordLocalBlock(memberID: spec.authorID, authorName: spec.authorName)
        }
        self.context = context
    }

    var shownAuthor: String {
        let trimmed = spec.authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }

    var moneyHost: String {
        spec.kind == .moneyClosed ? ReviewedAreaSwitch.productionAPIHost : "fixture.example"
    }
}

@MainActor
private struct UGCSafetyFixtureScreen: View {
    let model: UGCFixtureModel
    @State private var precheckAllowed: Bool?
    @State private var precheckLine = "—"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text(verbatim: model.spec.title)
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("ugc.fixture.title")
                Text(verbatim: model.shownAuthor)
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("ugc.fixture.author")
                Text(verbatim: String(model.spec.authorID))
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("ugc.fixture.memberID")
                UGCBlockedFilterContainer(
                    memberID: model.spec.authorID > 0 ? model.spec.authorID : nil,
                    authorName: model.spec.authorName
                ) {
                    Text(verbatim: model.spec.body)
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("ugc.fixture.content")
                } blockedPlaceholder: {
                    UGCBlockedNoticeBanner(
                        memberID: model.spec.authorID > 0 ? model.spec.authorID : nil,
                        authorName: model.spec.authorName,
                        clubID: model.spec.clubID
                    )
                }
                controls
                precheckNotice
                if model.spec.showsMoney {
                    moneyLine
                }
                NavigationLink {
                    SettingsSupportSafetyView()
                } label: {
                    Text("ugc.safety.action.contactSupport", tableName: "UGCSafety")
                        .font(CYTypography.label)
                        .foregroundStyle(CYColor.textPrimary)
                }
                .accessibilityLabel(Text("ugc.safety.action.contactSupport", tableName: "UGCSafety"))
                .accessibilityIdentifier("ugc.fixture.support")
                Text(verbatim: "DEBUG fixture · synthetic · no network")
                    .font(CYTypography.caption)
                    .foregroundStyle(CYColor.textSecondary)
            }
            .padding(CYSpacing.lg)
        }
        .background(CYColor.bgPage)
        .environment(\.ugcSafetyContext, model.context)
        .accessibilityIdentifier("ugc.fixture.screen")
        .modifier(UGCFixtureTheme(merchant: model.spec.merchant))
    }

    @ViewBuilder
    private var controls: some View {
        let spec = model.spec
        let presentation = UGCReportPresentationTarget(
            target: spec.target,
            subjectTitle: spec.body,
            authorMemberID: spec.authorID > 0 ? spec.authorID : nil,
            authorName: spec.authorName,
            clubID: spec.clubID
        )
        Group {
            switch spec.control {
            case .footer:
                UGCReviewSafetyFooter(
                    target: spec.target,
                    subjectTitle: spec.body,
                    authorMemberID: spec.authorID > 0 ? spec.authorID : nil,
                    authorName: spec.authorName,
                    clubID: spec.clubID
                )
            case .menu:
                UGCSafetyMenuButton(presentation: presentation)
            case .profile:
                UGCProfileSafetyActionsSection(memberID: spec.authorID, displayName: spec.authorName)
            }
        }
    }

    private var precheckNotice: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("ugc.safety.moderation.footer", tableName: "UGCSafety")
                .font(CYTypography.caption)
                .foregroundStyle(CYColor.textTertiary)
                .accessibilityIdentifier("ugc.safety.moderation.notice")
            Text(verbatim: precheckLine)
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("ugc.fixture.precheck.line")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(precheckIdentifier)
        .task {
            let result = await model.context.precheckContent(model.spec.body, scene: model.spec.id)
            let trimmed = result.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            precheckLine = trimmed.isEmpty ? "—" : trimmed
            precheckAllowed = result.allowed
        }
    }

    private var precheckIdentifier: String {
        if let allowed = precheckAllowed {
            return allowed ? "ugc.fixture.precheck.allowed" : "ugc.fixture.precheck.denied"
        }
        return "ugc.fixture.precheck.unknown"
    }

    private var moneyLine: some View {
        let open = ReviewedAreaSwitch.moneyPayments(apiHost: model.moneyHost)
        let shown = open ? "12.00" : "—"
        return Text(verbatim: shown)
            .font(CYTypography.body)
            .foregroundStyle(CYColor.textPrimary)
            .accessibilityLabel(Text(verbatim: shown))
            .accessibilityIdentifier("ugc.fixture.money")
    }
}

private struct UGCFixtureTheme: ViewModifier {
    let merchant: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if merchant {
            content.themeDomain(.merchant).preferredColorScheme(.light)
        } else {
            content.themeDomain(.player).preferredColorScheme(.dark)
        }
    }
}
#endif
