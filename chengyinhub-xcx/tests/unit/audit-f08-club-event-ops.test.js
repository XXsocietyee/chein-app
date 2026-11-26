'use strict'
// AUDIT-1122 L08-062 / L08-063 / L08-072:俱乐部场次运营页行为测试
const test = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const PAGE = path.resolve(__dirname, '../../pages/club/event-ops/index.js')
let config
let requests
const toasts = []

function mount() {
  requests = []
  global.getApp = () => ({ globalData: {}, sendRequest: (o) => { requests.push(o) }, getUserID: () => 9001 })
  global.Page = (c) => { config = c }
  global.getCurrentPages = () => [{}, {}]
  global.wx = Object.assign({}, global.wx, {
    showToast: (o) => toasts.push(o && o.title), stopPullDownRefresh() {}, setNavigationBarTitle() {},
    getStorageSync: () => '', setStorageSync() {}, removeStorageSync() {}, navigateBack() {}, switchTab() {},
  })
  delete require.cache[PAGE]
  require(PAGE)
  const p = Object.assign({}, config)
  p.data = JSON.parse(JSON.stringify(config.data))
  p.setData = function (patch, cb) { Object.assign(this.data, patch); if (cb) cb.call(this) }
  return p
}
const take = (url) => {
  const i = requests.findIndex((r) => r.url === url)
  assert.ok(i >= 0, 'missing ' + url)
  return requests.splice(i, 1)[0]
}
const roster = (registered, arrived) => ({ code: 200, data: { registered, waitlist: [], arrived, noShow: [], phoneIncluded: false } })

test('L08-062 标记到场成功后名册后台刷新:不回骨架,刷新失败保留名册', () => {
  const p = mount()
  p.setData({ canCheckin: true, activityId: 32, clubId: 7, rosterTab: 'registered' })
  p.loadRoster()
  assert.equal(p.data.rosterState, 'loading', '首载用骨架')
  take('/api/club/event-ops/roster').success(roster([{ memberId: 1 }, { memberId: 2 }], []))
  assert.equal(p.data.rosterState, 'ready')
  p.submitCorrection(1, true, 0, '现场到达')
  take('/api/club/event-ops/attendance/correct').success({ code: 200, data: { id: 99 } })
  assert.equal(p.data.rosterState, 'ready', '写后刷新不许塌成骨架')
  assert.equal(p.data.activeRoster.length, 2)
  take('/api/club/event-ops/roster').success(roster([{ memberId: 2 }], [{ memberId: 1 }]))
  assert.deepEqual(p.data.activeRoster.map((r) => r.memberId), [2])
  p.submitCorrection(2, true, 0, '现场到达')
  take('/api/club/event-ops/attendance/correct').success({ code: 200, data: { id: 100 } })
  take('/api/club/event-ops/roster').fail()
  assert.equal(p.data.rosterState, 'ready', '后台刷新失败不把整段换成错误态')
  assert.deepEqual(p.data.activeRoster.map((r) => r.memberId), [2])
})

test('L08-062 名册迟到的旧回包不覆盖新回包', () => {
  const p = mount()
  p.setData({ canCheckin: true, activityId: 32, clubId: 7, rosterTab: 'registered' })
  p.loadRoster()
  p.loadRoster()
  const [first, second] = requests.filter((r) => r.url === '/api/club/event-ops/roster')
  second.success(roster([{ memberId: 5 }], []))
  first.success(roster([{ memberId: 1 }, { memberId: 2 }], []))
  assert.deepEqual(p.data.activeRoster.map((r) => r.memberId), [5])
})

test('L08-063 先展开 A 再展开 B:A 的迟到场次列表不写到 B 下', () => {
  const p = mount()
  p.setData({ clubId: 7, canManage: true })
  p.toggleSeriesDates({ currentTarget: { dataset: { seriesId: 11 } } })
  p.toggleSeriesDates({ currentTarget: { dataset: { seriesId: 12 } } })
  const calls = requests.filter((r) => r.url === '/api/club/event-ops/series/occurrences')
  assert.equal(calls.length, 2)
  assert.equal(p.data.expandedSeriesId, 12)
  calls[0].success({ code: 200, data: [{ activityId: 1, startTime: '2026-12-01 09:00:00' }] })
  assert.equal(p.data.occurrenceState, 'loading')
  assert.deepEqual(p.data.occurrenceRows, [])
})

test('L08-072 日期下限按打开时的上海日期算,不是模块加载时冻结的', () => {
  const realNow = Date.now
  try {
    Date.now = () => Date.parse('2026-11-05T02:20:00Z')
    const p = mount()
    p.loadAccess = () => {}
    Date.now = () => Date.parse('2026-11-06T02:20:00Z')   // 过了上海零点再打开
    p.onLoad({ clubId: '7' })
    assert.equal(p.data.minDate, '2026-11-06')
    assert.equal(p.data.futureMinDate, '2026-11-07')
  } finally { Date.now = realNow }
})
