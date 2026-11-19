from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
local objects={};local methods={}
function methods:RegisterEvent(e)self.events[e]=true end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:SetText(v)self.text=v end
function methods:CreateFontString()return CreateFrame('Font')end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
function methods:HighlightText()self.highlighted=true end
function methods:SetFocus()self.focused=true end
local mt={__index=function(_,k)return methods[k] or function()end end}
function CreateFrame(kind,name)local f=setmetatable({kind=kind,name=name,events={},scripts={}},mt);objects[#objects+1]=f;return f end
function findText(s)for _,o in ipairs(objects)do if rawget(o,'text')==s then return o end end end
function findWindow()for _,o in ipairs(objects)do if rawget(o,'name')=='MarketeerDebugCopyWindow' then return o end end end
function findEdit()for _,o in ipairs(objects)do if o.kind=='EditBox' then return o end end end
function findListener()for _,o in ipairs(objects)do if o.events.ADDON_ACTION_BLOCKED then return o end end end
UIParent=CreateFrame('UI');MarketeerForeverCore={};GetTime=function()return 100 end
GetBuildInfo=function()return '1.60.1','70790','date',16001 end
C_AddOns={GetAddOnMetadata=function()return '1.0.99' end,IsAddOnLoaded=function(name)return name=='Baganator' end}
InCombatLockdown=function()return false end;GetCVar=function()return '1' end
C_Timer={After=function(_,f)f()end};print=function()end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/DebugReport.lua').read_text(encoding='utf8'))
lua.execute('''
local listener=findListener();listener.scripts.OnEvent(listener,'MAIL_SHOW');listener.scripts.OnEvent(listener,'ADDON_ACTION_BLOCKED','OtherAddon','UseContainerItem')
assert(not findText('Copy debug data'))
listener.scripts.OnEvent(listener,'ADDON_ACTION_BLOCKED','MarketeerForever','UseContainerItem')
local copy=findText('Copy debug data');assert(copy and copy.scripts.OnClick);copy.scripts.OnClick()
local box=findEdit();assert(findWindow().shown and box.focused and box.highlighted)
assert(box.text:find('UseContainerItem',1,true) and box.text:find('MAIL_SHOW',1,true) and box.text:find('Baganator',1,true))
assert(box.text:find('does not include a taint log',1,true))
''')
print('Blocked-action report opens selectable diagnostics and ignores other addons.')
