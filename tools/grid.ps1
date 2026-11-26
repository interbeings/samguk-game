param([string]$src, [int]$rows, [int]$cols, [int]$targetH, [string]$outPng, [string]$outJson, [string]$preview)
Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'GridSlice').Type) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
public static class GridSlice {
  static bool IsBg(int r,int g,int b){ return r>140 && b>140 && g<130 && (Math.Min(r,b)-g)>60; }
  public static string Run(string path,int R,int C,int targetH,string outPng,string preview){
    var bmp=new Bitmap(path); int W=bmp.Width,H=bmp.Height; int dil=3;
    var src=new Bitmap(W,H,PixelFormat.Format32bppArgb); using(var g0=Graphics.FromImage(src)) g0.DrawImage(bmp,0,0,W,H);
    var d=src.LockBits(new Rectangle(0,0,W,H),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    var px=new int[W*H]; Marshal.Copy(d.Scan0,px,0,W*H); src.UnlockBits(d);
    var fg=new bool[W*H];
    for(int i=0;i<W*H;i++){int c=px[i];int r=(c>>16)&255,g=(c>>8)&255,b=c&255; fg[i]=!IsBg(r,g,b);}
    var m=new bool[W*H];
    for(int y=0;y<H;y++)for(int x=0;x<W;x++){ if(!fg[y*W+x])continue;
      for(int dy=-dil;dy<=dil;dy++)for(int dx=-dil;dx<=dil;dx++){int X=x+dx,Y=y+dy; if(X>=0&&Y>=0&&X<W&&Y<H)m[Y*W+X]=true;}}
    var lab=new int[W*H]; int n=0; var st=new Stack<int>();
    var comps=new List<int[]>(); comps.Add(null); // x0,y0,x1,y1,count
    for(int i=0;i<W*H;i++){ if(!m[i]||lab[i]!=0)continue; n++; int x0=W,y0=H,x1=0,y1=0,cnt=0; st.Push(i); lab[i]=n;
      while(st.Count>0){int p=st.Pop(); int x=p%W,y=p/W; if(fg[p]){cnt++; if(x<x0)x0=x; if(y<y0)y0=y; if(x>x1)x1=x; if(y>y1)y1=y;}
        if(x>0&&m[p-1]&&lab[p-1]==0){lab[p-1]=n;st.Push(p-1);} if(x<W-1&&m[p+1]&&lab[p+1]==0){lab[p+1]=n;st.Push(p+1);}
        if(y>0&&m[p-W]&&lab[p-W]==0){lab[p-W]=n;st.Push(p-W);} if(y<H-1&&m[p+W]&&lab[p+W]==0){lab[p+W]=n;st.Push(p+W);} }
      comps.Add(new int[]{x0,y0,x1,y1,cnt}); }
    // assign components to cells
    var cell=new int[n+1]; var cellBig=new int[R*C]; var cellBox=new int[R*C][];
    for(int pass=0;pass<2;pass++)
    for(int k=1;k<=n;k++){ var c=comps[k]; if(pass==0)cell[k]=-1; if(c[4]<40)continue;
      bool small=c[4]<2500; if((pass==0)==small)continue;
      int w=c[2]-c[0]+1,h=c[3]-c[1]+1;
      // watermark: small sparkle in bottom-right corner
      if(c[0]>W-170 && c[1]>H-170 && w<70 && h<70) continue;
      int cx=(c[0]+c[2])/2, cy=(c[1]+c[3])/2; int id;
      if(!small){ int col=Math.Min(C-1,cx*C/W), row=Math.Min(R-1,cy*R/H); id=row*C+col; }
      else { // attach small bits (sparks, motion marks) to the nearest big figure
        double bd=1e18; id=-1;
        for(int y=Math.Max(0,c[1]-90);y<=Math.Min(H-1,c[3]+90);y+=2)for(int x=Math.Max(0,c[0]-90);x<=Math.Min(W-1,c[2]+90);x+=2){
          int i=y*W+x; if(!fg[i])continue; int q=lab[i]; if(q==k||q==0||cell[q]<0||comps[q][4]<2500)continue;
          double gx=Math.Max(0,Math.Max(c[0]-x,x-c[2])), gy=Math.Max(0,Math.Max(c[1]-y,y-c[3])); double dd=gx*gx+gy*gy;
          if(dd<bd){bd=dd;id=cell[q];} }
        if(id<0||bd>90*90) continue; }
      cell[k]=id;
      if(cellBig[id]==0||comps[cellBig[id]][4]<c[4]) cellBig[id]=k;
      if(cellBox[id]==null) cellBox[id]=new int[]{c[0],c[1],c[2],c[3]}; else { var b=cellBox[id]; b[0]=Math.Min(b[0],c[0]);b[1]=Math.Min(b[1],c[1]);b[2]=Math.Max(b[2],c[2]);b[3]=Math.Max(b[3],c[3]); } }
    // reference height = median-ish of row 0 main components
    var hs=new List<int>(); for(int c=0;c<C;c++){ int k=cellBig[c]; if(k>0) hs.Add(comps[k][3]-comps[k][1]+1); }
    hs.Sort(); double refH = hs.Count>0? hs[hs.Count/2] : 160; double sc = targetH/refH; if(sc>1) sc=1;
    // crop each cell into its own keyed bitmap, then scale
    var frames=new List<Bitmap>(); var meta=new List<double[]>(); var names=new List<string>();
    for(int id=0;id<R*C;id++){ var b=cellBox[id]; if(b==null)continue; int bw=b[2]-b[0]+1,bh=b[3]-b[1]+1;
      var fb=new Bitmap(bw,bh,PixelFormat.Format32bppArgb); var fp=new int[bw*bh];
      int big=cellBig[id]; var bc=comps[big]; long sx=0; int scn=0;
      for(int y=b[1];y<=b[3];y++)for(int x=b[0];x<=b[2];x++){ int i=y*W+x; if(!fg[i]||cell[lab[i]]!=id)continue;
        int c=px[i];int r=(c>>16)&255,g=(c>>8)&255,bl=c&255; int mg=Math.Min(r,bl)-g;
        if(mg>70) continue; if(mg>15){ r=Math.Max(0,r-(mg-15)); bl=Math.Max(0,bl-(mg-15)); }
        int a= mg>50?150:255;
        fp[(y-b[1])*bw+(x-b[0])]=(a<<24)|(r<<16)|(g<<8)|bl;
        if(lab[i]==big && y>bc[3]-14){ sx+=x; scn++; } }
      var fd=fb.LockBits(new Rectangle(0,0,bw,bh),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb); Marshal.Copy(fp,0,fd.Scan0,bw*bh); fb.UnlockBits(fd);
      int nw=Math.Max(1,(int)Math.Round(bw*sc)), nh=Math.Max(1,(int)Math.Round(bh*sc));
      var sb=new Bitmap(nw,nh,PixelFormat.Format32bppArgb);
      using(var g=Graphics.FromImage(sb)){ g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality; g.CompositingMode=CompositingMode.SourceCopy;
        using(var ia=new ImageAttributes()){ ia.SetWrapMode(WrapMode.TileFlipXY); g.DrawImage(fb,new Rectangle(0,0,nw,nh),0,0,bw,bh,GraphicsUnit.Pixel,ia);} }
      // anchor: densest torso column of the main component (weapons are thin, the body is thick)
      var hist=new double[bw]; int ch=bc[3]-bc[1]+1; int ty0=bc[1]+(int)(ch*0.25), ty1=bc[1]+(int)(ch*0.75);
      for(int y=ty0;y<=ty1;y++)for(int x=b[0];x<=b[2];x++){ int i=y*W+x; if(fg[i]&&lab[i]==big) hist[x-b[0]]++; }
      int win=Math.Max(8,(int)(ch*0.12)); double best=-1; int bx=bw/2;
      for(int x=0;x<bw;x++){ double s=0; for(int k=Math.Max(0,x-win);k<=Math.Min(bw-1,x+win);k++) s+=hist[k]; if(s>best){best=s;bx=x;} }
      double ax = bx; double ay = bc[3]-b[1]+1;
      if((double)(bc[2]-bc[0])/(bc[3]-bc[1]+1)>2.2) ax=(bc[0]+bc[2])/2.0-b[0];
      frames.Add(sb); meta.Add(new double[]{ax*sc, ay*sc}); names.Add((id/C)+"_"+(id%C)); fb.Dispose(); }
    int AW=1024,pad=2,cx2=pad,cy2=pad,rowH=0; var place=new List<int[]>();
    foreach(var f in frames){ if(cx2+f.Width+pad>AW){cx2=pad;cy2+=rowH+pad;rowH=0;} place.Add(new int[]{cx2,cy2}); cx2+=f.Width+pad; rowH=Math.Max(rowH,f.Height); }
    int AH=cy2+rowH+pad; var atlas=new Bitmap(AW,AH,PixelFormat.Format32bppArgb);
    var js=new StringBuilder("{\"h\":"+targetH+",\"f\":{");
    using(var g=Graphics.FromImage(atlas)){ g.CompositingMode=CompositingMode.SourceCopy;
      for(int k=0;k<frames.Count;k++){ g.DrawImageUnscaled(frames[k],place[k][0],place[k][1]);
        js.AppendFormat("{0}\"{1}\":[{2},{3},{4},{5},{6},{7}]",k>0?",":"",names[k],place[k][0],place[k][1],frames[k].Width,frames[k].Height,(int)Math.Round(meta[k][0]),(int)Math.Round(meta[k][1])); } }
    js.Append("}}"); atlas.Save(outPng,ImageFormat.Png);
    if(!string.IsNullOrEmpty(preview)){ var pv=new Bitmap(AW,AH); using(var g=Graphics.FromImage(pv)){ g.Clear(Color.FromArgb(40,40,48)); g.DrawImage(atlas,0,0);
        var font=new Font("Arial",9); for(int k=0;k<frames.Count;k++){ g.DrawString(names[k],font,Brushes.Yellow,place[k][0],place[k][1]);
          int ax=place[k][0]+(int)meta[k][0], ay=place[k][1]+(int)meta[k][1]; g.DrawLine(Pens.Cyan,ax-6,ay,ax+6,ay); g.DrawLine(Pens.Cyan,ax,ay-6,ax,ay); } }
      pv.Save(preview,ImageFormat.Png); }
    return js.ToString(); }
}
"@
}
$json = [GridSlice]::Run($src, $rows, $cols, $targetH, $outPng, $preview)
[IO.File]::WriteAllText($outJson, $json)
$json
