const T={'FRAME':'F','TEXT':'T','INSTANCE':'I','COMPONENT':'C','COMPONENT_SET':'S','RECTANGLE':'R','VECTOR':'V','GROUP':'G','ELLIPSE':'E','BOOLEAN_OPERATION':'B','LINE':'L'};
const VI={}; for(const v of await figma.variables.getLocalVariablesAsync()) VI[v.id]=v;
const bn=n=>{ try{ const f=n.fills&&Array.isArray(n.fills)&&n.fills.find(f=>f.visible!==false); if(!f) return ''; const b=f.boundVariables&&f.boundVariables.color; if(b) return '{'+(VI[b.id]?VI[b.id].name:'?')+'}'; if(f.type==='SOLID'){const c=f.color; return '#'+[c.r,c.g,c.b].map(x=>Math.round(x*255).toString(16).padStart(2,'0')).join('');} return f.type; }catch(e){return ''} };
async function dump(n,d,max,o){ if(o.len>o.cap) return; let s='  '.repeat(d)+(T[n.type]||n.type)+' '+n.id+' '+n.name.slice(0,20)+' '+Math.round(n.width)+'x'+Math.round(n.height)+(n.layoutPositioning==='ABSOLUTE'?' abs@'+Math.round(n.x)+','+Math.round(n.y):'');
 if(n.visible===false) s+=' HID';
 if(n.type==='TEXT') s+=' "'+n.characters.slice(0,18).replace(/\n/g,'⏎')+'" '+(typeof n.fontSize==='number'?n.fontSize:'mix')+(n.textStyleId?'':' ns')+(n.componentPropertyReferences&&n.componentPropertyReferences.characters?' →'+n.componentPropertyReferences.characters.split('#')[0]:'');
 if(n.type==='INSTANCE'){ const m=await n.getMainComponentAsync(); if(m) s+=' <'+(m.parent&&m.parent.type==='COMPONENT_SET'?m.parent.name+':'+m.name:m.name).slice(0,40)+'>'; }
 if('layoutMode' in n && n.layoutMode && n.layoutMode!=='NONE') s+=' AL'+n.layoutMode[0]+(n.primaryAxisSizingMode||'')[0]+(n.counterAxisSizingMode||'')[0]+'g'+n.itemSpacing;
 const f=bn(n); if(f) s+=' '+f;
 o.out.push(s); o.len+=s.length;
 if(d<max && 'children' in n && n.type!=='INSTANCE') for(const c of n.children.slice(0,o.kids||30)) await dump(c,d+1,max,o); }
const res={};
const props=n=>{ const own=n.type==='COMPONENT_SET'?n:(n.parent&&n.parent.type==='COMPONENT_SET'?n.parent:n); try{ return Object.entries(own.componentPropertyDefinitions).map(([k,v])=>k.split('#')[0]+':'+v.type[0]+(v.variantOptions?'['+v.variantOptions.join('/')+']':'')).join(' | '); }catch(e){ return 'err'; } };
for(const [id,pick,max,cap] of __JOBS__){ const n=await figma.getNodeByIdAsync(id); if(!n){ res[id]='MISSING'; continue; } const o={out:[],len:0,cap};
 o.out.push('PROPS '+props(n)+(n.type==='COMPONENT_SET'?' || variants: '+n.children.map(c=>c.name).join('; ').slice(0,900):''));
 const targets=n.type==='COMPONENT_SET'&&pick?n.children.filter(c=>pick.some(p=>c.name===p)):[n];
 for(const t of targets) await dump(t,0,max,o); res[id]=o.out.join('\n'); }
const cols=await figma.variables.getLocalVariableCollectionsAsync();
res.vars=cols.map(c=>c.name+' ['+c.modes.map(m=>m.name).join(',')+'] '+c.variableIds.map(id=>VI[id]&&VI[id].name).join(',')).join('\n').slice(0,6000);
res.styles=(await figma.getLocalTextStylesAsync()).map(s=>s.name+':'+s.fontSize).join(', ');
return res;
