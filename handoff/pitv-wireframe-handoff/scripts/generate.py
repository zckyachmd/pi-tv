#!/usr/bin/env python3
"""Design-only SVG/PNG generator. Run with Python, Pillow and CairoSVG on dev host."""
import argparse, json, math, os, subprocess, xml.etree.ElementTree as ET
from pathlib import Path
from html import escape
from PIL import Image, ImageFont, ImageOps, ImageDraw
import cairosvg
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--tokens',type=Path,default=ROOT/'token-snapshot.json');args=ap.parse_args()
T=json.loads(args.tokens.read_text()); assert T['version']=='1.1.0-proposed', 'Review token drift before generation'
PALETTES={k:{r:T['primitives']['color'][v] for r,v in p.items()} for k,p in T['semanticColor'].items()}
FONT='DejaVu Sans'; FP='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'; FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(size,bold=False):
    p=FB if bold else FP
    if not Path(p).exists(): p=subprocess.check_output(['fc-match','-f','%{file}',FONT+(':style=Bold' if bold else '')],text=True).strip()
    return ImageFont.truetype(p,round(size))
records=[]
class Canvas:
 def __init__(self,w,h,theme,id,variant,platform):
    self.w,self.h,self.c,self.id,self.variant,self.platform=w,h,PALETTES[theme],id,variant,platform;self.theme=theme
    self.e=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-labelledby="title desc"><title id="title">{id} {escape(variant)}</title><desc id="desc">Static design proposal, sample data, not functional.</desc>']; self.check=[]; self.rect(0,0,w,h,'background',r=0)
 def rect(self,x,y,w,h,fill='surface',r=12,stroke=None,sw=1):
    if min(x,y,w,h)<0 or x+w>self.w+.01 or y+h>self.h+.01: raise ValueError((self.id,self.variant,'rect',x,y,w,h))
    self.e.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{self.c.get(fill,fill)}"'+(f' stroke="{self.c.get(stroke,stroke)}" stroke-width="{sw}"' if stroke else '')+'/>')
 def line(self,x,y,x2,y2,color='border',sw=1): self.e.append(f'<path d="M{x} {y}L{x2} {y2}" fill="none" stroke="{self.c[color]}" stroke-width="{sw}" stroke-linecap="round"/>')
 def text(self,x,y,s,size=20,color='foreground',bold=False,width=None,anchor='start'):
    f=font(size,bold); tw=f.getlength(s); x0=x-tw/2 if anchor=='middle' else x-tw if anchor=='end' else x
    if width is not None and tw>width+.1: raise ValueError((self.id,self.variant,'text width',s,tw,width))
    if x0<0 or x0+tw>self.w or y-size<0 or y+size*.3>self.h: raise ValueError((self.id,self.variant,'text canvas',s,x0,y,tw,size))
    self.e.append(f'<text x="{x}" y="{y}" font-family="{FONT}, sans-serif" font-size="{size}" font-weight="{700 if bold else 400}" fill="{self.c.get(color,color)}" text-anchor="{anchor}">{escape(s)}</text>');self.check.append((s,round(tw,1)))
 def wrap(self,x,y,s,width,size=20,color='mutedForeground',bold=False,leading=None):
    f=font(size,bold); lines=[]; line=''
    for word in s.split():
      q=(line+' '+word).strip()
      if f.getlength(q)>width and line: lines.append(line); line=word
      else: line=q
    if line: lines.append(line)
    for i,l in enumerate(lines): self.text(x,y+i*(leading or round(size*1.42)),l,size,color,bold,width)
    return y+len(lines)*(leading or round(size*1.42))
 def button(self,x,y,w,h,label,focus=False,kind='secondary',size=18):
    fill,fg=('interactive','interactiveForeground') if kind=='primary' else ('disabledSurface','disabledForeground') if kind=='disabled' else ('surfaceRaised','foreground')
    # Focus uses offset gap, with adjacent background not same-color primary fill.
    self.rect(x,y,w,h,fill,r=T['radius']['md'],stroke='border' if kind=='secondary' and not focus and fill!='surfaceRaised' else None)
    if focus: self.rect(x-5,y-5,w+10,h+10,'none',r=16,stroke='focus',sw=3 if self.w==1280 else 4)
    self.text(x+w/2,y+h/2+size*.34,label,size,fg,True,w-16,'middle')
 def icon(self,x,y,kind,size=40,color='primary'):
    c=self.c[color]; s=size/24
    paths={'play':'M8 5L20 12L8 19Z','film':'M3 5H21V19H3Z M7 5V19 M17 5V19 M3 10H7 M17 10H21 M3 14H7 M17 14H21','music':'M9 18V5L20 3V16 M9 9L20 7 M9 18C9 22 2 22 2 18C2 15 9 14 9 18 M20 16C20 20 13 20 13 16C13 13 20 12 20 16','tv':'M2 3H22V17H2Z M8 21H16 M12 17V21','phone':'M7 2H17Q19 2 19 4V20Q19 22 17 22H7Q5 22 5 20V4Q5 2 7 2Z M10 19H14','shield':'M12 2L21 6V12Q21 18 12 22Q3 18 3 12V6Z M8 12L11 15L17 9','wifi':'M2 8Q12 0 22 8 M5 12Q12 6 19 12 M8 16Q12 12 16 16 M12 20H12.1','warning':'M12 3L22 21H2Z M12 9V14 M12 18H12.1','check':'M4 12L10 18L21 6','settings':'M4 5H20 M4 12H20 M4 19H20 M8 3V7 M16 10V14 M10 17V21','home':'M3 11L12 3L21 11V21H15V15H9V21H3Z','back':'M10 5L3 12L10 19 M3 12H21','keyboard':'M2 5H22V19H2Z M5 9H19 M5 13H19 M8 16H16','pointer':'M4 3L20 13L12 15L9 22Z','lock':'M6 10H18V22H6Z M8 10V6Q8 2 12 2Q16 2 16 6V10','qr':'M3 3H9V9H3Z M15 3H21V9H15Z M3 15H9V21H3Z M15 15H21V21 M12 3V7 M12 12H16 M18 12H21','bluetooth':'M11 2V22L18 16L6 6 M11 2L18 8L6 18','globe':'M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2 M2 12H22 M12 2Q4 12 12 22Q20 12 12 2'}
    self.e.append(f'<path transform="translate({x} {y}) scale({s})" d="{paths[kind]}" fill="none" stroke="{c}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>')
 def qr(self,x,y,s):
    # No data modules; deliberately not a valid QR symbol.
    self.rect(x,y,s,s,'#FFFFFF',r=12); p=s*.12; d=s*.22
    for a,b in [(x+p,y+p),(x+s-p-d,y+p),(x+p,y+s-p-d)]:
      self.rect(a,b,d,d,'#11131A',r=0);self.rect(a+d*.17,b+d*.17,d*.66,d*.66,'#FFFFFF',r=0);self.rect(a+d*.31,b+d*.31,d*.38,d*.38,'#11131A',r=0)
    self.text(x+s/2,y+s*.55,'DEMO',max(18,round(s*.12)),'#11131A',True,s*.86,'middle')
 def save(self,filename):
    p=ROOT/'wireframes'/self.platform/filename; p.parent.mkdir(exist_ok=True,parents=True);p.write_text('\n'.join(self.e+['</svg>'])+'\n');ET.parse(p)
    cairosvg.svg2png(url=str(p),write_to=str(p.with_suffix('.png'))); im=Image.open(p.with_suffix('.png')); assert im.size==(self.w,self.h)
    records.append({'id':self.id,'variant':self.variant,'theme':self.theme,'canvas':[self.w,self.h],'svg':str(p.relative_to(ROOT)),'png':str(p.with_suffix('.png').relative_to(ROOT)),'text_items':len(self.check)})

def tv(n,w,h,variant='base'):
 c=Canvas(w,h,'dark',f'TV-{n:02}',variant,'tv'); small=w==1280; m=round(w*.05)+12; top=round(h*.05)+12; right=w-m; inner=right-m; footer=h-top-8
 title=32 if small else T['tv']['titlePx']; sec=26 if small else T['tv']['sectionPx']; body=20 if small else T['tv']['bodyPx']; meta=18 if small else T['tv']['metaPx']; gap=24 if small else 32
 c.text(m,top+title,'Pi TV',title,bold=True); c.line(m,top+title+22,right,top+title+22); y=top+title+60
 setup=n in (1,4,5) or (n==10 and variant=='lost') or (n==6 and variant=='empty');
 c.text(right,top+title-3,'SETUP MODE' if setup else 'REMOTE READY' if variant!='offline' else 'INTERNET OFFLINE',meta,'warning' if setup or variant=='offline' else 'success',True,anchor='end')
 c.text(m,footer,'Use Pi TV Remote on your iPhone' if setup else 'D-pad  •  Select  •  Back  •  Home',meta,'mutedForeground'); c.text(right,footer,'Pi TV  /  '+('Setup' if setup else 'Local control'),meta,'mutedForeground',anchor='end')
 def heading(label,sub):
    c.text(m,y,label,sec,bold=True);c.text(m,y+round(body*1.65),sub,body,'mutedForeground',width=inner);return y+round(body*1.65)+gap
 def panel(x,yy,ww,hh):c.rect(x,yy,ww,hh,'surface',r=T['radius']['lg'])
 def row(x,yy,ww,label,sub,focus=False,icon='settings',status=None):
    hh=66 if small else 88; c.rect(x,yy,ww,hh,'surfaceRaised' if focus else 'surface',r=12,stroke='focus' if focus else None,sw=3 if small else 4);c.icon(x+16,yy+16,icon,32 if small else 42);tx=x+(66 if small else 84);c.text(tx,yy+body+7,label,body,bold=True,width=ww-(90 if small else 110));c.text(tx,yy+body+meta+10,sub,meta,'mutedForeground',width=ww-(90 if small else 110));return yy+hh+12
 if n in (1,4):
    expired=variant=='expired'; adding=variant=='add'; yy=heading('Welcome to Pi TV' if n==1 else 'Pair your iPhone','An existing owner opened this enrollment.' if adding else 'No keyboard, mouse or shared Wi-Fi needed.')
    q=240 if small else 340; x=m; tx=x+q+gap*2; tw=right-tx; panel(x,yy,q+20,q+58); 
    if expired: c.icon(x+q*.32,yy+36,'lock',q*.4,'warning');c.text(x+(q+20)/2,yy+q*.85,'Code expired',body,'warning',True,anchor='middle')
    else: c.qr(x+10,yy+10,q);c.text(x+(q+20)/2,yy+q+37,'Illustration — not scannable',meta,'mutedForeground',anchor='middle')
    c.text(tx,yy+30,'Open Pi TV Remote',sec,bold=True,width=tw); pos=yy+75
    for k,s in enumerate(['Enable Bluetooth on your iPhone.','Scan the code shown on this TV.','Verify this TV and finish setup on your phone.'] if not expired else ['This code is no longer valid.','Follow the recovery instructions in the app.','A fresh code requires authorized renewal.']):
      c.rect(tx,pos-24,36,36,'surfaceRaised',r=10);c.text(tx+18,pos,str(k+1),meta,'primary',True,anchor='middle');pos=c.wrap(tx+52,pos,s,tw-52,body,'foreground')+24
    c.wrap(tx,pos+3,('The existing owner must authorize this new controller.' if adding else 'Keep this code private. Scan only from the TV in front of you.') if not expired else 'An owned device never becomes open for enrollment just because a code expires.',tw,meta,'warning')
 elif n==2:
    yy=heading('Applications','Choose an app. Availability shown here is illustrative.')
    cols=3; names=[('YouTube','Video','play'),('Netflix','Video','film'),('Spotify','Music','music'),('Jellyfin','Personal media','tv'),('Local demo','Test fixture','play'),('Audio demo','Test fixture','music')]; names=[] if variant=='empty' else names
    if not names: panel(m,yy,inner,220 if small else 320);c.text(m+24,yy+56,'No applications available',sec,bold=True);c.text(m+24,yy+98,'Check the catalog or open Settings.',body,'mutedForeground');c.button(m+24,yy+132,220,54,'Settings',True,size=body)
    else:
      cw=(inner-(cols-1)*gap)//cols; ch=170 if small else 240; gy=yy
      for i,(label,sub,ico) in enumerate(names):
       x=m+(i%cols)*(cw+gap); a=gy+(i//cols)*(ch+16);focus=i==4; c.rect(x,a,cw,ch,'surfaceRaised' if focus else 'surface',r=12,stroke='focus' if focus else None,sw=3 if small else 4)
       sz=44 if small else 66; c.rect(x+18,a+16,sz+20,sz+20,'background',r=12); c.icon(x+28,a+26,ico,sz,'primary' if focus else 'mutedForeground'); tx=x+20; ty=a+(104 if small else 141);c.text(tx,ty,label,body,bold=True,width=cw-40);c.text(tx,ty+meta+7,'Not verified' if i<4 else sub,meta,'warning' if i<4 else 'mutedForeground',width=cw-40)
       if i<4:c.text(x+cw-18,a+ch-12,'Details ›',meta,'info',True,anchor='end')
      if not small:c.text(m,gy+2*(ch+16)+28,'Sample local fixtures only; provider certification pending.',meta,'mutedForeground')
    # Header actions distinct from cards; offset below status on wide viewport not needed.
    c.button(right-(260 if small else 320),top+title+28,118 if small else 144,44 if small else 52,'Pair',size=meta);c.button(right-(132 if small else 160),top+title+28,132 if small else 160,44 if small else 52,'Settings',size=meta)
 elif n==3:
    yy=heading('Opening application','The launcher is starting a foreground runtime.');panel(m,yy,inner,240 if small else 340); c.icon(m+36,yy+36,'play',72 if small else 96);tx=m+(140 if small else 180);c.text(tx,yy+66,'Local demo',sec,bold=True);c.text(tx,yy+108,'Starting…' if variant!='failure' else 'Could not open',body,'warning' if variant=='failure' else 'primary',True);c.wrap(tx,yy+145,'Playback is not confirmed until the application reports it.',right-tx-24,body);c.button(m,yy+(270 if small else 380),220,56,'Cancel' if variant!='failure' else 'Return home',True,size=body)
 elif n==5:
    yy=heading('Verify your TV','Finish enrollment on your iPhone, not on this screen.')
    panel(m,yy,inner,280 if small else 410);c.icon(m+36,yy+36,'shield',72 if small else 108);tx=m+(140 if small else 180);tw=right-tx-36;c.text(tx,yy+52,'Compare the verification phrase',sec,bold=True,width=tw);c.text(tx,yy+103,'RIVER  •  MAPLE  •  SKY',sec,'primary',True,width=tw);pos=c.wrap(tx,yy+155,'If the phrase matches the one in the app, confirm there. Otherwise cancel in the app.',tw,body);c.wrap(tx,pos+8,'If the phrase differs, cancel and do not continue.',tw,meta,'warning')
 elif n in (6,7,8):
    if n==6:
      yy=heading('Paired devices','Manage access from an authorized controller.'); data=[('My iPhone','Active controller • Ready','phone'),('Backup iPhone','Trusted • Disconnected','phone'),('Add a device','Requires authorized enrollment','qr')] if variant!='empty' else [('No paired devices','Use recovery from your iPhone','lock')]
    elif n==7:
      yy=heading('Settings','Manage your appliance from Pi TV Remote.'); data=[('Internet connection','Wi-Fi or Ethernet for streaming','wifi'),('Paired devices','View and revoke access','phone'),('Diagnostics','Device health and compatibility','settings'),('Reset Pi TV','Requires owner authorization','lock')]
      if variant=='reset':data=[('Reset remote access','Revoke controllers and rotate identity','lock'),('Keep saved app sessions','Default • no provider profile deletion','shield'),('Cancel reset','No changes made','back')]
    else:
      yy=heading('Diagnostics','Sample values — not measurements.');data=[('Bluetooth','Available • remote session ready','bluetooth'),('Internet','Offline' if variant=='offline' else 'Connected • streaming only','wifi'),('Display','HDMI • current output','tv'),('Back','Return to the previous screen','back')]
    for i,(a,b,ic) in enumerate(data):
      focused=(i==len(data)-1 if n==8 or variant=='reset' else i==0) and not (n==6 and variant=='empty')
      yy=row(m,yy,inner,a,b,focused,ic)
 elif n==9:
    yy=heading('Application unavailable','This application cannot be launched yet.'); panel(m,yy,inner,230 if small else 300);c.icon(m+32,yy+32,'warning',64 if small else 90,'warning');tx=m+(130 if small else 160);c.text(tx,yy+55,'Provider not verified',sec,bold=True);c.wrap(tx,yy+105,'Playback compatibility for this device has not been established. No unsupported DRM workaround will be attempted.',right-tx-28,body);c.button(m,yy+(260 if small else 340),260,56,'Back to apps',True,size=body)
 elif n==10:
    if variant=='lost':
      yy=heading('Recover your remote','You do not need a keyboard or a mouse.');panel(m,yy,inner,250 if small else 340);c.icon(m+32,yy+32,'lock',64 if small else 90);tx=m+(130 if small else 160);p=c.wrap(tx,yy+46,'Open Pi TV Remote on your replacement iPhone. Choose Recover device and use your saved recovery kit.',right-tx-28,body,'foreground');p=c.wrap(tx,p+18,'If all credentials are lost, secure re-provisioning is required. No automatic reset.',right-tx-28,body,'warning');c.wrap(tx,p+14,'No screen interaction is required for this recovery proposal.',right-tx-28,meta)
    else:
      yy=heading('Application stopped','Return home or try again from your iPhone.');panel(m,yy,inner,210 if small else 280);c.icon(m+32,yy+32,'warning',64 if small else 90,'warning');tx=m+(130 if small else 160);c.text(tx,yy+54,'The browser could not continue',sec,bold=True);c.wrap(tx,yy+102,'Your saved sessions have not been intentionally erased. If state is unknown, recovery will verify it.',right-tx-28,body);by=yy+(242 if small else 320);c.button(m,by,240,56,'Return home',True,size=body);c.button(m+264,by,160,56,'Retry',size=body);c.button(m+448,by,220,56,'Diagnostics',size=body)
 c.save(f'tv-{n:02}-{variant}-{w}x{h}.svg')

# iOS boards use point-sized reference coordinates, not production native layouts.
def ios(n,theme,variant='base',w=390,h=844):
 c=Canvas(w,h,theme,f'IOS-{n:02}',variant,'ios'); m=24; inner=w-2*m; right=w-m; title=28; body=17; meta=14
 c.text(m,34,'9:41',14,bold=True);c.text(right,34,'Bluetooth',13,'mutedForeground',anchor='end');c.line(m,48,right,48)
 def head(a,b):c.text(m,88,a,title,bold=True,width=inner);return c.wrap(m,118,b,inner,body)
 def card(y,a,b,ic='phone',status='mutedForeground'):
    c.rect(m,y,inner,86,'surface',r=12);c.icon(m+14,y+22,ic,32);c.text(m+58,y+30,a,17,bold=True,width=inner-72);c.wrap(m+58,y+54,b,inner-72,meta,status,leading=17);return y+98
 def btn(y,a,kind='primary'): c.button(m,y,inner,52,a,kind=kind,size=17);return y+64
 def note(y,s,col='mutedForeground'):return c.wrap(m,y,s,inner,meta,col,leading=20)
 def nav():
    c.line(m,h-84,right,h-84);c.text(m+32,h-51,'Remote',14,'primary' if n in (6,7) else 'mutedForeground',n in (6,7),anchor='middle');c.text(w/2,h-51,'Devices',14,'primary' if n in (5,9) else 'mutedForeground',n in (5,9),anchor='middle');c.text(right-32,h-51,'Help',14,'primary' if n==10 else 'mutedForeground',n==10,anchor='middle')
 if n==1:
    y=head('Welcome to Pi TV','Your iPhone is the remote. No shared Wi-Fi required.');c.icon(w/2-38,y+34,'bluetooth',76);y+=144;y=card(y,'Bluetooth access','Discover and control your Pi TV.','bluetooth');y=card(y,'Camera access','Scan the code on your TV.','qr');y=btn(y+12,'Continue');note(y+12,'You can change permissions in Settings.')
 elif n==2:
    y=head('Find your TV','Choose a nearby device or scan its on-screen code.');y=card(y+22,'Pi TV • nearby','Discovery hint only; identity not verified.','tv');y=btn(y+14,'Scan TV code');y=btn(y,'Search again','secondary');note(y+8,'Keep Bluetooth on and stay near your TV.')
 elif n==3:
    y=head('Scan TV code','Point your camera at the code shown on the television.'); q=min(inner,264);x=(w-q)/2;c.rect(x,y+30,q,q,'surfaceRaised',r=18);c.icon(x+q/2-42,y+30+q/2-42,'qr',84);c.text(w/2,y+30+q-22,'Camera preview illustration',meta,'mutedForeground',anchor='middle');y=btn(y+q+60,'Cancel','secondary');note(y+12,'Never scan a code sent by an unknown person.')
 elif n==4:
    if variant=='wrong':
      y=head('Identity mismatch','The TV identity could not be verified. Pairing has stopped.');y=card(y+28,'Pairing blocked','Do not accept an unexpected identity.','shield','danger');y=btn(y+12,'Scan a fresh code');y=btn(y,'Cancel pairing','secondary');note(y+8,'Only use a fresh code from your own TV.')
    elif variant=='recovery-kit':
      y=head('Save recovery kit','Your TV is paired. Save a backup before using your remote.');y=card(y+24,'Recovery kit','Keep it somewhere you can access if this iPhone is lost.','lock');y=btn(y+12,'Save recovery kit');y=btn(y,'I have saved it','secondary');note(y+10,'Illustration only. Never share the recovery credential.');note(y+74,'Backup and storage choices require security review.')
    else:
      y=head('Verify your TV','Check that the phrase matches your TV screen.');c.rect(m,y+20,inner,132,'surface',r=18);c.icon(m+18,y+42,'shield',36);c.text(m+64,y+55,'RIVER · MAPLE · SKY',18,'primary',True,width=inner-76);c.wrap(m+18,y+94,'Illustrative phrase, not a real pairing secret.',inner-36,meta); y+=178;y=btn(y,'Phrase matches');y=btn(y,'Cancel pairing','secondary');note(y+8,'Only confirm if you can see the matching phrase on your TV.')

 elif n==5:
    y=head('Your devices','Select a trusted TV to connect.');y=card(y+20,'Living room TV','Trusted • disconnected','tv');y=card(y,'Bedroom TV','Trusted • not in range','tv');y=btn(y+14,'Add a TV','secondary');nav()
 elif n==6:
    y=head('Living room TV','Ready • authenticated and synced' if variant in ('base','compact') else 'Synchronizing… controls disabled');
    cy=y+(118 if h<830 else 128);cx=w/2; c.rect(cx-104,cy-104,208,208,'surface',r=32); enabled=variant in ('base','compact')
    for dx,dy,a in [(0,-64,'↑'),(-64,0,'←'),(0,0,'OK'),(64,0,'→'),(0,64,'↓')]:
      c.button(cx+dx-28,cy+dy-28,56,56,a,kind='primary' if a=='OK' and enabled else 'secondary' if enabled else 'disabled',size=20)
    yy=cy+128; bw=(inner-24)//3
    for i,a in enumerate(['Back','Home','Keyboard']):c.button(m+i*(bw+12),yy,bw,48,a,kind='secondary' if enabled else 'disabled',size=14)
    yy+=64; c.button(m,yy,inner,48,'Switch to touchpad',kind='secondary' if enabled else 'disabled',size=16);yy+=70
    c.text(m,yy,'Media & volume',18,bold=True); yy+=18
    for i,a in enumerate(['Play / pause','Mute']):c.button(m+i*(inner/2+6),yy,inner/2-6,48,a,kind='secondary' if enabled else 'disabled',size=14)
    yy+=60;bw=(inner-24)//3
    for i,a in enumerate(['Volume −','Volume +','Next']):c.button(m+i*(bw+12),yy,bw,44,a,kind='secondary' if enabled and i<2 else 'disabled',size=13)
    yy+=60;note(yy,'Seek / next unavailable');nav()
 elif n==7:
    y=head('Touchpad','Ready • pointer mode');c.rect(m,y+16,inner,288,'surface',r=20);c.icon(w/2-22,y+104,'pointer',44);c.text(w/2,y+176,'Swipe to move',18,bold=True,anchor='middle');c.text(w/2,y+205,'Tap to click',meta,'mutedForeground',anchor='middle');yy=y+320;c.button(m,yy,inner/2-6,48,'Pointer',kind='primary',size=16);c.button(m+inner/2+6,yy,inner/2-6,48,'Scroll',size=16);yy+=64;yy=btn(yy,'Switch to D-pad','secondary');note(yy+10,'Accessible directional controls are available in D-pad mode.');nav()
 elif n==8:
    y=head('Send text','Enter text on your iPhone, then send it to the active app.');c.rect(m,y+20,inner,108,'surface',r=12);c.text(m+14,y+48,'Type here…',17,'mutedForeground');y+=148;y=btn(y,'Send text','disabled');y=btn(y,'Cancel','secondary');note(y+8,'Text is not logged. Delivery does not guarantee provider acceptance.');
    # Native keyboard region, intentionally schematic.
    c.rect(8,h-250,w-16,240,'surfaceRaised',r=20);c.text(w/2,h-220,'Native iOS keyboard',meta,'mutedForeground',anchor='middle')
    for ri,letters in enumerate(['QWERTYUIOP','ASDFGHJKL','ZXCVBNM']):
      kw=(w-50)//10;start=(w-(len(letters)*kw+(len(letters)-1)*3))/2
      for j,l in enumerate(letters):c.rect(start+j*(kw+3),h-204+ri*42,kw,36,'surface',r=5);c.text(start+j*(kw+3)+kw/2,h-180+ri*42,l,14,anchor='middle')
 elif n==9:
    if variant=='network':
      y=head('Internet setup','Only the Pi needs internet for streaming. Your remote stays on Bluetooth.');y=card(y+12,'Home network','Example network • secured','wifi');c.rect(m,y,inner,58,'surface',r=12);c.text(m+14,y+36,'Enter Wi-Fi password',17,'mutedForeground');y+=72;y=btn(y,'Connect Pi TV');y=btn(y,'Skip for now','secondary');note(y+8,'Send settings only through the authenticated session. Existing host settings are protected.');nav()
    else:
      y=head('Device settings','Manage this TV and keep a recovery kit.');y=card(y+12,'Living room TV','Trusted device','tv');y=card(y,'Recovery kit','Save outside this phone.','lock');y=card(y,'Internet setup','Configure Pi Wi-Fi after pairing.','wifi');y=btn(y+8,'Manage controllers','secondary');y=btn(y,'Reset access…','secondary');nav()
 elif n==10:
    busy=variant=='busy'; lost=variant=='lost'; y=head('TV is busy' if busy else 'Recover device' if lost else 'Connection lost','Another authorized controller is active.' if busy else 'Use the recovery kit saved during setup.' if lost else 'Playback may continue. Controls are disabled.');y=card(y+28,'Living room TV','Waiting for control' if busy else 'Identity verification required' if lost else 'Disconnected','lock' if lost else 'tv','warning');y=btn(y+12,'Use recovery kit' if lost else 'Try again');y=btn(y,'Choose another TV','secondary');note(y+10,'Do not retry commands with unknown outcomes.' if not lost else 'Without a trusted controller or recovery kit, secure re-provisioning is required.');nav()
 c.save(f'ios-{n:02}-{variant}-{theme}-{w}x{h}.svg')

for w,h in [(1920,1080),(1280,720)]:
 for n in range(1,11):tv(n,w,h)
 for n,var in [(2,'empty'),(3,'failure'),(4,'expired'),(4,'add'),(6,'empty'),(7,'reset'),(8,'offline'),(10,'lost')]:tv(n,w,h,var)
for theme in ('dark','light'):
 for n in range(1,11):ios(n,theme)
 for n,var in [(4,'wrong'),(4,'recovery-kit'),(6,'sync'),(9,'network'),(10,'busy'),(10,'lost')]:ios(n,theme,var)
# Compact viewport examples deliberately reflow the available vertical area.
for theme in ('dark','light'):ios(6,theme,'compact',375,812)
(ROOT/'manifest.json').write_text(json.dumps({'token_version':T['version'],'artifacts':records},indent=2)+'\n')
for platform in ('tv','ios'):
 rr=[r for r in records if r['svg'].startswith('wireframes/'+platform+'/')]; idx=['# '+platform.upper()+' static wireframes','', 'Illustrative only. See ../../KEYBOARD_FREE_REQUIREMENTS.md for proposed security and onboarding changes.','', '| Screen | Variant | Theme | Canvas | Source | Preview |','|---|---|---|---|---|---|']
 for r in rr:idx.append(f"| {r['id']} | {r['variant']} | {r['theme']} | {r['canvas'][0]} × {r['canvas'][1]} | [SVG]({Path(r['svg']).name}) | [PNG]({Path(r['png']).name}) |")
 (ROOT/'wireframes'/platform/'README.md').write_text('\n'.join(idx)+'\n')
print('Generated',len(records),'SVG/PNG pairs')
