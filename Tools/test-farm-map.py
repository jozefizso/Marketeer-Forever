from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]/'MarketeerForever/Market'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCore={}
MarketeerForeverFarmData={mobs={[2559]={name='Highland Strider'}}}
canvasScale=1;local canvas={GetWidth=function()return 1000 end,GetHeight=function()return 800 end,GetEffectiveScale=function()return canvasScale end}
UIParent={GetEffectiveScale=function()return 1 end}
WorldMapFrame={shown=false,GetCanvas=function()return canvas end,GetMapID=function()return 1417 end,
 IsShown=function(self)return self.shown end,HookScript=function(self,_,fn)self.onHide=fn end,
 Hide=function(self)self.shown=false;if self.onHide then self.onHide(self) end end}
MarketeerForeverMenu={shown=true,IsShown=function(self)return self.shown end,Hide=function(self)self.shown=false end}
reopened=0
MarketeerForeverCore.OpenTradingMenu=function()reopened=reopened+1;MarketeerForeverMenu.shown=true end
pins={}
function CreateFrame()
 local p={shown=false,scripts={}};function p:SetSize(w,h)self.width=w;self.height=h end;function p:SetScale(v)self.scale=v end;function p:EnableMouse()end;function p:SetFrameLevel()end;function p:SetScript(k,v)self.scripts[k]=v end
 function p:ClearAllPoints()end;function p:SetPoint(...)self.pos={...}end;function p:Show()self.shown=true end;function p:Hide()self.shown=false end
 function p:CreateTexture()local t={SetAllPoints=function()end,SetTexture=function(self,v)self.texture=v end,SetBlendMode=function(self,v)self.blend=v end,SetVertexColor=function()end,SetAtlas=function(self,v)self.atlas=v end};self.icon=t;return t end
 pins[#pins+1]=p;return p
end
callbacks={}
tooltipText='';GameTooltip={SetOwner=function(self,owner)self.owner=owner end,IsOwned=function(self,owner)return self.owner==owner end,AddLine=function(_,s)tooltipText=tooltipText..s end,Show=function()end,Hide=function(self)self.owner=nil end}
OpenMapAPI={version=2,IsStitched=function()return stitched end,CanvasFromWorldPos=function()return .4,.6 end,
 WorldFromMap=function(_,x,y)return x,y end,MapFromWorld=function(_,x,y)return x,y end,ArtTopLevel=function()return 100 end,
 RegisterCallback=function(_,event,fn)callbacks[event]=fn end,ShowWorld=function(u,v)focused={u,v}end}
stitched=true
C_Timer={After=function(_,f)f()end}
C_Map={GetMapChildrenInfo=function()return {}end,OpenWorldMap=function(id)opened=id;WorldMapFrame.shown=true end,
 SetUserWaypoint=function()error('normal-map waypoint must not be used')end}
print=function()end
''')
for name in ('FarmSpawns.lua','FarmMap.lua'):
 lua.execute((root/name).read_text(encoding='utf8'))
lua.execute('''
local c=MarketeerForeverCore
assert(c.FarmHasSpawnReferences(2559) and not c.FarmHasSpawnReferences(-1))
assert(not c.FarmHasSpawnReferences(276105) and not c.FarmHasSpawnReferences(276108))
local zones=c.FarmMapZones('Arathi Highlands, Hillsbrad Foothills')
assert(#zones==2 and zones[1].id==1417 and zones[2].id==1424)
local dungeon=c.FarmMapZones('Shadowfang Keep');assert(#dungeon==1 and dungeon[1].id==1421 and dungeon[1].entrance)
assert(c.FarmMapOpen(-1,dungeon[1]) and opened==1421 and focused~=nil)
assert(not MarketeerForeverMenu.shown)
WorldMapFrame:Hide();assert(MarketeerForeverMenu.shown and reopened==1)
WorldMapFrame:Hide();assert(reopened==1)
MarketeerForeverMenu.shown=false
assert(c.FarmMapOpen(-1,dungeon[1]));WorldMapFrame:Hide();assert(reopened==1 and not MarketeerForeverMenu.shown)
assert(c.FarmMapOpen(2559,zones[1]) and opened==1417 and #pins>0 and pins[1].shown)
assert(math.abs(focused[1]-.4)<.00001 and math.abs(focused[2]-.6)<.00001)
assert(pins[1].icon.atlas=='Waypoint-MapPin-Untracked')
assert(pins[1].width==12 and pins[1].pos[4]==400 and pins[1].pos[5]==-480)
canvasScale=4;callbacks.OpenMap_ViewChanged();assert(pins[1].width==3 and pins[1].pos[4]==400 and pins[1].pos[5]==-480 and pins[1].scale==nil)
canvasScale=.5;callbacks.OpenMap_ViewChanged();assert(pins[1].width==24 and pins[1].pos[4]==400 and pins[1].pos[5]==-480 and pins[1].scale==nil)
pins[1].scripts.OnEnter(pins[1]);assert(tooltipText:find('Highland Strider',1,true) and tooltipText:find('Classic spawn reference',1,true));pins[1].scripts.OnLeave(pins[1]);assert(not GameTooltip.owner)
assert(c.FarmMapOpen(-1,zones[1]) and opened==1417 and not pins[1].shown)
assert(c.FarmMapOpen(2559,zones[1]) and pins[1].shown)
assert(pins[1].pos[4]==400 and pins[1].pos[5]==-480)
MarketeerForeverFarmSpawns[999]={{0,.1,.2},{0,.9,.8},{0,.2,.3}}
OpenMapAPI.CanvasFromWorldPos=function(_,x,y)return x,y end
assert(c.FarmMapOpen(999,zones[1]) and math.abs(focused[1]-.5)<.00001 and math.abs(focused[2]-.5)<.00001)
stitched=false;callbacks.OpenMap_StitchedChanged();assert(not pins[1].shown)
stitched=true;callbacks.OpenMap_ViewChanged();assert(pins[1].shown)
OpenMapAPI.MapFromWorld=function()return 2,2 end
focused=nil
assert(c.FarmMapOpen(2559,zones[2]) and opened==1424 and not pins[1].shown)
assert(focused==nil)
InCombatLockdown=function()return true end;opened=nil;assert(not c.FarmMapOpen(2559,zones[1]) and not opened)
''')
print('OpenMap canvas overlay, callbacks, multiple zones and combat guard passed.')
