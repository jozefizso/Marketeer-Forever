from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

source=(Path(__file__).resolve().parents[1]/'MarketeerForever/BagValue.lua').read_text(encoding='utf8')
part=source[source.index('local function canMoveBags('):source.index('local function updateDrag(')]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCoreDB={bagPosition={x=50,y=80,version=2}}
local protected=false;local combat=false;local queued;local callback;local moves=0
UIParent={};ContainerFrameCombinedBags={IsProtected=function()return protected end,ClearAllPoints=function()moves=moves+1 end,SetPoint=function(_,_,_,_,x,y)assert(x==50 and y==80)end}
InCombatLockdown=function()return combat end;C_Timer={After=function(_,fn)queued=fn end};UpdateContainerFrameAnchors=function()end
hooksecurefunc=function(name,fn)assert(name=='UpdateContainerFrameAnchors');callback=fn end
'''+part+'''
hookPositionLayout();assert(callback);callback();callback();assert(moves==0 and queued);queued();assert(moves==1)
protected=true;callback();queued();assert(moves==1)
protected=false;combat=true;callback();queued();assert(moves==1)
combat=false;MarketeerForeverCoreDB.bagPosition=nil;callback();queued();assert(moves==1)
''')
print('Bag layout restoration is coalesced and never moves protected frames or runs in combat.')
