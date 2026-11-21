const page=await figma.getNodeByIdAsync('237:14642'); await figma.setCurrentPageAsync(page);
// note helper: visible canvas annotation under a frame (inside its section)
await figma.loadFontAsync({family:'SF Pro',style:'Regular'}); await figma.loadFontAsync({family:'SF Pro',style:'Semibold'});
async function NOTE(frameId, text, tag){ const f=await figma.getNodeByIdAsync(frameId); const par=f.parent; const old=par.children.find(c=>c.name===`note:${frameId}${tag?':'+tag:''}`); if(old) old.remove();
 const n=figma.createAutoLayout('VERTICAL'); par.appendChild(n); n.name=`note:${frameId}${tag?':'+tag:''}`; n.fills=[{type:'SOLID',color:{r:1,g:0.957,b:0.761}}]; n.cornerRadius=6; n.paddingTop=n.paddingBottom=6; n.paddingLeft=n.paddingRight=8; n.itemSpacing=2; n.counterAxisSizingMode='FIXED'; n.resize(Math.min(f.width,393),n.height);
 const t=figma.createText(); n.appendChild(t); t.fontName={family:'SF Pro',style:'Regular'}; t.fontSize=11; t.lineHeight={unit:'PIXELS',value:15}; t.characters=text; t.fills=[{type:'SOLID',color:{r:0.25,g:0.2,b:0.05}}]; t.layoutSizingHorizontal='FILL'; t.textAutoResize='HEIGHT';
 // stack below existing notes for this frame
 const mine=par.children.filter(c=>c!==n&&c.name.startsWith(`note:${frameId}`)); let y=f.y+f.height+10; for(const m of mine) y=Math.max(y,m.y+m.height+6);
 n.x=f.x; n.y=y; growSec(n); return n.id; }
async function SETTXT(id, s){ const t=await figma.getNodeByIdAsync(id); if(!t||t.type!=='TEXT') return 'miss '+id; for(const seg of t.getStyledTextSegments(['fontName'])) await figma.loadFontAsync(seg.fontName); t.characters=s; return id; }
function growSec(n){ const par=n.parent; if(par&&par.type==='SECTION'&&n.y+n.height+24>par.height) par.resizeWithoutConstraints(par.width,n.y+n.height+40); }
const done=[];
done.push(await SETTXT('237:22331','网络暂时不可用，请稍后重试'));
done.push(await NOTE('237:22192','note: 失败原因为示例文案；线上取接口返回的原因（CF-01）。'));
done.push(await SETTXT('237:51418','复制为新草稿'));
done.push(await SETTXT('237:51419','复制后需要重新选择：票种的集合时间与集合地点'));
done.push(await NOTE('237:51305','note: 正文列出的需重选项为示例；按实际缺失字段列出（CF-01）。'));
for(const id of ['241:2013','241:2429','241:2808','241:3185','249:42231','249:42646','249:43024','249:43400']) done.push(await SETTXT(id,'蓝 · 晴空'));
for(const f of ['241:1680','241:2059','241:2475','241:2854','249:41900','249:42278','249:42693','249:43071']) done.push(await NOTE(f,'note: 选中项的说明显示在选项下方（CF-01）。'));
done.push(await SETTXT('249:17123','主题详情')); done.push(await SETTXT('249:17133','第三章 · 码头旧仓'));
done.push(await NOTE('249:17076','note: 主题与章节名为样例数据（CF-01）。'));
for(const id of ['249:34150','249:34422','249:34698','249:34973','249:35243']) done.push(await SETTXT(id,'内容由 AI 生成，发布前请自行核对'));
done.push(await SETTXT('249:34970','生成失败，请稍后再试'));
for(const f of ['249:33879','249:34151','249:34423','249:34974']) done.push(await NOTE(f,'note: AI 来源说明行：固定文案，显示在生成结果下方（CF-01）。'));
done.push(await NOTE('249:34699','note: AI 来源说明为固定文案；失败原因为示例，线上取接口原因（CF-01）。'));
const card=await figma.getNodeByIdAsync('239:6450');
const kids=card.findAll(n=>/note|说明|备注|标注|设计/i.test(n.name)||(n.type==='TEXT'&&/设计|说明：|注：|note/i.test(n.characters))).map(n=>`${n.type} ${n.id} ${n.name.slice(0,30)} ${n.type==='TEXT'?n.characters.slice(0,60):''} p=${n.parent.name.slice(0,20)}`);
return {done, kids};
