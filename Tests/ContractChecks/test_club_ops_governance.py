"""Source contracts for mini-program pages/club/governance + pages/club/roles parity (native run is separate)."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
if not (ROOT / 'App').exists(): ROOT = ROOT.parent


def text(path): return (ROOT / path).read_text()


class ClubOpsGovernanceContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = text('Core/ClubOpsGovernancePresentation.swift')
        cls.ui = text('App/ClubOpsGovernanceSections.swift')
        cls.views = text('App/ClubGovernanceViews.swift')
        cls.form = text('App/ClubGovernanceCommandForm.swift')
        cls.service = text('Core/ClubGovernanceService.swift')
        cls.validation = text('Core/ClubGovernanceValidation.swift')
        cls.commands = text('Core/ClubGovernanceCommands.swift')
        cls.draft = text('Core/ClubGovernanceFormDraft.swift')
        cls.cases = text('App/ClubCaseSubmissionReturn.swift')
        cls.catalog = json.loads(text('Resources/ClubOpsGovernance.xcstrings'))
        cls.tests = text('Tests/CoreTests/ClubOpsGovernancePresentationTests.swift')

    def zh(self, key): return self.catalog['strings'][key]['localizations']['zh-Hans']['stringUnit']['value']

    def test_sources_and_catalog_are_registered(self):
        project = text('Questify.xcodeproj/project.pbxproj')
        for path in ['App/ClubOpsGovernanceSections.swift', 'Core/ClubOpsGovernancePresentation.swift', 'Resources/ClubOpsGovernance.xcstrings']:
            self.assertIn(path, project)
        self.assertIn('@testable import QuestifyCore', self.tests)
        self.assertNotIn('import SwiftUI', self.core)

    def test_catalog_is_complete_bilingual_and_covers_every_literal_key(self):
        self.assertEqual(self.catalog['sourceLanguage'], 'en'); self.assertEqual(self.catalog['version'], '1.0')
        strings = self.catalog['strings']
        for key, entry in strings.items():
            self.assertEqual(set(entry['localizations']), {'en', 'zh-Hans'}, key)
            for language in ['en', 'zh-Hans']:
                unit = entry['localizations'][language]['stringUnit']
                self.assertEqual(unit['state'], 'translated'); self.assertTrue(unit['value'].strip(), key)
        ui = re.sub(r'\.accessibilityIdentifier\("(?:\\.|[^"\\])*"\)', '', self.ui)
        literal = set(re.findall(r'"(clubOpsGov\.[A-Za-z0-9_.]+)"', ui))
        integers = {'clubOpsGov.memberNumber', 'clubOpsGov.days'}
        interpolated = {m.group(1) + (' %lld' if m.group(1) in integers else ' %@')
                        for m in re.finditer(r'Text\("(clubOpsGov\.[A-Za-z0-9_.]+) \\\(', ui)}
        self.assertGreaterEqual(len(interpolated), 12)
        for key in literal | interpolated:
            if key.endswith('.') or key.endswith('_'):
                continue
            self.assertTrue(key in strings, key)
        for prefix, suffixes in [('clubOpsGov.banStatus.', ['ACTIVE', 'EXPIRED', 'UNBANNED']), ('clubOpsGov.caseStatus.', ['PENDING', 'APPROVED', 'REJECTED']),
                                 ('clubOpsGov.caseType.', ['APPEAL', 'REPORT_CLUB', 'REPORT_ACTIVITY', 'REPORT_MEMBER'])]:
            for suffix in suffixes: self.assertIn(prefix + suffix, strings)
        self.assertEqual(ui.count('tableName: "ClubOpsGovernance"') >= 10, True)

    def test_mini_program_copy_is_exact(self):
        expected = {
            'clubOpsGov.denied.title': '当前身份不能管理成员', 'clubOpsGov.denied.body': '仅主理人和管理员可用',
            'clubOpsGov.roles.denied.title': '当前身份不能管理角色', 'clubOpsGov.roles.denied.body': '仅主理人可分配角色',
            'clubOpsGov.roles.empty': '还没有可委派的成员', 'clubOpsGov.roles.emptyBody': '先邀请成员加入俱乐部，再为他们分配运营角色。',
            'clubOpsGov.members.empty': '暂无可治理成员', 'clubOpsGov.members.emptyBody': '成员加入后可在这里进行安全治理；历史记录也会保留。',
            'clubOpsGov.bans.empty': '暂无治理记录', 'clubOpsGov.cases.empty': '暂无已提交工单',
            'clubOpsGov.appeal.current': '封禁中的这条', 'clubOpsGov.appeal.empty': '当前没有可申诉的封禁',
            'clubOpsGov.appeal.emptyBody': '仅限期封禁可申诉',
            'clubOpsGov.appeal.note': '申诉由平台裁决。申诉通过后解封，需重新入会。',
            'clubOpsGov.banReason %@': '封禁原因：%@', 'clubOpsGov.unbanNote %@': '解封说明：%@', 'clubOpsGov.submittedAt %@': '提交于 %@',
            'clubOpsGov.decision %@': '平台说明：%@', 'clubOpsGov.banTarget %@': '成员「%@」', 'clubOpsGov.memberNumber %lld': '成员 #%lld',
            'clubOpsGov.until %@': '至 %@', 'clubOpsGov.platformPermanent': '平台永久封禁', 'clubOpsGov.platformOnly': '仅平台可解封',
            'clubOpsGov.timeUnknown': '时间未知', 'clubOpsGov.source.platform': '平台治理', 'clubOpsGov.source.club': '俱乐部治理',
            'clubOpsGov.banStatus.ACTIVE': '封禁中', 'clubOpsGov.banStatus.EXPIRED': '已到期', 'clubOpsGov.banStatus.UNBANNED': '已解封',
            'clubOpsGov.caseStatus.PENDING': '平台处理中', 'clubOpsGov.caseStatus.APPROVED': '已支持', 'clubOpsGov.caseStatus.REJECTED': '未支持',
            'clubOpsGov.caseType.APPEAL': '封禁申诉', 'clubOpsGov.caseType.REPORT_CLUB': '俱乐部举报', 'clubOpsGov.caseType.REPORT_ACTIVITY': '活动举报',
            'clubOpsGov.caseType.REPORT_MEMBER': '成员举报',
            'clubOpsGov.ban.title %@': '确认封禁 %@', 'clubOpsGov.ban.reasonHint': '填写封禁原因（必填）',
            'clubOpsGov.ban.consequence': '封禁后对方立即失去成员身份与群聊入口；解封只恢复申请资格，成员身份不会自动恢复。',
            'clubOpsGov.unban.reasonHint': '填写复核说明（可选）', 'clubOpsGov.transfer.title %@': '转让主理人给 %@',
            'clubOpsGov.transfer.hint': '转让后你将失去主理人权限', 'clubOpsGov.transfer.reasonHint': '填写交接原因（必填）',
            'clubOpsGov.report.note': '请提交可核实的事实。',
            'clubOpsGov.success.ban': '已封禁并移出俱乐部', 'clubOpsGov.success.unban': '已解除封禁', 'clubOpsGov.success.transfer': '主理人已转让',
            'clubOpsGov.success.case': '已提交平台处理', 'clubOpsGov.roles.success.assign': '角色已分配', 'clubOpsGov.roles.success.revoke': '角色已撤销',
            'clubOpsGov.roles.ownerSummary': '全部权限，不可撤销', 'clubOpsGov.roles.roleFallback': '角色', 'clubOpsGov.roles.until %@': ' · 至 %@',
            'clubOpsGov.roles.assign.title': '分配固定角色', 'clubOpsGov.roles.assign.caption': '选择成员后，从下方分配一个固定角色',
            'clubOpsGov.roles.footer': '撤销后立即生效',
            'clubOpsGov.roles.revoke.title %@': '撤销「%@」?', 'clubOpsGov.roles.revoke.body': '撤销后对方立即失去这个范围内的权限。',
            'clubOpsGov.roles.revoke.consequence1': '对方立刻失去该范围内的全部管理动作,进行中的操作会被打断',
            'clubOpsGov.roles.revoke.consequence2': '对方仍然是俱乐部成员,只是不再有这个角色',
            'clubOpsGov.roles.revoke.consequence3': '此操作不可撤销;要恢复只能重新分配一次角色',
            'clubOpsGov.days %lld': '%lld 天',
        }
        for key, value in expected.items(): self.assertEqual(self.zh(key), value, key)

    def test_banned_viewer_reads_only_own_cases(self):
        gate = 'if operation == .cases, accessReply["active"] == .bool(false), let clubID = accessReply["club"]["id"].int, clubID == scope.clubID {'
        branch = self.service.split(gate, 1)[1].split('}', 1)[0]
        self.assertIn('permissions: nil', branch)
        # The raw access reply is unvalidated only for this exact inactive-own-cases check; every other path validates it.
        self.assertIn('let accessReply = try await post(.access, scope: scope, options: [:], token: session.token, validating: false, check: check)', self.service)
        self.assertEqual(self.service.count('validating: false'), 1)
        self.assertLess(self.service.index(gate), self.service.index('let raw = try ClubGovernanceValidation.validate(accessReply, operation: .access, scope: scope)'))
        self.assertLess(self.service.index('let raw = try ClubGovernanceValidation.validate(accessReply, operation: .access, scope: scope)'), self.service.index('let access = try ClubGovernancePermissions(value: raw, scope: scope)'))
        self.assertEqual(self.service.count('permissions: nil'), 1)
        self.assertIn('guard operation == .cases, let ban = body.object?["activeBan"] else { return body["data"] }', self.service)
        self.assertIn('return validating ? try ClubGovernanceValidation.validate(payload, operation: operation, scope: scope) : payload', self.service)

    def test_active_ban_fact_and_appeal_review_fail_closed(self):
        self.assertIn('try require(Set(object.keys) == ["data", "activeBan"])', self.validation)
        self.assertIn('ban["clubId"].int == scope.clubID && ban["status"] == .string("ACTIVE")', self.validation)
        appeal = self.validation.split('if operation == .appeal {', 1)[1].split('} else if operation != .hostApply', 1)[0]
        for token in ['guard ban != ClubGovernanceValue.null else { throw ClubGovernanceFailure.forbidden }',
                      'if let p = snapshot.permissions { try authorize(p) } else { guard ban?.object != nil else { throw ClubGovernanceFailure.forbidden } }']:
            self.assertIn(token, appeal)
        self.assertIn('guard let p = snapshot.permissions else { throw ClubGovernanceFailure.forbidden }; try authorize(p)', self.validation)
        self.assertIn('guard operation == .appeal || source.snapshot.permissions != nil else { return }', self.cases)
        self.assertIn('(snapshot.permissions == nil && snapshot.value["activeBan"].object != nil)', self.cases)
        self.assertIn('public var canAppeal: Bool { if case .ban = appeal { return true }; return false }', self.core)

    def test_ban_body_sends_duration_days_7_30_90(self):
        self.assertIn('requiredKeys = ["targetMemberId", "reason", "requestId", "durationDays"]', self.commands)
        self.assertIn('guard let days = result["durationDays"]?.int, ClubGovernanceFormDraft.banDayChoices.contains(days)', self.commands)
        self.assertNotIn('expiresAtEpochMs', self.commands)
        self.assertNotIn('maximumClubBanMilliseconds', self.commands)
        self.assertIn('public static let banDayChoices = [7, 30, 90]', self.draft)
        self.assertIn('public static let defaultBanDays = 30', self.draft)
        self.assertIn('Self.banDayChoices.contains(days)', self.draft)
        self.assertIn('values["durationDays"] = .integer(days)', self.draft)
        self.assertNotIn('expiresAtEpochMs', self.draft)
        self.assertNotIn('expiresAt', text('Core/ClubGovernanceProduction.swift'))

    def test_unban_note_optional_and_revoke_note_fixed(self):
        self.assertIn('operation == .unban ? value.trimmingCharacters(in: .whitespacesAndNewlines).count <= 500', self.commands)
        self.assertIn('public static let revokeRoleReason = "主理人在角色管理页撤销"', self.draft)
        self.assertIn('case .revokeRole: text["reason"] = Self.revokeRoleReason', self.draft)
        self.assertIn('(route.operation != .ban || key != "banDays") && (route.operation != .revokeRole || key != "reason")', self.form)

    def test_views_route_every_action_through_existing_edit_gates(self):
        for token in ['ClubOpsRoleSection(roles: snapshot, context: readContext, access: access, assign: AnyView(edit(.assignRole)))',
                      'AnyView(edit(.revokeRole, seed: row.revokeSeed, role: .inlineDestructive))',
                      'ClubOpsBanSection(list: bans, scope: scope, capability: .init(permissions: snapshot.permissions, scope: scope), document: snapshot.value) { row in AnyView(edit(.unban, seed: row.unbanSeed ?? [:])) }',
                      'ban: { AnyView(edit(.ban, seed: $0.seed, role: .inlineDestructive)) }, transfer: { AnyView(edit(.transferOwner, seed: $0.seed, role: .inlineDestructive)) }',
                      'report: cases.canReport ? AnyView(edit(.report)) : nil, appeal: cases.canAppeal ? AnyView(edit(.appeal)) : nil',
                      'if failure == .forbidden { ClubOpsGovernanceDeniedNote(operation: operation, cases: scope.clubID == nil ? nil : AnyView(link(.cases))) }']:
            self.assertIn(token, self.views)
        for forbidden in ['coordinator.confirm', 'coordinator.prepare', '.send(', 'Approval(', 'URLRequest', 'UserDefaults']:
            self.assertNotIn(forbidden, self.ui); self.assertNotIn(forbidden, self.core)
        self.assertIn('if row.unbanSeed != nil { unban(row) }', self.ui)
        self.assertIn('unbanSeed: unbannable ? ["banId": row["id"], "version": row["version"]] : nil', self.core)
        self.assertIn('let unbannable = status == .active && source == .club', self.core)

    def test_roles_join_member_names_client_side_with_fallbacks(self):
        self.assertIn('access.read(.members, scope: expected.scope, options: [:], check: check)', self.ui)
        self.assertIn('ClubOpsRoleRoster(roles: roles, members: names.accepted(context))', self.ui)
        self.assertIn('if let members, members.operation == .members, members.scope == roles.scope', self.core)
        self.assertIn('Text("clubOpsGov.memberNumber \\(id)", tableName: "ClubOpsGovernance")', self.ui)
        self.assertIn('ClubOpsGovernanceCopy.text("clubOpsGov.roles.roleFallback")', self.ui)
        self.assertLess(self.ui.index('accessibilityIdentifier("clubOpsGov.roles.owner")'), self.ui.index('ForEach(roster.assignments)'))

    def test_success_copy_only_after_acknowledged_receipt(self):
        receipt = self.form.split('if let receipt {', 1)[1].split('.background {', 1)[0]
        self.assertIn('ClubOpsGovernanceSuccess(operation: route.operation)', receipt)
        self.assertEqual(self.form.count('ClubOpsGovernanceSuccess('), 1)
        self.assertIn('receipt = value; self.review = nil; locked = true', self.form)
        review = self.form.split('if let review {', 1)[1].split('Button(', 1)[0]
        self.assertIn('.filter { $0 != "expiresAtEpochMs" && ', review)
        self.assertIn('ClubOpsBanExpiryReview(fields: review.command.fields)', review)

    def test_localizable_copy_diffs_changed_in_fragment_and_catalog(self):
        catalog = json.loads(text('Resources/Localizable.xcstrings'))['strings']
        fragment = json.loads(text('Resources/ClubGovernanceLocalizations.fragment.json'))['strings']
        for key, zh in [('club.gov.assignments', '当前委派'), ('club.gov.action.revokeRole', '撤销')]:
            self.assertEqual(catalog[key], fragment[key])
            self.assertEqual(catalog[key]['localizations']['zh-Hans']['stringUnit']['value'], zh)


if __name__ == '__main__': unittest.main()
