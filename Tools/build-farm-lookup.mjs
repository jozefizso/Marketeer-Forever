// Build the item-to-monster lookup independently of market prices and levels.
import {readFile,writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const base=dirname(fileURLToPath(import.meta.url)),root=join(base,'..','..');
const checkpoint=JSON.parse(await readFile(join(root,'wowhead-scraper','wowhead-drops.json'),'utf8'));
const npcs=new Map(),items=new Map(),anonymous=new Map();let nextAnonymous=-1;
const num=v=>{if(v===null||v===undefined||v==='')return null;const n=Number(String(v).replace(/,/g,''));return Number.isFinite(n)?n:null};
const quote=v=>JSON.stringify(String(v));
for(const [key,item] of Object.entries(checkpoint.items)){
  const itemId=Number(key);if(!Number.isInteger(itemId)||item?.source_schema!==2||!Array.isArray(item.dropped_by))continue;
  const drops=new Map();
  for(const d of item.dropped_by){
    let id=Number(d.npc_url?.match(/\/npc=(\d+)/)?.[1]);
    if(!id){const key=JSON.stringify([d.name,d.level,d.location]);if(!anonymous.has(key))anonymous.set(key,nextAnonymous--);id=anonymous.get(key)}
    if(!npcs.has(id))npcs.set(id,{name:d.name||'Unknown',level:d.level||'Unknown',location:d.location||'Unknown'});
    const rate=num(d.drop_percent),total=num(d.total_looted);
    const entry=[id,rate!==null&&rate>=0&&rate<=100?rate:null,total!==null&&total>0?total:null,d.rate_source==='Classic Era'];
    const old=drops.get(id);if(!old||(entry[2]||0)>(old[2]||0))drops.set(id,entry);
  }
  const sources=[];
  for(const vendor of item.sold_by||[]) sources.push({name:vendor.name||'Unknown vendor',level:vendor.level||'—',location:vendor.location||'Unknown',type:'Sold by',rate:null,sample:null});
  for(const group of item.other_sources||[]) for(const row of group.rows||[]){
    const columns=row.columns||[];const cell=n=>columns.find(c=>String(c.name||'').toLowerCase()===n.toLowerCase());
    const named=cell('Name');let name=named?.text||named?.links?.find(l=>l.name)?.name;
    if(!name&&group.id==='created-by-spell')name=cell('Reagents')?.text;
    if(!name&&group.id==='contained-in-item')name=cell('ILvl')?.text;
    const location=cell('Location')?.text||cell('Category')?.text||'Unknown';
    const raw=cell('%')?.text,match=typeof raw==='string'&&raw.match(/^\s*(\d+(?:\.\d+)?)\s*%?\s*$/);
    const count=cell('Count')?.text;
    sources.push({name:name||'Details unavailable',level:cell('Level')?.text||'—',location,type:(group.label||'Other source').replace(/\s*\(\d+\)\s*$/,''),rate:match?Number(match[1]):null,sample:typeof count==='string'&&/\d\s+out of\s+\d/i.test(count)?count:null});
  }
  items.set(itemId,{name:item.item?.name||`Item #${itemId}`,drops:[...drops.values()].sort((a,b)=>(b[1]??-1)-(a[1]??-1)),sources});
}
let out='-- Completed AH-item drop snapshot; unknown levels/rates are retained.\nMarketeerForeverFarmLookup={npcs={\n';
for(const [id,n] of npcs)out+=`[${id}]={${quote(n.name)},${quote(n.level)},${quote(n.location)}},\n`;
out+='},items={\n';let count=0;
for(const [id,item] of items){count+=item.drops.length;out+=`[${id}]={name=${quote(item.name)},drops={${item.drops.map(d=>`{${d[0]},${d[1]??'nil'},${d[2]??'nil'},${d[3]?'true':'false'}}`).join(',')}},sources={${item.sources.map(s=>`{${quote(s.name)},${quote(s.level)},${quote(s.location)},${s.rate??'nil'},${s.sample?quote(s.sample):'nil'},${quote(s.type)}}`).join(',')}}},\n`}
out+='}}\n';await writeFile(join(base,'..','MarketeerForever','Market','FarmLookupData.lua'),out);
console.log(JSON.stringify({items:items.size,npcs:npcs.size,drops:count,bytes:Buffer.byteLength(out)}));
