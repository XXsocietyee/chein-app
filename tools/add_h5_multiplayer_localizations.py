#!/usr/bin/env python3
"""Adds the H5 / U06 multiplayer strings (team seats, invitation deadline, blocker and rejection codes,
team duty, leave consequences) to Resources/Localizable.xcstrings. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # U06-01 seats (mini pages/team/utils/team-seats.js)
    'team.seats.paid': ('Holding valid', '持有效票'),
    'team.seats.missing': ('Ticket no longer', '票已失效'),
    'team.seats.pending': ('Applications', '待审申请'),
    'team.seats.available': ('Seats still open', '还可加入'),
    'team.invite.expires %@': ('Invite valid %@', '%@ 到期'),
    # U06-01 /info viewer blockers (hints only)
    'team.blocker.NOT_SIGNED_IN': ('Sign in to join this team.', '登录后才能加入队伍'),
    'team.blocker.ALREADY_JOINED': ("You're already in team.", '你已在队伍中'),
    'team.blocker.APPLY_REJECTED': ("You can't rejoin this team.", '你的申请已被拒绝'),
    'team.blocker.TEAM_FULL': ('This team full.', '队伍已满'),
    'team.blocker.TEAM_UNDER_REVIEW': ('Team under review.', '队伍审核中'),
    'team.blocker.APPLY_BLOCKED': ("You can't join this team right now.", '暂时不能加入这支队伍'),
    'team.blocker.TICKET_REQUIRED': ('You need a ticket for session first.', '需要先买这一场的票'),
    'team.blocker.TEAM_NOT_PUBLIC': ("Team isn't recruiting.", '队伍不公开招募'),
    'team.blocker.APPLY_PENDING': ('Request.', '申请审核中'),
    'team.blocker.INVITE_UNAVAILABLE': ('Invite no longer.', '邀请已失效'),
    # U06-01 / U06-03 write rejections by errorCode
    'team.reject.NOT_SIGNED_IN': ('Sign in, then try again.', '请先登录后再试'),
    'team.reject.ALREADY_JOINED': ("You're already in this team. Refresh to see it.", '你已在队伍中，刷新即可查看'),
    'team.reject.APPLY_REJECTED': ("You can't join this team again with this link.", '你已被拒绝或移出，不能用这个链接再加入'),
    'team.reject.TEAM_FULL': ('The team filled up or stopped recruiting. Nothing changed; look for another team.', '队伍已满或已停止招募，没有加入；可以换一支队伍'),
    'team.reject.TEAM_UNDER_REVIEW': ("The team is under review isn't taking members.", '队伍审核中，暂不能加入'),
    'team.reject.APPLY_BLOCKED': ("You can't join this team right now.", '暂时无法加入该队伍'),
    'team.reject.TICKET_REQUIRED': ('You need a ticket for this session to join. Nothing was charged.', '持有这一场的票才能加入，没有产生任何扣费'),
    'team.reject.TEAM_NOT_PUBLIC': ("This team isn't recruiting publicly. Ask the captain for invite.", '队伍不公开招募，请向队长要邀请'),
    'team.reject.APPLY_PENDING': ('Your request already awaiting review.', '你的申请正在审核中'),
    'team.reject.INVITE_UNAVAILABLE': ('This invite is no longer valid. Ask the captain for new link.', '邀请已失效，请让队长重新分享'),
    'team.reject.INVITE_REVOKED': ('This invitation was replaced or withdrawn. Ask the captain for a new link.', '邀请已撤销或换码，请让队长重新分享链接'),
    'team.reject.INVITE_EXPIRED': ('This team is no longer recruiting. Look for another team.', '队伍已过招募期，可以换一支队伍'),
    'team.reject.TEAM_STATE_CHANGED': ('The team changed before this went through. Nothing changed; refresh and try again.', '队伍状态已变化，本次没有生效；请刷新后重试'),
    'team.reject.LEADER_HANDOVER_FAILED': ("Leadership couldn't be handed over, so you're still captain. Refresh and try again; during a run, ask on-site staff.", '队长移交失败，你仍是队长；请刷新后重试，游戏进行中请联系现场工作人员'),
    'team.reject.APPLY_STATE_CHANGED': ('The request changed before went through. Refresh try again.', '申请状态已变化，请刷新后重试'),
    'team.reject.APPLY_NOT_PENDING': ('This request already handled expired.', '申请已处理或已失效'),
    # U06-01 / U06-03 viewer relationship
    'team.viewer.captain': ('You are captain', '你是队长'),
    'team.viewer.member': ('You are a member', '你是队员'),
    'team.viewer.dutyScope': ('Captain is a team duty only. Story roles and host permissions are assigned separately.', '队长只是队伍职务，剧情角色和主持权限另行分配'),
    'team.viewer.application.PENDING': ('Your request is awaiting review.', '你的申请正在审核'),
    'team.viewer.application.EXPIRED': ('Your earlier application expired.', '你之前的申请已过期'),
    'team.viewer.application.QUIT': ('You left this team earlier.', '你之前退出过这支队伍'),
    'team.viewer.application.KICKED': ('You were removed from this team.', '你已被移出这支队伍'),
    'team.viewer.application.REJECTED': ('Your application was declined.', '你的申请未通过'),
    'team.viewer.application.WITHDRAWN': ('You withdrew your earlier application.', '你已撤回之前的申请'),
    # U06-03 leave consequences (mini utils/danger-actions.js team.quit / team.quit-leader)
    'team.leave.consequence.member': ("Leaving doesn't refund your ticket; it stays valid. You lose team-chat access, and rejoining needs a new invitation.", '退队不会同步退票，你的票仍然有效。你会失去队伍群聊入口，重新加入需要新的邀请。'),
    'team.leave.consequence.leader': ("Leaving doesn't refund your ticket; it stays valid. You lose team-chat access. Captain passes to the earliest-joined teammate; if you're the only one left, the team disbands. This can't be undone.", '退队不会同步退票，你的票仍然有效。你会失去队伍群聊入口；队长会移交给最早加入的队员，只剩你一人时队伍直接解散。此操作不可撤销。'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def append(path, keys, indent):
    """Appends only missing keys as text so the rest of the catalog keeps its formatting; never overwrites."""
    text = path.read_text(encoding='utf-8')
    existing = json.loads(text)['strings']
    blocks = []
    for key in keys:
        if key in existing:
            continue
        en, zh = S[key]
        entry = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
        body = json.dumps(entry, ensure_ascii=False, indent=indent).replace('\n', '\n    ')
        blocks.append('    ' + json.dumps(key, ensure_ascii=False) + ': ' + body)
    if blocks:
        tail = '\n  },\n  "version"'
        index = text.rindex(tail)
        text = text[:index] + ',\n' + ',\n'.join(blocks) + text[index:]
        json.loads(text)
        path.write_text(text, encoding='utf-8')
    return len(blocks)


def main():
    written = append(ROOT / 'Resources/Localizable.xcstrings', list(S), 2)
    # The team page catalog check reads its own fragment.
    fragment = append(ROOT / 'Resources/TeamLocalizations.fragment.json', [k for k in S if k.startswith('team.')], 4)
    print(f'{written} h5 multiplayer strings written; {fragment} added to the team fragment')


if __name__ == '__main__':
    main()
