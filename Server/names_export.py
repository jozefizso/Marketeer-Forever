#!/usr/bin/env python3
import base64
import sqlite3
import sys
import time
from urllib.parse import quote

def export(db,now):
    rows=[]
    for item,name in db.execute('select item,name from item_names order by item'):
        if isinstance(item,int) and item>0 and isinstance(name,str) and name:
            rows.append(str(item)+':'+base64.b64encode(name.encode('utf-8')).decode('ascii'))
    return 'NAM1|%d|%d\n%s\n'%(now,len(rows),'\n'.join(rows))
if __name__=='__main__':
    db=sqlite3.connect('file:'+quote(sys.argv[1],safe='/')+'?mode=ro',uri=True,timeout=30)
    try:print(export(db,int(time.time())),end='')
    finally:db.close()
