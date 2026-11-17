from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
objects={};local methods={}
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:CreateFontString()return CreateFrame('Font',nil,self) end
function methods:SetText(v)self.text=v end
function methods:GetText()return self.text or '' end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
function methods:SetShown(v)self.shown=not not v end
function methods:GetFrameLevel()return 1 end
function methods:ClearFocus()end
local mt={__index=function(_,k)return methods[k] or function()end end}
function CreateFrame(kind,_,parent)local o=setmetatable({kind=kind,parent=parent,scripts={},shown=true},mt);objects[#objects+1]=o;return o end
UIParent=CreateFrame('UI');MarketeerForeverCore={Market=function()return 'test' end}
MarketeerForeverHistory={schemaVersion=1,market='test',generatedAt=1000,items={}}
MarketeerForeverItemNames={schemaVersion=1,items={}}
for i=1,12 do MarketeerForeverHistory.items[i]='';MarketeerForeverItemNames.items[i]=string.format('Blue %02d',i) end
C_Timer={After=function(_,f)f()end};GetServerTime=function()return 1000 end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/History.lua').read_text(encoding='utf8'))
lua.execute('''
local panel=MarketeerForeverCore.CreateHistoryPanel(UIParent);panel:Show()
local input,resultPanel,rows
for _,o in ipairs(objects) do
 if o.kind=='EditBox' then input=o end
 if o.scripts.OnMouseWheel and o.kind=='Frame' then resultPanel=o end
end
assert(input and resultPanel);input:SetText('Blue');input.scripts.OnTextChanged(input,true)
for i=1,30 do panel.scripts.OnUpdate(panel) end
rows={};for _,o in ipairs(objects) do if o.parent==resultPanel and o.kind=='Button' and type(rawget(o,'item'))=='table' then rows[#rows+1]=o end end
assert(#rows==5 and rows[1].item.id==1)
rows[1].scripts.OnMouseWheel(rows[1],-1);assert(rows[1].item.id==2)
for i=1,20 do resultPanel.scripts.OnMouseWheel(resultPanel,-1) end
assert(rows[1].item.id==8 and rows[5].item.id==12)
resultPanel.scripts.OnMouseWheel(resultPanel,1);assert(rows[1].item.id==7)
input.scripts.OnArrowPressed(input,'DOWN');input.scripts.OnEnterPressed();assert(input:GetText()=='Blue 08' and not resultPanel.shown)
''')
print('Search results scroll one row at a time, clamp at ends and preserve keyboard selection.')
