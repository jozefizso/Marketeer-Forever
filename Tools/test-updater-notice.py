from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
clock=200000;GetServerTime=function()return clock end
MarketeerForeverCore={active=true,Market=function()return 'forever/pvp/horde/us' end}
MarketeerForeverCoreDB={};MarketeerForeverAPI={GetTableInfo=function()return {updated=clock}end}
StaticPopupDialogs={};notices={};print=function(s)notices[#notices+1]=s end
C_Timer={After=function(_,fn)fn()end}
objects={};local methods={}
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetScript(k,fn)self.scripts[k]=fn end
function methods:CreateFontString()return CreateFrame('Font')end
function methods:SetText(t)self.text=t end
function methods:Show()self.shown=true;self.shows=(self.shows or 0)+1 end
function methods:Hide()self.shown=false end
local mt={__index=function(_,k)return methods[k] or function()end end}
function CreateFrame(kind,name)local f=setmetatable({kind=kind,name=name,events={},scripts={},shown=true,shows=0},mt);objects[#objects+1]=f;return f end
UIParent=CreateFrame('UI')
function findName(n)for _,o in ipairs(objects) do if o.name==n then return o end end end
function findText(t)for _,o in ipairs(objects) do if o.text==t then return o end end end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/UpdaterNotice.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
local events;for _,o in ipairs(objects) do if o.events.AUCTION_HOUSE_SHOW then events=o end end
assert(events and next(StaticPopupDialogs)==nil)
events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');local dialog=findName('MarketeerUpdaterReminder');assert(dialog and dialog.shown and dialog.shows==1)
events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==1)
clock=clock+86400;events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==2)
local silence=findText('Silence reminders');silence.scripts.OnClick(silence);assert(MarketeerForeverCoreDB.silenceUpdaterReminders and not dialog.shown)
clock=clock+86400;events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==2)
MarketeerForeverCoreDB.silenceUpdaterReminders=false
MarketeerForeverMarketData={schemaVersion=1,periodHours=24,tables={['forever/pvp/horde/us']={updated=clock,text='2589:1:1:1:1:1:1:1:1'}}}
events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==2)
clock=clock+86401;events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==3)
clock=clock+86400;MarketeerForeverCore.active=false;events.scripts.OnEvent(events,'AUCTION_HOUSE_SHOW');assert(dialog.shows==3)
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','OtherAddon','SomeAction');assert(#notices==0)
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','MarketeerForever','UseContainerItem');assert(#notices==1 and notices[1]:find('UseContainerItem',1,true))
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','MarketeerForever','UseContainerItem');assert(#notices==1)
''')
print('Private reminder, 24-hour snooze, silence and blocked-action diagnostics passed.')
