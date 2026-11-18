from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile
import sqlite3
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Server'))
from lupa.lua51 import LuaRuntime
import trends
import build_data_addon
import publish_data_addon

now=1_800_000_000
market='forever/pvp/horde/us'
db=trends.connect(':memory:')
db.execute('create table item_names(item integer primary key,name text not null)')
db.execute('insert into item_names values(42,?)',('Ice "Éclair"',))
for age in range(30):
    observed=now-age*3600-1
    body='AHL1|%s|%d|1\n42:120:100:10:90:80:70:130:30\n'%(market,observed)
    trends.ingest(db,{'market':market,'body':body},now)
with TemporaryDirectory(dir=Path(__file__).resolve().parent) as folder:
    path=Path(folder)/'data.zip'
    body='AHL1|%s|%d|1\n42:120:100:10:90:80:70:130:30\n'%(market,now-1)
    build_data_addon.build(db,path,[market],now,lambda _:body)
    with ZipFile(path) as z:
        module='MarketeerSnapshot_forever_pvp_horde_us'
        toc=z.read(module+'/'+module+'.toc').decode()
        assert '## LoadOnDemand: 1' in toc
        assert '## Group: MarketeerMarketSnapshots' in toc
        assert '## IconTexture: Interface\\MoneyFrame\\UI-GoldIcon' in toc
        assert '## IconTexture: Interface\\MoneyFrame\\UI-GoldIcon' in z.read('MarketeerMarketSnapshots/MarketeerMarketSnapshots.toc').decode()
        lua=LuaRuntime(unpack_returned_tuples=True)
        lua.execute(z.read('MarketeerMarketSnapshots/Names.lua').decode())
        lua.execute(z.read(module+'/Data.lua').decode())
        assert lua.eval("MarketeerSnapshotItemNames.items[42]")=='Ice "Éclair"'
        assert lua.eval("MarketeerSnapshotMarketData.tables['forever/pvp/horde/us'].count")==1
        assert lua.eval("MarketeerSnapshotHistory.items[42]")
        assert lua.eval("MarketeerSnapshotTrends.items[42][1]")==200
    class Response:
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def read(self,_):return b'{"id":12345}'
    def fake_upload(request,timeout):
        assert request.full_url=='https://wow.curseforge.com/api/projects/1814022/upload-file'
        assert request.method=='POST' and timeout==120
        assert request.get_header('X-api-token')=='test-token'
        assert b'"releaseType":"release"' in request.data and b'Content-Type: application/zip' in request.data
        return Response()
    assert publish_data_addon.upload(path,'1814022','test-token',fake_upload)==12345
    import json
    class StatusResponse:
        def __init__(self,files): self.files=files
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def read(self,_):return json.dumps({'id':1814022,'files':self.files}).encode()
    def status(files):
        return lambda request,timeout: StatusResponse(files)
    assert publish_data_addon.previous_file_released('1814022',12345,status([{'id':12345,'type':'release'}]))
    assert not publish_data_addon.previous_file_released('1814022',12345,status([]))
    assert not publish_data_addon.previous_file_released('1814022',12345,status([{'id':12345,'type':'beta'}]))
    gate={'project':1814022,'status':'pending','file_id':12345,'submitted':1000}
    assert not publish_data_addon.release_ready('1814022',gate,8199,lambda *_:True)
    assert publish_data_addon.release_ready('1814022',gate,8200,lambda *_:True)
    assert not publish_data_addon.release_ready('1814022',gate,8200,lambda *_:False)
    try:publish_data_addon.release_ready('1814022',{'project':1814022,'status':'uploading'},8200)
    except ValueError:pass
    else:raise AssertionError('An uncertain upload must stop the publisher')
    state=Path(folder)/'state.json';publish_data_addon.write_state(state,{'project':1814022,'status':'pending','file_id':12345})
    assert json.loads(state.read_text())['file_id']==12345
    empty='AHL1|%s|%d|0\n'%(market,now)
    empty_db=trends.connect(':memory:');empty_db.execute('create table item_names(item integer,name text)')
    assert 'items={' in build_data_addon.module_data(empty_db,market,now,empty)
    try:build_data_addon.module_data(db,market,now,body.replace(':120:',':bad:'))
    except ValueError:pass
    else:raise AssertionError('Malformed upstream table accepted')

source=(Path(__file__).resolve().parents[1]/'MarketeerForever/Core.lua').read_text(encoding='utf8')
a=source.index('function core.LoadMarketSnapshot()');b=source.index('function core.AutoScanEnabled()',a)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
local core={Market=function()return 'forever/pvp/horde/us' end};local function now()return 1800000000 end
local loaded=false;local called=0
MarketeerSnapshotCompanion=1
C_AddOns={DoesAddOnExist=function(n)assert(n=='MarketeerSnapshot_forever_pvp_horde_us');return true end,IsAddOnLoaded=function()return loaded end,LoadAddOn=function()called=called+1;loaded=true end}
'''+source[a:b]+'''
MarketeerForeverHistory={schemaVersion=2,market='forever/pvp/horde/us',generatedAt=1799999997,items={}}
MarketeerSnapshotHistory={schemaVersion=2,market='forever/pvp/horde/us',generatedAt=1799999999,items={}}
assert(core.MarketHistoryData()==MarketeerSnapshotHistory and called==1)
assert(core.MarketHistoryData()==MarketeerSnapshotHistory and called==1)
MarketeerSnapshotHistory.market='other';assert(core.MarketHistoryData()==MarketeerForeverHistory)
MarketeerSnapshotItemNames=nil;MarketeerForeverItemNames={items={}};assert(core.ItemNamesData()==MarketeerForeverItemNames)
''')
source=(Path(__file__).resolve().parents[1]/'MarketeerForever/Core.lua').read_text(encoding='utf8')
a=source.index('local tableCache={}');b=source.index('function core.Subscribe(',a)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
local core={Market=function()return 'forever/pvp/horde/us' end,LoadMarketSnapshot=function()end}
local function now()return 1800000000 end
MarketeerForeverCoreDB={importedTables={}}
MarketeerForeverMarketData={schemaVersion=1,periodHours=24,tables={['forever/pvp/horde/us']={updated=1799999000,count=1,text='42:10:9:1:1:1:1:1:20'}}}
MarketeerSnapshotMarketData={schemaVersion=1,periodHours=24,tables={['forever/pvp/horde/us']={updated=1799999500,count=1,text='42:20:19:1:1:1:1:1:30'}}}
'''+source[a:b]+'''
assert(MarketeerForeverAPI.GetPrice(42).minBuyout==19 and MarketeerForeverAPI.GetPrice(42).soldPerDay==3)
MarketeerForeverCoreDB.importedTables['forever/pvp/horde/us']={updated=1799999600,count=1,text='42:30:29:1:1:1:1:1:40'}
assert(MarketeerForeverAPI.GetPrice(42).minBuyout==29)
MarketeerForeverCoreDB.importedTables={};MarketeerSnapshotMarketData.tables['forever/pvp/horde/us'].updated=1800000400
assert(MarketeerForeverAPI.GetPrice(42).minBuyout==9)
''')
print('Companion package, isolated market loading, and legacy history fallback passed.')
