#!/usr/bin/env python3
"""fix/parity2-play-roam strings (audit docs/audit/parity/play-roam.md). Idempotent: re-running rewrites the same values."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

# key: (en, zh-Hans)
S = {
    # RCODE-2
    'roamSub.w208.voucher.network': ('Network error. Try again later.', '网络异常，请稍后重试'),
    'roamSub.w208.voucher.retry': ('Retry', '重试'),
    # RCODE-4: MP scene-qr-citynode short form (no ASCII comma in CJK)
    'roamSub.w208.voucher.desc': ('Show it to the merchant to scan and receive a coupon', '出示给商家扫码领券'),
    # RROUTE-3 / RROUTES-2: route copy into the catalog (noun 路线 kept until the owner glossary rules 线路/路线)
    'officialRoute.badge': ('Official route', '官方路线'),
    'officialRoute.openFirstStop': ('Open first stop in Maps', '在地图中打开起点'),
    'officialRoute.stat.duration': ('Duration', '用时'),
    'officialRoute.stat.distance': ('Distance', '距离'),
    'officialRoute.stat.stops': ('Stops', '站点'),
    # B3D-3 / B3D-4
    'badge3d.title': ('Badge', '徽章'),
    'badge3d.loading': ('Preparing the 3D badge…', '正在准备 3D 徽章…'),
    'badge3d.toggle.static': ('Static preview', '静态预览'),
    'badge3d.toggle.threeD': ('3D view', '3D 展台'),
    # BWALL-5
    'profile.badges.partial': ('Some badge data did not arrive; this list is incomplete', '部分勋章数据未到达，当前结果不完整'),
    # OCARDS-1: MP 藏品册
    'objects.title': ('Collection', '藏品册'),
    'objects.login': ('Sign in to view your collection', '登录后查看你的藏品'),
    # RSTAMP-4: per-step stamp failures (MP citystamp _failDeliver copy)
    'media.stamp.phase.failed.upload': ("The photo didn't upload. Try again.", '图没传上去，请重试一次'),
    'media.stamp.phase.failed.create': ("The stamp wasn't saved. Try again.", '没存上，请重试一次'),
    # JSEAT-7
    'mp.seats.unconfirmed': ('The result is not confirmed yet. Check again later.', '结果还没确认，请稍后查询'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        if key in strings and 'localizations' in strings[key]:
            # Existing key: replace the values only, keep the entry's other fields (and fragment mirrors) as they were.
            strings[key]['localizations']['en'] = unit(en)
            strings[key]['localizations']['zh-Hans'] = unit(zh)
        else:
            strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} parity2 play-roam strings written')


if __name__ == '__main__':
    main()
