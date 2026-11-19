from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
with ZipFile(root / 'Marketeer-1.0.99.zip') as previous:
    names = set(previous.namelist())
names.update({'MarketeerForever/DebugReport.lua', 'MarketeerForever/Market/FarmSkinData.lua'})
toc = (root / 'MarketeerForever/MarketeerForever.toc').read_text(encoding='utf-8-sig')
for line in toc.splitlines():
    if line and not line.startswith('#'):
        name = 'MarketeerForever/' + line.replace('\\', '/')
        if name not in names or not (root / name).is_file():
            raise SystemExit('Missing addon file: ' + name)
with ZipFile(root / 'Marketeer-1.1.0.zip', 'w', ZIP_DEFLATED, compresslevel=9) as out:
    for name in sorted(names):
        out.write(root / name, name)
with ZipFile(root / 'Marketeer-1.1.0.zip') as archive:
    if archive.testzip():
        raise SystemExit('Release archive failed integrity check')
    print('Release archive verified:', len(archive.namelist()), 'files')
