// AUDIT-1122 F01:pages/play/index 行为测试(不读源码文本,只跑真实 Page 定义上的方法)。
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const memoryStorage = require('../helpers/memory-storage');
const PAGE = path.resolve(__dirname, '../../pages/play/index.js');
const tick = () => new Promise(resolve => setImmediate(resolve));

function load(extraWx = {}, respond) {
  const requests = [];
  const storage = memoryStorage();
  const app = {
    DEV_TOKEN: 'dev-token', getUserID: () => 7, getAuthorization: () => 'tok',
    sendRequest(options) { requests.push(options); if (respond) Promise.resolve().then(() => options.success(respond(options))); },
  };
  let definition;
  global.getApp = () => app; global.getCurrentPages = () => [];
  global.Page = value => { definition = value; };
  global.wx = Object.assign({
    getStorageSync: storage.getStorageSync, setStorageSync: storage.setStorageSync,
    removeStorageSync: storage.removeStorageSync, getStorageInfoSync: storage.getStorageInfoSync,
    nextTick(fn) { if (fn) fn(); }, showToast() {}, showModal() {},
  }, extraWx);
  delete require.cache[PAGE]; require(PAGE);
  return { definition, requests, app, keys: () => global.wx.getStorageInfoSync().keys };
}

function realPage(definition, data, names) {
  const page = { data: Object.assign({}, definition.data, data), setData(patch) { Object.assign(this.data, patch); } };
  for (const [name, value] of Object.entries(definition)) if (typeof value === 'function') page[name] = names.includes(name) ? value : () => {};
  return page;
}

const ROUTE = ['_boundPlayOwner', '_playMember', '_capturePlayLoginContext', '_isPlayAccountCurrent', '_sessionParams', '_sessionKey',
  '_ensureRouteActionStore', '_routeWritePayload', '_basicIntentHome', '_resolveRouteAction', '_readBasicRouteIntent'];

test('L01-001 局号从空变成 N 后回读原意图:不在新作用域新建意图,回读用原 routeActionId', async () => {
  const h = load();
  const page = realPage(h.definition, { topicId: 31 }, ROUTE);
  page._routeState = { sessionId: '', version: 1 };
  page._boundPlayOwner();
  const first = page._routeWritePayload('answer', 5, { answer: 'orig' });
  first._markIntentUnknown();
  const keysBefore = h.keys().filter(k => k.startsWith('cy_play_intents_v1:')).sort();
  page._routeState = { sessionId: '7', version: 2 };
  page._readBasicRouteIntent('answer', 5);
  const keysAfter = h.keys().filter(k => k.startsWith('cy_play_intents_v1:')).sort();
  assert.deepEqual(keysAfter, keysBefore, '回读不能在新作用域落盘新意图');
  const read = h.requests.at(-1);
  assert.equal(read.url, '/api/play/action-receipt');
  assert.equal(read.data.routeActionId, first.routeActionId);
  // 下一次真实写仍带上玩家这次的答案,不会被回读造出的空壳顶掉
  const next = page._routeWritePayload('answer', 5, { answer: 'x' });
  assert.equal(next.answer, 'x');
});

test('L01-001 本页没有待确认意图时回读如实返回未确认,不发请求也不新建', async () => {
  const h = load();
  const page = realPage(h.definition, { topicId: 31 }, ROUTE);
  page._routeState = { sessionId: '7', version: 2 };
  page._boundPlayOwner();
  const result = await page._readBasicRouteIntent('checkin', 9);
  assert.equal(result.intentTerminal, false);
  assert.equal(result.notFound, true);
  assert.equal(h.requests.length, 0);
  assert.equal(h.keys().filter(k => k.startsWith('cy_play_intents_v1:')).length, 0);
});

test('L01-001 结清走原意图所在的存储', () => {
  const h = load();
  const page = realPage(h.definition, { topicId: 31 }, ROUTE);
  page._routeState = { sessionId: '', version: 1 };
  page._boundPlayOwner();
  const first = page._routeWritePayload('arrive', 3, {});
  page._routeState = { sessionId: '8', version: 2 };
  const home = page._basicIntentHome('arrive', 3);
  assert.ok(home);
  page._resolveRouteAction('arrive', 3);
  assert.equal(page._basicIntentHome('arrive', 3), null);
  // 原存储里已结清:同作用域再取是新身份
  const again = home.payload('arrive', 3, page._routeState, { topicId: 31, nodeId: 3 });
  assert.notEqual(again.routeActionId, first.routeActionId);
});

function lifecycle(definition, stack) {
  const names = ['onShow', 'onHide'];
  const page = realPage(definition, { topicId: 31, loading: false }, names);
  let loads = 0, pending = 0;
  page.loadData = () => { loads++; };
  page._consumePendingStart = () => { pending++; };
  page._playOwner = undefined;
  global.getCurrentPages = () => (stack === 'left' ? [page, {}] : [page]);
  return { page, get loads() { return loads; }, get pending() { return pending; } };
}

test('L01-002 扫码/拍照这类短暂切后台回来不整页重读', () => {
  const h = load();
  const l = lifecycle(h.definition, 'same');
  l.page.onHide(); l.page.onShow();
  assert.equal(l.loads, 0); assert.equal(l.pending, 1);
});

test('L01-002 离开过本页、隐藏超过一分钟、加载被打断、或有待开玩法时整页重读', () => {
  const h = load();
  let l = lifecycle(h.definition, 'left');
  l.page.onHide(); global.getCurrentPages = () => [l.page]; l.page.onShow();
  assert.equal(l.loads, 1);

  l = lifecycle(h.definition, 'same');
  l.page.onHide(); l.page._playReloadOnShow.at -= 61000; l.page.onShow();
  assert.equal(l.loads, 1);

  l = lifecycle(h.definition, 'same');
  l.page._playLoadStarted = 4; l.page._playLoadSettled = 3;
  l.page.onHide(); l.page.onShow();
  assert.equal(l.loads, 1);

  l = lifecycle(h.definition, 'same');
  l.page.onHide(); l.page._pendingStartNode = { nodeId: 1 }; l.page.onShow();
  assert.equal(l.loads, 1);

  l = lifecycle(h.definition, 'same');
  l.page.data.loading = true;
  l.page.onHide(); l.page.onShow();
  assert.equal(l.loads, 1);
});

test('L01-002 没切过后台时首屏仍按原规则:加载中不重读,已加载才重读', () => {
  const h = load();
  let l = lifecycle(h.definition, 'same');
  l.page.data.loading = true; l.page.onShow();
  assert.equal(l.loads, 0);
  l = lifecycle(h.definition, 'same');
  l.page.onShow();
  assert.equal(l.loads, 1);
});

test('L01-003 轮询来的空认领步数同步两分钟内只 wx.login 一次;提交前同步不受限', async () => {
  let logins = 0;
  const h = load({
    getSetting: o => o.success({ authSetting: { 'scope.werun': true } }),
    login: o => { logins++; o.success({ code: 'c' + logins }); },
    getWeRunData: o => o.success({ encryptedData: 'e', iv: 'i' }),
  }, () => ({ code: 500 }));
  const page = realPage(h.definition, { topicId: 31 }, ['_syncThoughts', '_weRunCipher', '_boundPlayOwner', '_playMember',
    '_capturePlayLoginContext', '_isPlayAccountCurrent', '_sessionParams', '_sessionKey']);
  page._routeState = { sessionId: '7' };
  page._boundPlayOwner();
  await page._syncThoughts([]);
  await page._syncThoughts([]);
  await page._syncThoughts([]);
  assert.equal(logins, 1);
  await page._syncThoughts([], () => true);
  assert.equal(logins, 2);
  page._stepSyncAt -= 121000;
  await page._syncThoughts([]);
  assert.equal(logins, 3);
});

test('L01-003 伏笔没变时步数回包不重排整章', async () => {
  let reply = { sessionId: '7', thoughts: [{ key: 'a' }] };
  const h = load({
    getSetting: o => o.success({ authSetting: { 'scope.werun': true } }),
    login: o => o.success({ code: 'c' }),
    getWeRunData: o => o.success({ encryptedData: 'e', iv: 'i' }),
  }, () => ({ code: 200, data: reply }));
  const page = realPage(h.definition, { topicId: 31, chapterFull: true, chapStory: { show: false } }, ['_syncThoughts', '_weRunCipher',
    '_boundPlayOwner', '_playMember', '_capturePlayLoginContext', '_isPlayAccountCurrent', '_sessionParams', '_sessionKey']);
  page._routeState = { sessionId: '7', thoughts: [{ key: 'a' }] };
  page._boundPlayOwner();
  let reopened = 0;
  page.openChapterFull = () => { reopened++; };
  page._applyRouteState = (state, cb) => { page._routeState = Object.assign({}, page._routeState, state); cb(true); };
  await page._syncThoughts(['a']);
  assert.equal(reopened, 0);
  reply = { sessionId: '7', thoughts: [{ key: 'a' }, { key: 'b' }] };
  await page._syncThoughts(['b']);
  assert.equal(reopened, 1);
});

test('L01-009 回前台五分钟内不重复拉功能开关,拉取中不先把社区入口关掉', async () => {
  const h = load();
  let loads = 0, resolveFlags;
  h.app.loadFeatureFlags = () => { loads++; return new Promise(r => { resolveFlags = r; }); };
  let can = true;
  h.app.canUseCommunity = () => can;
  const page = realPage(h.definition, { communityPostWrite: true }, ['_syncCommunityEntry']);
  page._syncCommunityEntry();
  assert.equal(loads, 1);
  assert.equal(page.data.communityPostWrite, true, '回包前不改入口');
  resolveFlags({}); await tick();
  assert.equal(page.data.communityPostWrite, true);
  can = false;
  page._syncCommunityEntry();
  assert.equal(loads, 1, '五分钟内只读缓存');
  assert.equal(page.data.communityPostWrite, false);
  page._communityFlagsAt -= 5 * 60000 + 1;
  page._syncCommunityEntry();
  assert.equal(loads, 2);
});

test('L01-013 路线状态回包被判为旧投影拒收时,解锁并还原同步前的站点', async () => {
  const h = load({}, () => ({ code: 200, data: { sessionId: '5', version: 4, routeMode: 'BRANCH_GRAPH' } }));
  const page = realPage(h.definition, { topicId: 31 }, ['refreshRouteState', '_failClosedRouteState', '_applyRouteState',
    '_acceptRouteStateProjection', '_routeStateVersionKnown', '_boundPlayOwner', '_playMember', '_capturePlayLoginContext',
    '_isPlayAccountCurrent', '_sessionParams', '_sessionKey']);
  page._boundPlayOwner();
  page._routeState = { sessionId: '5', version: 5, routeMode: 'BRANCH_GRAPH' };
  const nodes = [{ nodeId: 1, done: false, playable: true, locked: false }];
  page.data.nodes = nodes; page.data.nextNode = nodes[0];
  const ok = await page.refreshRouteState();
  assert.equal(ok, false);
  assert.equal(page.data.routeRefreshing, false);
  assert.equal(page.data.nodes, nodes);
  assert.equal(page.data.nextNode, nodes[0]);
});

test('L01-023 到达写在途时不开相机;扫码回来账号已换就不提交', () => {
  let scans = 0, scanOpts = null;
  const h = load({ scanCode: o => { scans++; scanOpts = o; } });
  const page = realPage(h.definition, { topicId: 31 }, ['onScanArrive', 'scanArrive', '_boundPlayOwner', '_playMember',
    '_capturePlayLoginContext', '_isPlayAccountCurrent', '_sessionParams', '_sessionKey']);
  page._boundPlayOwner();
  page._arriveTarget = () => ({ nodeId: 3 });
  let checkins = 0; page.checkin = () => { checkins++; };
  page._arrivalWriteInFlight = true;
  page.onScanArrive();
  assert.equal(scans, 0);
  page._arrivalWriteInFlight = false;
  page.onScanArrive();
  assert.equal(scans, 1);
  page._playDisposed = true;
  scanOpts.success({ result: 'code' });
  assert.equal(checkins, 0);
  page._playDisposed = false;
  scanOpts.success({ result: 'code' });
  assert.equal(checkins, 1);
});

test('L01-034 故事流被整屏层盖住时判定为遮挡,浮尘循环据此跳过绘制', () => {
  const h = load();
  const page = realPage(h.definition, { chapterFull: true, chapStory: { show: false } }, ['_chfullCovered']);
  assert.equal(page._chfullCovered(), false);
  page.data.screen = 'gamePlay'; assert.equal(page._chfullCovered(), true);
  page.data.screen = ''; page.data.album = { show: true }; assert.equal(page._chfullCovered(), true);
  page.data.album = { show: false }; page.data.playKit = { show: true, pop: true }; assert.equal(page._chfullCovered(), false);
  page.data.playKit = { show: true, pop: false }; assert.equal(page._chfullCovered(), true);
  page.data.chapStory = { show: true }; assert.equal(page._chfullCovered(), false);
});

test('L01-020 同一主题新的一局不接上一局的轨迹;超过 24 小时的本机轨迹丢弃', () => {
  const h = load();
  const page = realPage(h.definition, { topicId: 31 }, ['_playTrail', '_sessionKey', '_sessionParams']);
  page._routeState = { sessionId: '7' };
  const first = page._playTrail();
  first.note({ latitude: 31.2, longitude: 121.4 }); first.note({ latitude: 31.21, longitude: 121.41 }); first.persist();
  assert.equal(first.points().length, 2);
  page._routeState = { sessionId: '8' };
  assert.equal(page._playTrail().points().length, 0);
  // 回到 7 那一局但副本已过期
  const saved = global.wx.getStorageInfoSync().keys.find(k => k.startsWith('cy_play_trail'));
  const record = global.wx.getStorageSync(saved);
  if (record && record.key) { record.key = 't:31#7'; record.startedAt = Date.now() - 25 * 3600 * 1000; record.points = [{ lat: 1, lng: 1 }]; global.wx.setStorageSync(saved, record); }
  page._routeState = { sessionId: '7' };
  assert.equal(page._playTrail().points().length, 0);
});

test('L01-028 收起结算还原故事地图的回看叠加,下一次结算重新取底', () => {
  const h = load();
  const page = realPage(h.definition, {}, ['_hideFinish']);
  page._finishViewContext = () => ({});
  page._reviewBase = [{ points: [1] }];
  page.data.fmPolyline = [{ points: [1] }, { points: [2], review: true }];
  page.data.fmNodes = [{ nodeId: 1, reviewLabel: '徽章' }, { nodeId: 2, reviewLabel: '' }];
  page._hideFinish();
  assert.deepEqual(page.data.fmPolyline, [{ points: [1] }]);
  assert.equal(page.data.fmNodes[0].reviewLabel, '');
  assert.equal(page._reviewBase, null);
});
