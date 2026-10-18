#!/usr/bin/env python3
"""Close a desktop by relocating its clients; never close application windows."""
import datetime,json,re,shutil,subprocess,sys,os
from pathlib import Path

def query(name):return json.loads(subprocess.check_output(['hyprctl',name,'-j']))
def dispatch(expression):
    result=subprocess.run(['hyprctl','dispatch',expression],capture_output=True,text=True)
    if result.returncode or result.stdout.strip()!='ok':raise RuntimeError(result.stdout.strip() or result.stderr.strip())
def selector(ws):
    if ws['name'].startswith('special:'):return ws['name']
    return str(ws['id']) if ws['id']>0 else 'name:'+ws['name']
def create_desktop(monitor):
    monitors=query('monitors')
    if not any(m['name']==monitor for m in monitors):raise RuntimeError('This monitor is no longer connected.')
    desktop_id=max([w['id'] for w in query('workspaces') if w['id']>0]+[0])+1
    config=Path.home()/'.config/hypr/config/workspaces.lua'
    backup=Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'devine/backups'/('before-creating-desktop-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir(parents=True);shutil.copy2(config,backup/config.name)
    with config.open('a') as file:
        file.write('\n-- Created from desktop overview\nhl.workspace_rule({ workspace = '+json.dumps(str(desktop_id))+', monitor = '+json.dumps(monitor)+', persistent = true })\n')
    subprocess.run(['hyprctl','reload'],check=True,capture_output=True)
    dispatch('hl.dsp.focus({monitor='+json.dumps(monitor)+'})')
    dispatch('hl.dsp.focus({workspace='+json.dumps(str(desktop_id))+'})')
    return {'ok':True,'desktop':desktop_id}

def main():
    if sys.argv[1]=='create':return create_desktop(sys.argv[2])
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
