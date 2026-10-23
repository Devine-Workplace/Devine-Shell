#!/usr/bin/env python3
"""Close a desktop by relocating its clients; never close application windows."""
import datetime,json,re,shutil,subprocess,sys,os,fcntl,time
from pathlib import Path

def query(name):return json.loads(subprocess.check_output(['hyprctl',name,'-j']))
def dispatch(expression):
    result=subprocess.run(['hyprctl','dispatch',expression],capture_output=True,text=True)
    if result.returncode or result.stdout.strip()!='ok':raise RuntimeError(result.stdout.strip() or result.stderr.strip())
def selector(ws):
    if ws['name'].startswith('special:'):return ws['name']
    return str(ws['id']) if ws['id']>0 else 'name:'+ws['name']
def create_desktop(monitor):
    runtime=Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/'devine'
    runtime.mkdir(parents=True,exist_ok=True)
    state_path=runtime/'desktop-create.json'
    with (runtime/'desktop-create.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        now=time.monotonic()
        try:state=json.loads(state_path.read_text())
        except (OSError,ValueError):state={}
        # A second click can arrive before Hyprland publishes the new workspace.
        # Treat it as the same request, including when another shell instance sent it.
        age=now-state.get('time',0)
        if state.get('monitor')==monitor and 0<=age<0.8:
            return {'ok':True,'desktop':state.get('desktop'),'duplicate':True}
        monitors=query('monitors')
        if not any(m['name']==monitor for m in monitors):raise RuntimeError('This monitor is no longer connected.')
        config=Path.home()/'.config/hypr/config/workspaces.lua'
        config_text=config.read_text()
        configured=[int(value) for value in re.findall(r'hl\.workspace_rule\s*\(\s*\{[^}]*workspace\s*=\s*["\'](\d+)["\']',config_text)]
        desktop_id=max([w['id'] for w in query('workspaces') if w['id']>0]+configured+[0])+1
        backup=Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'devine/backups'/('before-creating-desktop-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        backup.mkdir(parents=True);shutil.copy2(config,backup/config.name)
        with config.open('a') as file:
            file.write('\n-- Created from desktop overview\nhl.workspace_rule({ workspace = '+json.dumps(str(desktop_id))+', monitor = '+json.dumps(monitor)+', persistent = true })\n')
        subprocess.run(['hyprctl','reload'],check=True,capture_output=True)
        state_path.write_text(json.dumps({'monitor':monitor,'desktop':desktop_id,'time':now}))
        return {'ok':True,'desktop':desktop_id}

def set_pinned(workspace_id,pinned):
    workspaces=query('workspaces')
    source=next((w for w in workspaces if w['id']==workspace_id),None)
    if source is None:raise RuntimeError('This desktop no longer exists.')
    config=Path.home()/'.config/hypr/config/workspaces.lua'
    original=config.read_text()
    name=source['name']
    selectors={str(workspace_id),name,'name:'+name}
    selector_re=re.compile(r'\bworkspace\s*=\s*(["\'])(.*?)\1')
    persistent_re=re.compile(r'\bpersistent\s*=\s*(true|false)')
    lines=[];matched=False;changed=False
    for line in original.splitlines(keepends=True):
        match=selector_re.search(line)
        if line.lstrip().startswith('--') or 'hl.workspace_rule' not in line or not match or match.group(2) not in selectors:
            lines.append(line);continue
        matched=True
        existing=persistent_re.search(line)
        is_persistent=bool(existing and existing.group(1)=='true')
        if is_persistent==pinned:
            lines.append(line);continue
        if existing:
            line=persistent_re.sub('persistent = '+str(pinned).lower(),line,count=1)
        elif pinned:
            line=re.sub(r'\}\s*\)\s*$',', persistent = true })'+('\n' if line.endswith('\n') else ''),line)
        else:
            lines.append(line);continue
        lines.append(line);changed=True
    if pinned and not matched:
        lines.append('\nhl.workspace_rule({ workspace = '+json.dumps('name:'+name if not name.isdigit() else name)+', monitor = '+json.dumps(source['monitor'])+', persistent = true })\n')
        changed=True
    if not changed:return {'ok':True,'pinned':pinned}
    backup=Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'devine/backups'/('before-'+('pinning' if pinned else 'unpinning')+'-desktop-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True);shutil.copy2(config,backup/config.name)
    config.write_text(''.join(lines))
    subprocess.run(['hyprctl','reload'],check=True,capture_output=True)
    return {'ok':True,'pinned':pinned,'backup':str(backup)}

def main():
    if sys.argv[1]=='create':return create_desktop(sys.argv[2])
    if sys.argv[1] in ('pin','unpin'):return set_pinned(int(sys.argv[2]),sys.argv[1]=='pin')
    source_id=int(sys.argv[1]); confirmed='--confirmed' in sys.argv[2:]
    workspaces=query('workspaces'); clients=query('clients')
    source=next((w for w in workspaces if w['id']==source_id),None)
    if source is None:return {'ok':True}
    visible_ids={w['workspace']['id'] for w in clients}
    siblings=sorted([w for w in workspaces if w['monitor']==source['monitor'] and (not w['name'].startswith('special:') or w['id'] in visible_ids or w['id']==source_id)],key=lambda w:w['id'])
    if len(siblings)<2:raise RuntimeError('Keep at least one desktop on this monitor.')
    index=siblings.index(source)
    destination=siblings[index-1] if index else siblings[index+1]
    moving=[w for w in clients if w['workspace']['id']==source_id]
    if moving and not confirmed:return {'ok':False,'confirmationRequired':True,'count':len(moving),'destination':destination['id']}
    backup=Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'devine/backups'/('before-closing-desktop-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True); (backup/'desktop.json').write_text(json.dumps({'source':source,'destination':destination,'windows':moving},indent=2))
    config=Path.home()/'.config/hypr/config/workspaces.lua'
    shutil.copy2(config,backup/config.name)
    target=json.dumps(selector(destination))
    for window in moving:
        dispatch('hl.dsp.window.move({workspace='+target+',window='+json.dumps('address:'+window['address'])+',follow=false})')
    if any(w['workspace']['id']==source_id for w in query('clients')):
        raise RuntimeError('A window is still on this desktop; it has been left open.')
    # Remove this desktop's persistence rule, preserving it verbatim in the backup.
    selectors={str(source_id),source['name'],'name:'+source['name']}
    lines=[]
    for line in config.read_text().splitlines(keepends=True):
        rule=re.search(r'\bworkspace\s*=\s*(["\'])(.*?)\1',line)
        if not line.lstrip().startswith('--') and 'hl.workspace_rule' in line and rule and rule.group(2) in selectors:
            lines.append('-- Closed from overview: '+line)
        else:lines.append(line)
    config.write_text(''.join(lines))
    subprocess.run(['hyprctl','reload'],check=True,capture_output=True)
    dispatch('hl.dsp.focus({monitor='+json.dumps(source['monitor'])+'})')
    dispatch('hl.dsp.focus({workspace='+target+'})')
    return {'ok':True,'destination':destination['id'],'backup':str(backup)}
try:print(json.dumps(main()))
except Exception as error:print(json.dumps({'ok':False,'error':str(error)}));sys.exit(1)
