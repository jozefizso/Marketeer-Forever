from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]/'MarketeerForever/Market'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCore={}
MarketeerForeverFarmData={mobs={[2559]={name='Highland Strider'}}}
local canvas={GetWidth=function()return 1000 end,GetHeight=function()return 800 end}
WorldMapFrame={GetCanvas=function()return canvas end,GetMapID=function()return 1417 end}
pins={}
function CreateFrame()
 local p={shown=false};function p:SetSize()end;function p:EnableMouse()end;function p:SetFrameLevel()end
 function p:ClearAllPoints()end;function p:SetPoint(...)self.pos={...}end;function p:Show()self.shown=true end;function p:Hide()self.shown=false end
 function p:CreateTexture()return {SetAllPoints=function()end,SetTexture=function()end,SetVertexColor=function()end} end
 pins[#pins+1]=p;return p
end
callbacks={}
OpenMapAPI={version=2,IsStitched=function()return stitched end,CanvasFromWorldPos=function()return .4,.6 end,
 WorldFromMap=function(_,x,y)return x,y end,MapFromWorld=function(_,x,y)return x,y end,ArtTopLevel=function()return 100 end,
 RegisterCallback=function(_,event,fn)callbacks[event]=fn end}
stitched=true
C_Timer={After=function(_,f)f()end}
C_Map={GetMapChildrenInfo=function()return {}end,OpenWorldMap=function(id)opened=id end,
 SetUserWaypoint=function()error('normal-map waypoint must not be used')end}
print=function()end
''')
for name in ('FarmSpawns.lua','FarmMap.lua'):
 lua.execute((root/name).read_text(encoding='utf8'))
lua.execute('''
local c=MarketeerForeverCore
local zones=c.FarmMapZones('Arathi Highlands, Hillsbrad Foothills')
assert(#zones==2 and zones[1].id==1417 and zones[2].id==1424)
assert(c.FarmMapOpen(2559,zones[1]) and opened==1417 and #pins>0 and pins[1].shown)
assert(pins[1].pos[4]==400 and pins[1].pos[5]==-480)
stitched=false;callbacks.OpenMap_StitchedChanged();assert(not pins[1].shown)
stitched=true;callbacks.OpenMap_ViewChanged();assert(pins[1].shown)
OpenMapAPI.MapFromWorld=function()return 2,2 end
assert(c.FarmMapOpen(2559,zones[2]) and opened==1424 and not pins[1].shown)
InCombatLockdown=function()return true end;opened=nil;assert(not c.FarmMapOpen(2559,zones[1]) and not opened)
''')
print('OpenMap canvas overlay, callbacks, multiple zones and combat guard passed.')
