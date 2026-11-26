'use strict'
// AUDIT-1122 lane F08:IM 会话列表 / 聊天页行为测试
const { test } = require('node:test')
const assert = require('node:assert/strict')

function load(rel, extra) {
  let def
  const writes = []
  const requests = []
  const storage = Object.assign({}, (extra && extra.storage) || {})
  global.getApp = () => ({
    globalData: {}, sendRequest: (o) => requests.push(o), tips() {},
    getUserID: () => 1, getRequestErrorMessage: (r, f) => f,
  })
  global.wx = { getStorageSync: (k) => storage[k] || '', setStorageSync: (k, v) => { storage[k] = v }, removeStorageSync: (k) => { delete storage[k] }, navigateTo() {} }
  global.Page = c => { def = c }
  const mod = require.resolve(rel)
  delete require.cache[mod]
  require(mod)
  const page = Object.assign({}, def)
  page.data = JSON.parse(JSON.stringify(def.data))
  page.setData = function (patch) { writes.push(patch); Object.assign(this.data, patch) }
  return { page, writes, requests, storage }
}

const LIST = '../../subpackageB/pages/im/list/index.js'

test('L08-123 静音 / 已读 / 返回刷新重算列表时不再重播入场动画', () => {
  const { page, writes } = load(LIST)
  page.data.list = [{ conversationId: 1, type: 1, unread: 2 }]
  page.refreshView(); page.refreshView(); page.refreshView()
  assert.equal(writes.filter((w) => 'pmList' in w).length, 0)
  assert.equal(page.data.viewList.length, 1)
})

const CHAT = '../../subpackageB/pages/im/chat/index.js'

test('L08-119 服务端确认没有、本页也无失败气泡的发送收据被清掉,不再每次打开都查', () => {
  const { page, requests, storage } = load(CHAT, { storage: { 'im_send_receipts_v1:1:10': [{ id: 'im_a' }] } })
  Object.assign(page.data, { myId: 1, conversationId: 10, msgs: [] })
  page.recoverPending()
  const read = requests.filter((r) => r.url === '/api/im/send-receipt')
  assert.equal(read.length, 1)
  read[0].success({ code: 200, data: { found: false } })
  assert.deepEqual(storage['im_send_receipts_v1:1:10'], [])
})

test('L08-119 本页还有失败气泡时保留收据(重发要用它)', () => {
  const { page, requests, storage } = load(CHAT, { storage: { 'im_send_receipts_v1:1:10': [{ id: 'im_b' }] } })
  Object.assign(page.data, { myId: 1, conversationId: 10, msgs: [{ id: 'tmp_im_b', clientMessageId: 'im_b', sendPayload: {}, failed: true }] })
  page.recoverPending()
  requests.filter((r) => r.url === '/api/im/send-receipt')[0].success({ code: 200, data: { found: false } })
  assert.deepEqual(storage['im_send_receipts_v1:1:10'], [{ id: 'im_b' }])
})
