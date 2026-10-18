#!/usr/bin/env python3
import subprocess as s, sys, json
from pathlib import Path
script_dir = Path(__file__).resolve().parent
devine_command = str(Path.home()/'.local/bin/devine')

def run(*args):
    return s.run(args).returncode

a=' '.join(sys.argv[1:])
commands={
'settings-toggle':[devine_command,'shell','nexus','open'],
'panel-toggle control-center':[devine_command,'shell','drawers','toggle','dashboard'],
'panel-toggle launcher':[devine_command,'shell','drawers','toggle','launcher'],
'panel-toggle launcher /emo':[devine_command,'emoji','-p'],
'session lock':[devine_command,'shell','lock','lock'],
'panel-toggle session':[devine_command,'shell','drawers','toggle','session'],
'volume-up':['wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SINK@','5%+'],
'volume-down':['wpctl','set-volume','@DEFAULT_AUDIO_SINK@','5%-'],
'volume-mute':['wpctl','set-mute','@DEFAULT_AUDIO_SINK@','toggle'],
'mic-mute':['wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@','toggle'],
'media toggle':[devine_command,'shell','mpris','playPause'],
'media next':[devine_command,'shell','mpris','next'],
'media previous':[devine_command,'shell','mpris','previous'],
'brightness-up':[devine_command,'shell','brightness','set','+5%'],
'brightness-down':[devine_command,'shell','brightness','set','5%-'],
'screenshot-region':[str(script_dir/'screenshot.py'),'region'],
'screenshot-fullscreen':[str(script_dir/'screenshot.py'),'fullscreen'],
'panel-toggle wallpaper':[devine_command,'shell','nexus','open'],
'panel-toggle clipboard':[devine_command,'clipboard'],
'panel-toggle control-center notifications':[devine_command,'shell','drawers','toggle','sidebar'],
}
if a=='window-switcher':
    clients=json.loads(s.check_output(['hyprctl','clients','-j']))
    labels=[f"{i+1}: {c.get('class','')} — {c.get('title','')}".replace('\n',' ') for i,c in enumerate(clients)]
    selected=s.run(['fuzzel','--dmenu','--index','--prompt','Windows: '],input='\n'.join(labels),text=True,capture_output=True)
    if selected.returncode==0 and selected.stdout.strip().isdigit():
        index=int(selected.stdout.strip())
        if index<len(clients): run('hyprctl','dispatch','focuswindow','address:'+clients[index]['address'])
elif a in commands: sys.exit(run(*commands[a]))
else: sys.exit('Unknown desktop action: '+a)
