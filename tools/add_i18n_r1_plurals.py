#!/usr/bin/env python3
"""i18n r1 (locale lane): English plural variants for count strings ("1 stop" / "2 stops").

Only player/club keys (never merchant.*) whose English value has exactly one format argument, an
integer (`%lld`, `%ld`, `%d`, `%1$lld`), followed directly by a known plural noun are converted.
English becomes an Xcode plural variation (`one` / `other`); Chinese keeps its single stringUnit
(Chinese has no grammatical plural). Keys referenced literally by tools/ or Tests/ are skipped so
pinned contract checks keep reading a stringUnit. en-layout r3: a key spelled only in a docs/port/strings
fragment that round-trips byte for byte (same rule as add_i18n_r2_substitutions.py) is converted too, and
that fragment's English entry is updated so a later fragment merge does not revert it. Idempotent.

Usage: python3 -B tools/add_i18n_r1_plurals.py [--check]
  --check  exit 1 when a convertible key is still a plain stringUnit (ratchet for new count strings).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Resources/Localizable.xcstrings'

SINGULAR = {
    'activities': 'activity', 'applications': 'application', 'attempts': 'attempt', 'badges': 'badge',
    'cards': 'card', 'chapters': 'chapter', 'check-ins': 'check-in', 'cities': 'city', 'clubs': 'club',
    'clues': 'clue', 'comments': 'comment', 'coupons': 'coupon', 'days': 'day', 'endings': 'ending',
    'entries': 'entry', 'events': 'event', 'followers': 'follower', 'friends': 'friend', 'games': 'game',
    'hours': 'hour', 'invitations': 'invitation', 'items': 'item', 'likes': 'like', 'locations': 'location',
    'members': 'member', 'messages': 'message', 'minutes': 'minute', 'months': 'month', 'nodes': 'node',
    'notifications': 'notification', 'orders': 'order', 'participants': 'participant', 'passes': 'pass',
    'people': 'person', 'photos': 'photo', 'places': 'place', 'players': 'player', 'plays': 'play',
    'points': 'point', 'posts': 'post', 'questions': 'question', 'records': 'record', 'replies': 'reply',
    'requests': 'request', 'results': 'result', 'reviews': 'review', 'roams': 'roam', 'rounds': 'round',
    'routes': 'route', 'seats': 'seat', 'seconds': 'second', 'sessions': 'session', 'shops': 'shop',
    'spots': 'spot', 'stations': 'station', 'steps': 'step', 'stops': 'stop', 'tasks': 'task',
    'teams': 'team', 'themes': 'theme', 'tickets': 'ticket', 'times': 'time', 'topics': 'topic',
    'weeks': 'week', 'works': 'work', 'years': 'year', 'stamps': 'stamp', 'districts': 'district',
    'groups': 'group', 'runs': 'run', 'visits': 'visit', 'votes': 'vote', 'tries': 'try', 'winners': 'winner', 'pieces': 'piece',
}
# Keys where the matched word is a verb ("the invite for seat %lld stops working"), not a counted noun.
VERB_KEYS = {'mp.seats.cancel.message %lld'}
# Keys whose call site runs `String(format:)` on the resolved value; they stay plain stringUnits.
FORMAT_KEYS = {'club.settings.customerCount %lld'}
FRAGMENTS = 'docs/port/strings/'
# One-shot generators that seeded a key's first values: they compare nothing, so they do not pin it.
GENERATORS = ('tools/add_u9_cde_localizations.py',)


def stable_fragment(name):
    """A docs/port/strings JSON that json.dumps(indent=2) reproduces byte for byte can be rewritten without churn."""
    if not (name.startswith(FRAGMENTS) and name.endswith('.json')):
        return False
    try:
        text = (ROOT / name).read_text(encoding='utf-8')
        return json.dumps(json.loads(text), indent=2, ensure_ascii=False) + '\n' == text
    except (UnicodeDecodeError, OSError, ValueError):
        return False
# en-layout r3 run 35: converted by hand; their mentions elsewhere are list docs no tool merges, catalog-shaped
# port fragments updated to the same variations, or contract checks that read the plural `other` form.
UNPINNED = {
    '%lld 个点位', 'discovery.chapters %lld', 'globalSearch.resultsAnnounced %lld', 'passport.stamps.collected %lld',
    'official.summary.live %lld', 'official.summary.ended %lld', 'official.summary.mine %lld',
    'official.summary.upcoming %lld', 'official.detailParity.duration.days %lld', 'official.detailParity.duration.hours %lld',
    # Square counts: `docs/parity/w2-07-localizations.json` rows carry `en_one`, and build_w2_07 writes the variations.
    'square.xcx.commentsA11y %lld', 'square.xcx.likesA11y %lld', 'square.xcx.play.completedNodes %lld',
    # Builders that write `en_one` themselves (build_roam_private_tools_localizations, add_im_messaging_localizations).
    'roam.capsule.daysLeft %lld', 'roam.export.rows %lld', 'roam.goals.unit.routes %lld', 'roam.goals.unit.days %lld',
    'im.card.pointCount %lld', 'social.guideTemplates.playedTimes %lld', 'playerJourney.parity.countdown %lld',
    # EN_ONE in add_mp_drift / add_h8_ug / add_u10_screens; ClubStoryLocalizations fragment mirrors the catalog.
    '%lld 站',
    'club.story.stopCount %lld',
    'mpd.chapters.allSub %lld',
    'mpd.chapters.openSub %lld',
    'mpd.chapters.completedSub %lld',
    'mpd.chapters.lockedSub %lld',
    'playHelp.freeLeft %lld',
    'playHelp.cost %lld',
    'playHelp.points %lld',
    'playHelp.confirm.cost %lld',
    'playHelp.chargedOnly %lld',
    'playHelp.charged %lld %lld',
    'u10.template.summary.games %lld',
    'u10.template.summary.stops %lld',
}
# Families a contract check reads by prefix (Tests/ContractChecks/test_activity_registration_parity_w2_06.py).
PINNED_PREFIXES = ('activityParity.', 'registrationParity.')
ARG = re.compile(r'%(?:\d+\$)?(?:lld|ld|li|d|i|@|f|\.\d+f|u|llu|lu)')
INT_NOUN = re.compile(r'(%(?:\d+\$)?(?:lld|ld|li|d))(\s+)([A-Za-z][A-Za-z-]*)\b')


def pinned_keys():
    """Keys spelled anywhere in tools/, Tests/ or docs/ (contract checks, generators, fragments) stay plain stringUnits."""
    files = subprocess.run(['git', 'ls-files', '--', 'tools', 'Tests', 'docs', 'Resources/*.json'], cwd=ROOT, capture_output=True, text=True).stdout.split()
    blob = []
    for name in files:
        if name.endswith(('.py', '.json', '.swift', '.md', '.txt', '.xcstrings')) and name != 'tools/add_i18n_r1_plurals.py':
            if name == 'tools/add_i18n_r2_substitutions.py' or name in GENERATORS or stable_fragment(name):
                continue
            if name.startswith('docs/') and name.endswith('.md'):
                continue  # receipts and briefs only mention keys; they do not compare values
            try:
                blob.append((ROOT / name).read_text(encoding='utf-8'))
            except (UnicodeDecodeError, OSError):
                continue
    text = '\n'.join(blob)
    catalog = json.loads(CATALOG.read_text())['strings']
    escaped = lambda key: json.dumps(key, ensure_ascii=False)[1:-1]
    # Only count strings can be affected, so only their keys are searched (the blob is large).
    candidates = [key for key, entry in catalog.items() if 'variations' in entry['localizations'].get('en', {})
                  or INT_NOUN.search(entry['localizations'].get('en', {}).get('stringUnit', {}).get('value', ''))]
    return {key for key in candidates if key not in UNPINNED and (key in text or escaped(key) in text or key.startswith(PINNED_PREFIXES))}


def convertible(key, entry, pinned):
    if key.startswith('merchant') or key in pinned or key in VERB_KEYS or key in FORMAT_KEYS:
        return None
    en = entry.get('localizations', {}).get('en', {})
    unit = en.get('stringUnit')
    if not unit:
        return None
    value = unit.get('value', '')
    args = ARG.findall(value)
    if len(args) != 1:
        return None
    match = INT_NOUN.search(value)
    if not match or match.group(3).lower() not in SINGULAR:
        return None
    noun = match.group(3)
    singular = SINGULAR[noun.lower()]
    if noun[0].isupper():
        singular = singular[0].upper() + singular[1:]
    one = value[:match.start(3)] + singular + value[match.end(3):]
    return value, one


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    check = '--check' in sys.argv
    text = CATALOG.read_text()
    catalog = json.loads(text)
    pinned = pinned_keys()
    changed = []
    for key in VERB_KEYS | (pinned & set(catalog['strings'])):
        entry = catalog['strings'].get(key)
        en = entry and entry['localizations']['en'].get('variations')
        if en and not check:
            entry['localizations']['en'] = en['plural']['other']
    for key, entry in catalog['strings'].items():
        found = convertible(key, entry, pinned)
        if not found:
            continue
        other, one = found
        changed.append(key)
        if not check:
            entry['localizations']['en'] = {'variations': {'plural': {'one': unit(one), 'other': unit(other)}}}
    if check:
        if changed:
            print('FAIL plural variants missing for %d count string(s): %s' % (len(changed), ', '.join(changed[:10])))
            sys.exit(1)
        print('PASS plural variants: every convertible count string varies by plural')
        return
    if changed or not check:
        CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    touched = []
    files = subprocess.run(['git', 'ls-files', '--', FRAGMENTS], cwd=ROOT, capture_output=True, text=True).stdout.split()
    for name in files:
        if not changed or not stable_fragment(name):
            continue
        data = json.loads((ROOT / name).read_text())
        strings = data.get('strings') if isinstance(data.get('strings'), dict) else data
        edited = False
        for key in changed:
            if isinstance(strings.get(key), dict) and 'en' in strings[key].get('localizations', {}):
                strings[key]['localizations']['en'] = catalog['strings'][key]['localizations']['en']
                edited = True
        if edited:
            (ROOT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
            touched.append(name)
    print(json.dumps({'status': 'PLURALIZED', 'converted': len(changed), 'fragments': touched}))


if __name__ == '__main__':
    main()
