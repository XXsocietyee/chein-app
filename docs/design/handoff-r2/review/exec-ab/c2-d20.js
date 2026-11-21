const sec=await SECTION('A4 玩法设置卡 · 挑战 family（A4.24–A4.34）· temp 节点玩法模板编辑'); const out={};
const ATTR='加上属性';
async function D20(card,o={}){
 await SUB(card,'检定');
 if(o.attrState==='none'){ await FIELD(card,'技能','例如 观察',{ph:true}); HINT(card,'主题还没有设置属性，可以先写一个技能名'); }
 else if(o.attrState==='fail'){ const r=XROW(card,ATTR,null); const e=AL(card,'HORIZONTAL',{gap:6,align:'CENTER',name:'attr load error'}); e.layoutSizingHorizontal='FILL'; IC(e,'alert',14,'bad'); TX(e,'没有读取成功，请再试一次。','MP/label','bad',{size:12}); }
 else if(o.attrOpen){ XROW(card,ATTR,'洞察',{open:true,valueColor:'ink'}); const g=AL(card,'VERTICAL',{gap:0,pad:[4,12,4,12],r:12,fill:'surface-2',name:'attribute checklist'}); g.layoutSizingHorizontal='FILL'; for(const [a,on] of [['探索',false],['体魄',false],['洞察',true],['魅力',false],['运气',false],['城识',false]]) CHECKROW(g,a,on); const ad=AL(g,'HORIZONTAL',{gap:4,align:'CENTER',pad:[10,0,10,0]}); IC(ad,'plus',14,'link'); TX(ad,'添加属性','MP/body','link',{size:14}); }
 else XROW(card,ATTR,o.attr||'未选',{valueColor:o.attr?'ink':'ink-3'});
 HAIR(card);
 const dd=await DD(card,'难度',o.diff||'中等');
 HAIR(card);
 await LABEL(card,'情境加值');
 const bon=o.bonus||[];
 for(let i=0;i<bon.length;i++){ const [cond,val,open]=bon[i]; await ITEM(card,`${cond} · ${val}`,async it=>{ if(open){ STEP(it,'至少','1'); CHIPS(it,['固定加值','加上属性值'],0,{grow:true}); STEP(it,'加值','+2'); const d=AL(it,'HORIZONTAL',{main:'MIN'}); TX(d,'删除','MP/body-strong','bad',{size:13}); } }); }
 await ADD(card,'＋ 添加加值');
 if(o.bargain!==undefined){ HAIR(card); await SW(card,'魔鬼交易',o.bargain); if(o.bargain){ await FIELD(card,'说明','用一点体魄换更高的加值'); await LABEL(card,'加值'); CHIPS(card,['加值 +1','加值 +2','加值 +3'],1,{grow:true}); await LABEL(card,'代价'); await ITEM(card,'体魄 × 1',async it=>{ STEP(it,'数量','1'); const d=AL(it,'HORIZONTAL',{main:'MIN'}); TX(d,'删除','MP/body-strong','bad',{size:13}); }); await ITEM(card,'运气 × 2',null); await ADD(card,'＋ 添加代价'); } }
 HAIR(card);
 await FIELD(card,'过了说一句',o.pass||'例如 你在石缝里摸到了一把旧钥匙',{area:true,ph:!o.pass});
 await FIELD(card,'没过说一句',o.fail||'例如 什么也没找到，换个角度再看看',{area:true,ph:!o.fail});
 if(o.effects){ await LABEL(card,'判定通过后的效果'); await ITEM(card,'效果 1',async it=>{ const r=AL(it,'HORIZONTAL',{gap:8}); r.layoutSizingHorizontal='FILL'; TX(r,'体魄','MP/body','ink',{size:14}).layoutGrow=1; TX(r,'增加 1','MP/body','ink-3',{size:14}); }); await LABEL(card,'判定失败后的效果'); await ITEM(card,'效果 1',async it=>{ const r=AL(it,'HORIZONTAL',{gap:8}); r.layoutSizingHorizontal='FILL'; TX(r,'运气','MP/body','ink',{size:14}).layoutGrow=1; TX(r,'恢复到至少 1','MP/body','ink-3',{size:14}); }); }
 HAIR(card);
 await SW(card,'幸运',!!o.luck); let luckDD=null; if(o.luck){ luckDD=(await DD(card,'幸运加分',o.luck,{open:o.luckOpen})).d; }
 await SW(card,'生命值越低越困难',!!o.hp);
 await SW(card,'状态不好时松一点',!!o.relax); if(o.relax) await DD(card,'放宽方式','血量低时多给 30 秒');
 return {dd,luckDD};}
// a 默认
{const {f,card}=await FRAME(sec,'A4.24a D20 · 默认'); await D20(card,{}); NOTE(f,'A4.24 D20 check, new node (owner ③a 5390:13149). 难度 is a dropdown, as in the owner reference (the spec text says segmented; owner wins). 状态不好时松一点 sits in the card as in the owner reference. 魔鬼交易 is hidden because the theme has not enabled it. Lists drag-reorder (owner Q8).'); out.a=f.id;}
// b 已配置
{const {f,card}=await FRAME(sec,'A4.24b D20 · 已配置 (full)'); await D20(card,{attr:'洞察',bonus:[['手里有放大镜','+2',true],['天黑以后','+1',false]],pass:'你在石缝里摸到了一把旧钥匙。',fail:'什么也没找到，换个角度再看看。',effects:true,luck:'幸运高多 1 分，幸运低少 1 分',hp:true,relax:true}); NOTE(f,'A4.24 configured (owner ③b 5390:13171): 加上属性 = 洞察 (theme attribute from 六维), 情境加值 with one row expanded (至少 / 固定加值·加上属性值 / 加值 / 删除), result texts, effect rows (A5.3), 幸运加分, 生命值越低越困难, 状态不好时松一点. Condition names and texts are samples.'); out.b=f.id;}
// c attribute checklist open
{const {f,card}=await FRAME(sec,'A4.24c D20 · 加上属性 展开（属性清单）'); await D20(card,{attrOpen:true}); NOTE(f,'A4.24 加上属性 expanded: the theme’s attributes (六维: 探索 / 体魄 / 洞察 / 魅力 / 运气 / 城识) as a checklist, and 添加属性 which goes back to the theme’s d20 settings (B7.8). One group row open at a time.'); out.c=f.id;}
// d no attributes
{const {f,card}=await FRAME(sec,'A4.24d D20 · 主题没有属性（技能文本）'); await D20(card,{attrState:'none'}); NOTE(f,'A4.24 the theme has no attributes: 技能 is a plain text field.'); out.d=f.id;}
// e load failed
{const {f,card}=await FRAME(sec,'A4.24e D20 · 属性读取失败'); await D20(card,{attrState:'fail'}); NOTE(f,'A4.24 attribute list failed to load: red line, tap to retry.'); out.e=f.id;}
// f luck dropdown open
{const {f,card}=await FRAME(sec,'A4.24f D20 · 幸运加分 下拉展开'); const {luckDD}=await D20(card,{luck:'幸运高多 1 分',luckOpen:true}); await PANEL(f,luckDD,['幸运高多 1 分','幸运低少 1 分','幸运高多 1 分，幸运低少 1 分'],0); NOTE(f,'A4.24 幸运加分 options (owner ③c 5390:13199; copy from the code).'); out.f=f.id;}
// g bargain on
{const {f,card}=await FRAME(sec,'A4.24g D20 · 魔鬼交易 开 (full)'); await D20(card,{attr:'洞察',bargain:true}); NOTE(f,'A4.24 魔鬼交易 (shown only when the theme enables it): 说明, 加值 +1/+2/+3, 代价 rows with a quantity stepper and 删除, 添加代价 opens A11.5 (drawn in section A11). Cost names are theme values (samples).'); out.g=f.id;}
// h drag reorder
{const {f,card}=await FRAME(sec,'A4.24h D20 · 情境加值 拖动排序（Q8）'); await D20(card,{attr:'洞察',bonus:[['手里有放大镜','+2',false],['天黑以后','+1',false],['和队友一起','+1',false]]}); const items=card.findAll(x=>x.name.startsWith('list item/')); const lifted=items[1]; if(lifted){ lifted.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.18},offset:{x:0,y:8},radius:20,spread:0,visible:true,blendMode:'NORMAL'}]; lifted.rotation=0; lifted.opacity=1; lifted.name+=' · lifted'; }
 NOTE(f,'Owner answer Q8: list editors get drag handles. The second 情境加值 row is lifted (shadow, .impact(.light) on pick-up, .selection on each slot change, .impact(.medium) on drop). Order is saved as shown. Same pattern for 代价.'); out.h=f.id;}
FIT(sec);
return out;
