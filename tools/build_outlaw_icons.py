"""Original, editable celestial cowboy placeholders; no external art dependencies."""
from pathlib import Path
import random
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/icons/abilities/outlaw';OUT.mkdir(parents=True,exist_ok=True)
G='#dfb77b';B='#81d5ff';R='#ef697b';W='#eee0c8';D='#191e2b'
def path(d,fill='none',stroke=G,width=5):return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
def circle(x,y,r,fill,stroke=G,width=4):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def star(x,y,r=18,color=W):return path(f'M{x} {y-r} L{x+4} {y-4} L{x+r} {y} L{x+4} {y+4} L{x} {y+r} L{x-4} {y+4} L{x-r} {y} L{x-4} {y-4} Z',color,color,1)
def hat(x=128,y=80,s=1):
 return f'<g transform="translate({x-128*s} {y-80*s}) scale({s})">'+path('M73 91 Q99 80 108 57 L142 54 Q154 69 160 84 Q181 79 192 85 Q172 109 129 108 Q92 111 65 99 Z','#302b29',G,4)+path('M106 79 L154 77','none',G,5)+star(135,72,9)+'</g>'
def gun():
 return path('M58 130 L108 126 L116 119 L194 119 L194 143 L122 144 L110 158 L90 157 L79 199 L56 194 L67 153 L54 147 Z','#455464',W,5)+circle(105,137,15,D,G,4)+path('M83 158 Q102 178 117 149 M125 128 L184 128 M69 169 L78 172 M65 179 L76 182','none',G,3)
def knife():
 return path('M70 187 L91 164 L107 180 L86 202 Z','#65442d',G,4)+path('M89 152 L119 184','none',G,9)+path('M104 159 L150 103 Q169 84 190 65 L184 114 Q155 161 118 172 Z','#607a8e',W,4)+path('M118 159 Q153 134 180 87','none',R,5)+path('M76 181 L88 191 M80 175 L94 185','none',W,2)
art={}
art['starshot']=f'<g transform="rotate(-25 128 128)">{gun()}</g>'+path('M178 87 L215 45 M174 80 L191 44 M188 96 L226 87','none',B,5)+star(207,59,23,B)+star(218,88,9)
art['severe']=path('M46 198 Q213 198 203 65 Q180 159 52 167 Z','#642437',R,3)+knife()+path('M172 184 Q187 205 173 209 Q161 207 172 184 Z',R,R,2)
art['trickshot']=path('M186 108 L217 108 L217 208 L186 208 Z','#252735','#615568',3)+path('M37 174 L119 56 L230 71 L222 171','none',B,6)+circle(121,57,20,'#876335',G,5)+star(121,57,11)+circle(220,180,13,'#463039',R,3)+star(218,176,9,R)+path('M72 174 L43 174 L43 143','none',G,5)
art['coin_toss']=path('M56 205 L66 173 L102 159 L121 145 Q130 150 123 160 L107 177 L136 166 Q148 168 143 176 L105 205 Z','#344354',W,4)+path('M106 152 Q111 82 183 62','none',B,4)+circle(180,59,27,'#8b632d',G,5)+circle(180,59,19,'#3c3540',G,2)+star(180,59,15)+circle(132,104,13,'#544632',G,3)+path('M145 37 L157 42 M217 77 L225 82','none',W,3)
# Robot anatomy is icon-scale symbolism; the actual game model is the v2 mannequin.
art['backflip']=path('M52 196 Q17 112 78 56 Q157 15 211 87','none',B,7)+path('M211 60 L215 92 L184 85',B,B,4)+hat(137,121,.58)+circle(137,139,13,D,W,3)+path('M134 156 L103 171 L80 150 M105 169 L126 193 L153 174 M143 157 L169 140','none',W,11)+path('M89 214 L114 214 M124 226 L143 226','none',G,3)+star(55,100,12)
art['roll']=path('M31 190 L222 190 M39 204 L160 204','none',B,6)+path('M204 175 L223 190 L204 203',B,B,4)+hat(128,91,.6)+circle(129,109,13,D,W,3)+path('M128 125 L93 141 L114 165 L147 150 L167 170 M139 127 L159 144 L174 134','none',W,11)+path('M44 148 L68 148 M34 164 L58 164','none',G,4)+star(196,148,10)
art['defense_detonation']=circle(126,167,37,'#303443',G,7)+circle(126,167,22,D,W,3)
for x,y in [(68,75),(126,54),(186,75)]:
 art['defense_detonation']+=path(f'M{x-11} {y+33} L{x-11} {y+1} Q{x} {y-23} {x+11} {y+1} L{x+11} {y+33} Z','#3e6583',B,4)+path(f'M{x} {y+38} L{126+(x-126)*.45} 123','none',G,3)+star(x,y,10)
art['deadeye']=hat(128,72,1.12)+path('M89 119 L112 125 M145 125 L168 119','none',G,6)+circle(129,166,36,'none',R,5)+path('M129 115 L129 142 M129 190 L129 220 M79 166 L105 166 M153 166 L178 166','none',R,4)+circle(129,166,8,G,G,2)+star(51,179,14,B)+star(206,179,14,B)
art['ward']=path('M128 37 Q158 66 209 62 L202 133 Q184 189 128 219 Q70 190 54 133 L48 62 Q98 65 128 37 Z','#244159',B,5)
art['ward']+=path('M128 67 L143 98 L178 100 L155 127 L164 161 L128 146 L94 161 L102 127 L79 100 L113 98 Z','#9c713c',G,4)+circle(128,119,15,D,W,3)+star(128,119,11)+path('M27 122 L48 134 L30 151','none',W,4)
art['mend']=path('M96 62 L152 62 L150 91 Q179 104 182 136 L177 192 Q130 213 80 192 L76 137 Q79 102 98 91 Z','#2e5967',G,5)+path('M96 47 L151 47 L155 65 L91 65 Z','#684b34',W,4)+path('M86 144 Q130 159 174 136 L170 187 Q128 202 86 187 Z','#68adb3',B,2)+star(128,132,27,W)+path('M202 49 L202 82 M186 65 L217 65','none',B,6)+hat(127,195,.40)
for name,body in art.items():
 random.seed(122)
 specks=''.join(circle(random.randint(24,232),random.randint(24,232),random.choice([.6,1,1.4]),'#8193b5','none',0) for _ in range(35))
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><defs><radialGradient id="sky"><stop stop-color="#28374c"/><stop offset="1" stop-color="#090d18"/></radialGradient></defs><rect width="256" height="256" rx="18" fill="url(#sky)"/><rect x="10" y="10" width="236" height="236" rx="12" fill="none" stroke="#9f8054" stroke-width="3"/>{specks}{body}<path d="M17 36V18H35 M221 18H239V36 M17 220V238H35 M220 238H239V220" fill="none" stroke="#dfb77b" stroke-width="3"/></svg>'''
 (OUT/(name+'.svg')).write_text(svg,encoding='utf-8')
print('OUTLAW_PLACEHOLDER_ICONS',len(art))
