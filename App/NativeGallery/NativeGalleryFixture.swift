#if DEBUG
import SwiftUI

// DEBUG-only native iOS design gallery. Launch with `--design-fixture native-gallery`
// or `native-gallery-<slug>-light|dark|ax5`. Mock copy comes from the mini program.
// Product screens are not mounted here.

enum NativeGalleryMode {
    case light
    case dark
    case ax5

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var dynamicTypeSize: DynamicTypeSize { self == .ax5 ? .accessibility5 : .large }
}

enum NativeGalleryRoute {
    case index
    case page(slug: String, mode: NativeGalleryMode)
    case unknown

    static func parse(_ name: String) -> NativeGalleryRoute {
        if name == "native-gallery" { return .index }
        let prefix = "native-gallery-"
        guard name.hasPrefix(prefix) else { return .unknown }
        let rest = String(name.dropFirst(prefix.count))
        let mode: NativeGalleryMode
        let slug: String
        if rest.hasSuffix("-light") {
            mode = .light
            slug = String(rest.dropLast(6))
        } else if rest.hasSuffix("-dark") {
            mode = .dark
            slug = String(rest.dropLast(5))
        } else if rest.hasSuffix("-ax5") {
            mode = .ax5
            slug = String(rest.dropLast(4))
        } else {
            return .unknown
        }
        guard !slug.isEmpty else { return .unknown }
        return .page(slug: slug, mode: mode)
    }
}

enum NativeGalleryPaint {
    static let margin: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let heroRadius: CGFloat = 20

    static var action: Color { .accentColor }
}

enum NativeGalleryTagKind {
    case success
    case warning
    case danger
    case info
    case accent
}

struct NativeGalleryTag: View {
    let text: String
    let kind: NativeGalleryTagKind

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch kind {
        case .success:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        case .info:
            return .secondary
        case .accent:
            return .accentColor
        }
    }
}

struct NativeGalleryProminentButton: View {
    let title: String

    var body: some View {
        Button {} label: {
            Text(verbatim: title)
                .font(.body)
        }
        .buttonStyle(.borderedProminent)
        .tint(NativeGalleryPaint.action)
    }
}

struct NativeGalleryBorderedButton: View {
    let title: String

    var body: some View {
        Button {} label: {
            Text(verbatim: title)
                .font(.body)
        }
        .buttonStyle(.bordered)
        .tint(NativeGalleryPaint.action)
    }
}

enum NativeGalleryTab: String, CaseIterable, Identifiable {
    case home
    case square
    case play
    case club
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .square: return "动态"
        case .play: return "玩法"
        case .club: return "俱乐部"
        case .me: return "我的"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .square: return "square.grid.2x2"
        case .play: return "play.circle"
        case .club: return "person.3"
        case .me: return "person"
        }
    }
}

struct NativeGalleryTabBar: View {
    let selected: NativeGalleryTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NativeGalleryTab.allCases) { tab in
                VStack(spacing: 2) {
                    Image(systemName: tab.symbol)
                        .font(.body)
                    Text(tab.title)
                        .font(.caption)
                }
                .foregroundStyle(tab == selected ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(tab == selected ? "当前" + tab.title : "前往" + tab.title)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, NativeGalleryPaint.margin)
        .background(.bar)
    }
}

struct NativeGalleryMerchantTabBar: View {
    private let titles = ["工作台", "营销", "模板", "发现", "我的"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.caption)
                    .foregroundStyle(title == "工作台" ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, NativeGalleryPaint.margin)
        .background(.bar)
    }
}

struct NativeGalleryHero: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NativeGalleryCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NativeGalleryModeModifier: ViewModifier {
    let mode: NativeGalleryMode

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(mode.colorScheme)
            .environment(\.dynamicTypeSize, mode.dynamicTypeSize)
    }
}

struct NativeGalleryFixture: View {
    let route: String

    var body: some View {
        switch NativeGalleryRoute.parse(route) {
        case .index:
            NavigationStack { NativeGalleryIndex() }
                .accessibilityIdentifier(route)
        case .page(let slug, let mode):
            NavigationStack { NativeGalleryPage(slug: slug) }
                .modifier(NativeGalleryModeModifier(mode: mode))
                .accessibilityIdentifier(route)
        case .unknown:
            ContentUnavailableView("未知样张", systemImage: "questionmark", description: Text(route))
                .accessibilityIdentifier(route)
        }
    }
}

struct NativeGalleryIndex: View {
    var body: some View {
        List {
            Section("组件") {
                ForEach(NativeGalleryCatalog.components) { item in
                    NavigationLink {
                        NativeGalleryPage(slug: item.slug)
                    } label: {
                        indexRow(item.title, slug: item.slug)
                    }
                }
            }
            Section("页面") {
                ForEach(NativeGalleryCatalog.screens) { item in
                    NavigationLink {
                        NativeGalleryPage(slug: item.slug)
                    } label: {
                        indexRow(item.title, slug: item.slug)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("原生样张")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func indexRow(_ title: String, slug: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
            Text("native-gallery-" + slug)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct NativeGalleryEntry: Identifiable {
    let slug: String
    let title: String
    var id: String { slug }
}

enum NativeGalleryCatalog {
    static let components: [NativeGalleryEntry] = [
        NativeGalleryEntry(slug: "list-form", title: "分组列表与表单"),
        NativeGalleryEntry(slug: "cards", title: "卡片与主视觉"),
        NativeGalleryEntry(slug: "sheets", title: "半屏弹层"),
        NativeGalleryEntry(slug: "empty-error", title: "空态与错误"),
        NativeGalleryEntry(slug: "buttons", title: "系统按钮"),
        NativeGalleryEntry(slug: "confirm", title: "破坏性确认"),
        NativeGalleryEntry(slug: "status-tags", title: "状态标签"),
        NativeGalleryEntry(slug: "type-ramp", title: "字号阶梯")
    ]

    static let screens: [NativeGalleryEntry] = [
        NativeGalleryEntry(slug: "home", title: "首页"),
        NativeGalleryEntry(slug: "square", title: "动态"),
        NativeGalleryEntry(slug: "play-tab", title: "玩法"),
        NativeGalleryEntry(slug: "club-tab", title: "俱乐部"),
        NativeGalleryEntry(slug: "topic-detail", title: "主题详情"),
        NativeGalleryEntry(slug: "activity-detail", title: "活动详情"),
        NativeGalleryEntry(slug: "play", title: "游玩"),
        NativeGalleryEntry(slug: "club-home", title: "俱乐部主页"),
        NativeGalleryEntry(slug: "merchant", title: "工作台"),
        NativeGalleryEntry(slug: "me", title: "我的"),
        NativeGalleryEntry(slug: "settings", title: "设置"),
        NativeGalleryEntry(slug: "lobby", title: "开局大厅")
    ]
}

struct NativeGalleryPage: View {
    let slug: String

    var body: some View {
        Group {
            switch slug {
            case "list-form": NativeGalleryListForm()
            case "cards": NativeGalleryCards()
            case "sheets": NativeGallerySheets()
            case "empty-error": NativeGalleryEmptyError()
            case "buttons": NativeGalleryButtons()
            case "confirm": NativeGalleryConfirm()
            case "status-tags": NativeGalleryStatusTags()
            case "type-ramp": NativeGalleryTypeRamp()
            case "home": NativeGalleryHome()
            case "square": NativeGallerySquare()
            case "play-tab": NativeGalleryPlayTab()
            case "club-tab": NativeGalleryClubTab()
            case "topic-detail": NativeGalleryTopicDetail()
            case "activity-detail": NativeGalleryActivityDetail()
            case "play": NativeGalleryPlayPage()
            case "club-home": NativeGalleryClubHome()
            case "merchant": NativeGalleryMerchant()
            case "me": NativeGalleryMe()
            case "settings": NativeGallerySettings()
            case "lobby": NativeGalleryLobby()
            default:
                ContentUnavailableView("未知样张", systemImage: "questionmark", description: Text(slug))
            }
        }
        .accessibilityIdentifier("native-gallery-" + slug)
    }
}

struct NativeGalleryListForm: View {
    var body: some View {
        Form {
            Section("表单") {
                TextField("昵称", text: .constant("陈小北"))
                    .font(.body)
                Picker("城市", selection: .constant("杭州")) {
                    Text("杭州").tag("杭州")
                    Text("上海").tag("上海")
                }
                .font(.body)
                Toggle("到点提醒", isOn: .constant(true))
                    .font(.body)
            }
            Section("列表") {
                LabeledContent("累计收入") {
                    Text("¥12,480.00").font(.body).monospacedDigit()
                }
                LabeledContent("已报名") {
                    Text("18 人").font(.body).monospacedDigit()
                }
                LabeledContent("玩家") {
                    Text("陈小北").font(.body)
                }
            }
        }
        .navigationTitle("分组列表与表单")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryCards: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NativeGalleryHero(
                    eyebrow: "城瘾精选",
                    title: "西湖夜游漫步",
                    detail: "城市定向 · 杭州 · 约 90 分钟"
                )
                NativeGalleryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("良渚秋日探索")
                                .font(.headline)
                            Spacer()
                            NativeGalleryTag(text: "进行中", kind: .success)
                        }
                        Text("集合点 · 良渚古城遗址公园")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("¥68.00")
                            .font(.body)
                            .monospacedDigit()
                    }
                }
                NativeGalleryCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("钱塘夜色")
                            .font(.headline)
                        Text("公开加入 · 128 名成员")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(NativeGalleryPaint.margin)
        }
        .navigationTitle("卡片与主视觉")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGallerySheets: View {
    @State private var open = true

    var body: some View {
        Form {
            Section {
                Button("打开半屏") { open = true }
                    .font(.body)
            } footer: {
                Text("标准 sheet，可停在中档或大档。")
                    .font(.footnote)
            }
        }
        .navigationTitle("半屏弹层")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $open) {
            NavigationStack {
                Form {
                    Section("开局前准备") {
                        Text("西湖夜游漫步")
                            .font(.headline)
                        Text("同票 2 人。出发前请确认集合点与身份。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        NativeGalleryProminentButton(title: "开始游玩")
                        Button { open = false } label: {
                            Text(verbatim: "取消")
                                .font(.body)
                        }
                    }
                }
                .navigationTitle("开局前准备")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { open = false } label: {
                            Text(verbatim: "取消")
                                .font(.body)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct NativeGalleryEmptyError: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ContentUnavailableView(
                    "暂时没有主题",
                    systemImage: "map",
                    description: Text("编辑精选暂无内容。")
                )
                ContentUnavailableView {
                    Label("附近活动加载失败", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("请求失败。页面不再假装正在加载。")
                        .font(.body)
                } actions: {
                    NativeGalleryBorderedButton(title: "重试")
                }
            }
            .padding(NativeGalleryPaint.margin)
        }
        .navigationTitle("空态与错误")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryButtons: View {
    var body: some View {
        Form {
            Section("主要") {
                NativeGalleryProminentButton(title: "立即报名")
                NativeGalleryProminentButton(title: "去起点")
            }
            Section("次要") {
                NativeGalleryBorderedButton(title: "查看详情")
                NativeGalleryBorderedButton(title: "重试")
            }
        }
        .navigationTitle("系统按钮")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NativeGalleryConfirm: View {
    @State private var open = true

    var body: some View {
        Form {
            Section {
                Button("放弃本轮修改") { open = true }
                    .font(.body)
            } footer: {
                Text("红只留给不可逆动作。退出账号仍是中性按钮。")
                    .font(.footnote)
            }
        }
        .navigationTitle("破坏性确认")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("放弃本轮修改", isPresented: $open, titleVisibility: .visible) {
            Button("确认放弃", role: .destructive) {}
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("本轮修改会丢掉。")
        }
    }
}

struct NativeGalleryStatusTags: View {
    var body: some View {
        Form {
            Section("状态") {
                tagRow("进行中", .success)
                tagRow("即将开始", .warning)
                tagRow("已取消", .danger)
                tagRow("营业中", .info)
                tagRow("试玩", .accent)
            }
            Section {
                Text("选中页签用品牌色。成功、警告、危险、信息用状态色。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("状态标签")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tagRow(_ text: String, _ kind: NativeGalleryTagKind) -> some View {
        HStack {
            Text(text)
                .font(.body)
            Spacer()
            NativeGalleryTag(text: text, kind: kind)
        }
    }
}

struct NativeGalleryTypeRamp: View {
    private let rows: [(String, Font)] = [
        ("largeTitle", .largeTitle),
        ("title", .title),
        ("title2", .title2),
        ("title3", .title3),
        ("headline", .headline),
        ("body", .body),
        ("callout", .callout),
        ("subheadline", .subheadline),
        ("footnote", .footnote),
        ("caption", .caption)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.0)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("城瘾 · 西湖夜游漫步")
                            .font(row.1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NativeGalleryPaint.margin)
        }
        .navigationTitle("字号阶梯")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
