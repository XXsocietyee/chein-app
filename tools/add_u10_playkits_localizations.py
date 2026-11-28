#!/usr/bin/env python3
"""Adds the U10 playkit strings (hangman, accusation, album, profile and preference paging) to Resources/Localizable.xcstrings. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # Shared UG write gate (UG-01 / UG-03 NOT_RUN)
    'playkit.questo.unavailable': ("This step can't be sent from this device yet. Nothing was submitted.", '这台设备暂时还不能提交这一步，什么都没有发送。'),
    # F103 pages/play/components/playkit-hangman
    'playkit.kind.hangman': ('Word guess', '逐字猜词'),
    'playkit.hangman.placeholder': ('Tap a cell and type with the keyboard', '点格子，用系统键盘输入'),
    'playkit.hangman.field': ('Word guess input', '逐字猜词输入框'),
    'playkit.hangman.wrong': ('Not quite. Look at the clue again.', '还不对，再看看题面'),
    'playkit.hangman.submit': ('Submit', '提交'),
    'playkit.hangman.continue': ('Continue', '继续'),
    'playkit.hangman.answer %@': ('Answer: %@', '答案：%@'),
    'playkit.hangman.cell %lld %@': ('Cell %1$lld: %2$@', '第 %1$lld 格：%2$@'),
    'playkit.hangman.cellEmpty %lld': ('Cell %lld: empty', '第 %lld 格：空'),
    # F104 pages/play/components/playkit-accusation
    'playkit.accusation.board': ('Clue board', '线索板'),
    'playkit.accusation.clue': ('Clue', '线索'),
    'playkit.accusation.clueLabel %@': ('Clue: %@', '线索：%@'),
    'playkit.accusation.wrong': ('Not this person. Keep investigating.', '还不是这个人，继续调查'),
    'playkit.accusation.next': ('Next suspect', '下一位'),
    'playkit.accusation.thinkAgain': ('Think again', '再想想'),
    'playkit.accusation.accuse %@': ('Accuse %@', '指认 %@'),
    'playkit.accusation.confirmTitle %@': ('This is your final accusation: %@', '这是最终指认：%@'),
    'playkit.accusation.someone': ('the chosen person', '所选人物'),
    'playkit.accusation.final': ("You can't change it after accusing", '指认后不能更改'),
    'playkit.accusation.confirm': ('Confirm accusation', '确认指认'),
    'playkit.accusation.collapse': ('Close', '收起'),
    'playkit.accusation.pending': ('Confirming the result', '结算确认中'),
    'playkit.accusation.solved': ('Case closed', '正常结案'),
    'playkit.accusation.early': ('Closed early', '提前结案'),
    'playkit.accusation.failed': ('Accusation failed', '指认失败'),
    'playkit.accusation.position %lld %lld': ('%1$lld of %2$lld', '第 %1$lld / %2$lld 位'),
    'playkit.accusation.endingImage': ('Ending image', '结局配图'),
    # F95 pages/play/components/playkit-album + album-glass
    'playkit.kind.album': ('Album', '相册'),
    'playkit.album.title': ('Album', '相册'),
    'playkit.album.close': ('Close album', '收起相册'),
    'playkit.album.locked': ("Photo submitted. The album is view-only and can't be changed.", '照片已提交，相册仅供查看，不能再更换'),
    'playkit.album.carousel': ('Album. Swipe to switch photos.', '相册，左右滑动切换'),
    'playkit.album.complete': ('Take or choose a photo to finish the album', '拍照或选择照片完成相册'),
    # F82 pages/play/components/playkit-profile one question at a time
    'playkit.profile.formTitle': ('Registration form', '登记表'),
    'playkit.profile.previous': ('Previous', '上一题'),
    'playkit.profile.next': ('Next', '下一题'),
    'playkit.profile.finish': ('Finish registration', '完成建档'),
    'playkit.profile.registered': ('Registered', '已登记'),
    'playkit.profile.placeholder': ('Write here', '写在这里'),
    'playkit.profile.required': ('Required', '必填'),
    'playkit.profile.stepCount %lld %lld': ('Question %1$lld of %2$lld', '第 %1$lld 题，共 %2$lld 题'),
    'playkit.profile.seal': ('All readings within range', '各项指标在范围内'),
    'playkit.profile.sealLabel': ('Record submitted. All readings within range.', '档案已提交，各项指标在范围内'),
    'playkit.profile.avatarOptional': ('Add a photo (optional)', '放张照片（可选）'),
    'playkit.profile.avatarRequired': ('Add a photo', '放一张照片'),
    # F46 pages/play preference quiz one step at a time
    'playx.preference.next': ('Next', '下一题'),
    'playx.preference.generate': ('Get my result', '生成我的结果'),
    'playx.preference.pickFirst': ('Pick the answer that fits you best first', '先选一个更像你的答案'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} u10 playkit strings written')


if __name__ == '__main__':
    main()
