// Run as: page switch to R3 (91:33) + pre.js + wiz.js + this file, in one use_figma call. (NOTE helper in pre.js; relabel/card/item/wizard in wiz.js)
const E='成为主理人';
const s1=(err)=>[{t:'field',label:'实名/昵称',req:true,value:err?'你的称呼':'小城',state:err?'Error':'Filled',help:err?'填写实名或昵称':''},{t:'field',label:'手机号',req:true,value:err?'138 1234 567':'138 1234 5678',state:err?'Error':'Filled',help:err?'手机号是 11 位':'只用于平台联系你，不对外展示'},{t:'field',label:'身份说明（选填）',value:'如：高校社团负责人 / 户外领队',state:'Empty'},{t:'field',label:'联合创始人（选填）',value:'多人用逗号分隔',state:'Empty'}];
const s4=[{t:'sw',label:'持有导游 / 旅游资质',sub:'打开后上传证件，审核通过会显示资质标',on:true},{t:'uploads',labels:['资质证件','带队案例图']},{t:'text',s:'没有资质也可以先提交，之后在设置里补。',icon:'info'}];
const SPECS=[
 {id:'204:24431',step:1,eyebrow:E,title:'先认识一下你',sub:'四步，大约两分钟。',items:s1(false),primary:'下一步',note:'MC-10 · one wizard kit with 创建俱乐部. MC-05: 联系方式 → 手机号.'},
 {id:'225:13107',step:1,eyebrow:E,title:'先认识一下你',sub:'四步，大约两分钟。',items:s1(true),primary:'下一步',note:'MC-10 validation: inline errors, primary stays ENABLED and jumps to the first error (shake 240 ms, .error).'},
 {id:'204:24471',step:2,eyebrow:E,title:'你带过多少场？',sub:'按实际情况选，平台会据此推荐合作。',items:[...[['还没带过','从第一场开始也可以','person'],['1–5 场','带过几次小型活动','flag'],['5–20 场','有稳定的参与者','people'],['20 场以上','长期带队','star']].map(([t,s,i])=>({t:'opt',kind:'Single',title:t,sub:s,icon:i,sel:t==='5–20 场'})),{t:'pair',fields:[{kind:'Number',label:'最大带队人数',value:'30',suffix:'人'},{kind:'Number',label:'平均参与人数',value:'12',suffix:'人'}]}],primary:'下一步',note:'MC-10 · Single option cards replace square-box rows; Number fields with unit suffix.'},
 {id:'204:24516',step:3,eyebrow:E,title:'你能自己做哪些？',sub:'可多选，会显示在你的主理人资料里。',items:[['设计城市路线','路线、节点和步行顺序','route',true],['设计任务和解谜','线索、谜题和答案','layers',true],['带 NPC 和角色','现场扮演与互动','person',false],['与商家联动','合作店铺与权益','store',false]].map(([t,s,i,sel])=>({t:'opt',kind:'Multi',title:t,sub:s,icon:i,sel})),primary:'下一步 · 已选 2',note:'MC-10 · Multi option cards; count in the primary.'},
 {id:'204:24556',step:4,eyebrow:E,title:'有资质就传一份',sub:'这一步可以跳过。',items:s4,primary:'提交申请',note:'MC-10 · last apply step reads 提交申请. Neutral switch — Owner confirmed 2026-11-16 (Q-B).'},
 {id:'225:13162',step:4,eyebrow:E,title:'有资质就传一份',sub:'这一步可以跳过。',items:[...s4,{t:'banner',title:'提交没有完成',line:'网络异常，填写的内容已保留，再试一次。'}],primary:'重新提交',note:'MC-10 · submit failure = inline banner; primary retries.'},
];
const res=[]; for(const sp of SPECS) res.push(await wizard(sp)); return res;
