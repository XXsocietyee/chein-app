const T={'FRAME':'F','TEXT':'T','INSTANCE':'I','COMPONENT':'C','COMPONENT_SET':'S','RECTANGLE':'R','VECTOR':'V','GROUP':'G','ELLIPSE':'E','SECTION':'§','BOOLEAN_OPERATION':'B','LINE':'L'};
const VI={}; for(const v of await figma.variables.getLocalVariablesAsync()) VI[v.id]=v.name;
const bn=n=>{ try{ const f=n.fills&&Array.isArray(n.fills)&&n.fills.find(f=>f.visible!==false); if(!f) return ''; const b=f.boundVariables&&f.boundVariables.color; if(b) return '{'+VI[b.id]+'}'; if(f.type==='SOLID'){const c=f.color; return '#'+[c.r,c.g,c.b].map(x=>Math.round(x*255).toString(16).padStart(2,'0')).join('')+(f.opacity!=null&&f.opacity<1?'@'+f.opacity.toFixed(2):'');} return f.type; }catch(e){return ''} };
async function dump(n,d,max,o){ if(o.len>o.cap) return; let s='  '.repeat(d)+(T[n.type]||n.type)+' '+n.id+' '+n.name.slice(0,22)+' '+Math.round(n.width)+'x'+Math.round(n.height)+'@'+Math.round(n.x)+','+Math.round(n.y);
 if(n.visible===false) s+=' HID';
 if(n.type==='TEXT') s+=' "'+n.characters.slice(0,30).replace(/\n/g,'⏎')+'" '+(typeof n.fontSize==='number'?n.fontSize:'mix')+(n.textStyleId?'':' ns');
 if(n.type==='INSTANCE'){ const m=await n.getMainComponentAsync(); if(m) s+=' <'+(m.parent&&m.parent.type==='COMPONENT_SET'?m.parent.name+':'+m.name:m.name).slice(0,60)+'>'; try{ const p=n.componentProperties; s+=' {'+Object.entries(p).map(([k,v])=>k.split('#')[0]+'='+String(v.value).slice(0,14)).join('|').slice(0,160)+'}'; }catch(e){} }
 if('layoutMode' in n && n.layoutMode && n.layoutMode!=='NONE') s+=' AL:'+n.layoutMode[0]+(n.primaryAxisSizingMode||'')[0]+(n.counterAxisSizingMode||'')[0]+' g'+n.itemSpacing;
 const f=bn(n); if(f) s+=' '+f;
 o.out.push(s); o.len+=s.length;
 if(d<max && 'children' in n && (n.type!=='INSTANCE'||o.inst)) for(const c of n.children.slice(0,o.kids||40)) await dump(c,d+1,max,o); }
const JOBS=__JOBS__; const res={};
for(const [id,max,cap,inst,kids] of JOBS){ const n=await figma.getNodeByIdAsync(id); if(!n){ res[id]='MISSING'; continue; } const o={out:[],len:0,cap,inst,kids}; await dump(n,0,max,o); res[id]=o.out.join('\n'); }
return res;
