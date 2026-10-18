#!/usr/bin/env python3
import datetime,json,subprocess as s,sys
from pathlib import Path
script_dir = Path(__file__).resolve().parent
mode=sys.argv[1] if len(sys.argv)>1 else 'region'
cmd=['grim']
if mode=='region':
    sys.exit(s.run(['qs','-c','devine','ipc','call','picker','openFreeze']).returncode)
else:
    monitors=json.loads(s.check_output(['hyprctl','monitors','-j']))
    focused=next((m for m in monitors if m.get('focused')),None)
    if focused:cmd+=['-o',focused['name']]
image=s.check_output(cmd+['-'])
name=datetime.datetime.now().strftime('screenshot-%Y-%m-%d_%H-%M-%S.png')
s.run([str(script_dir/"themed-swash.py"),'--stdin','--name',name],input=image,check=True)
