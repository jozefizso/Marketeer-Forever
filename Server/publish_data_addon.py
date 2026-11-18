#!/usr/bin/env python3
"""Build and upload one CurseForge release; token stays in a root-only file."""
import argparse
import json
import os
import re
import stat
import time
import urllib.request
import uuid
from pathlib import Path

import build_data_addon
import sqlite3

def token_from(path):
    path=Path(path);info=path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
        raise ValueError('Token must be a private regular file (mode 0600)')
    value=path.read_text(encoding='utf-8').strip()
    if not value or any(ord(c)<33 or ord(c)>126 for c in value): raise ValueError('Invalid token')
    return value

def upload(path,project,token,open_url=urllib.request.urlopen):
    if not re.fullmatch(r'[1-9][0-9]*',str(project)): raise ValueError('Invalid project ID')
    boundary='marketeer'+uuid.uuid4().hex
    metadata=json.dumps({'changelog':'AHledger price and history data refresh (prepared approximately every two hours).','changelogType':'text','displayName':'Marketeer Market Data '+time.strftime('%Y-%m-%d %H:%M UTC',time.gmtime()),'gameVersions':[17053],'releaseType':'release'},separators=(',',':')).encode()
    filename='MarketeerMarketData-'+time.strftime('%Y%m%d-%H%M%S',time.gmtime())+'.zip'
    if not re.fullmatch(r'[A-Za-z0-9_.-]+',filename): raise ValueError('Unsafe package name')
    head=('--'+boundary+'\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n').encode()+metadata+b'\r\n'
    head+=('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="'+filename+'"\r\nContent-Type: application/zip\r\n\r\n').encode()
    body=head+Path(path).read_bytes()+('\r\n--'+boundary+'--\r\n').encode()
    req=urllib.request.Request('https://wow.curseforge.com/api/projects/'+str(project)+'/upload-file',data=body,headers={'X-Api-Token':token,'Content-Type':'multipart/form-data; boundary='+boundary,'User-Agent':'MarketeerForeverData/1.0'},method='POST')
    with open_url(req,timeout=120) as response: result=json.loads(response.read(100_001))
    if not isinstance(result,dict) or not isinstance(result.get('id'),int) or result['id']<=0: raise ValueError('No file ID returned')
    return result['id']

def previous_file_released(project,file_id,open_url=urllib.request.urlopen):
    if not re.fullmatch(r'[1-9][0-9]*',str(project)) or not isinstance(file_id,int) or file_id<=0: raise ValueError('Invalid pending file')
    # Public listing mirror: a missing/unavailable listing is not proof of
    # rejection. Fail closed and retry later; no credentials are sent here.
    req=urllib.request.Request('https://api.cfwidget.com/'+str(project),headers={'User-Agent':'MarketeerForeverData/1.0'})
    with open_url(req,timeout=30) as response: result=json.loads(response.read(1_000_001))
    if not isinstance(result,dict) or result.get('id')!=int(project) or not isinstance(result.get('files'),list): raise ValueError('Unrecognized public project listing')
    return any(isinstance(row,dict) and row.get('id')==file_id and row.get('type')=='release' for row in result['files'])

def write_state(path,value):
    path=Path(path);tmp=path.with_name(path.name+'.tmp')
    fd=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as handle:
            json.dump(value,handle);handle.flush();os.fsync(handle.fileno())
        os.replace(tmp,path)
    finally:
        if tmp.exists(): tmp.unlink()

def release_ready(project,state,now,lookup=previous_file_released):
    if state.get('project')!=int(project): raise ValueError('Publisher state belongs to a different project')
    if state.get('status')!='pending' or not isinstance(state.get('file_id'),int) or not isinstance(state.get('submitted'),int): raise ValueError('Previous upload outcome is unknown; check CurseForge before resuming')
    if now-state['submitted']<7200: return False
    return lookup(project,state['file_id'])

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--token-file',required=True);p.add_argument('--state-file');p.add_argument('--project',required=True);p.add_argument('--output',required=True);p.add_argument('--dry-run',action='store_true');args=p.parse_args()
    if not args.dry_run:
        if not args.state_file: raise ValueError('A state file is required for safe publishing')
        upload_token=token_from(args.token_file)
        state_path=Path(args.state_file)
        if state_path.exists():
            state=json.loads(state_path.read_text(encoding='utf-8'))
            if not release_ready(args.project,state,int(time.time())):
                print('Waiting for the two-hour interval and the previous public release.',flush=True);return
    now=int(time.time());out=Path(args.output);temp=out.with_suffix(out.suffix+'.tmp')
    db=sqlite3.connect('file:'+args.db+'?mode=ro',uri=True,timeout=30)
    try:
        build_data_addon.build(db,temp,build_data_addon.MARKETS,now)
        from zipfile import ZipFile
        with ZipFile(temp) as archive:
            if archive.testzip() is not None: raise ValueError('Corrupt package')
        temp.replace(out)
    finally:
        db.close()
        if temp.exists(): temp.unlink()
    if args.dry_run:
        print('Verified package:',out,flush=True);return
    # An interrupted POST may have succeeded. Persist an uncertainty marker
    # before sending so the next run cannot create duplicate submissions.
    write_state(args.state_file,{'project':int(args.project),'status':'uploading'})
    file_id=upload(out,args.project,upload_token)
    write_state(args.state_file,{'project':int(args.project),'status':'pending','file_id':file_id,'submitted':int(time.time())})
    print('Submitted CurseForge file ID:',file_id,'(availability follows review)',flush=True)

if __name__=='__main__': main()
