#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root/"cli"/"src"))
import configparser,json,re,subprocess as sp,os,signal
from devine.utils.theme import gen_replace,gen_sequences,apply_terms
from devine.utils.paths import templates_dir
home=Path.home();cfg=home/'.config';base=Path(__file__).resolve().parent.parent/"shell"
source=(base/'services/Colours.qml').read_text()
col={k:v.lower() for k,v in re.findall(r'property color m3(\w+): "#([0-9a-fA-F]+)"',source)}
col.update({k:v.lower() for k,v in re.findall(r'property color (term\d+): "#([0-9a-fA-F]+)"',source)})
try:
 data=json.loads((home/'.local/state/devine/scheme.json').read_text());col.update({k:v.lstrip('#').lower() for k,v in data['colours'].items() if isinstance(v,str) and re.fullmatch(r'#?[0-9a-fA-F]{6}',v)})
except (OSError,ValueError,KeyError):pass

for alias,role in {'red':'error','maroon':'term9','green':'success','yellow':'term3','peach':'tertiary','teal':'term6','sky':'term14','sapphire':'term4','blue':'term4','lavender':'term12','mauve':'primary','klink':'primary','kvisited':'tertiary','knegative':'error','kpositive':'success','kneutral':'tertiary'}.items():
 col[alias]=col[role]
for key in ['klink','kvisited','knegative','kpositive','kneutral']:
 col[key+'Selection']=col['onPrimary']

def write(path,text):
 path.parent.mkdir(parents=True,exist_ok=True)
 if not path.exists() or path.read_text()!=text:path.write_text(text)

def ini(path):
 c=configparser.ConfigParser(interpolation=None,strict=False);c.optionxform=str
 if path.exists():c.read(path)
 return c

def saveini(path,c):
 import io
 out=io.StringIO();c.write(out,space_around_delimiters=False);write(path,out.getvalue())

# Terminal persistent palette; preserve opacity, padding and all other settings.
kitty='\n'.join([f'foreground #{col["onSurface"]}',f'background #{col["surface"]}',f'cursor #{col["primary"]}',f'cursor_text_color #{col["onPrimary"]}',f'selection_background #{col["primaryContainer"]}',f'selection_foreground #{col["onPrimaryContainer"]}',f'url_color #{col["primary"]}',f'active_border_color #{col["primary"]}',f'inactive_border_color #{col["outlineVariant"]}']+[f'color{i} #{col[f"term{i}"]}' for i in range(16)])+'\n'
write(cfg/'kitty/themes/devine.conf',kitty)
p=cfg/'kitty/kitty.conf';s=p.read_text();s=re.sub(r'^include\s+themes/(?:noctalia|devine|devine)\.conf\s*$', 'include themes/devine.conf',s,flags=re.M);write(p,s)
# Alacritty: replace its existing explicit colour sections while retaining behaviour/font settings.
p=cfg/'alacritty/alacritty.toml'
if p.exists():
 s=p.read_text().replace('themes/noctalia.toml','themes/devine.toml')
 blocks={'colors.primary':{'background':'surface','foreground':'onSurface'},'colors.normal':dict(zip(['black','red','green','yellow','blue','magenta','cyan','white'],[f'term{i}' for i in range(8)])),'colors.bright':dict(zip(['black','red','green','yellow','blue','magenta','cyan','white'],[f'term{i}' for i in range(8,16)]))}
 theme=''
 for section,entries in blocks.items():
  body='\n'.join(f'{k} = "#{col[v]}"' for k,v in entries.items())+'\n'
  theme+=f'[{section}]\n'+body+'\n'
  pattern=r'(?ms)^\['+re.escape(section)+r'\]\n.*?(?=^\[|\Z)'
  s=re.sub(pattern,f'[{section}]\n'+body+'\n',s)
 write(cfg/'alacritty/themes/devine.toml',theme);write(p,s)
# GTK3/4 use one shared generated palette.
css=gen_replace(col,templates_dir/'gtk.css',hash=True)
for version in ['gtk-3.0','gtk-4.0']:
 folder=cfg/version;write(folder/'thunar.css',gen_replace(col,templates_dir/'thunar.css',hash=True));write(folder/'devine.css',css);write(folder/'gtk.css','@import url("devine.css");\n')
 p=folder/'settings.ini';c=ini(p)
 if not c.has_section('Settings'):c.add_section('Settings')
 c['Settings']['gtk-application-prefer-dark-theme']='1'
 if version=='gtk-3.0':c['Settings']['gtk-theme-name']='adw-gtk3-dark'
 saveini(p,c)
# Qt palette (22 documented QPalette roles), preserving Fusion and icon choices.
roles=['onSurface','surfaceContainer','surfaceBright','surfaceContainerHigh','surfaceContainerLowest','outlineVariant','onSurface','onSurface','onSurface','surface','surface','shadow','primary','onPrimary','primary','tertiary','surfaceContainerLow','surface','surfaceContainer','onSurface','onSurfaceVariant','primary']
for version in ['qt5ct','qt6ct']:
 folder=cfg/version
 if not folder.exists():continue
 palette='[ColorScheme]\n'+'\n'.join(name+'='+', '.join('#'+col[r] for r in roles) for name in ['active_colors','disabled_colors','inactive_colors'])+'\n'
 write(folder/'colors/devine.conf',palette)
 p=folder/(version+'.conf');c=ini(p)
 if not c.has_section('Appearance'):c.add_section('Appearance')
 c['Appearance']['color_scheme_path']=str(folder/'colors/devine.conf');c['Appearance']['custom_palette']='true';saveini(p,c)
# KDE apps (including Dolphin) use the equivalent Material colour scheme.
kde=gen_replace(col,templates_dir/'qtdark.colors',hash=True)
write(home/'.local/share/color-schemes/Devine.colors',kde)
p=cfg/'kdeglobals';c=ini(p);generated=configparser.ConfigParser(interpolation=None);generated.optionxform=str;generated.read_string(kde)
for section in generated.sections():
 if section=='General':continue
 if not c.has_section(section):c.add_section(section)
 for k,v in generated[section].items():c[section][k]=v
if not c.has_section('General'):c.add_section('General')
c['General']['ColorScheme']='Devine';c['General']['Name']='Devine';saveini(p,c)
# btop and Fuzzel.
write(cfg/'btop/themes/devine.theme',gen_replace(col,templates_dir/'btop.theme',hash=True))
p=cfg/'btop/btop.conf'
if p.exists():write(p,re.sub(r'^color_theme\s*=.*$', 'color_theme = "devine"',p.read_text(),flags=re.M))
p=cfg/'fuzzel/fuzzel.ini';c=ini(p)
if not c.has_section('main'):c.add_section('main')
c['main']['terminal']='kitty';c['main']['font']='monospace:size=12'
if not c.has_section('colors'):c.add_section('colors')
for k,r in {'background':'surface','text':'onSurface','prompt':'primary','placeholder':'outline','input':'onSurface','match':'tertiary','selection':'primaryContainer','selection-text':'onPrimaryContainer','selection-match':'tertiary','counter':'outline','border':'primary'}.items():c['colors'][k]=col[r]+'ff'
if not c.has_section('border'):c.add_section('border')
c['border']['radius']='25';saveini(p,c)
# Window borders and rounding match the shell's border token.
p=cfg/'hypr/config/decorations.lua';s=p.read_text();s=re.sub(r'rounding\s*=\s*\d+', 'rounding = 25',s);s=re.sub(r'colors = \{ "rgba\([0-9a-f]+\)", "rgba\([0-9a-f]+\)" \}',f'colors = {{ "rgba({col["primary"]}ff)", "rgba({col["secondary"]}ff)" }}',s);write(p,s)
# Update visible terminals and reload Kitty's persistent theme.
apply_terms(gen_sequences(col))
r=sp.run(['pgrep','-u',str(os.getuid()),'-x','kitty'],capture_output=True,text=True)
for pid in r.stdout.split():
 try:os.kill(int(pid),signal.SIGUSR1)
 except ProcessLookupError:pass
sp.run(['gsettings','set','org.gnome.desktop.interface','color-scheme','prefer-dark'],capture_output=True)
sp.run(['gsettings','set','org.gnome.desktop.interface','gtk-theme','adw-gtk3-dark'],capture_output=True)
sp.run(['hyprctl','reload'],stdout=sp.DEVNULL)
sp.run([str(Path(__file__).resolve().parent/"themed-swash.py"),'--prepare-theme'],capture_output=True)
print('Matched Kitty, Alacritty, GTK3/4, Qt5/6, KDE, Fuzzel, btop and Swash to Devine; window rounding: 25px.')
