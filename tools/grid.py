# Python port of grid.ps1: python3 grid.py <sheet.png> <rows> <cols> <targetH> <out_atlas.png> <out.json> [preview.png]
import sys,json,numpy as np
from PIL import Image
from scipy import ndimage
src,R,C,TH,outPng,outJson=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),sys.argv[5],sys.argv[6]
im=np.array(Image.open(src).convert('RGB')).astype(int);H,W,_=im.shape
r,g,b=im[...,0],im[...,1],im[...,2]
bg=(r>140)&(b>140)&(g<130)&((np.minimum(r,b)-g)>60);fg=~bg
m=ndimage.binary_dilation(fg,structure=np.ones((7,7),bool))
lab,n=ndimage.label(m)
comps=[None]
objs=ndimage.find_objects(lab)
for k in range(1,n+1):
    sl=objs[k-1];sub=(lab[sl]==k)&fg[sl];ys,xs=np.nonzero(sub)
    if len(ys)==0:comps.append([0,0,0,0,0]);continue
    comps.append([xs.min()+sl[1].start,ys.min()+sl[0].start,xs.max()+sl[1].start,ys.max()+sl[0].start,len(ys)])
cell=[-1]*(n+1);cellBig=[0]*(R*C);cellBox=[None]*(R*C)
for pas in (0,1):
    for k in range(1,n+1):
        c=comps[k]
        if c[4]<40:continue
        small=c[4]<2500
        if (pas==0)==small:continue
        w=c[2]-c[0]+1;h=c[3]-c[1]+1
        if c[0]>W-170 and c[1]>H-170 and w<70 and h<70:continue
        cx=(c[0]+c[2])//2;cy=(c[1]+c[3])//2
        if not small:id_=min(R-1,cy*R//H)*C+min(C-1,cx*C//W)
        else:
            y0,y1=max(0,c[1]-90),min(H-1,c[3]+90);x0,x1=max(0,c[0]-90),min(W-1,c[2]+90)
            bd=1e18;id_=-1
            for y in range(y0,y1+1,2):
                for x in range(x0,x1+1,2):
                    if not fg[y,x]:continue
                    q=lab[y,x]
                    if q==k or q==0 or cell[q]<0 or comps[q][4]<2500:continue
                    gx=max(0,c[0]-x,x-c[2]);gy=max(0,c[1]-y,y-c[3]);dd=gx*gx+gy*gy
                    if dd<bd:bd=dd;id_=cell[q]
            if id_<0 or bd>90*90:continue
        cell[k]=id_
        if cellBig[id_]==0 or comps[cellBig[id_]][4]<c[4]:cellBig[id_]=k
        bx=cellBox[id_]
        cellBox[id_]=[c[0],c[1],c[2],c[3]] if bx is None else [min(bx[0],c[0]),min(bx[1],c[1]),max(bx[2],c[2]),max(bx[3],c[3])]
hs=sorted(comps[cellBig[c]][3]-comps[cellBig[c]][1]+1 for c in range(C) if cellBig[c]>0)
refH=hs[len(hs)//2] if hs else 160;sc=min(1,TH/refH)
cellOf=np.array(cell+[0])  # map label->cell
labcell=np.where(lab>0,np.array(cell)[lab],-1)
frames=[];meta=[];names=[]
for id_ in range(R*C):
    bx=cellBox[id_]
    if bx is None:continue
    x0,y0,x1,y1=bx;bw,bh=x1-x0+1,y1-y0+1
    sub=im[y0:y1+1,x0:x1+1];f=fg[y0:y1+1,x0:x1+1]&(labcell[y0:y1+1,x0:x1+1]==id_)
    rr,gg,bb=sub[...,0].copy(),sub[...,1].copy(),sub[...,2].copy();mg=np.minimum(rr,bb)-gg
    keep=f&(mg<=70);adj=np.clip(mg-15,0,None)*(mg>15)
    rr=np.clip(rr-adj,0,255);bb=np.clip(bb-adj,0,255)
    a=np.where(mg>50,150,255)*keep
    rgba=np.dstack([rr,gg,bb,a]).astype(np.uint8);rgba[~keep]=0
    big=cellBig[id_];bc=comps[big]
    fb=Image.fromarray(rgba,'RGBA')
    nw,nh=max(1,round(bw*sc)),max(1,round(bh*sc))
    # premultiplied resize to avoid dark fringes
    sb=fb.resize((nw,nh),Image.LANCZOS) if sc<1 else fb
    ch=bc[3]-bc[1]+1;ty0=bc[1]+int(ch*.25);ty1=bc[1]+int(ch*.75)
    bigmask=(lab[ty0:ty1+1,x0:x1+1]==big)&fg[ty0:ty1+1,x0:x1+1]
    hist=bigmask.sum(0).astype(float);win=max(8,int(ch*.12))
    cs=np.concatenate([[0],np.cumsum(hist)]);best=-1;bxp=bw//2
    for x in range(bw):
        s=cs[min(bw,x+win+1)]-cs[max(0,x-win)]
        if s>best:best=s;bxp=x
    ax=bxp;ay=bc[3]-y0+1
    if (bc[2]-bc[0])/(bc[3]-bc[1]+1)>2.2:ax=(bc[0]+bc[2])/2-x0
    frames.append(sb);meta.append((ax*sc,ay*sc));names.append(f'{id_//C}_{id_%C}')
AW,pad=1024,2;cx,cy,rowH=pad,pad,0;place=[]
for f in frames:
    if cx+f.width+pad>AW:cx=pad;cy+=rowH+pad;rowH=0
    place.append((cx,cy));cx+=f.width+pad;rowH=max(rowH,f.height)
AH=cy+rowH+pad;atlas=Image.new('RGBA',(AW,AH),(0,0,0,0))
fr={}
for k,f in enumerate(frames):
    atlas.paste(f,place[k]);fr[names[k]]=[place[k][0],place[k][1],f.width,f.height,round(meta[k][0]),round(meta[k][1])]
atlas.save(outPng);js=json.dumps({'h':TH,'f':fr},separators=(',',':'));open(outJson,'w').write(js);print(js)
if len(sys.argv)>7:
    from PIL import ImageDraw
    pv=Image.new('RGBA',(AW,AH),(40,40,48,255));pv.alpha_composite(atlas);d=ImageDraw.Draw(pv)
    for k in range(len(frames)):
        d.text(place[k],names[k],fill='yellow');ax,ay=place[k][0]+int(meta[k][0]),place[k][1]+int(meta[k][1]);d.line([ax-6,ay,ax+6,ay],fill='cyan');d.line([ax,ay-6,ax,ay],fill='cyan')
    pv.convert('RGB').save(sys.argv[7])
