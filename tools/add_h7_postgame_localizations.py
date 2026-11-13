#!/usr/bin/env python3
"""Adds the §九 U08 (cloud-h7) post-game strings to Resources/Localizable.xcstrings:
battle-report problem feedback (U08-02), private memory notes (U08-01), unranked-run note (U08-05)
and the neutral finish-screen title. zh copy follows the mini-program and the server messages. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # U08-01 finish screen: every stop done but no server result yet.
    'medalScreen.allDone': ('Every stop done', '全部站点已完成'),
    # U08-01 / P8 memory
    'mp.report.memory.private': ('Your photos stay private. Sharing publicly is a separate step.', '照片默认仅自己可见，公开分享需要单独操作'),
    'mp.report.memory.peerHidden': ("Companions' photos aren't shown without their consent.", '同行未授权，不展示他们的照片'),
    # U08-05 scoped board coverage
    'mp.rank.unverified %lld': ("%lld runs without a valid ticket aren't ranked", '%lld 局没有有效报名，未计入排名'),
    # U08-02 problem feedback
    'mp.feedback.entry': ('Report a problem', '反馈问题'),
    'mp.feedback.title': ('Report a problem', '反馈问题'),
    'mp.feedback.category': ('Type', '问题类型'),
    'mp.feedback.category.place': ('Place', '地点'),
    'mp.feedback.category.question': ('Puzzle', '题目'),
    'mp.feedback.category.other': ('Other', '其他'),
    'mp.feedback.node': ('Stop', '节点'),
    'mp.feedback.node.none': ('Not about one stop', '不针对某个节点'),
    'mp.feedback.text': ('What went wrong', '遇到的问题'),
    'mp.feedback.placeholder': ("Describe what happened. Don't include answers or personal details.", '说说遇到了什么，不要写答案或个人信息'),
    'mp.feedback.count %lld %lld': ('%lld / %lld', '%lld / %lld'),
    'mp.feedback.submit': ('Send', '提交'),
    'mp.feedback.sending': ('Sending…', '提交中…'),
    'mp.feedback.received': ("Received. It's linked to this run so the creator can trace it.", '已收到，已关联这一局，方便作者核对'),
    'mp.feedback.unconfirmed': ("We couldn't confirm it was sent. Check again: the same request is used, so it won't be sent twice.", '暂时无法确认是否已提交。再次核对会使用同一请求，不会重复提交'),
    'mp.feedback.recheck': ('Check again', '再次核对'),
    'mp.feedback.refused': ("Couldn't send", '没有提交成功'),
    'mp.feedback.another': ('Send another', '再反馈一条'),
    'mp.feedback.problem.empty': ('Write what happened', '请写下遇到的问题'),
    'mp.feedback.problem.tooLong': ('Keep it within 500 characters', '反馈不能超过 500 字'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    # Inserted as text after the "strings" opener so the rest of the catalog keeps its formatting.
    path = ROOT / 'Resources/Localizable.xcstrings'
    text = path.read_text(encoding='utf-8')
    existing = json.loads(text)['strings']
    chunks = []
    for key, (en, zh) in S.items():
        if key in existing:
            continue
        entry = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
        lines = json.dumps({key: entry}, ensure_ascii=False, indent=2).split('\n')[1:-1]
        chunks.append('\n'.join('  ' + line for line in lines))
    if chunks:
        marker = '  "strings": {\n'
        at = text.index(marker) + len(marker)
        text = text[:at] + ',\n'.join(chunks) + ',\n' + text[at:]
        json.loads(text)
        path.write_text(text, encoding='utf-8')
    print(f'{len(chunks)} h7 post-game strings written')


if __name__ == '__main__':
    main()
