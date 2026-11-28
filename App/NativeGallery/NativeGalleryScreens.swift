#if DEBUG
import SwiftUI

// Mock screens. Strings are the mini program's own labels, with fixture names and counts.
// Sources are listed in docs/release/receipts/cursor-native-gallery.md.

struct NativeGalleryHome: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("城瘾")
                        .font(.largeTitle)
                    Text("陈小北")
                        .font(.title3)
                    Text("玩家 · 杭州")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                NativeGalleryHero(
                    eyebrow: "编辑精选",
                    title: "西湖夜游漫步",
                    detail: "编辑精选 · 参加条件以详情为准"
                )
                sectionTitle("附近活动")
                NativeGalleryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("良渚秋日探索")
                                .font(.headline)
                            Spacer()
                            NativeGalleryTag(text: "进行中", kind: .success)
                        }
                        Text("杭州 · 集合点见活动详情")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        NativeGalleryBorderedButton(title: "查看详情")
                    }
                }
                sectionTitle("即将上线")
                NativeGalleryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("钱塘江夜跑")
                                .font(.headline)
                            Spacer()
                            NativeGalleryTag(text: "即将开始", kind: .warning)
                        }
                        Text("长期开放")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                sectionTitle("主题")
                Text("暂时没有更多主题。没有更多了。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(NativeGalleryPaint.margin)
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryTabBar(selected: .home) }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }
}

struct NativeGallerySquare: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("即将开始")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("良渚秋日探索")
                        .font(.headline)
                    Text("今晚 19:00 · 杭州")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                squarePost(
                    name: "城瘾玩家",
                    meta: "Lv.7 · 2小时前",
                    body: "河坊街茶韵线走完了。夜色比封面还静，集合点就在巷口。"
                )
                squarePost(
                    name: "林晚",
                    meta: "俱乐部 · 昨天",
                    body: "钱塘夜色本周公开加入。想一起走西湖夜游的，评论里留个座位。"
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("动态")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryTabBar(selected: .square) }
    }

    private func squarePost(name: String, meta: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
            Text(meta)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(body)
                .font(.body)
            HStack(spacing: 16) {
                Text("点赞 12")
                Text("评论 3")
                Text("收藏")
                Text("转发")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

struct NativeGalleryPlayTab: View {
    var body: some View {
        List {
            Section("可玩") {
                playRow("西湖夜游漫步", "城市定向 · 约 90 分钟", tag: "试玩", kind: .accent)
                playRow("大运河灯火巡礼", "自由探索 · 约 60 分钟", tag: "长期开放", kind: .info)
                playRow("河坊街茶韵线", "节点玩法 · 杭州", tag: "即将开始", kind: .warning)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("玩法")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryTabBar(selected: .play) }
    }

    private func playRow(_ title: String, _ detail: String, tag: String, kind: NativeGalleryTagKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                NativeGalleryTag(text: tag, kind: kind)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NativeGalleryProminentButton(title: "开始游玩")
        }
        .padding(.vertical, 4)
    }
}

struct NativeGalleryClubTab: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("创建你自己的俱乐部")
                        .font(.headline)
                    NativeGalleryBorderedButton(title: "创建俱乐部")
                }
                .padding(.vertical, 4)
            }
            Section("俱乐部") {
                clubRow("钱塘夜色", "我创建的 · 128 名成员 · 杭州")
                clubRow("清河坊茶社", "我加入的 · 46 名成员 · 公开加入")
                clubRow("良渚同行", "同城其他俱乐部 · 需审核加入")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryTabBar(selected: .club) }
    }

    private func clubRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("打开俱乐部主页")
    }
}

struct NativeGalleryTopicDetail: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NativeGalleryHero(
                    eyebrow: "城市定向",
                    title: "西湖夜游漫步",
                    detail: "陈小北 发布 · 杭州"
                )
                HStack(spacing: 8) {
                    NativeGalleryTag(text: "试玩", kind: .accent)
                    Text("试玩期，玩家照常可玩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("从断桥走到河坊街。夜色、茶香和一组需要走到点上才揭开的谜。")
                    .font(.body)
                NativeGalleryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("出发前")
                            .font(.headline)
                        fact("价格与包含", "¥68.00")
                        fact("同票人数", "2 人")
                        fact("通关所得", "印章 1 · 积分 80")
                    }
                }
                Picker("栏目", selection: .constant(0)) {
                    Text("详情").tag(0)
                    Text("路线节点").tag(1)
                    Text("路线").tag(2)
                }
                .cyAdaptiveSegmented()
                Text("还没有人评价过这条路线")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NativeGalleryProminentButton(title: "立即报名")
                NativeGalleryBorderedButton(title: "收藏主题")
            }
            .padding(NativeGalleryPaint.margin)
        }
        .navigationTitle("主题详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fact(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }
}

struct NativeGalleryActivityDetail: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("良渚秋日探索")
                            .font(.title3)
                        Spacer()
                        NativeGalleryTag(text: "进行中", kind: .success)
                    }
                    Text("城市探索 · 杭州")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                LabeledContent("已报名") {
                    Text("18 人").font(.body).monospacedDigit()
                }
                LabeledContent("集合点") {
                    Text("良渚古城遗址公园").font(.body)
                }
                LabeledContent("分类") {
                    Text("城市定向").font(.body)
                }
            }
            Section("关于这场活动") {
                Text("主理人带队走良渚。未核销报名可按规则退款。")
                    .font(.body)
                LabeledContent("主办方") {
                    Text("钱塘夜色").font(.body)
                }
                LabeledContent("发起人") {
                    Text("主理人").font(.body)
                }
            }
            Section("票种") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("普通票")
                        .font(.headline)
                    Text("¥68.00")
                        .font(.body)
                        .monospacedDigit()
                    Text("报名截止 11月30日 18:00")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                NativeGalleryProminentButton(title: "立即报名")
                NativeGalleryBorderedButton(title: "查看主题路线")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("活动详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryPlayPage: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("西湖夜游漫步")
                        .font(.title3)
                    Text("城市定向 · 试玩")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    NativeGalleryTag(text: "试玩", kind: .accent)
                }
            }
            Section("本局") {
                LabeledContent("本局用时") {
                    Text("48:20").font(.body).monospacedDigit()
                }
                LabeledContent("当前得分") {
                    Text("960").font(.body).monospacedDigit()
                }
                LabeledContent("同行者榜") {
                    Text("第 3 名").font(.body).monospacedDigit()
                }
                LabeledContent("延伸任务") {
                    Text("2").font(.body).monospacedDigit()
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扫码到达")
                        .font(.body)
                    Text("到站后扫现场的码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("背包与任务")
                    .font(.body)
                Text("回到故事")
                    .font(.body)
                Text("我的角色")
                    .font(.body)
                Text("各站奖励")
                    .font(.body)
            }
            Section {
                NativeGalleryProminentButton(title: "开始")
                NativeGalleryBorderedButton(title: "提示")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("游玩")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryClubHome: View {
    @State private var tab = 0

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("钱塘夜色")
                        .font(.title3)
                    Text("城市定向 · 128 名成员")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("公开加入")
                        .font(.subheadline)
                    NativeGalleryProminentButton(title: "加入俱乐部")
                }
                .padding(.vertical, 4)
            }
            Section {
                Picker("栏目", selection: $tab) {
                    Text("帖子").tag(0)
                    Text("活动").tag(1)
                    Text("概览").tag(2)
                    Text("管理").tag(3)
                }
                .cyAdaptiveSegmented()
            }
            if tab == 0 {
                Section("帖子") {
                    Text("暂无帖文")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("入会后可发布")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if tab == 1 {
                Section("活动") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("良渚秋日探索")
                            .font(.headline)
                        Text("未开始 · 良渚古城遗址公园")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        NativeGalleryBorderedButton(title: "邀约承接")
                    }
                    .padding(.vertical, 4)
                }
            } else if tab == 2 {
                Section("概览") {
                    Text("俱乐部对所有人开放浏览。")
                        .font(.body)
                }
            } else {
                Section("管理") {
                    Text("俱乐部管理")
                        .font(.body)
                    Text("返回俱乐部")
                        .font(.body)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("俱乐部主页")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryMerchant: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("清河坊茶馆")
                            .font(.title3)
                        Spacer()
                        NativeGalleryTag(text: "营业中", kind: .info)
                    }
                    Text("当前营业中，点击打烊")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("收入") {
                LabeledContent("累计收入") {
                    Text("¥12,480.00").cyText(.numericTitle)
                }
                Text("3 笔售后待回应")
                    .font(.subheadline)
            }
            Section("快捷操作") {
                HStack {
                    Text("扫码").frame(maxWidth: .infinity)
                    Text("客户").frame(maxWidth: .infinity)
                    Text("财务").frame(maxWidth: .infinity)
                    Text("更多").frame(maxWidth: .infinity)
                }
                .font(.body)
            }
            Section("项目") {
                VStack(alignment: .leading, spacing: 6) {
                    NativeGalleryTag(text: "12 张待核销", kind: .warning)
                    Text("西湖夜游漫步")
                        .font(.headline)
                    Text("承接 · 今日待办")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Text("完善品牌中心")
                    .font(.body)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("工作台")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryMerchantTabBar() }
    }
}

struct NativeGalleryMe: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("陈小北")
                        .font(.title3)
                    Text("Lv.7 城市探索者")
                        .font(.subheadline)
                    Text("杭州")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("连续探索：6天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    stat("12", "好友")
                    stat("36", "关注")
                    stat("128", "粉丝")
                }
            }
            Section {
                LabeledContent("我的订单") {
                    Text("2").font(.body).monospacedDigit()
                }
                LabeledContent("我的项目") {
                    Text("1").font(.body).monospacedDigit()
                }
                LabeledContent("我的资产") {
                    Text("¥128.50").font(.body).monospacedDigit()
                }
                LabeledContent("城瘾积分") {
                    Text("1,280").font(.body).monospacedDigit()
                }
                LabeledContent("总积分排名") {
                    Text("42").font(.body).monospacedDigit()
                }
            }
            Section("收集册") {
                Text("勋章")
                    .font(.body)
                Text("邮票")
                    .font(.body)
                Text("藏品")
                    .font(.body)
            }
            Section {
                Text("成长记录从第一次探索开始")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { NativeGalleryTabBar(selected: .me) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NativeGallerySettings: View {
    var body: some View {
        Form {
            Section {
                NavigationLink("个人资料") {
                    settingsDetail("个人资料", "陈小北 · 杭州")
                }
                NavigationLink("成为俱乐部主理人") {
                    settingsDetail("成为俱乐部主理人", "提交申请前请先阅读说明。")
                }
                NavigationLink("成为商家") {
                    settingsDetail("成为商家", "提交入驻申请。")
                }
                NavigationLink("城瘾玩法") { settingsDetail("城瘾玩法", "从首页主题进入一条路线。") }
                NavigationLink("我的收藏") { settingsDetail("我的收藏", "收藏过的主题会留在这里。") }
                NavigationLink("邀请与收益") { settingsDetail("邀请与收益", "邀请好友后在这里看收益。") }
                NavigationLink("隐私与定位") { settingsDetail("隐私与定位", "用于确定首页城市、到点打卡判定与漫游足迹记录。") }
                NavigationLink("AI 对话记录") { settingsDetail("AI 对话记录", "只保留你和店铺形象的对话。") }
                NavigationLink("营销消息与优惠券") { settingsDetail("营销消息与优惠券", "可以按商家分别关闭。") }
                NavigationLink("帖文处置与申诉") { settingsDetail("帖文处置与申诉", "查看处置结果和申诉进度。") }
                NavigationLink("投诉建议") { settingsDetail("投诉建议", "提交建议。") }
                NavigationLink("我的申诉") { settingsDetail("我的申诉", "申诉记录留在这里。") }
                NavigationLink("发票") { settingsDetail("发票", "按订单申请发票。") }
                NavigationLink("用户服务协议") { settingsDetail("用户服务协议", "协议在本页打开，不另跳。") }
                NavigationLink("账号注销") { settingsDetail("账号注销", "注销不可恢复。退出账号可以随时再登录。") }
                NavigationLink("关于") { settingsDetail("关于", "城瘾") }
            }
            Section {
                NativeGalleryBorderedButton(title: "退出账号")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsDetail(_ title: String, _ body: String) -> some View {
        Form {
            Section {
                Text(body)
                    .font(.body)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryLobby: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("西湖夜游漫步")
                        .font(.title3)
                    Text("城市定向 · 杭州")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                LabeledContent("以 陈小北 身份游玩") {
                    Text("编辑").font(.body)
                }
            }
            Section {
                HStack {
                    Text("一起玩的人")
                        .font(.headline)
                    Spacer()
                    Text("2/4")
                        .font(.body)
                        .monospacedDigit()
                    Text("邀请")
                        .font(.body)
                        .foregroundStyle(CYColor.brand)
                }
                LabeledContent("第1席") {
                    Text("房主").font(.body)
                }
                LabeledContent("第2席") {
                    Text("林晚").font(.body)
                }
                Text("第3席 空位")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("第4席 空位")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Section("怎么玩") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("城市定向")
                        .font(.headline)
                    Text("走到点上打卡")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("自由探索")
                        .font(.headline)
                    Text("不按顺序")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("已邀请") {
                HStack {
                    Text("第2席 · 剩余23小时")
                        .font(.body)
                        .monospacedDigit()
                    Spacer()
                    Text("撤回")
                        .font(.body)
                        .foregroundStyle(CYColor.dangerText)
                }
            }
            Section {
                NativeGalleryProminentButton(title: "去起点")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("开局大厅")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
