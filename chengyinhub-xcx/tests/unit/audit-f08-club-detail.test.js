'use strict';
// AUDIT-1122 lane F08:pages/club/detail 行为测试(挂真页面代码,桩掉 app/wx)。
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '../..');
const REL = 'pages/club/detail/index.js';

function loadClubDetail() {
  const requests = [];
  const timers = { live: new Set(), next: 1, fns: new Map() };
  const app = {
    globalData: { statusBarHeight: 20, navBarHeight: 44 },
    sendRequest(o) { requests.push(o); },
    tips() {}, getUserID: () => 1001, getUserRole: () => 'club', getUserType: () => 'club',
    getAvatar: () => '', getNickname: () => '测试', getAuthorization: () => 'Bearer t',
    getRequestErrorMessage: (res, fallback) => (res && res.msg) || fallback,
  };
  const wx = {
    showToast() {}, navigateTo() {}, navigateBack() {}, redirectTo() {}, switchTab() {},
    stopPullDownRefresh() {}, getStorageSync: () => '', setStorageSync() {}, removeStorageSync() {},
    previewImage() {}, scanCode() {}, setNavigationBarColor() {}, getSystemInfoSync: () => ({}), createSelectorQuery: () => ({ in() { return this; }, select() { return this; }, boundingClientRect() { return this; }, exec() {} }),
  };
  global.wx = wx;
  global.getApp = () => app;
  const file = path.resolve(ROOT, REL);
  const stubs = {
    '../../../utils/scene-registry.js': { getScene: () => ({}) },
    '../utils/mockData.js': { DEMO_NEARBY_CLUB_ID: -1 },
    '../utils/aiPlanToDraft.js': { aiPlanToDraft: () => ({}) },
    '../../../utils/group-code-session.js': { buildGroupCodeIssuePayload: (id) => (id ? { activityId: id } : null), listGroupCodeActivities: () => [] },
  };
  let definition;
  vm.runInNewContext(fs.readFileSync(file, 'utf8'), {
    getApp: () => app, Page(p) { definition = p; }, Component(p) { definition = p; },
    getCurrentPages: () => [{}, {}],
    setTimeout(fn) { if (fn) fn(); return 0; }, clearTimeout() {},
    setInterval(fn) { const id = timers.next++; timers.live.add(id); timers.fns.set(id, fn); return id; },
    clearInterval(id) { timers.live.delete(id); },
    console, Set, Map, Date, JSON, Math, Object, String, Number, Array, Promise, RegExp, Error, encodeURIComponent, decodeURIComponent,
    require(id) { return stubs[id] || require(path.resolve(path.dirname(file), id)); },
    wx,
  }, { filename: REL });
  const page = Object.assign({}, definition, {
    data: JSON.parse(JSON.stringify(definition.data)),
    setData(patch, cb) {
      for (const [k, v] of Object.entries(patch)) {
        if (/[.[]/.test(k)) {
          const parts = k.replace(/\[(\d+)\]/g, '.$1').split('.');
          let o = this.data;
          for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
          o[parts[parts.length - 1]] = v;
        } else this.data[k] = v;
      }
      if (cb) cb.call(this);
    },
  });
  return { page, requests, timers };
}

test('L08-003 关闭团码弹层后迟到的签发回包不起倒计时、不再签发', () => {
  const { page, requests, timers } = loadClubDetail();
  page.setData({ groupCodeVisible: true, groupCodeActivityId: 30 });
  page.issueGroupCode();
  const issue = requests.filter((r) => r.url === '/api/verify/groupcode/issue');
  assert.equal(issue.length, 1);
  page.onCloseGroupCode();
  issue[0].success({ code: 200, data: { code: 'C1', qrcodeUrl: 'https://oss.test/q.png', ttlMs: 300000 } });
  assert.equal(timers.live.size, 0, '弹层已关:不许留计时器');
  assert.notEqual(page.data.groupCodeState, 'ready');
});

test('L08-003 两次并发签发只留一个计时器,旧回包作废', () => {
  const { page, requests, timers } = loadClubDetail();
  page.setData({ groupCodeVisible: true, groupCodeActivityId: 30 });
  page.issueGroupCode();
  page.issueGroupCode();
  const issue = requests.filter((r) => r.url === '/api/verify/groupcode/issue');
  assert.equal(issue.length, 2);
  issue[1].success({ code: 200, data: { code: 'C2', qrcodeUrl: 'https://oss.test/2.png', ttlMs: 300000 } });
  issue[0].success({ code: 200, data: { code: 'C1', qrcodeUrl: 'https://oss.test/1.png', ttlMs: 300000 } });
  assert.equal(timers.live.size, 1, '至多一个倒计时');
  assert.equal(page.data.groupCodeCode, 'C2', '旧回包不覆盖新码');
  page.onCloseGroupCode();
  assert.equal(timers.live.size, 0);
});

function accessOk(clubId, permissions) {
  return { code: 200, data: { active: true, club: { id: clubId }, permissions, roleCodes: ['CLUB_EVENT_LEAD'], eventAccesses: [] } };
}

test('L08-001 委派角色在 管理 tab 上重载同一俱乐部:不被踢回概览,权限不先收回', () => {
  const { page, requests } = loadClubDetail();
  page.setData({ clubId: 7, club: { id: 7, isJoined: true, viewerCanGovern: false }, activeTab: 'manage', tabInitialized: true });
  page.loadClubAccess();
  requests.pop().success(accessOk(7, ['club:event:operate']));
  assert.equal(page.data.canUseManageTab, true);
  assert.equal(page.data.activeTab, 'manage');
  // 子页面返回 → 再拉一次 access:在途期间快照保留
  page.loadClubAccess();
  assert.equal(page.data.activeTab, 'manage', '在途时不许踢回概览');
  assert.equal(page.data.canOperateEvents, true, '在途时按钮不闪掉');
  requests.pop().success(accessOk(7, ['club:event:operate']));
  assert.equal(page.data.activeTab, 'manage');
});

test('L08-001 重载回包失败照旧收回权限;换账号先收回', () => {
  const { page, requests } = loadClubDetail();
  page.setData({ clubId: 7, club: { id: 7, isJoined: true, viewerCanGovern: false }, activeTab: 'manage', tabInitialized: true });
  page.loadClubAccess();
  requests.pop().success(accessOk(7, ['club:event:operate']));
  page.loadClubAccess();
  requests.pop().success({ code: 200, data: { active: false } });
  assert.equal(page.data.canOperateEvents, false);
  assert.equal(page.data.canUseManageTab, false);
  assert.equal(page.data.activeTab, 'overview');
});

test('L08-002 看大图回来不整页重拉;之后真的从子页回来照旧重拉', () => {
  const { page } = loadClubDetail();
  let loads = 0;
  page.loadAll = () => { loads += 1; };
  page._hasShown = true;
  page.setData({ clubId: 7, club: { id: 7, isJoined: true, viewerCanGovern: true }, canUseManageTab: true });
  page.onPreviewImage({ detail: { picList: ['https://a/1.png'], picIndex: 0 }, currentTarget: { dataset: {} } });
  page.onHide(); page.onShow();
  assert.equal(loads, 0, '系统浮层返回不重拉');
  page.onHide(); page.onShow();
  assert.equal(loads, 1, '普通返回照旧重拉');
  page.onPreviewImage({ detail: { picList: [], picIndex: 0 }, currentTarget: { dataset: {} } });
  page.onHide(); page.onShow();
  assert.equal(loads, 2, '没打开浮层不许吞掉下一次刷新');
});

test('L08-004 点赞成功只改这条帖(含转发条目),不重拉帖子列表', () => {
  const { page, requests } = loadClubDetail();
  page.setData({ clubId: 7, posts: [
    { id: 11, feedKey: '11', isLiked: false, likeCount: 2 },
    { id: 12, feedKey: '12', isLiked: false, likeCount: 0 },
    { id: 11, feedKey: 'r5', isRepostItem: true, isLiked: false, likeCount: 2 },
  ] });
  page.onLikePost({ detail: { postId: 11 }, currentTarget: { dataset: {} } });
  const like = requests.filter((r) => r.url === '/api/club/post/like');
  assert.equal(like.length, 1);
  assert.equal(JSON.parse(like[0].data).liked, true);
  requests.length = 0;
  like[0].success({ code: '200', data: { liked: true } });
  assert.equal(requests.filter((r) => r.url === '/api/club/post/list').length, 0, '不整页重拉');
  assert.deepEqual(page.data.posts.map((p) => [p.isLiked, p.likeCount]), [[true, 3], [false, 0], [true, 3]]);
});

test('L08-006 只有日期的 endDate:最后一天仍算未结束', () => {
  const { page, requests } = loadClubDetail();
  page.setData({ clubId: 7 });
  const realNow = Date.now;
  try {
    Date.now = () => Date.parse('2026-11-23T08:00:00Z');   // 上海 16:00
    page.loadTopics();
    requests.find((r) => r.url === '/api/club/topics').success({ code: 200, data: [
      { id: 1, name: '今天最后一天', startDate: '2026-11-01', endDate: '2026-11-23' },
      { id: 2, name: '昨天结束', startDate: '2026-11-01', endDate: '2026-11-22' },
    ] });
    const byId = Object.fromEntries(page._topics.map((t) => [t.id, t.ended]));
    assert.equal(byId[1], false);
    assert.equal(byId[2], true);
  } finally { Date.now = realNow; }
});

test('L08-005 快速切排序:旧排序迟到回包不覆盖新榜单', () => {
  const { page, requests } = loadClubDetail();
  page.setData({ clubId: 7 });
  page._leaderboardSort = 'composite'; page.loadLeaderboard();
  page._leaderboardSort = 'mileage'; page.loadLeaderboard();
  const [a, b] = requests.filter((r) => r.url === '/api/club/leaderboard');
  b.success({ code: '200', data: [{ memberId: 2, nickname: 'B' }] });
  a.success({ code: '200', data: [{ memberId: 1, nickname: 'A' }] });
  assert.equal(page._leaderboardSortBy, 'mileage');
  assert.deepEqual(page._leaderboardRows.map((r) => r.memberId), [2]);
});

test('L08-022 带队进度的最近邀请时间跨年也取最新', () => {
  const { page } = loadClubDetail();
  page.setData({ topics: [{ id: 1 }], sentInvites: [
    { status: 0, createTime: '2025-12-28 10:00:00', timeText: '12-28 10:00' },
    { status: 0, createTime: '2026-01-03 09:00:00', timeText: '01-03 09:00' },
  ] });
  const nodes = page.buildLeadTimeline('pending').nodes;
  assert.equal(nodes[1].time, '01-03 09:00');
});
