#!/usr/bin/env python3
from pathlib import Path
import os,re,json,sys,shutil
home=Path.home()
base=Path(__file__).resolve().parent.parent/"shell"
source=(base/'services/Colours.qml').read_text()
colours={k:v for k,v in re.findall(r'property color m3(\w+): "(#[0-9a-fA-F]+)"',source)}
try:
    scheme=json.loads((home/'.local/state/caelestia/scheme.json').read_text())
    colours.update({k:'#'+v.lstrip('#') for k,v in scheme['colours'].items() if isinstance(v,str) and re.fullmatch(r'#?[0-9a-fA-F]{6,8}',v)})
except (OSError,ValueError,KeyError): pass
cfg=home/'.config/devine/swash-theme'
(cfg/'gtk-4.0').mkdir(parents=True,exist_ok=True)
link=cfg/'swash'
if not link.exists():link.symlink_to(home/'.config/swash',target_is_directory=True)
roles={'window_bg_color':'surface','window_fg_color':'onSurface','view_bg_color':'surfaceContainerLowest','view_fg_color':'onSurface','headerbar_bg_color':'surfaceContainer','headerbar_fg_color':'onSurface','card_bg_color':'surfaceContainer','card_fg_color':'onSurface','popover_bg_color':'surfaceContainer','popover_fg_color':'onSurface','dialog_bg_color':'surfaceContainer','dialog_fg_color':'onSurface','accent_bg_color':'primary','accent_fg_color':'onPrimary','accent_color':'primary','borders':'outlineVariant'}
css='\n'.join(f'@define-color {key} {colours[val]};' for key,val in roles.items())
css+='''
window.window { background: @window_bg_color; color: @window_fg_color; }
.overlay-pill, bottom-sheet > sheet.background {
    color: @window_fg_color;
    background: @headerbar_bg_color;
    background-image: none;
    border: 1px solid @borders;
    box-shadow: 0 4px 16px alpha(black, 0.2);
}
.app-chrome-group { border-color: @borders; }
.overlay-pill button, .app-chrome-group button { color: @window_fg_color; }
.overlay-pill button:hover, .app-chrome-group button:hover { background: alpha(@accent_bg_color, 0.14); }
.overlay-pill button:checked, .app-chrome-group button:checked { background: @accent_bg_color; color: @accent_fg_color; }
'''
(cfg/'gtk-4.0/gtk.css').write_text(css)
(cfg/'gtk-4.0/settings.ini').write_text('[Settings]\ngtk-application-prefer-dark-theme=1\n')
if '--prepare-theme' in sys.argv:sys.exit(0)
env=os.environ.copy();env['XDG_CONFIG_HOME']=str(cfg)
binary=os.environ.get("DEVINE_SWASH_BIN") or shutil.which("swash")
if not binary: sys.exit("Swash was not found. Install Swash or set DEVINE_SWASH_BIN.")
os.execvpe(binary,[binary,*sys.argv[1:]],env)
