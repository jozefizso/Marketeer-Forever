from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
_G=_G or {}; clock=200000;GetServerTime=function()return clock end
MarketeerForeverCore={active=true,Market=function()return 'forever/pvp/horde/us' end}
MarketeerForeverCoreDB={};MarketeerForeverAPI={GetTableInfo=function()return {updated=clock}end}
StaticPopupDialogs={};shows=0;StaticPopup_Show=function(_,message)shows=shows+1;lastMessage=message;return {} end
C_Timer={After=function(_,fn)fn()end}
CreateFrame=function() local f={};function f:RegisterEvent()end;function f:SetScript(_,fn)self.run=fn;eventFrame=self end;return f end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/UpdaterNotice.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
eventFrame.run();assert(shows==1 and lastMessage:find('missing',1,true))
eventFrame.run();assert(shows==1)
clock=clock+86400;eventFrame.run();assert(shows==2)
StaticPopupDialogs.MARKETEER_FOREVER_DATA_UPDATER_REMINDER.OnCancel(nil,nil,'clicked');assert(MarketeerForeverCoreDB.silenceUpdaterReminders)
clock=clock+86400;eventFrame.run();assert(shows==2)
MarketeerForeverCoreDB.silenceUpdaterReminders=false
MarketeerForeverMarketData={schemaVersion=1,periodHours=24,tables={['forever/pvp/horde/us']={updated=clock,text='2589:1:1:1:1:1:1:1:1'}}}
eventFrame.run();assert(shows==2)
clock=clock+86401;eventFrame.run();assert(shows==3 and lastMessage:find('24 hours old',1,true))
clock=clock+86400;MarketeerForeverCore.active=false;eventFrame.run();assert(shows==3)
''')
print('Updater reminders: missing, fresh, stale, 24-hour snooze and silence passed.')
