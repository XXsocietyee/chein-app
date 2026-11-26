'use strict'
// AUDIT-1122 L08-059 / L08-060:俱乐部群发 —— 发送出去的受众必须就是预览过人数的那个受众。
const test = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')

const ROOT = path.resolve(__dirname, '../..')
let pageConfig
let requests

global.getApp = () => ({ globalData: { statusBarHeight: 44, navBarHeight: 44 }, sendRequest: (r) => { requests.push(r) } })
global.wx = { getSystemInfoSync: () => ({}), showToast() {}, stopPullDownRefresh() {}, navigateBack() {}, switchTab() {} }
global.getCurrentPages = () => []
global.Page = (config) => { pageConfig = config }

function respond(request, payload) {
  request.success({ code: 200, data: payload })
  if (request.complete) request.complete()
}
const take = (url) => {
  const i = requests.findIndex((r) => r.url === url)
  assert.ok(i >= 0, 'missing request ' + url)
  return requests.splice(i, 1)[0]
}
const access = (permissions) => ({ active: true, club: { id: 21 }, permissions })
const previewOk = (n) => ({ recipientCount: n, inApp: 'AVAILABLE', wechatSubscription: 'UNAVAILABLE', phoneIncluded: false })

function loadPage() {
  requests = []
  const absolute = path.join(ROOT, 'pages/club/notify/index.js')
  delete require.cache[require.resolve(absolute)]
  require(absolute)
  const page = Object.assign({}, pageConfig)
  page.data = JSON.parse(JSON.stringify(pageConfig.data))
  page.setData = function (patch) { Object.assign(this.data, patch) }
  page.onLoad({ clubId: 21, activityId: 31 })
  respond(take('/api/club/access/me'), access(['club:event:operate', 'club:notify:send']))
  requests.length = 0
  page.onTitleInput({ detail: { value: '集合提醒' } })
  page.onContentInput({ detail: { value: '提前十分钟到' } })
  return page
}

test('L08-059 预览 管理员 后下拉刷新:受众仍可用就保留,不悄悄换回默认', () => {
  const page = loadPage()
  page.chooseAudience({ currentTarget: { dataset: { value: 'ADMINS' } } })
  page.preview()
  respond(take('/api/club/event-notification/preview'), previewOk(3))
  assert.equal(page.data.previewState, 'ready')
  page.onPullDownRefresh()
  respond(take('/api/club/access/me'), access(['club:event:operate', 'club:notify:send']))
  assert.equal(page.data.audienceType, 'ADMINS')
  requests.length = 0
  page.send()
  const sent = take('/api/club/event-notification/send')
  assert.equal(JSON.parse(sent.data).audienceType, 'ADMINS')
})

test('L08-059 刷新后受众被换掉 ⇒ 作废预览,点发送只会重新预览,不直接发', () => {
  const page = loadPage()
  page.chooseAudience({ currentTarget: { dataset: { value: 'ADMINS' } } })
  page.preview()
  respond(take('/api/club/event-notification/preview'), previewOk(3))
  page.onPullDownRefresh()
  respond(take('/api/club/access/me'), access(['club:event:operate']))   // 不再有 notify:send
  assert.equal(page.data.audienceType, 'REGISTERED')
  assert.equal(page.data.previewState, 'idle')
  assert.equal(page.data.draftRequestId, '')
  requests.length = 0
  page.send()
  assert.equal(requests.filter((r) => r.url === '/api/club/event-notification/send').length, 0, '不许不经预览就发')
  assert.equal(requests.filter((r) => r.url === '/api/club/event-notification/preview').length, 1)
})

test('L08-060 预览在途时换受众:迟到的旧预览回包不把页面置为 ready', () => {
  const page = loadPage()
  page.preview()
  const first = take('/api/club/event-notification/preview')
  page.chooseAudience({ currentTarget: { dataset: { value: 'ADMINS' } } })
  respond(first, previewOk(40))
  assert.equal(page.data.previewState, 'idle')
  assert.notEqual(page.data.recipientCount, 40)
})
