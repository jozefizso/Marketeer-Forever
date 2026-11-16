-- A session shopping list: craft counts mean crafts, independent of output yield.
local core=MarketeerForeverCore
local recipes,vendors={},{}
local frame,content,scroll
local render,rendering
local requestedNames={}
local function bagCounts()
  if not C_Container or type(C_Container.GetContainerNumSlots)~='function' or type(C_Container.GetContainerItemInfo)~='function' then return nil end
  local counts,bagIDs,seen={},{},{}
  for bag=0,(NUM_BAG_SLOTS or 4) do bagIDs[#bagIDs+1]=bag;seen[bag]=true end
  local reagent=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
  if type(reagent)=='number' and reagent>=0 and not seen[reagent] then bagIDs[#bagIDs+1]=reagent end
  for _,bag in ipairs(bagIDs) do
    local ok,slots=pcall(C_Container.GetContainerNumSlots,bag)
    if not ok or (issecretvalue and issecretvalue(slots)) or type(slots)~='number' then return nil end
    for slot=1,slots do
      local success,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
      if not success then return nil end
      if info then
        local id,quantity=info.itemID,info.stackCount
        if issecretvalue and (issecretvalue(id) or issecretvalue(quantity)) then return nil end
        if type(id)~='number' or type(quantity)~='number' then return nil end
        counts[id]=(counts[id] or 0)+quantity
      end
    end
  end
  return counts
end
local function itemName(id,fallback)
  local name=GetItemInfo and GetItemInfo(id)
  if not name and C_Item and C_Item.GetItemNameByID then name=C_Item.GetItemNameByID(id) end
  local known=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[id]
  name=name or (known and known.name) or (MarketeerForeverFarmData and MarketeerForeverFarmData.items and MarketeerForeverFarmData.items[id])
  if not name and not requestedNames[id] and C_Item and C_Item.RequestLoadItemDataByID then requestedNames[id]=true;pcall(C_Item.RequestLoadItemDataByID,id) end
  return name or fallback or ('Item #'..id)
end
local function label(parent,x,y,w,font)
  local t
  if parent.pooled then parent.labelIndex=(parent.labelIndex or 0)+1;parent.labels=parent.labels or {};t=parent.labels[parent.labelIndex];if not t then t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');parent.labels[parent.labelIndex]=t end;t:SetFontObject(font or 'GameFontHighlightSmall');t:ClearAllPoints();t:Show()
  else t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall') end
  t:SetPoint('TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetWordWrap(false);return t
end
local function button(parent,text,w,fn)
  local b
  if parent.pooled then parent.buttonIndex=(parent.buttonIndex or 0)+1;parent.buttons=parent.buttons or {};b=parent.buttons[parent.buttonIndex];if not b then b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');parent.buttons[parent.buttonIndex]=b end;b:ClearAllPoints();b:Show()
  else b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate') end
  b:SetSize(w,22);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function create()
  if frame then return end
  frame=CreateFrame('Frame','MarketeerShoppingList',UIParent,'BackdropTemplate');frame:SetSize(420,420);frame:SetPoint('CENTER',UIParent,'CENTER',260,0);frame:SetFrameStrata('DIALOG');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(360,260,800,900) elseif frame.SetMinResize then frame:SetMinResize(360,260) end
  frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});frame:SetBackdropColor(.055,.075,.065,.98);frame:SetBackdropBorderColor(.25,.48,.34,1)
  local bar=CreateFrame('Frame',nil,frame);bar:SetPoint('TOPLEFT');bar:SetPoint('TOPRIGHT');bar:SetHeight(38);bar:EnableMouse(true);bar:RegisterForDrag('LeftButton');bar:SetScript('OnDragStart',function()frame:StartMoving()end);bar:SetScript('OnDragStop',function()frame:StopMovingOrSizing()end)
  label(bar,14,-12,280,'GameFontNormal'):SetText('SHOPPING LIST')
  local close=button(bar,'X',28,function()frame:Hide()end);close:SetPoint('TOPRIGHT',-8,-8)
  scroll=CreateFrame('ScrollFrame',nil,frame,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',12,-42);scroll:SetPoint('BOTTOMRIGHT',-30,42)
  content=CreateFrame('Frame',nil,scroll);content:SetSize(360,1);scroll:SetScrollChild(content)
  local clear=button(frame,'Clear list',85,function()recipes={};vendors={};render()end);clear:SetPoint('BOTTOMLEFT',12,10)
  local resize=button(frame,'Resize',64,function()end);resize:SetPoint('BOTTOMRIGHT',-8,8)
  resize:SetScript('OnMouseDown',function(_,which)if which=='LeftButton' then frame:StartSizing('BOTTOMRIGHT') end end);resize:SetScript('OnMouseUp',function()frame:StopMovingOrSizing()end);resize:SetScript('OnHide',function()frame:StopMovingOrSizing()end)
  frame:SetScript('OnSizeChanged',function()if render then render() end end)
  frame:Hide()
end
local widgets,used={},0
local function line(kind,y,width)
  used=used+1;local row=widgets[used];if not row then row=CreateFrame('Frame',nil,content);row.pooled=true;widgets[used]=row end
  row.labelIndex=0;row.buttonIndex=0;row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetSize(width,24);row:Show();return row
end
render=function()
  if not content or rendering then return end
  rendering=true
  for _,row in ipairs(widgets) do row:Hide();for _,v in ipairs(row.labels or {}) do v:Hide() end;for _,v in ipairs(row.buttons or {}) do v:Hide() end;if row.edit then row.edit:Hide() end end;used=0
  local width=math.max(300,(frame:GetWidth() or 420)-48);content:SetWidth(width);local y=0
  local materials={};local carried=bagCounts()
  if #recipes>0 then local r=line('heading',y,width);label(r,2,-4,width,'GameFontNormalSmall'):SetText('RECIPES  |  CRAFTS');y=y+25 end
  for i,recipe in ipairs(recipes) do
    local row=line('recipe',y,width);label(row,2,-4,width-150):SetText(recipe.name)
    local remove=button(row,'X',24,function()table.remove(recipes,i);render()end);remove:SetPoint('TOPRIGHT',0,0)
    local plus=button(row,'+',24,function()recipe.count=math.min(10000,recipe.count+1);render()end);plus:SetPoint('RIGHT',remove,'LEFT',-3,0)
    local edit=row.edit;if not edit then edit=CreateFrame('EditBox',nil,row,'InputBoxTemplate');row.edit=edit;edit:SetAutoFocus(false);edit:SetNumeric(true);edit:SetMaxLetters(5) end;edit:ClearAllPoints();edit:SetSize(44,22);edit:SetPoint('RIGHT',plus,'LEFT',-4,0);edit:SetText(tostring(recipe.count));edit:Show()
    edit:SetScript('OnTextChanged',function(s,userInput)if userInput then local n=tonumber(s:GetText());if n and n>0 then recipe.count=math.min(10000,math.floor(n)) end end end)
    edit:SetScript('OnEditFocusGained',function(s)s.startCount=recipe.count end)
    edit:SetScript('OnEditFocusLost',function()if not rendering then render() end end)
    edit:SetScript('OnEnterPressed',function(s)s:ClearFocus();render()end)
    edit:SetScript('OnEscapePressed',function(s)recipe.count=s.startCount or recipe.count;s:ClearFocus();render()end)
    local minus=button(row,'-',24,function()recipe.count=math.max(1,recipe.count-1);render()end);minus:SetPoint('RIGHT',edit,'LEFT',-4,0)
    for _,m in ipairs(recipe.materials) do local a=materials[m.id] or {id=m.id,name=m.name,quantity=0};a.quantity=a.quantity+m.quantity*recipe.count;materials[m.id]=a end
    y=y+27
  end
  local all={};for _,m in pairs(materials) do all[#all+1]=m end;table.sort(all,function(a,b)return a.name:lower()<b.name:lower()end)
  if #all>0 then local r=line('heading',y,width);label(r,2,-4,width-140,'GameFontNormalSmall'):SetText('MATERIALS NEEDED');local h=label(r,width-132,-4,130,'GameFontNormalSmall');h:SetJustifyH('RIGHT');h:SetText('IN BAGS / NEED');y=y+24 end
  for _,m in ipairs(all) do
    local r=line('material',y,width);label(r,8,-4,width-150):SetText(itemName(m.id,m.name))
    local have=carried and (carried[m.id] or 0);local progress=label(r,width-132,-4,130);progress:SetJustifyH('RIGHT')
    if have and have>=m.quantity then progress:SetText('|cff73e6a3[OK] '..have..' / '..m.quantity..'|r') else progress:SetText((have and tostring(have) or '--')..' / '..m.quantity) end
    y=y+22
  end
  if #vendors>0 then local r=line('heading',y,width);label(r,2,-4,width,'GameFontNormalSmall'):SetText('VENDOR ITEMS');y=y+24 end
  for i,item in ipairs(vendors) do local r=line('vendor',y,width);label(r,8,-4,width-105):SetText(item.name);local have=carried and (carried[item.id] or 0);local state=label(r,width-94,-4,58);state:SetJustifyH('RIGHT');state:SetText(have==nil and '--' or have>0 and '|cff73e6a3[OK]|r' or 'Needed');local remove=button(r,'X',24,function()table.remove(vendors,i);render()end);remove:SetPoint('TOPRIGHT',0,0);y=y+25 end
  if #recipes==0 and #vendors==0 then local r=line('empty',y,width);label(r,2,-4,width):SetText('Add a recipe or vendor item to get started.');y=y+25 end
  content:SetHeight(math.max(1,y+5))
  rendering=false
end
local itemEvents=CreateFrame('Frame');itemEvents:RegisterEvent('GET_ITEM_INFO_RECEIVED');itemEvents:RegisterEvent('BAG_UPDATE_DELAYED');itemEvents:SetScript('OnEvent',function(_,event,id,success)
  if event=='GET_ITEM_INFO_RECEIVED' then if not success or not requestedNames[id] then return end;requestedNames[id]=nil end
  if not frame or not frame:IsShown() then return end
  for _,row in ipairs(widgets) do if row.edit and row.edit.HasFocus and row.edit:HasFocus() then return end end
  render()
end)
function core.AddShoppingRecipe(recipe)
  if type(recipe)~='table' or type(recipe.materials)~='table' then return end
  local key=recipe.id or recipe.output or recipe.name;local found
  for _,r in ipairs(recipes) do if r.key==key then found=r;break end end
  if found then found.count=math.min(10000,found.count+1) else
    local r={key=key,name=recipe.name or 'Recipe',count=1,materials={}}
    for _,m in ipairs(recipe.materials) do if type(m.id)=='number' and type(m.quantity)=='number' and m.quantity>0 then r.materials[#r.materials+1]={id=m.id,name=m.name or ('Item #'..m.id),quantity=m.quantity} end end
    recipes[#recipes+1]=r
  end
  create();render();frame:Show()
end
function core.AddShoppingVendor(item)
  if type(item)~='table' or type(item.id)~='number' then return end
  local found=false;for _,v in ipairs(vendors) do if v.id==item.id then found=true;break end end
  if not found then vendors[#vendors+1]={id=item.id,name=item.name or ('Item #'..item.id)} end
  create();render();frame:Show()
end
