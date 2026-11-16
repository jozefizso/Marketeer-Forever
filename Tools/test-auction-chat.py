from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCoreDB={};UnitGUID=function()return 'player-one' end
CHAT_CONFIG_OTHER_SYSTEM={};ChatTypeInfo={SYSTEM={r=1,g=1,b=0}}
ChatFrame1={messageTypeList={'SYSTEM'},messages={},GetID=function()return 1 end,AddMessage=function(s,t)s.messages[#s.messages+1]=t end}
ChatFrame2={messageTypeList={},messages={},GetID=function()return 2 end,AddMessage=function(s,t)s.messages[#s.messages+1]=t end}
current=ChatFrame2;FCF_GetCurrentChatFrame=function()return current end
Enum={AuctionHouseNotification={AuctionSold=4,AuctionWon=2,BidPlaced=1}}
ChatFrameUtil={GetAuctionHouseNotificationText=function(n,arg)if n==4 then return 'Sold: '..arg elseif n==2 then return 'Won: '..arg elseif n==1 then return 'Bid placed' end end}
function CreateFrame() local f={};function f:RegisterEvent()end;function f:SetScript(_,fn)self.event=fn end;listener=f;return f end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/AuctionChat.lua').read_text(encoding='utf8'))
lua.execute('''
listener.event(nil,'PLAYER_LOGIN');listener.event(nil,'ADDON_LOADED');assert(#CHAT_CONFIG_OTHER_SYSTEM==1)
local setting=CHAT_CONFIG_OTHER_SYSTEM[1];assert(not setting.checked());setting.func(nil,true);assert(setting.checked())
listener.event(nil,'AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION',4,'Linen Cloth');assert(#ChatFrame2.messages==1 and ChatFrame2.messages[1]=='Sold: Linen Cloth');assert(#ChatFrame1.messages==0)
listener.event(nil,'AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION','Copper',3);assert(ChatFrame2.messages[2]=='Won: Copper x3')
ChatFrame2.messageTypeList={'SYSTEM'};listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(#ChatFrame2.messages==2)
ChatFrame2.messageTypeList={};setting.func(nil,false);listener.event(nil,'AUCTION_HOUSE_SHOW_NOTIFICATION',1);assert(#ChatFrame2.messages==2)
''')
print('Per-tab auction notification routing and duplicate avoidance passed.')
