await figma.setCurrentPageAsync(await figma.getNodeByIdAsync('204:7911'));
const T={'FRAME':'F','TEXT':'T','INSTANCE':'I','COMPONENT':'C','COMPONENT_SET':'S','RECTANGLE':'R','VECTOR':'V','GROUP':'G','ELLIPSE':'E','SECTION':'§','BOOLEAN_OPERATION':'B'};
const VI={}; for(const v of await figma.variables.getLocalVariablesAsync()) VI[v.id]=v;
const bn=n=>{ try{ const f=n.fills&&Array.isArray(n.fills)&&n.fills.find(f=>f.visible!==false); if(!f) return ''; const b=f.boundVariables&&f.boundVariables.color; return b?'{'+(VI[b.id]?VI[b.id].name:'?')+'}':''; }catch(e){return ''} };
const res={};
const top=n=>{ let p=n; while(p.parent&&p.parent.type!=='SECTION'&&p.parent.type!=='PAGE') p=p.parent; return p; };
async function dump(n,d,max,o){ if(o.len>o.cap) return; let s='  '.repeat(d)+(T[n.type]||n.type)+' '+n.id+' '+n.name.slice(0,18)+' '+Math.round(n.width)+'x'+Math.round(n.height)+'@'+Math.round(n.x)+','+Math.round(n.y)+(n.visible===false?' HID':'');
 if(n.type==='TEXT') s+=' "'+n.characters.slice(0,26).replace(/\n/g,'⏎')+'" '+(typeof n.fontSize==='number'?n.fontSize:'m');
 if(n.type==='INSTANCE'){ const m=await n.getMainComponentAsync(); if(m) s+=' <'+(m.parent&&m.parent.type==='COMPONENT_SET'?m.parent.name+':'+m.name:m.name).slice(0,44)+'>'; try{ s+=' {'+Object.entries(n.componentProperties).filter(([k,v])=>v.type!=='INSTANCE_SWAP'&&v.type!=='VARIANT').map(([k,v])=>k.split('#')[0]+'='+String(v.value).slice(0,12)).join('|').slice(0,120)+'}'; }catch(e){} }
 if('layoutMode' in n&&n.layoutMode&&n.layoutMode!=='NONE') s+=' AL'+n.layoutMode[0]; const f=bn(n); if(f) s+=' '+f;
 o.out.push(s); o.len+=s.length; if(d<max&&'children' in n&&n.type!=='INSTANCE') for(const c of n.children.slice(0,24)) await dump(c,d+1,max,o); }
const J=__J__;
for(const [id,max,cap] of J){ const n=await figma.getNodeByIdAsync(id); if(!n){ res[id]='MISSING'; continue; } const o={out:[],len:0,cap}; await dump(n,0,max,o); res[id]=o.out.join('\n'); }
// all deed instances on the page
const deeds=[]; for(const i of figma.currentPage.findAllWithCriteria({types:['INSTANCE']})){ if(i.name!=='City/Deed Card'&&!/Deed/.test(i.name)) continue; const m=await i.getMainComponentAsync(); if(!m||!m.parent||m.parent.name!=='City/Deed Card') continue; const p=i.componentProperties; const g=k=>{ const e=Object.entries(p).find(([kk])=>kk.split('#')[0]===k); return e?e[1].value:''; }; deeds.push(i.id+'|'+top(i).name.slice(0,14)+'|'+m.name.replace('Size=','').replace(', State=','/')+'|'+g('名称')+'|'+g('等级')); }
res.deeds=deeds.join('\n');
const sec=await figma.getNodeByIdAsync('399:4429'); res.strips=sec?sec.children.filter(c=>c.type==='FRAME').map(c=>c.id+' '+c.name.slice(0,30)+' ['+c.children.map(k=>k.name.slice(0,14)).join(',').slice(0,90)+']').join('\n').slice(0,5000):'none';
const la=await figma.getNodeByIdAsync('208:2662'); res.la=la.children.filter(c=>c.type==='FRAME').map(c=>c.id+' '+c.name.slice(0,20)+' '+c.findAll(n=>n.type!=='TEXT'&&Array.isArray(n.fills)&&n.fills.some(f=>f.boundVariables&&f.boundVariables.color&&/info|ok|warn|teal|me|link|route/.test((VI[f.boundVariables.color.id]||{}).name||''))).map(n=>n.name.slice(0,12)+':'+bn(n)).slice(0,6).join(',')).join('\n');
return res;
