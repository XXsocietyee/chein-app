'use strict'
// AUDIT-1122 lane F08:pages/club/topic-detail 与 topic-story 行为测试
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')

const ROOT = path.resolve(__dirname, '../..')

function loadPage(rel) {
  const requests = []
  let definition = null
  const storage = {}
  const app = {
    globalData: { statusBarHeight: 20, navBarHeight: 44 },
    sendRequest(o) { requests.push(o) },
    getUserID: () => 9008, getUserRole: () => 'CLUB', getUserType: () => 1,
  }
  const base = {
    getStorageSync: (k) => storage[k] || '', setStorageSync: (k, v) => { storage[k] = v }, removeStorageSync: (k) => { delete storage[k] },
    getWindowInfo: () => ({ windowWidth: 375, windowHeight: 667 }), getSystemInfoSync: () => ({}),
  }
  const wx = new Proxy(base, { get(t, k) { return k in t ? t[k] : () => {} } })
  global.wx = wx
  global.getApp = () => app
  vm.runInNewContext(fs.readFileSync(path.join(ROOT, rel), 'utf8'), {
    getApp: () => app, Page: (config) => { definition = config }, wx, console, Date, setTimeout, clearTimeout, JSON, Math, Promise,
    getCurrentPages: () => [],
    require: (id) => require(path.resolve(ROOT, path.dirname(rel), id)),
  }, { filename: rel })
  const page = Object.assign({}, definition, {
    data: JSON.parse(JSON.stringify(definition.data)),
    setData(patch) { Object.assign(this.data, patch) },
  })
  return { page, requests }
}

test('L08-037 结束主题网络失败 / 5xx:说「结果待确认」,不说「没能结束」;明确 4xx 才说没结束', () => {
  for (const [kind, expectPending] of [['fail', true], [502, true], [408, true], [403, false]]) {
    const { page, requests } = loadPage('pages/club/topic-detail/index.js')
    page._topicId = 88; page._clubId = 9; page._endCancellationEpoch = 1
    page.confirmEndTopic()
    const req = requests.find((r) => r.url === '/api/club/topic-setting/end')
    assert.ok(req, '发出结束请求')
    if (kind === 'fail') req.fail()
    else req.successStatusAbnormal({ code: kind, msg: '当前岗位没有这个权限' }, kind)
    if (expectPending) assert.match(page.data.endErrorText, /待确认/, String(kind))
    else assert.equal(page.data.endErrorText, '当前岗位没有这个权限')
    assert.equal(page.data.endSubmitting, false)
  }
})

test('L08-038 先看 A 关掉再看 B:A 的迟到答案不落进 B 的弹层', () => {
  const { page, requests } = loadPage('pages/club/topic-story/index.js')
  page.clubId = 9; page.topicId = 88
  page.onViewAnswer({ currentTarget: { dataset: { nodeId: 1, title: 'A 题' } } })
  page.closeAnswer()
  page.onViewAnswer({ currentTarget: { dataset: { nodeId: 2, title: 'B 题' } } })
  const [a, b] = requests.filter((r) => /node-answer/.test(r.url))
  b.success({ code: '200', data: { question: 'B?', answerReveal: '答案B' } })
  a.success({ code: '200', data: { question: 'A?', answerReveal: '答案A' } })
  assert.equal(page.data.answerNodeName, 'B 题')
  assert.equal(page.data.answer.answerReveal, '答案B')
})

test('L08-035 从剧情页回来不整页重拉;从场次运营回来照旧重拉(CU-C-80)', () => {
  const { page, requests } = loadPage('pages/club/topic-detail/index.js')
  page._topicId = 88; page._clubId = 9; page._hasShown = true
  Object.assign(page.data, { loaded: true, loadError: '', missingParam: false })
  let fetches = 0
  page.fetchDetail = () => { fetches += 1 }
  page.loadManageStats = () => {}
  page.goStory(); page.onHide(); page.onShow()
  assert.equal(fetches, 0)
  page.goEventOps(); page.onHide(); page.onShow()
  assert.equal(fetches, 1)
})
