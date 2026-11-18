from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
clock=200000;GetServerTime=function()return clock end
MarketeerForeverCore={Market=function()return 'forever/pvp/horde/us' end,LoadMarketSnapshot=function()end}
MarketeerForeverCoreDB={};notices={};print=function(s)notices[#notices+1]=s end
C_Timer={After=function(_,fn)fn()end}
objects={};local methods={}
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetScript(k,fn)self.scripts[k]=fn end
function methods:CreateFontString()return CreateFrame('Font')end
function methods:SetText(t)self.text=t end
function methods:Show()self.shown=true;self.shows=(self.shows or 0)+1 end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
local mt={__index=function(_,k)return methods[k] or function()end end}
function CreateFrame(kind,name)local f=setmetatable({kind=kind,name=name,events={},scripts={},shown=false,shows=0},mt);objects[#objects+1]=f;return f end
UIParent=CreateFrame('UI')
function findName(n)for _,o in ipairs(objects) do if o.name==n then return o end end end
function findText(t)for _,o in ipairs(objects) do if o.text==t then return o end end end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/UpdaterNotice.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
local events;for _,o in ipairs(objects) do if o.events.PLAYER_LOGIN then events=o end end
assert(events);events.scripts.OnEvent(events,'PLAYER_LOGIN');assert(not findName('MarketeerDataAnnouncement'))
MarketeerSnapshotCompanion=1
MarketeerSnapshotMarketData={schemaVersion=1,periodHours=24,tables={['forever/pvp/horde/us']={updated=clock-200000,count=1,text='2589:1:1:1:1:1:1:1:1'}}}
events.scripts.OnEvent(events,'PLAYER_LOGIN');assert(not findName('MarketeerDataAnnouncement'))
MarketeerSnapshotMarketData.tables['forever/pvp/horde/us'].updated=clock
events.scripts.OnEvent(events,'PLAYER_LOGIN');local dialog=findName('MarketeerDataAnnouncement');assert(dialog and dialog.shown)
local continue=findText('Continue');local back=findText('Back');local confirm=findText('Yes, I understand')
assert(continue.shown and not back.shown and not confirm.shown)
continue.scripts.OnClick();assert(not continue.shown and back.shown and confirm.shown)
local found=false;for _,o in ipairs(objects) do local t=rawget(o,'text');if t and t:find('disable the old Marketeer Data addon',1,true) then assert(t:find('Keep Marketeer Market Data enabled',1,true));assert(t:find('|cffffd100HIGHLY RECOMMENDED:',1,true));found=true end end;assert(found)
back.scripts.OnClick();assert(continue.shown and not confirm.shown)
continue.scripts.OnClick();confirm.scripts.OnClick();assert(not dialog.shown and MarketeerForeverCoreDB.dataCompanionAcknowledged)
events.scripts.OnEvent(events,'PLAYER_LOGIN');assert(dialog.shows==1)
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','OtherAddon','SomeAction');assert(#notices==0)
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','MarketeerForever','UseContainerItem');assert(#notices==1 and notices[1]:find('UseContainerItem',1,true))
events.scripts.OnEvent(events,'ADDON_ACTION_BLOCKED','MarketeerForever','UseContainerItem');assert(#notices==1)
''')
print('Two-step companion announcement waits for current data and preserves blocked-action diagnostics.')
