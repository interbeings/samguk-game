# Python port of build2.ps1: python3 build.py <out.html>
import sys,json,base64,re,os
s=os.path.dirname(os.path.abspath(__file__))
B64=lambda p,m='image/png':'data:%s;base64,'%m+base64.b64encode(open(p,'rb').read()).decode()
parts=[]
gf=open(f'{s}/guan_atlas.json',encoding='utf-8-sig').read()
gf=re.sub(r'"jumpA":\[(\d+),(\d+),(\d+),(\d+),\d+',r'"jumpA":[\1,\2,\3,\4,52',gf)
gf=re.sub(r'"jumpB":\[(\d+),(\d+),(\d+),(\d+),\d+',r'"jumpB":[\1,\2,\3,\4,50',gf)
parts.append('"guan":{"src":"'+B64(f'{s}/guan_atlas.png')+'","h":160,"face":1,"f":'+gf+'}')
for k in ['zhangfei','zhaoyun','huangzhong','weiyan','foe','boss1','boss2','boss3','boss4','boss5','boss6']:
    if not os.path.exists(f'{s}/{k}_atlas.png'):print('missing',k);continue
    fr=open(f'{s}/{k}.json',encoding='utf-8-sig').read();j=json.loads(fr)
    fj=fr[fr.index('"f":')+4:].rstrip();fj=fj[:-1]
    parts.append('"%s":{"src":"%s","h":%s,"face":1,"f":%s}'%(k,B64(f'{s}/{k}_atlas.png'),j['h'],fj))
js='{'+','.join(parts)+'}'
bg=[]
meta=json.load(open(f'{s}/bg_meta.json',encoding='utf-8-sig'))
for n,v in meta.items():
    f=f'{s}/bg_{n}.jpg'
    if os.path.exists(f):bg.append('"%s":{"src":"%s","gy":%s}'%(n,B64(f,'image/jpeg'),v))
html=open(f'{s}/game_src2.html',encoding='utf-8-sig',newline='').read().replace('__SETS__',js).replace('__BGS__','{'+','.join(bg)+'}')
open(sys.argv[1],'w',encoding='utf-8',newline='').write(html);print(os.path.getsize(sys.argv[1]))
