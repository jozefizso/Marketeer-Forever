from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCoreDB={};UnitGUID=function()return 'player-one' end
MarketeerForeverCore={RegisterEscapeFrame=function()end}
CHAT_CONFIG_OTHER_SYSTEM={};ChatTypeInfo={SYSTEM={r=1,g=1,b=0}}
ChatFrame1={messageTypeList={'SYSTEM'},messages={},GetID=function()return 1 end,AddMessage=function(s,t)s.messages[#s.messages+1]=t end}
ChatFrame2={messageTypeList={},messages={},GetID=function()return 2 end,AddMessage=function(s,t)s.messages[#s.messages+1]=t end}
current=ChatFrame2;FCF_GetCurrentChatFrame=function()return current end
Enum={AuctionHouseNotification={AuctionSold=4,AuctionWon=2,BidPlaced=1}}
ChatFrameUtil={GetAuctionHouseNotificationText=function(n,arg)if n==4 then return 'Sold: '..arg elseif n==2 then return 'Won: '..arg elseif n==1 then return 'Bid placed' end end}
frames={};local methods={}
function methods:RegisterEvent()end
function methods:SetScript(k,fn)self.scripts[k]=fn;if k=='OnEvent' then self.event=fn end end
function methods:CreateFontString()return CreateFrame('Font')end
function methods:SetText(t)self.text=t end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:SetChecked(v)self.checked=v end
function methods:GetChecked()return self.checked end
local mt={__index=function(_,k)return methods[k] or function()end end}
function CreateFrame(kind,name) local f=setmetatable({kind=kind,name=name,scripts={}},mt);frames[#frames+1]=f;if not listener then listener=f end;return f end
UIParent=CreateFrame('UI');listener=nil
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/AuctionChat.lua').read_text(encoding='utf8'))
lua.execute('''
listener.event(nil,'PLAYER_LOGIN');listener.event(nil,'ADDON_LOADED');assert(#CHAT_CONFIG_OTHER_SYSTEM==1)
local setting=CHAT_CONFIG_OTHER_SYSTEM[1];assert(not setting.checked());setting.func(nil,true);assert(setting.checked())
listener.event(nil,'AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Linen Cloth');assert(#ChatFrame2.messages==1 and ChatFrame2.messages[1]=='Sold: Linen Cloth');assert(#ChatFrame1.messages==0)
listener.event(nil,'AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION','Copper',3);assert(ChatFrame2.messages[2]=='Won: Copper x3')
ChatFrame2.messageTypeList={'SYSTEM'};listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(#ChatFrame2.messages==2)
ChatFrame2.messageTypeList={};setting.func(nil,false);listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(#ChatFrame2.messages==2)
Chattynator={API={GetWindowsAndTabs=function()return {{'General','Auction'},{'Trade'}} end,AddMessageToWindowAndTab=function(w,t,text)lastChatty={w,t,text}end}}
MarketeerForeverCoreDB.auctionChattyTabs={['player-one']={['1'..string.char(31)..'Auction']=true}}
listener.event(nil,'AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Linen Cloth');assert(lastChatty[1]==1 and lastChatty[2]==2 and lastChatty[3]=='Sold: Linen Cloth')
lastChatty=nil;Chattynator.API.GetWindowsAndTabs=function()return {{'Auction','General'}}end
listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(lastChatty[1]==1 and lastChatty[2]==1)
lastChatty=nil;Chattynator.API.GetWindowsAndTabs=function()return {{'General'}}end
listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(lastChatty==nil and #ChatFrame2.messages==2)
Chattynator.API.GetWindowsAndTabs=function()return {{'General','Auction'}}end
MarketeerForeverCore.ShowAuctionChatSettings()
local popup,auctionRow
for _,f in ipairs(frames) do if f.name=='MarketeerAuctionChatSettings' then popup=f end;local key=rawget(f,'key');if key and key:find('Auction',1,true) then auctionRow=f end end
assert(popup and popup.shown and auctionRow and auctionRow.checked)
auctionRow.checked=false;auctionRow.scripts.OnClick(auctionRow);assert(not MarketeerForeverCoreDB.auctionChattyTabs['player-one'][auctionRow.key])
''')
print('Per-tab auction notification routing and duplicate avoidance passed.')
