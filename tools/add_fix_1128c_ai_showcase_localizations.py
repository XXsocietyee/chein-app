#!/usr/bin/env python3
"""fix/1128c-ai-showcase: home AI showcase, Create with AI, AI template fill and the AI safety precheck (en + zh-Hans).

The `aiShowcase.guide.*` entries are content: the guide's suggestion for today per weather slot. The owner revises
that copy here (or the ai-npc-guide branch serves its own reviewed line); no view holds the text.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Resources' / 'Localizable.xcstrings'

STRINGS = {
    # Home showcase (level B)
    'aiShowcase.eyebrow': ('AI guide · AI NPCs', 'AI 向导 · AI NPC'),
    'aiShowcase.title': ('Explore with your AI guide', '让 AI 向导陪你探索'),
    'aiShowcase.subtitle': ('Reviewed tips for where you are, NPCs with their own stories, and weather that changes the game.',
                            '按你所在的地方给出提示，NPC 各有故事，天气还会改变玩法。'),
    'aiShowcase.today': ("Today's suggestion", '今日建议'),
    'aiShowcase.nearbyNPC': ('AI NPC nearby', '附近的 AI NPC'),
    'aiShowcase.chatWith %@': ('Chat with %@', '和%@聊聊'),
    'aiShowcase.startGuide': ('Start AI guide', '开启 AI 向导'),
    'aiShowcase.startGuide.hint': ('Opens Roam, where the AI guide walks with you.', '打开漫游，AI 向导会陪你一起走。'),
    'aiShowcase.create': ('Create with AI', '用 AI 创作'),
    'aiShowcase.create.hint': ('Draft a route, fill a template or plan a club event with AI.', '用 AI 起草路线、填写玩法模板或策划俱乐部活动。'),
    'aiShowcase.disclosure': ('AI-generated. Lines are reviewed before they are shown.', '内容由 AI 生成，展示前已经过审核。'),
    'aiShowcase.weather.clear': ('Clear', '晴'),
    'aiShowcase.weather.cloudy': ('Cloudy', '多云'),
    'aiShowcase.weather.rain': ('Rain', '雨'),
    'aiShowcase.weather.snow': ('Snow', '雪'),
    'aiShowcase.weather.fog': ('Fog', '雾'),
    'aiShowcase.weather.wind': ('Windy', '有风'),
    'aiShowcase.weather.storm': ('Storm', '雷雨'),
    'aiShowcase.weather.sand': ('Dust', '沙尘'),
    # Content: the guide's suggestion for today, three per weather slot ("any" = no weather observed).
    'aiShowcase.guide.any.1': ('Pick a street you have never walked and let the map light up as you go.', '挑一条从没走过的街，边走边把地图点亮。'),
    'aiShowcase.guide.any.2': ('Start a short roam near you; the guide will point out what you pass.', '在附近开一段短漫游，向导会告诉你路过的地方有什么故事。'),
    'aiShowcase.guide.any.3': ('Collect one new stamp today and see who else has been there.', '今天收集一枚新印章，看看还有谁来过这里。'),
    'aiShowcase.guide.clear.1': ('Clear skies: a good day for a longer roam along the water.', '天气晴好，适合沿着水边走一段长一点的漫游。'),
    'aiShowcase.guide.clear.2': ('Sunny out. Try a city orienteering route and race the clock.', '阳光正好，试试一条城市定向路线，和时间赛跑。'),
    'aiShowcase.guide.clear.3': ('Bright light for photo tasks: find a route with a photo stop.', '光线很好，找一条带拍照任务的路线吧。'),
    'aiShowcase.guide.cloudy.1': ('Soft light and cool air: an easy day to explore a new neighbourhood.', '光线柔和、空气清爽，适合去一个新街区逛逛。'),
    'aiShowcase.guide.cloudy.2': ('Clouds overhead. A short loop with a café stop fits today.', '今天多云，走一小圈再找家咖啡店歇脚正合适。'),
    'aiShowcase.guide.cloudy.3': ('Good walking weather. Light up three new tiles on your map.', '很适合走路的天气，去地图上点亮三个新格子。'),
    'aiShowcase.guide.rain.1': ('Rain today: try a covered route through arcades and shops.', '今天有雨，试试穿过骑楼和商场的避雨路线。'),
    'aiShowcase.guide.rain.2': ('Wet streets glow at night. Some story nodes only open in the rain.', '雨后的街道很好看，有些剧情节点只在下雨时开放。'),
    'aiShowcase.guide.rain.3': ('Stay dry: pick an in-store game and chat with the shop NPC.', '别淋湿了，选一个店内玩法，和店里的 NPC 聊聊。'),
    'aiShowcase.guide.snow.1': ('Snow on the ground: short routes, warm stops, careful steps.', '下雪了，选短一点的路线，中途找个暖和的地方歇歇，注意脚下。'),
    'aiShowcase.guide.snow.2': ('A snowy city looks new. Revisit a favourite place and see it change.', '雪中的城市像换了个样子，回一个喜欢的地方看看。'),
    'aiShowcase.guide.snow.3': ('Cold out. An indoor route with a hot drink is a good plan.', '外面很冷，选条室内路线，再来杯热饮。'),
    'aiShowcase.guide.fog.1': ('Foggy today: stay on lit streets and let the guide lead the way.', '今天有雾，走灯光明亮的街道，跟着向导走。'),
    'aiShowcase.guide.fog.2': ('Fog hides the skyline. A good day for a mystery route.', '雾把天际线藏起来了，正适合一条悬疑路线。'),
    'aiShowcase.guide.fog.3': ('Low visibility: keep routes short and close to home.', '能见度低，路线选短一点、离家近一点。'),
    'aiShowcase.guide.wind.1': ('Windy out. Pick a sheltered route between buildings.', '今天风大，选一条有楼房挡风的路线。'),
    'aiShowcase.guide.wind.2': ('Wind on the water: watch the waves from a lakeside stop.', '风吹过水面，找个湖边的点位看看浪。'),
    'aiShowcase.guide.wind.3': ('Gusty today. Short hops between stamps work best.', '阵风比较多，在几个印章点之间短距离移动最合适。'),
    'aiShowcase.guide.storm.1': ('Storm warning: stay indoors. Plan tomorrow’s route instead.', '有雷雨，先待在室内，规划一下明天的路线吧。'),
    'aiShowcase.guide.storm.2': ('Thunder today. Try an in-store game and wait it out.', '今天打雷，先玩一个店内玩法，等雨停再出发。'),
    'aiShowcase.guide.storm.3': ('Bad weather outside. Draft your own route with AI while you wait.', '外面天气不好，趁这会儿用 AI 起草一条自己的路线。'),
    'aiShowcase.guide.sand.1': ('Dusty air today: keep the roam short and stay indoors between stops.', '今天有沙尘，漫游走短一点，点位之间尽量待在室内。'),
    'aiShowcase.guide.sand.2': ('Hazy skies. A good day for an in-store game or a museum route.', '天色朦胧，适合玩店内玩法或走一条博物馆路线。'),
    'aiShowcase.guide.sand.3': ('Wear a mask if you head out, and plan a longer route for a clearer day.', '出门记得戴口罩，长一点的路线留到天晴再走。'),
    # Create with AI (level C)
    'aiCreation.title': ('Create with AI', '用 AI 创作'),
    'aiCreation.entry.detail': ('Start from one sentence: AI drafts it, you review before anything is used.', '从一句话开始：AI 起草，你确认后才会使用。'),
    'aiCreation.section': ('Start with AI', '先用 AI 起个头'),
    'aiCreation.theme.title': ('Draft a route with AI', '用 AI 起草路线'),
    'aiCreation.theme.detail': ('Describe an idea; AI drafts the title, story and up to three stops.', '说出你的想法，AI 起草标题、故事和最多三个点位。'),
    'aiCreation.theme.unavailable': ('AI drafting is not available for this account yet.', '当前账号暂不能使用 AI 起草。'),
    'aiCreation.template.title': ('Fill a template with AI', '用 AI 填写玩法模板'),
    'aiCreation.template.detail': ('Name the venue and the idea; AI fills the task, hints and medal.', '填写场地和想法，AI 帮你写好任务、提示和勋章名。'),
    'aiCreation.club.title': ('Design a club event with AI', '用 AI 策划俱乐部活动'),
    'aiCreation.club.detail': ("Open your club's Manage tab and choose AI planning.", '在俱乐部的管理页里选择 AI 策划。'),
    'aiCreation.footer': ('AI suggestions are drafts. Nothing is published until you review it and publish it yourself.', 'AI 给出的只是草稿，经你确认并亲自发布后才会公开。'),
    'aiCreation.safety.section': ('Before you publish', '发布之前'),
    'aiCreation.safety.title': ('AI safety precheck', 'AI 安全预检'),
    'aiCreation.safety.detail': ('When a club host publishes, AI reads the copy for safety risks first. If AI is unavailable, publishing continues.',
                                 '俱乐部主理人发布时，AI 会先检查文案里的安全风险；AI 暂不可用时不影响发布。'),
    'aiCreation.undoDraft': ('Undo AI draft', '撤销 AI 草稿'),
    'aiCreation.signedOut.title': ('Sign in to create with AI', '登录后即可用 AI 创作'),
    'aiCreation.signedOut.body': ('AI drafts are saved to your account.', 'AI 草稿会保存在你的账号里。'),
    # AI template fill
    'aiTemplate.title': ('Fill template with AI', 'AI 填写模板'),
    'aiTemplate.request': ('What should players do?', '想让玩家做什么？'),
    'aiTemplate.request.footer': ('Only the venue name and your idea are sent to AI.', '只会把场地名称和你的想法发给 AI。'),
    'aiTemplate.venue': ('Venue name', '场地名称'),
    'aiTemplate.idea': ('Your idea', '你的想法'),
    'aiTemplate.more': ('More details', '更多细节'),
    'aiTemplate.category': ('Category', '类别'),
    'aiTemplate.reward': ('Reward', '奖励'),
    'aiTemplate.playStyle': ('Play style', '玩法风格'),
    'aiTemplate.generate': ('Fill with AI', '用 AI 填写'),
    'aiTemplate.retry': ('Try again', '再试一次'),
    'aiTemplate.working': ('AI is writing…', 'AI 正在撰写…'),
    'aiTemplate.failed': ('AI could not fill the template. Try again.', 'AI 没能完成填写，请再试一次。'),
    'aiTemplate.needsInput': ('Enter the venue name and your idea.', '请填写场地名称和你的想法。'),
    'aiTemplate.review': ('Review the AI suggestion', '确认 AI 建议'),
    'aiTemplate.reviewNotice': ('Check every line before you use it.', '使用前请逐条检查。'),
    'aiTemplate.apply': ('Use in the template editor', '填入模板编辑器'),
    'aiTemplate.discard': ('Discard', '不使用'),
    'aiTemplate.openEditor': ('Open the template editor', '打开模板编辑器'),
    'aiTemplate.undo': ('Undo AI fill', '撤销 AI 填写'),
    'aiTemplate.applied.footer': ('The suggestion is in your draft. Edit it, then submit it from the editor.', '建议已填入草稿，可以继续修改，再从编辑器提交。'),
    'aiTemplate.applyFailed': ('Finish or discard the saved template draft first, then try again.', '请先处理已保存的模板草稿，再试一次。'),
    'aiTemplate.field.title': ('Title', '标题'),
    'aiTemplate.field.description': ('Description', '描述'),
    'aiTemplate.field.ruleInstructions': ('Task', '任务说明'),
    'aiTemplate.field.questionName': ('Question', '题目'),
    'aiTemplate.field.questionAnswer': ('Answer', '答案'),
    'aiTemplate.field.hint1': ('Hint 1', '提示 1'),
    'aiTemplate.field.hint2': ('Hint 2', '提示 2'),
    'aiTemplate.field.storyText': ('Story', '剧情'),
    'aiTemplate.field.feedbackText': ('Feedback', '完成反馈'),
    'aiTemplate.field.medalName': ('Medal name', '勋章名'),
    # AI safety precheck (H-08b)
    'aiSafety.title': ('AI safety precheck', 'AI 安全预检'),
    'aiSafety.footer': ('Runs when you tap Next. If AI is unavailable, publishing continues.', '点「下一步」时运行；AI 暂不可用时不影响发布。'),
    'aiSafety.idle': ('Not run yet', '尚未预检'),
    'aiSafety.running': ('Running the safety precheck…', '安全预检中…'),
    'aiSafety.passed': ('No issues found', '未发现问题'),
    'aiSafety.skipped.quota': ('AI uses are used up for today. The precheck was skipped; publishing is not affected.',
                               'AI 次数已用完，本次跳过安全预检（不影响发布）。'),
    'aiSafety.skipped.unavailable': ('The safety precheck is unavailable. It was skipped; publishing is not affected.',
                                     '安全预检暂不可用，本次跳过（不影响发布）。'),
    'aiSafety.blocked.title': ('Fix before publishing', '发布前请先修改'),
    'aiSafety.blocked.footer': ('AI found content that may be unsafe. Edit it, then tap Next again.', 'AI 发现了可能有安全风险的内容，修改后再点「下一步」。'),
    'aiSafety.blocked.keepEditing': ('Keep Editing', '继续修改'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in STRINGS.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
