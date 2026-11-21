const page=await figma.getNodeByIdAsync(PAGEID); await figma.setCurrentPageAsync(page);
await figma.loadFontAsync({family:'SF Pro',style:'Regular'});
const D={fit:'fit = .height(content) ≤ 62% · single detent: no grabber, no resize',
 ml:'.medium → .large (opens at .medium) · drag grows; content scrolls only at .large',
 fl:'fit → .large (opens at fit) · drag grows; content scrolls only at .large',
 f62:'.fraction(0.62) → .large (opens at 0.62, story flow visible above) · sub-pages push and force .large',
 l:'.large only (full-height task) · sub-editors push inside the sheet',
 h200:'.height(200) above the keyboard → grows with lines to .large', med:'.medium → .large as lines are added', lg:'.large (long text)', f420:'fit ≈ 420 · native graphical DatePicker'};
const ROWS=[
 [['237:51012','238:10351','239:33835','249:18596','237:64541','237:64724','239:20809','239:20874','239:20944','239:625','239:771','243:26185','243:26341','243:26503','238:19113','238:19278'],'fit'],
 [['246:6728','246:6908'],'f420'],
 [['238:10642','238:10960','246:5882','246:6169','246:7094','249:33124','249:33404','243:6962','237:53314','249:35244','249:35539','243:2078','247:17464','247:17512','247:17565','247:17619'],'ml'],
 [['238:11297','238:11545','239:31173','239:31330','239:31468'],'fl'],
 [['249:38453'],'f62'], [['239:33463'],'h200'],[['239:33587'],'med'],[['239:33711'],'lg'],
 [['248:3258','248:3357','248:3448'],'l'],
 [['R:238:19720:238:22215','R:237:71933:237:74256'],'f62'],
 [['R:239:24873:239:27314','R:237:64911:237:69968','R:237:70572:237:71146','R:237:25791:237:33389','R:239:1333:239:1749','R:239:21290:239:22084'],'ml'],
 [['R:239:31923:239:33192','S:241:1679','R:249:16472:249:17369'],'l'],
 [['R:249:19029:249:20582','R:249:32604:249:32995','R:237:70136:237:70439','R:237:74533:237:76180','R:238:15426:238:16017'],'fit'],
 [['R:238:12643:238:13611','R:239:919:239:1210'],'fl'],
];
const tops=[]; for(const s of page.children) if(s.type==='SECTION') for(const f of s.children) if(f.type==='FRAME'&&!f.name.startsWith('note')) tops.push(f);
const num=id=>{const [a,b]=id.split(':').map(Number); return a*1e6+b;};
const target=new Map();
for(const [ids,k] of ROWS) for(const id of ids){
  if(id.startsWith('R:')){ const [,a1,a2,b1,b2]=id.split(':'); const lo=num(a1+':'+a2), hi=num(b1+':'+b2); for(const f of tops){ const v=num(f.id); if(v>=lo&&v<=hi&&/弹层|sheet|·|选择|设置|编辑|确认|结果|添加|工具|消耗|奖励|费用|线索|投票|次数|限时|时段|排行|语音|音乐|物资|扫完|类别|场所|模板|合作者|预览|检查|分类|活动|成功/.test(f.name)) target.set(f.id,k); } }
  else if(id.startsWith('S:')){ const s=await figma.getNodeByIdAsync(id.slice(2)); if(s&&s.parent===page) for(const f of s.children) if(f.type==='FRAME') target.set(f.id,k); }
  else { const f=tops.find(t=>t.id===id); if(f) target.set(id,k); } }
let n=0;
for(const [id,k] of target){ const f=tops.find(t=>t.id===id); if(!f) continue; const par=f.parent; const nm=`note:${id}:detent`; const old=par.children.find(c=>c.name===nm); if(old) old.remove();
  const box=figma.createAutoLayout('VERTICAL'); par.appendChild(box); box.name=nm; box.fills=[{type:'SOLID',color:{r:0.89,g:0.94,b:1}}]; box.cornerRadius=6; box.paddingTop=box.paddingBottom=6; box.paddingLeft=box.paddingRight=8; box.counterAxisSizingMode='FIXED'; box.resize(Math.min(f.width,393),box.height);
  const t=figma.createText(); box.appendChild(t); t.fontName={family:'SF Pro',style:'Regular'}; t.fontSize=11; t.lineHeight={unit:'PIXELS',value:15}; t.characters=`Sheet detents (CF-13 · §3): ${D[k]}. Spring between detents: spring(response 0.38, dampingFraction 0.86) · Figma Smart Animate spring 290/27/1. Present ≈350 ms, dismiss 280 ms. Haptic .selection on settle. Reduce Motion: 200 ms cross-fade.`; t.fills=[{type:'SOLID',color:{r:0.08,g:0.2,b:0.45}}]; t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
  const mine=par.children.filter(c=>c!==box&&c.name.startsWith(`note:${id}`)); let y=f.y+f.height+10; for(const m of mine) y=Math.max(y,m.y+m.height+6); box.x=f.x; box.y=y;
  if(par.type==='SECTION'&&box.y+box.height+24>par.height) par.resizeWithoutConstraints(par.width,box.y+box.height+40); n++; }
return {n, ids:[...target.keys()].join(' ')};
