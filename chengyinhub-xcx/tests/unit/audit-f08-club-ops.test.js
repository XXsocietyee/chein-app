'use strict'
// AUDIT-1122 lane F08:俱乐部运营子页(checkin-detail / governance / payout-receiver / roles / group-code …)行为测试
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const ROOT = path.join(__dirname, '../..')

function mount(rel, opts) {
  const requests = []
  const toasts = []
  const navs = []
  let definition
  const storage = {}
  const app = Object.assign({ globalData: { user_id: 7, role: 'club', user_type: 1, statusBarHeight: 20, navBarHeight: 44 },
    getUserID: () => 7, sendRequest(o) { requests.push(o) } }, (opts && opts.app) || {})
  const wx = Object.assign({
    navigateBack() { navs.push('back') }, navigateTo(o) { navs.push(o.url) }, switchTab() {}, redirectTo() {}, stopPullDownRefresh() {},
    showToast(o) { toasts.push(o && o.title) }, getStorageSync: (k) => storage[k] || '', setStorageSync: (k, v) => { storage[k] = v },
    removeStorageSync: (k) => { delete storage[k] }, login(o) { o.success && o.success({ code: 'c' }) }, showModal() {},
    getSystemInfoSync: () => ({}), getWindowInfo: () => ({}),
  }, (opts && opts.wx) || {})
  global.wx = wx
  global.getApp = () => app
  const timers = []
  const sandbox = {
    getApp: () => app, Page(config) { definition = config }, Component(config) { definition = config },
    getCurrentPages: () => [{}, {}],
    require(request) {
      if (/utils\/toast\.js$/.test(request)) { const t = (m) => toasts.push(m); t.success = t; t.error = t; return t }
      return require(path.resolve(ROOT, path.dirname(rel), request))
    },
    wx, console, Date, JSON, Math, Promise,
    setTimeout(fn, ms) { timers.push({ fn, ms, kind: 'timeout' }); return timers.length },
    clearTimeout(id) { if (timers[id - 1]) timers[id - 1].cleared = true },
    setInterval(fn, ms) { timers.push({ fn, ms, kind: 'interval' }); return timers.length },
    clearInterval(id) { if (timers[id - 1]) timers[id - 1].cleared = true },
    decodeURIComponent, encodeURIComponent,
  }
  vm.runInNewContext(fs.readFileSync(path.join(ROOT, rel), 'utf8'), sandbox, { filename: rel })
  const page = Object.assign({}, definition, {
    data: JSON.parse(JSON.stringify(definition.data || {})),
    setData(patch, cb) { Object.assign(this.data, patch); if (cb) cb.call(this) },
  })
  return { page, requests, toasts, navs, timers }
}
const byUrl = (requests, url) => requests.filter((r) => r.url === url)

test('L08-064 核销详情:退款前的旧读迟到也不覆盖退款后的新读', () => {
  const { page, requests } = mount('pages/club/checkin-detail/index.js')
  page.onLoad({ clubId: '1', registrationId: '9' })
  page.load(true)
  const [older, newer] = byUrl(requests, '/api/club/crm/checkin/detail')
  newer.success({ code: 200, data: { registrationId: 9, statusCode: 'REFUNDED', canRefund: false } })
  older.success({ code: 200, data: { registrationId: 9, statusCode: 'PAID', canRefund: true } })
  assert.equal(page.data.detail.statusCode, 'REFUNDED')
})


test('L08-065 举报网络失败后重试复用同一 requestId;明确答复后下一次是新 id', () => {
  const { page, requests } = mount('pages/club/governance/index.js')
  page.setData({ clubId: 5, reportTargetId: 31, reportTargetType: 'TOPIC' })
  page.submitCase('report', '现场收费不透明')
  byUrl(requests, '/api/club/governance/cases/report')[0].fail()
  page.submitCase('report', '现场收费不透明')
  const [a, b] = byUrl(requests, '/api/club/governance/cases/report').map((r) => JSON.parse(r.data).requestId)
  assert.equal(a, b, '结果未知的重试必须同一个 requestId')
  byUrl(requests, '/api/club/governance/cases/report')[1].success({ code: 200 })
  page.submitCase('report', '现场收费不透明')
  const c = JSON.parse(byUrl(requests, '/api/club/governance/cases/report')[2].data).requestId
  assert.notEqual(c, b)
  page.submitCase('report', '另一件事')
  const d = JSON.parse(byUrl(requests, '/api/club/governance/cases/report')[3].data).requestId
  assert.notEqual(d, c, '内容变了是新请求')
})

test('B7 转让成功后 1.5s 内离开本页:回调不再 navigateBack', () => {
  const { page, requests, navs, timers } = mount('pages/club/governance/index.js')
  page.setData({ clubId: 5 })
  page.submitOwnerTransfer(9, '交接', '小王')
  const req = byUrl(requests, '/api/club/governance/owner/transfer')[0]
  req.success({ code: 200 })
  page.onUnload()
  timers.filter((t) => t.kind === 'timeout' && !t.cleared).forEach((t) => t.fn())
  assert.deepEqual(navs, [])
})

test('L08-068 分配成功后的角色刷新失败:保留列表并提示,不整页报错;首载失败照旧报错', () => {
  const { page, requests, toasts } = mount('pages/club/roles/index.js')
  page.setData({ clubId: 5, state: 'ready', assignments: [{ id: 1 }] })
  page._loadCycle = 3
  page.loadRoleData(3, { afterAction: true })
  byUrl(requests, '/api/club/roles/list')[0].fail()
  assert.equal(page.data.state, 'ready')
  assert.deepEqual(page.data.assignments, [{ id: 1 }])
  assert.ok(toasts.some((t) => /没刷新成功/.test(String(t))))
  page.setData({ state: 'loading' })
  page.loadRoleData(3)
  byUrl(requests, '/api/club/roles/list')[1].fail()
  assert.equal(page.data.state, 'error')
})

test('L08-067 个人收款「重新加载」回到加载态,不把事件对象当成下拉', () => {
  let stops = 0
  const { page } = mount('pages/club/payout-receiver/index.js', { wx: { stopPullDownRefresh() { stops += 1 } } })
  page._clubId = 5
  page.setData({ state: 'error' })
  page.loadStatus = () => {}
  page.retryLoad({ type: 'retry' })
  assert.equal(page.data.state, 'loading')
  assert.equal(stops, 0)
})

test('L08-093/094 客户详情:刷新不关编辑草稿;保存网络失败后重试复用 requestId', () => {
  const { page, requests } = mount('pages/club/customer-detail/index.js')
  page._clubId = 5; page._memberId = 8
  page.setData({ state: 'ready', detail: { memberId: 8, tags: ['老客'], remark: '', canEdit: true }, editing: true, draftTags: ['老客', '新'], draftRemark: '周末来' })
  page.load()
  const detail = byUrl(requests, '/api/club/crm/customers/detail')[0]
  detail.success({ code: '200', data: { summary: { memberId: 8, arrivedCount: 1, pendingCount: 0, refundedCount: 0, paidAmount: null }, tags: ['老客'], remark: '', canEdit: true, records: [] } })
  assert.equal(page.data.state, 'ready')
  assert.equal(page.data.editing, true, '刷新不关编辑')
  assert.deepEqual(page.data.draftTags, ['老客', '新'])
  page.saveTagRemark()
  const first = byUrl(requests, '/api/club/crm/customers/tag-remark')[0]
  first.fail(); first.complete && first.complete()
  page.saveTagRemark()
  const second = byUrl(requests, '/api/club/crm/customers/tag-remark')[1]
  assert.equal(JSON.parse(second.data).requestId, JSON.parse(first.data).requestId)
})

test('L08-095 客户列表:看完客户直接返回不重拉;详情保存过才重拉', () => {
  let events = null
  const { page, requests } = mount('pages/club/customers/index.js', { wx: { navigateTo(o) { events = o.events } } })
  page.onLoad({ clubId: '5' })
  page.onShow()
  const n = byUrl(requests, '/api/club/crm/customers/list').length
  page.setData({ state: 'ready' })
  page.openCustomer({ currentTarget: { dataset: { memberId: 8 } } })
  page.onShow()
  assert.equal(byUrl(requests, '/api/club/crm/customers/list').length, n, '没改动不重拉')
  page.openCustomer({ currentTarget: { dataset: { memberId: 8 } } })
  events.customerSaved()
  page.onShow()
  assert.equal(byUrl(requests, '/api/club/crm/customers/list').length, n + 1)
})

test('L08-096 客户名单单行坏数据只跳过该行', () => {
  const vmod = require('../../pages/club/customers/view-model.js')
  const list = vmod.shapeCustomerList({ total: 3, monthNew: 0, items: [
    { memberId: 1, verifiedCount: 1, pendingCount: 0, displayName: 'A' },
    { memberId: 'x', verifiedCount: 1, pendingCount: 0 },
    { memberId: 3, verifiedCount: -1, pendingCount: 0 },
  ] })
  assert.ok(list)
  assert.deepEqual(list.items.map((i) => i.memberId), [1])
  assert.equal(list.skipped, 2)
  assert.equal(vmod.shapeCustomerList({ total: 'x', monthNew: 0, items: [] }), null, 'total 仍严格')
})

test('L08-087 团码深链名字里有孤立 % 不崩,原样显示', () => {
  const { page } = mount('pages/club/group-code/index.js')
  page.onLoad({ topicId: '1', topicName: '%E4%25' })
  assert.equal(page.data.title, '%E4%25')
})

test('L08-116 解散后 500ms 内已离开编辑页:不再 navigateBack', () => {
  const { page, navs, timers } = mount('pages/club/edit/index.js')
  page.onDissolved()
  page.onUnload()
  timers.filter((t) => t.kind === 'timeout').forEach((t) => t.fn())
  assert.deepEqual(navs, [])
})
