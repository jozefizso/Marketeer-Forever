// Build a local snapshot from the user's completed AH item-source scrape.
import {readFile,writeFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const base=dirname(fileURLToPath(import.meta.url));
const root=join(base,'..','..');
const checkpoint=JSON.parse(await readFile(join(root,'wowhead-scraper','wowhead-drops.json'),'utf8'));
const queue=JSON.parse(await readFile(join(root,'wowhead-scraper','ahledger-all-markets-history-queue.json'),'utf8'));
const mobs=new Map(), names=new Map();
const number=v=>{if(v===null||v===undefined||v==='')return null;const n=Number(String(v).replace(/,/g,''));return Number.isFinite(n)?n:null};
for(const {itemId} of queue.items){
  const item=checkpoint.items[itemId];
  if(!item||item.source_schema!==2||!Array.isArray(item.dropped_by))continue;
  names.set(itemId,item.item?.name||`Item #${itemId}`);
  for(const d of item.dropped_by){
    const id=Number(d.npc_url?.match(/\/npc=(\d+)/)?.[1]);
    const range=String(d.level||'').match(/^(\d+)(?:\s*-\s*(\d+))?/);
    const pct=number(d.drop_percent), hits=number(d.drops), total=number(d.total_looted);
    if(!id||!range||pct===null||pct<0||pct>100||!total||hits===null||hits<0||hits>total)continue;
    const min=Number(range[1]), max=Number(range[2]||range[1]);
    if(min<1||max<min||max>100)continue;
    let mob=mobs.get(id);
    if(!mob){mob={id,name:d.name||`NPC #${id}`,min,max,level:d.level,location:d.location||'Unknown',drops:new Map()};mobs.set(id,mob)}
    else {mob.min=Math.min(mob.min,min);mob.max=Math.max(mob.max,max)}
    const previous=mob.drops.get(itemId);
    if(!previous||total>previous.total)mob.drops.set(itemId,{id:itemId,pct,hits,total,classic:d.rate_source==='Classic Era'});
  }
}
const quote=value=>JSON.stringify(String(value)).replace(/\\u0000/g,'');
let out='-- Local snapshot of Wowhead item sources; rates are observations.\nMarketeerForeverFarmData={items={\n';
for(const [id,name] of names)out+=`[${id}]=${quote(name)},\n`;
out+='},mobs={\n';
let dropCount=0;
for(const mob of mobs.values()){
  const rows=[...mob.drops.values()];dropCount+=rows.length;
  out+=`[${mob.id}]={name=${quote(mob.name)},min=${mob.min},max=${mob.max},level=${quote(mob.level)},location=${quote(mob.location)},drops={${rows.map(d=>`{${d.id},${d.pct},${d.hits},${d.total},${d.classic?'true':'false'}}`).join(',')}}},\n`;
}
out+='}}\n';
await writeFile(join(base,'..','MarketeerForever','Market','FarmData.lua'),out);
console.log(JSON.stringify({mobs:mobs.size,drops:dropCount,items:names.size,bytes:Buffer.byteLength(out)}));
