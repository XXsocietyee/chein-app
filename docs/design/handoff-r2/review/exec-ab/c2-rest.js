const sec=await SECTION('A4 玩法设置卡 · 挑战 family（A4.24–A4.34）· temp 节点玩法模板编辑'); const out={};
const MK=async(label,build,note)=>{const {f,card}=await FRAME(sec,label); await build(card,f); NOTE(f,note); out[label]=f.id; return f;};
// A4.25 D20 加值
const D20B=async(card,o={})=>{await SUB(card,'D20 加值'); await FIELD(card,'标题 *',o.title??'能否找到钟楼里的暗门',{ph:o.title===''}); await GRID(card,['难度 DC · 1 至 40 *',o.dc??'12',false,o.dcErr],['加值（−20–20）','+2']); const dd=await DD(card,'掷骰方式',o.mode||'普通 · 掷一颗',{open:o.open}); await FIELD(card,'成功结果 *',o.ok??'你摸到一块松动的砖，暗门开了。',{area:true,ph:o.ok==='',err:o.okErr}); await FIELD(card,'失败结果 *','门纹丝不动。绕到钟楼背面，再找一次。',{area:true}); return dd;};
await MK('A4.25a D20 加值 · 已填',c=>D20B(c),'A4.25 diceRoll d20. Placeholders: 标题「例如 能否找到暗门」, 成功结果「成功后发生什么」, 失败结果「失败后发生什么，玩家接下来做什么」; each result 1–200 字. Sample content.');
await MK('A4.25b D20 加值 · 掷骰方式下拉',async (c,f)=>{const dd=await D20B(c,{open:true}); await PANEL(f,dd.d,['普通 · 掷一颗','优势 · 两颗取高','劣势 · 两颗取低'],0);},'A4.25 掷骰方式 options.');
await MK('A4.25c D20 加值 · 校验错误',c=>D20B(c,{dc:'41',dcErr:'D20 难度 DC 须为 1 至 40 的整数',ok:'',okErr:'D20 成功结果须为 1 至 200 字'}),'A4.25 validator messages (advanced-game-config.js). The page scrolls to the first error.');
// A4.26 steps — Apple Health wording (Q7)
const STEPS=async(card,o={})=>{await SUB(card,'计步挑战'); const h=AL(card,'HORIZONTAL',{gap:8,pad:[10,12,10,12],r:11,fill:'surface-2',align:'CENTER',name:'source line (Q7)'}); h.layoutSizingHorizontal='FILL'; HINT(h,'以 Apple 健康同步的步数为准'); await FIELD(card,'目标步数 *',o.goal??'6000',{err:o.err}); await FIELD(card,'小标题','低碳行动 · 今日步数'); await FIELD(card,'奖励分','10');};
await MK('A4.26a 计步挑战',c=>STEPS(c),'A4.26 steps. Owner Q7: Apple Health wording in the app (the mini-program says 微信运动). 目标步数 placeholder「100 至 100000」, default 6000; 小标题 ≤ 32 (「例如 低碳行动 · 今日步数」); 奖励分「0 表示不给分」, 0–1000.');
await MK('A4.26b 计步挑战 · 校验错误',c=>STEPS(c,{goal:'50',err:'计步目标须为 100 至 100000 步'}),'A4.26 error.');
// A4.27 reaction
const REACT=async(card,o={})=>{await SUB(card,'变色就点'); await FIELD(card,'标题 *','变绿就点'); await GRID(card,['几轮 *','3'],['达标毫秒 *',o.ms??'320',false,o.err]);};
await MK('A4.27a 变色就点',c=>REACT(c),'A4.27 reaction: 几轮 1 至 10 (3), 达标毫秒 120 至 2000 (320).');
await MK('A4.27b 变色就点 · 校验错误',c=>REACT(c,{ms:'100',err:'达标毫秒须为 120 至 2000'}),'A4.27 error.');
// A4.28 ballShake
const BALL=async(card,on)=>{await SUB(card,'弹球'); await FIELD(card,'标题 *','撞够 30 次'); await FIELD(card,'要撞多少次 *','30'); await SW(card,'限时',on); if(on) await FIELD(card,'时限（秒） *','12');};
await MK('A4.28a 弹球 · 不限时',c=>BALL(c,false),'A4.28 ballShake: 要撞多少次 1 至 200 (30); 限时 off by default.');
await MK('A4.28b 弹球 · 限时开',c=>BALL(c,true),'A4.28 限时 on → 时限（秒）3 至 300 (12). Relax option on the page: 血量低时弹球多给 5 秒.');
// A4.29 quietHold
await MK('A4.29 安静挑战',async c=>{await SUB(c,'安静挑战'); await FIELD(c,'标题 *','别出声'); await FIELD(c,'要安静多久（秒） *','15'); await FIELD(c,'说明','声音过线就从头再来');},'A4.29 quietHold: 5 至 300 秒 (15).');
// A4.30 compass
const COMP=async(card,o={})=>{await SUB(card,'罗盘指向'); await FIELD(card,'标题 *','把手机转向钟楼'); const r=AL(card,'HORIZONTAL',{gap:8,align:'MAX',name:'bearing + read button'}); r.layoutSizingHorizontal='FILL'; const fld=await FIELD(r,'目标方位（度） *',o.bearing??'0 至 359，正北是 0',{ph:o.bearing==null,err:o.err}); fld.layoutSizingHorizontal='FILL'; const b=AL(r,'HORIZONTAL',{fill:'surface-2',r:11,pad:[0,14,0,14],gap:6,main:'CENTER',align:'CENTER',name:'对准方向取值'}); b.counterAxisSizingMode='FIXED'; b.resize(b.width,44); if(o.err) {r.counterAxisAlignItems='CENTER';} TX(b,'对准方向取值','MP/body-strong','ink',{size:13});
 await GRID(card,['容差（度） *','15'],['保持几秒 *','3']); await FIELD(card,'提示语','它比你想的更靠右'); await FIELD(card,'奖励分','10'); await SW(card,'允许跳过',false);};
await MK('A4.30a 罗盘指向 · 未取值',c=>COMP(c),'A4.30 compass: 目标方位 empty by default (placeholder「0 至 359，正北是 0」); 对准方向取值 reads the device heading. 容差 5 至 90 (15), 保持几秒 1 至 10 (3), 提示语 ≤ 60, 允许跳过 off.');
await MK('A4.30b 罗盘指向 · 已取值',async (c,f)=>{await COMP(c,{bearing:'128'}); TOAST(f,'已记下当前方向',220);},'A4.30 after 对准方向取值: value filled + toast 已记下当前方向 (.success haptic).');
await MK('A4.30c 罗盘指向 · 设备没报方向',async (c,f)=>{await COMP(c,{bearing:'0 至 359，正北是 0',err:'罗盘目标方位须为 0 至 359 度'}); TOAST(f,'这台设备没报出方向，请在真机上试',220);},'A4.30 no heading from the device (simulator / no compass): toast, and on save the field error.');
// A4.31 shout
await MK('A4.31 喊一嗓子',async c=>{await SUB(c,'喊一嗓子'); await FIELD(c,'标题 *','一起喊，让这儿听见'); await FIELD(c,'要连续喊满几秒 *','5'); await FIELD(c,'奖励分','10');},'A4.31 shout: 5 至 300 秒 (5); 奖励分 default 10, 0–1000.');
// A4.32 countdown
const CD=async(card,o={})=>{await SUB(card,'倒计时'); await FIELD(card,'标题 *','倒计时'); await FIELD(card,'倒计时长（秒） *','90'); await FIELD(card,'到点时说什么 *',o.done??'时间到。',{ph:o.done==='例如 时间到。',err:o.err});};
await MK('A4.32a 倒计时',c=>CD(c),'A4.32 countdown: 5 至 3600 秒 (90); 到点时说什么 ≤ 60.');
await MK('A4.32b 倒计时 · 校验错误',c=>CD(c,{done:'例如 时间到。',err:'到点时说什么不能为空'}),'A4.32 error.');
// A4.33 stopwatch
await MK('A4.33 精准停表',async c=>{await SUB(c,'精准停表'); await FIELD(c,'标题 *','把手机拿到面前，随时可以开始'); await GRID(c,['目标时间（秒） *','10'],['允许误差（毫秒） *','300']); await FIELD(c,'次数上限','3'); HINT(c,'0 表示不限，最多 10 次');},'A4.33 stopwatch: 目标 3 至 120 秒 (10), 误差 50 至 5000 毫秒 (300), 次数上限 0–10 (3; placeholder「0 表示不限」).');
// A4.34 typeIn
const TYPE=async(card,old)=>{await SUB(card,'输入挑战'); await FIELD(card,'标题 *','打出这行字'); await FIELD(card,'要打的那行字（1 至 40 字） *','hello world'); if(old) await GRID(card,['限时（3 至 120 秒） *','10'],['次数上限（0 = 不限）','0']); else await FIELD(card,'次数上限（0 = 不限）','0'); await SW(card,'区分大小写',false); await SW(card,'终端样式（黑底白字，打对后整屏收成一条线）',true); await FIELD(card,'奖励分','10'); if(!old) HINT(card,'限时在「互动工具 · 限时挑战」里设置');};
await MK('A4.34a 输入挑战 · 旧模板（卡内限时）',c=>TYPE(c,true),'A4.34 typeIn on an older template: the time limit sits in the card. 限时 3 至 120 秒 (10); 次数 ≥ 0.');
await MK('A4.34b 输入挑战 · 新模板（限时移到工具）',c=>TYPE(c,false),'A4.34 on new-style templates only the tries field shows; the time limit moves to the 限时挑战 tool (A10.7).');
FIT(sec);
// ---------- G4 sensor challenge (App) ----------
const g4=await SECTION('G4 传感器挑战 · 保持静止 / 步数挑战 / 音频片段 · App（TemplateSensorDraft）');
const MKG=async(label,build,note)=>{const {f,card}=await FRAME(g4,label); await build(card,f); NOTE(f,note); out[label]=f.id;};
const SENSOR=async(card,o={})=>{await SUB(card,'传感器挑战类型'); const dd=await DD(card,'类型',o.kind||'请选择类型；不会自动填写默认值',{ph:!o.kind,open:o.open});
 if(o.kind==='保持静止') await FIELD(card,'静止目标时长（秒）',o.v1??'30',{ph:o.v1==='未填写',err:o.err});
 if(o.kind==='步数挑战'){ await FIELD(card,'目标步数',o.v1??'2000',{err:o.err}); await FIELD(card,'计步时间窗（秒）',o.v2??'未填写',{ph:o.v2==null}); }
 if(o.kind==='音频片段') await FIELD(card,'音频最短时长（秒）',o.v1??'5');
 if(o.status) HINT(card,o.status,o.statusColor);
 const n=AL(card,'HORIZONTAL',{gap:8,pad:[10,12,10,12],r:11,fill:'surface-2',align:'MIN',name:'scope note'}); n.layoutSizingHorizontal='FILL'; HINT(n,'仅预览设置。不会录音、计步、上传或发布，也不会申请权限。');
 const b=AL(card,'HORIZONTAL',{fill:o.readOnly?'surface-2':'cta',r:999,main:'CENTER',align:'CENTER',name:'预览传感器配置'}); b.layoutSizingHorizontal='FILL'; b.counterAxisSizingMode='FIXED'; b.resize(b.width,44); TX(b,'预览传感器配置','MP/button',o.readOnly?'mp/disabled':'cta-ink',{size:15}); return dd;};
await MKG('G4a 传感器挑战 · 未选类型',c=>SENSOR(c,{status:'当前输入不完整或无效，仍可保存为本地草稿。'}),'G4 nothing preselected. Source: App/TemplateSensorDraftConfigurationView.swift + Core/TemplateSensorDraft.swift (no mini-program editor).');
await MKG('G4b 传感器挑战 · 类型下拉',async (c,f)=>{const dd=await SENSOR(c,{open:true}); await PANEL(f,dd.d,['保持静止','步数挑战','音频片段'],-1);},'G4 kinds: 保持静止 · 步数挑战 · 音频片段.');
await MKG('G4c 保持静止 · 已填',c=>SENSOR(c,{kind:'保持静止',v1:'30',status:'配置数值有效，尚未验证设备运行效果。'}),'G4 保持静止: 静止目标时长 1–600 秒, integers only.');
await MKG('G4d 步数挑战 · 未填完',c=>SENSOR(c,{kind:'步数挑战',v1:'2000',v2:null,status:'当前输入不完整或无效，仍可保存为本地草稿。'}),'G4 步数挑战: 目标步数 1–100000, 计步时间窗 1–86400 秒; an empty value shows 未填写.');
await MKG('G4e 音频片段 · 已填',c=>SENSOR(c,{kind:'音频片段',v1:'5',status:'配置数值有效，尚未验证设备运行效果。'}),'G4 音频片段 (声音密码): 音频最短时长 1–60 秒.');
await MKG('G4f 保持静止 · 字段错误',c=>SENSOR(c,{kind:'保持静止',v1:'900',err:'请输入所示范围内的整数。空白值会保持缺失状态。',status:'当前输入不完整或无效，仍可保存为本地草稿。',statusColor:'bad'}),'G4 field error (out of range).');
await MKG('G4g 已保存的设置不支持（只读）',async c=>{await SUB(c,'传感器挑战类型'); const n=AL(c,'HORIZONTAL',{gap:8,pad:12,r:11,fill:'warn-soft',align:'CENTER'}); n.layoutSizingHorizontal='FILL'; IC(n,'alert',16,'warn'); HINT(n,'此已保存的设置暂不支持，无法编辑，已原样保留。','ink'); await DD(c,'类型','—'); },'G4 read-only: unsupported stored data is kept as is.');
FIT(g4);
return out;
