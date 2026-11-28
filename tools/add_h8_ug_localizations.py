#!/usr/bin/env python3
"""Adds the H8 UG strings (hint ladder panel, score detail, picture options, whole-word guess, author hint ladder) to Resources/Localizable.xcstrings. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # UG-05..09 player hint ladder (pages/play/play-help.wxml + utils/play-help-panel.js)
    'playHelp.title': ('Hints', '提示'),
    'playHelp.open': ('Hints', '提示'),
    'playHelp.close': ('Close hints', '关闭提示'),
    'playHelp.freeLeft %lld': ('%lld free hints left this run', '本局剩余免费 %lld 次'),
    'playHelp.type.text': ('Text hint', '文字提示'),
    'playHelp.type.image': ('Picture hint', '图片提示'),
    'playHelp.type.letter': ('First letter', '首字'),
    'playHelp.type.digit': ('One digit', '一个数字'),
    'playHelp.type.answer': ('Answer', '答案'),
    'playHelp.type.skip': ('Skip this question', '跳过本题'),
    'playHelp.type.other': ('Hint', '提示'),
    'playHelp.review': ('View again', '重看'),
    'playHelp.gated': ('Open the one above first', '需先看上一层'),
    'playHelp.free': ('Free', '免费'),
    'playHelp.cost %lld': ('%lld points', '%lld 积分'),
    'playHelp.points %lld': ('%lld points', '%lld 积分'),
    'playHelp.unavailable': ('Unavailable', '暂不可用'),
    'playHelp.keepChecking': ('Keep checking', '继续核对'),
    'playHelp.pending': ('Result not confirmed yet', '结果待确认'),
    'playHelp.insufficient': ('Not enough points. This hint is still locked.', '积分不足，本层未解锁'),
    'playHelp.refused': ('This hint is unavailable right now', '本层暂不可用'),
    'playHelp.storageUnavailable': ("This device can't save the request, so nothing was sent", '无法保存原请求，暂不提交'),
    'playHelp.sending': ('Sending', '提交中'),
    'playHelp.view': ('View', '查看'),
    'playHelp.cancel': ('Cancel', '取消'),
    'playHelp.confirm.free': ('Free to view this time', '本次免费查看'),
    'playHelp.confirm.cost %lld': ('Viewing uses %lld points', '查看将消耗 %lld 积分'),
    'playHelp.charged %lld %lld': ('Used %1$lld points · %2$lld left', '消耗 %1$lld 积分 · 余 %2$lld'),
    'playHelp.chargedOnly %lld': ('Used %lld points', '消耗 %lld 积分'),
    'playHelp.skip': ('Skip this question', '跳过本题'),
    'playHelp.skip.confirm': ('Skip', '跳过'),
    'playHelp.skip.consequence': ('This question scores 0 and is marked as assisted.', '本题记 0 分并标辅助完成'),
    'playHelp.skip.refused': ("This question can't be skipped right now", '本题暂不能跳过'),
    'playHelp.skipped': ('Skipped · 0 points · assisted', '已跳过 · 记 0 分 · 辅助完成'),
    'playHelp.receipt': ('Score detail', '分数明细'),
    'playHelp.expanded': ('Expanded', '已展开'),
    'playHelp.collapsed': ('Collapsed', '已收起'),
    'playHelp.receipt.unavailable': ('Score detail is unavailable right now', '结算明细暂不可用'),
    'playHelp.receipt.question': ('This question', '本题'),
    'playHelp.receipt.score': ('Puzzle score', '解谜分'),
    'playHelp.receipt.notScored': ('Not scored', '本题不计分'),
    'playHelp.receipt.base': ('Puzzle score for this question', '本题解谜分'),
    'playHelp.receipt.bonus': ('Bonus', '加成'),
    'playHelp.receipt.helpDeduction': ('Hint deduction', '提示扣分'),
    'playHelp.receipt.skipDeduction': ('Skip deduction', '跳过扣分'),
    'playHelp.receipt.net': ('Score for this question', '本题得分'),
    'playHelp.receipt.points': ('Points used on hints', '提示消耗积分'),
    'playHelp.receipt.level %lld': ('Layer %lld', '第 %lld 层'),
    'playHelp.receipt.detail': ('Detail', '明细'),
    'playHelp.receipt.detailMissing': ('Detail to come', '明细待补'),
    'playHelp.receipt.skippedValue': ('Skipped · 0 points · assisted', '跳过 · 记 0 分 · 辅助完成'),
    'playHelp.receipt.revealedValue': ('Answer revealed, not solved yourself', '揭示答案，未自行解出'),
    # UG-02 picture options (pages/play/components/playkit-qa picGrid)
    'playkit.qa.pictureOption %@ %@': ('Option %1$@: %2$@', '选项 %1$@：%2$@'),
    # UG-01 whole-word answer
    'playkit.hangman.useWholeWord': ('Type the whole word instead', '改为整词作答'),
    'playkit.hangman.useCells': ('Fill the cells instead', '改为逐格作答'),
    'playkit.hangman.wholePlaceholder': ('Type the whole answer', '输入完整答案'),
    'playkit.hangman.wholeField': ('Whole-word answer', '整词作答输入框'),
    # UG-11 author hint ladder (pages/publish/temp/questo-author.js)
    'templateHint.enabled': ('Hints for this question', '本题启用提示'),
    'templateHint.freeUses': ('Free hints per run', '整局免费次数'),
    'templateHint.freeUses.placeholder': ('0', '0'),
    'templateHint.freeUses.note': ('One count shared by every question in the run. It does not reset per question.', '整局共用一个次数，切换题目不会重置。'),
    'templateHint.layer %lld': ('Layer %lld', '第 %lld 层'),
    'templateHint.removeLayer %lld': ('Remove layer %lld', '删除第 %lld 层'),
    'templateHint.addLayer': ('Add a layer', '添加一层'),
    'templateHint.type': ('Type', '类型'),
    'templateHint.type.text': ('Text', '文字'),
    'templateHint.type.image': ('Picture', '图片'),
    'templateHint.type.letter': ('First letter', '首字'),
    'templateHint.type.digit': ('Digit', '数字'),
    'templateHint.type.answer': ('Answer', '答案'),
    'templateHint.type.skip': ('Skip', '跳过'),
    'templateHint.points': ('Points', '消耗积分'),
    'templateHint.points.placeholder': ('Points (0 means free)', '消耗积分（0 表示免费）'),
    'templateHint.text.placeholder': ('Hint text', '提示文字'),
    'templateHint.answer.placeholder': ('Text shown with the answer (optional)', '揭晓时的文字（可不填）'),
    'templateHint.image.placeholder': ('Picture link', '提示图片地址'),
    'templateHint.letter.placeholder': ('Which character to reveal (default 1)', '揭示第几个字（不填为第 1 个）'),
    'templateHint.digit.note': ('Reveals one digit of the answer.', '揭示答案中的一个数字。'),
    'templateHint.skip.note': ('Skipping scores 0 and marks the question as assisted. On-site proof steps cannot be skipped.', '跳过记 0 分并标辅助完成；现场凭证类题目不能跳过。'),
    'templateHint.preview.note': ('Players see layers in this order. Each layer costs points only the first time it opens.', '玩家按这个顺序看到各层；每层只在第一次打开时消耗。'),
    'templateHint.validation.quota': ('Free hints must be a whole number from 0 to 1000', '免费次数须为 0 至 1000 的整数'),
    'templateHint.validation.quotaWithoutLadder': ('Free hints need at least one hint layer', '免费次数需要至少一层提示'),
    'templateHint.validation.tooMany': ('Up to 6 hint layers', '提示最多 6 层'),
    'templateHint.validation.type': ('Choose a hint type', '请选择提示类型'),
    'templateHint.validation.text': ('Write the hint text', '请填写提示文字'),
    'templateHint.validation.image': ('Add a hint picture', '请上传提示图片'),
    'templateHint.validation.imageURL': ('The picture link must be https or a site path', '图片地址须为 https 或站内路径'),
    'templateHint.validation.letter': ('The position must be a whole number from 1', '位置须为 1 起的整数'),
    'templateHint.validation.points': ('Points must be a whole number of 0 or more', '积分须为非负整数'),
}


# en-layout r3: English count strings vary by plural; the S value is the `other` form.
EN_ONE = {
    'playHelp.freeLeft %lld': '%lld free hint left this run',
    'playHelp.cost %lld': '%lld point',
    'playHelp.points %lld': '%lld point',
    'playHelp.confirm.cost %lld': 'Viewing uses %lld point',
    'playHelp.chargedOnly %lld': 'Used %lld point',
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


# Two-argument count: the first argument (points used) varies by plural through a substitution.
EN_SUBSTITUTED = {
    'playHelp.charged %lld %lld': {
        'stringUnit': {'state': 'translated', 'value': 'Used %#@points@ · %2$lld left'},
        'substitutions': {'points': {'argNum': 1, 'formatSpecifier': 'lld', 'variations': {'plural': {
            'one': {'stringUnit': {'state': 'translated', 'value': '%arg point'}},
            'other': {'stringUnit': {'state': 'translated', 'value': '%arg points'}}}}}},
    },
}


def english(key, en):
    if key in EN_SUBSTITUTED:
        return EN_SUBSTITUTED[key]
    if key in EN_ONE:
        return {'variations': {'plural': {'one': unit(EN_ONE[key]), 'other': unit(en)}}}
    return unit(en)


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': english(key, en), 'zh-Hans': unit(zh)}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} h8 UG strings written')


if __name__ == '__main__':
    main()
