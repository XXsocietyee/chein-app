import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// MP `roam-place-note` (subpackageRoam/components/roam-place-note/index.js) plus `placeNoteForTags`
/// (subpackageRoam/utils/roam-city-catalog.js:27-36): a place whose tags carry the import seed
/// `roam:seed:v1:<catalog id>` gets the catalog's checked reason and its source links. No seed, or a seed
/// the catalog does not know, gives nothing (never matched by name or address).
struct RoamPlaceNote: Equatable {
    let reason: String
    let sources: [String]

    static let seedPrefix = "roam:seed:v1:"

    /// `/api/roam/pois` tags arrive as a JSON array string split on commas; brackets and quotes are trimmed first.
    static func cleaned(_ tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "[]\"' "))
    }

    static func seedID(in tags: [String]) -> String? {
        for tag in tags {
            let value = cleaned(tag)
            if value.hasPrefix(seedPrefix) {
                let id = String(value.dropFirst(seedPrefix.count))
                if !id.isEmpty { return id }
            }
        }
        return nil
    }

    static func lookup(tags: [String]) -> RoamPlaceNote? {
        guard let id = seedID(in: tags) else { return nil }
        guard let place = RoamCityGuideCatalog.places.first(where: { $0.id == id }) else { return nil }
        return RoamPlaceNote(reason: place.reason, sources: RoamCityGuideSources.byID[id] ?? [])
    }

    /// MP `tagList`: the seed marker is import data, not a label the player reads.
    static func visibleTags(_ tags: [String]) -> [String] {
        tags.map { cleaned($0) }.filter { !$0.isEmpty && !$0.hasPrefix(seedPrefix) }
    }
}

/// MP entry-place sheet / pace card (pages/roam/index.wxml:57-63, 397-402): the reason quote, then a folded
/// 资料来源 row whose 来源 N links copy the URL (MP `copyEntrySource`). Native: `DisclosureGroup` for 展开 / 收起.
struct RoamPlaceNoteRows: View {
    let note: RoamPlaceNote
    @State private var sourcesOpen = false
    @State private var copied = false

    var body: some View {
        Text(LocalizedStringKey(note.reason))
            .font(.body.italic())
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("roam.placeNote.reason")
        if !note.sources.isEmpty {
            DisclosureGroup(isExpanded: $sourcesOpen) {
                ForEach(note.sources.indices, id: \.self) { index in
                    Button {
                        copy(note.sources[index])
                    } label: {
                        Label("roam.placeNote.source \(index + 1)", systemImage: "link")
                    }
                    .accessibilityHint(Text("roam.placeNote.copyHint"))
                    .accessibilityIdentifier("roam.placeNote.source.\(index + 1)")
                }
                if copied {
                    Text("roam.placeNote.copied")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text("roam.placeNote.sources")
            }
            .accessibilityIdentifier("roam.placeNote.sources")
        }
    }

    private func copy(_ url: String) {
        #if canImport(UIKit)
        UIPasteboard.general.setItems([["public.utf8-plain-text": url]], options: [.localOnly: true])
        #endif
        copied = true
    }
}

/// Source links of `subpackageRoam/data/roam-city-catalog.js` v1 (`places[].sources`), keyed by catalog id.
/// Generated from the MP data file next to `RoamCityGuideCatalog`; do not hand-edit.
enum RoamCityGuideSources {
    static let byID: [String: [String]] = [
        "sh-shanyin-road": ["https://touch.shio.gov.cn/jsp/whjljd_detail.jsp?id=89", "https://www.shhk.gov.cn/qyfwy/030002/030002002/030002002002/20181206/7cc9807d-1b83-42ec-8803-c81449ed54c5.html"],
        "sh-luxun-park": ["https://www.shanghai.gov.cn/nw17239/20260821/437444e8364445a1a88082f9fbca30b3.html", "https://ditu.amap.com/place/B00155KZKW"],
        "sh-uchiyama-books": ["https://www.chinawriter.com.cn/n1/2026/0826/c403994-40786320.html", "https://whlyj.sh.gov.cn/gqfc/20240828/c93b4408b6ee4268a338c0c794a29a0a.html"],
        "bj-zhuanta-hutong": ["https://www.visitbeijing.com.cn/article/4LblHd9FikI", "https://www.beijing.gov.cn/renwen/rwzyd/qxdw/jxndqcqx/zhyshj/202309/t20230918_3261515.html"],
        "bj-wanshou-park": ["https://yllhj.beijing.gov.cn/ggfw/bjsggml/zhgy/xcq/202206/t20220614_2740270.shtml", "https://you.ctrip.com/sight/beijing1/112123.html"],
        "bj-zhengyang-books": ["https://www.beijing.gov.cn/renwen/rwzyd/qxdw/jxndqcqx/zhyshj/202309/t20230918_3261515.html", "https://www.nationalreading.gov.cn/ydkj/202512/t20251222_943225.html"],
        "hz-mantoushan": ["https://www.zjucce.zju.edu.cn/zh-cn/jiedaoshequkaocha/124519.html", "https://hznews.hangzhou.com.cn/chengshi/content/2023-04/21/content_8517676.htm"],
        "hz-chengbei-park": ["https://z.hangzhou.com.cn/2023/zjyl/content/content_8651963.html", "https://ditu.amap.com/place/B023B09Y7Q"],
        "hz-silk-museum": ["https://www.chinasilkmuseum.com/gwgk/info_4.aspx?itemid=8790", "https://www.amap.com/place/B023B09JLL"],
        "cd-tangba-street": ["https://www.nbd.com.cn/articles/2019-04-29/1326718.html", "https://ditu.amap.com/place/B0FFH6JHJ6"],
        "cd-wangjiang-park": ["https://www.wangjianglou.com/about.html", "https://ditu.amap.com/place/B001C06R0O"],
        "cd-a4-museum": ["https://www.a4artmuseum.com/about-us/contact/", "https://you.ctrip.com/sight/chengdu104/140776071.html"],
        "xa-banpo-art": ["https://big5.cri.cn/gate/big5/sn.cri.cn/n/20180424/5fbab288-509d-90b8-ac21-7b63bd259273.html", "https://you.ctrip.com/sight/xian7/1475462.html"],
        "xa-xicheng-park": ["https://xadfz.xa.gov.cn/xadq/dqtk/63edda39f8fd1c4c21407585.html", "https://you.ctrip.com/sight/xian7/121516.html"],
        "xa-shaanxi-art": ["https://www.sxpam.com.cn/html/content/index.html", "https://www.amap.com/place/B001D04JH6"],
        "cq-sujia-trail": ["https://cq.gov.cn/zwgk/zfxxgkml/zdlyxxgk/ggwh/ly/zxdt/202605/t20260520_15691032.html", "https://cq.people.com.cn/n2/2022/0701/c365401-40019120-3.html"],
        "cq-pingdingshan-park": ["https://www.cq.gov.cn/ywdt/jrcq/202202/t20220203_10369346.html", "https://www.amap.com/place/B00170I04F"],
        "cq-jiaotong-tea": ["https://www.cqjlp.gov.cn/zwxx/qxdt/202606/t20260618_15763966.html", "https://ditu.amap.com/place/B001790I1V"],
        "sz-oct-loft": ["https://www.szns.gov.cn/mlns/nsgk_113865/lechuang/content/post_3780578.html", "https://wtl.sz.gov.cn/ggfw/whl/whcyyqlyb/index.html"],
        "sz-xiangmi-park": ["https://cgj.sz.gov.cn/xsmh/gysz/twf/etly/content/post_10841297.html", "https://www.amap.com/place/B0FFG1V706"],
        "sz-hexiangning-art": ["https://www.sz.gov.cn/szzt2010/szwtt/wtcg/whcg/content/mpost_11131257.html", "https://www.amap.com/place/B02F30248A"],
        "gz-xinhepu": ["https://www.yuexiu.gov.cn/zjyx/yxjd/bgjq/content/post_8665420.html", "https://sthjj.gz.gov.cn/mlzg/sfyb/mlxb/content/post_10696347.html"],
        "gz-xiaogang-park": ["https://www.haizhu.gov.cn/hzdt/ztlm/tzhz/rjhj/lyjd/smgy/content/post_9055133.html", "https://www.amap.com/place/B00140UFR2"],
        "gz-kuiyuan-art": ["https://www.gzass.gd.cn/whzc/wenhuasheshi/wenhuachangguan/326.html", "https://www.amap.com/place/B00141KR0X"],
        "wh-qingdao-road": ["https://wlj.wuhan.gov.cn/whly/wbsy/202201/t20220112_1894179.shtml", "https://news.cjn.cn/whpd/lbt_19946/202508/t5194738.htm"],
        "wh-jiefang-park": ["https://ylj.wuhan.gov.cn/zwgk/zwxxgkzl_12298/jggk_12304/xsdwszjzz_12308/202001/t20200110_726396.shtml", "https://ditu.amap.com/place/B001B0IZT0"],
        "wh-united-art": ["https://wlt.hubei.gov.cn/zfxxgk/fdzdgknr/gysyjs/ggwhfw/ggmsg/202011/t20201102_2994450.shtml", "https://you.ctrip.com/sight/wuhan145/69376375.html"],
        "hk-tai-nan-street": ["https://www.discoverhongkong.com/tc/place-to-go/travel.guide-tai-nan-street.html", "https://www.td.gov.hk/tc/traffic_notices/index_id_79034.html"],
        "hk-cattle-depot-park": ["https://www.lcsd.gov.hk/sc/parks/cdap/index.html", "https://www.archsd.gov.hk/sc/exhibition/8254_Revitalisation_of_the_Rear_Portion_of_the_Cattle_Depot.html"],
        "hk-aco-books": ["https://www.aco.hk/aco-chi", "https://www.art-mate.net/tc/doc/44408?name=%E8%89%BA%E9%B5%A0%E6%9B%B8%E5%BA%97"],
        "xm-huaxin-road": ["https://www.hxfzzx.com/2026-05/06/content_2338096.htm", "https://news.xmnn.cn/xmxw/202607/t20260710_439108.html"],
        "xm-zhonglun-park": ["https://you.ctrip.com/sight/xiamen21/119140.html", "https://www.amap.com/place/B025003JXK"],
        "xm-three-shadows": ["https://www.threeshadows.cn/cn/about/visit/", "https://you.ctrip.com/sight/xiamen21/2105373.html"],
    ]
}
