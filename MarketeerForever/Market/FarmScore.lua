-- Value estimates assume one unit per drop; actual quantities are not in this snapshot.
MarketeerForeverFarmScore={}
local F=MarketeerForeverFarmScore
-- Expected value per successful skin; the source snapshot does not record stack sizes.
function F.Skin(drops,getMarket)
  if type(drops)~='table' or #drops==0 then return nil end
  local gross,priced,classic=0,0,false
  for _,drop in ipairs(drops) do
    local market=getMarket(drop[1]) or {};local price=market.price;local chance=drop[2]
    if type(price)=='number' and price>0 and type(chance)=='number' and chance>0 and chance<=100 then gross=gross+price*chance/100;priced=priced+1;if drop[4] then classic=true end end
  end
  return {gross=priced>0 and gross or nil,priced=priced,total=#drops,partial=priced<#drops,classic=classic}
end
function F.Drop(drop,price,sales)
  local percent,hits,total=drop[2],drop[3],drop[4]
  if type(percent)~='number' or type(total)~='number' or total<=0 or type(hits)~='number' or hits<0 or hits>total then return nil,nil end
  if type(price)~='number' or price<=0 then return nil,nil end
  local gross=price*percent/100
  if type(sales)~='number' or sales<0 or total<20 then return gross,nil end
  -- Conservative 80% one-sided Wilson lower bound, and strong liquidity discount.
  -- Wowhead's displayed rate and observation count can use different bases.
  -- Never substitute hits/total for the displayed percentage.
  local p=math.max(0,math.min(1,percent/100));local z=1.2815515655;local z2=z*z
  local lower=(p+z2/(2*total)-z*math.sqrt((p*(1-p)+z2/(4*total))/total))/(1+z2/total)
  -- Volume-only heuristic, not a sale probability; no listing supply is used.
  local weight=math.min(sales/300,1)
  return gross,price*math.max(0,lower)*weight*.95
end
function F.Mob(mob,getMarket,includeEntries)
  local gross,score,priced,scored,missingPrice,missingDemand,lowSample=0,0,0,0,0,0,0
  local entries={}
  for _,drop in ipairs(mob.drops) do
    local market=getMarket(drop[1]) or {};local value,weighted=F.Drop(drop,market.price,market.sales)
    if value then gross=gross+value;priced=priced+1 else missingPrice=missingPrice+1 end
    if weighted~=nil then score=score+weighted;scored=scored+1
    elseif value and drop[4]<20 then lowSample=lowSample+1
    elseif value then missingDemand=missingDemand+1 end
    if includeEntries then entries[#entries+1]={drop=drop,market=market,gross=value,score=weighted} end
  end
  return {gross=priced>0 and gross or nil,score=scored>0 and score or nil,priced=priced,scored=scored,missingPrice=missingPrice,missingDemand=missingDemand,lowSample=lowSample,entries=entries}
end
