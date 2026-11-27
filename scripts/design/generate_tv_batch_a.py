#!/usr/bin/env python3
"""Generate the Session 1C.3B TV batch A review wireframes."""
import json
from pathlib import Path
from html import escape

ROOT = Path(__file__).resolve().parents[2]
TOKENS = json.loads((ROOT / 'docs/design/design-tokens.json').read_text())
COLORS = TOKENS['primitives']['color']
C = {k: COLORS[v] for k, v in TOKENS['semanticColor']['dark'].items()}
OUT = ROOT / 'docs/design/wireframes/tv'
OUT.mkdir(parents=True, exist_ok=True)


def generate(screen, w, h):
    small = w == 1280
    m, top = int(w * .05) + 4, int(h * .05) + 4
    title, body, meta = (36, 22, 18) if small else (48, 28, 22)
    gap = 24 if small else 32
    content = w - 2 * m
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-labelledby="title desc">', f'<title id="title">{screen} Pi TV wireframe</title><desc id="desc">Proposed design, illustrative only.</desc>', f'<rect width="{w}" height="{h}" fill="{C["background"]}"/>']
    def rect(x,y,ww,hh,fill='surface',focus=False):
        parts.append(f'<rect x="{x}" y="{y}" width="{ww}" height="{hh}" rx="12" fill="{C[fill]}" stroke="{C["focus"] if focus else C["border"]}" stroke-width="{(3 if small else 4) if focus else 1}"/>')
    def text(x,y,s,size=body,color='foreground',bold=False):
        parts.append(f'<text x="{x}" y="{y}" fill="{C[color]}" font-family="Arial, sans-serif" font-size="{size}" font-weight="{"700" if bold else "400"}">{escape(s)}</text>')
    def button(x,y,ww,label,focus=False,disabled=False):
        rect(x,y,ww,56 if small else 68,'surface' if disabled else 'surfaceRaised',focus)
        text(x+20,y+(36 if small else 44),label,body,'mutedForeground' if disabled else 'foreground',True)
    text(m,top+title,'Pi TV',title,bold=True)
    text(w-m,top+title-5,screen,meta,'mutedForeground') if False else None
    text(m, h-top-5, '↑ ↓ ← → Navigate    •    OK Select    •    Back Return',meta,'mutedForeground')
    y=top+title+gap+14
    if screen == 'TV-02':
        text(m,y,'Applications',body+6,bold=True)
        text(m,y+32,'Choose an available application. Provider support is not implied.',meta,'mutedForeground')
        cols = 2 if small else 3
        cardw = (content-(cols-1)*gap)//cols
        cardh = 150 if small else 200
        yy=y+58
        cards=[('Example application','Available • Press OK to open'),('Another application','Available'),('Unavailable application','Activation disabled • See details')]
        for i,(name,sub) in enumerate(cards):
            x=m+(i%cols)*(cardw+gap); cy=yy+(i//cols)*(cardh+gap)
            rect(x,cy,cardw,cardh,'surfaceRaised' if i==0 else 'surface',i==0)
            text(x+24,cy+54,name,body,bold=True)
            text(x+24,cy+90,sub,meta,'mutedForeground')
            if i==2: text(x+24,cy+125,'Details →',meta,'info',True)
        text(w-m-260,top+title,'Pair device   •   Settings',meta,'foreground')
    elif screen == 'TV-01':
        text(m,y,'Welcome to Pi TV',body+6,bold=True)
        text(m,y+42,'Set up this device using an approved local method.',body)
        text(m,y+78,'Local setup is available only after its security path is approved.',meta,'mutedForeground')
        rect(m,y+110,content,110 if small else 150)
        text(m+24,y+155,'Local setup unavailable?',body,bold=True)
        text(m+24,y+190,'Open help for recovery guidance. A phone cannot approve setup.',meta,'mutedForeground')
        button(m,y+(250 if small else 300),240,'Open help',True)
        button(m+264,y+(250 if small else 300),260,'Begin setup',disabled=True)
        text(m+264,y+(335 if small else 400),'Requires approved local method',meta,'mutedForeground')
    elif screen == 'TV-03':
        text(m,y,'Opening application',body+6,bold=True)
        rect(m,y+45,content,200 if small else 250)
        text(m+28,y+105,'Launching…',body,bold=True)
        text(m+28,y+145,'Please wait. Opening does not confirm playback.',meta,'mutedForeground')
        button(m,y+(280 if small else 340),200,'Cancel',True)
    elif screen == 'TV-04':
        text(m,y,'Pair a controller',body+6,bold=True)
        q = 210 if small else 300
        qx=m; qy=y+42
        rect(qx,qy,q,q,'surfaceRaised')
        text(qx+22,qy+q//2-10,'QR illustration',meta,bold=True)
        text(qx+22,qy+q//2+22,'NOT FUNCTIONAL',meta,'warning',True)
        tx=qx+q+gap
        text(tx,qy+38,'Scan using the companion app.',body,bold=True)
        text(tx,qy+78,'The enrollment window is temporary and one-use.',meta,'mutedForeground')
        text(tx,qy+110,'Local confirmation is required when approved.',meta,'mutedForeground')
        text(tx,qy+150,'Expired? Renew through the approved local ceremony.',meta,'warning')
        button(tx,qy+190,200,'Cancel',True)
    elif screen == 'TV-05':
        dw= min(content, 1000 if not small else 900); dx=m+(content-dw)//2
        dy=y+15; dh=365 if small else 450
        rect(dx,dy,dw,dh,'surfaceRaised')
        text(dx+32,dy+55,'Confirm enrollment',body+6,bold=True)
        text(dx+32,dy+100,'A controller is awaiting a local decision.',body)
        text(dx+32,dy+140,'Verify the request using the approved local path.',meta,'mutedForeground')
        text(dx+32,dy+175,'No approved path? Reject and use recovery guidance.',meta,'warning')
        button(dx+32,dy+225,180,'Reject',True)
        button(dx+235,dy+225,220,'Approve',disabled=True)
        text(dx+32,dy+320,'Approval stays disabled until the local method is approved.',meta,'mutedForeground')
    parts.append('</svg>')
    (OUT / f'{screen.lower()}-{w}x{h}.svg').write_text('\n'.join(parts)+'\n')

for screen in ['TV-02','TV-01','TV-03','TV-04','TV-05']:
    for w,h in [(1920,1080),(1280,720)]:
        generate(screen,w,h)
    print(screen, 'saved', flush=True)
