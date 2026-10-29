using System.Runtime.InteropServices;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Views;

internal sealed class ShapeCursor : IDisposable
{
    private nint _rotation;
    private int _rotationSize;
    private nint _grab;
    private int _grabSize;
    private readonly ToolCursor _tools=new();
    internal nint Current {get;private set;}
    internal void Update(BoardObject? selected,ObjectHandles.Handle? handle,uint dpi=96,int defaultResource=32512,bool grabbing=false,string? tool=null)
    {
        var resource=defaultResource; // Borrowed shared Windows cursors must never be destroyed.
        if(handle is {Kind:"resize"} resize&&selected is not null)
        {
            // Eight local handle directions rotate with the object, independent of its aspect ratio.
            var degrees=(resize.Index*45+225+selected.Rotation)%180;
            var direction=((int)Math.Round(degrees/45)+4)%4;
            resource=direction switch {0=>32644,1=>32642,2=>32645,_=>32643};
        }
        else if(handle is {Kind:"endpoint" or "vertex" or "arc_start" or "arc_end"})resource=32515;
        if(grabbing)
        {
            var size=Math.Clamp((int)Math.Ceiling(GetSystemMetricsForDpi(13,dpi)/8d)*8,32,128);
            if(_grabSize!=size){SetCursor(LoadCursor(0,new nint(32512)));if(_grab!=0)DestroyCursor(_grab);_grab=CreateGrab(size);_grabSize=size;}
            Current=_grab!=0?_grab:LoadCursor(0,new nint(32649));
        }
        else if(handle is {Kind:"rotate"})
        {
            var size=Math.Clamp((int)Math.Ceiling(GetSystemMetricsForDpi(13,dpi)/8d)*8,32,128);
            if(_rotationSize!=size){SetCursor(LoadCursor(0,new nint(32512)));if(_rotation!=0)DestroyCursor(_rotation);_rotation=CreateRotation(size);_rotationSize=size;}
            Current=_rotation!=0?_rotation:LoadCursor(0,new nint(32646));
        }
        else if(handle is null&&tool is not null&&tool!="select")
        {
            var size=Math.Clamp((int)Math.Ceiling(GetSystemMetricsForDpi(13,dpi)/8d)*8,32,128);
            var cursor=_tools.Get(tool,size);Current=cursor!=0?cursor:LoadCursor(0,new nint(32515));
        }
        else Current=LoadCursor(0,new nint(resource));
        SetCursor(Current);
    }
    internal void Apply(){if(Current!=0)SetCursor(Current);}
    private static nint CreateRotation(int size)
    {
        var and=new byte[size*size/8];Array.Fill(and,(byte)255);var xor=new byte[and.Length];
        for(var y=0;y<size;y++)for(var x=0;x<size;x++)
        {
            var px=(x+.5)*32/size;var py=(y+.5)*32/size;
            var dx=px-15.5;var dy=py-15.5;var angle=(Math.Atan2(dy,dx)*180/Math.PI+360)%360;
            var arc=angle>=40&&angle<=310&&Math.Abs(Math.Sqrt(dx*dx+dy*dy)-10)<2.5;
            var a=Cross(29,13,19,9,px,py);var b=Cross(19,9,26,3,px,py);var c=Cross(26,3,29,13,px,py);
            var triangle=(a>=0&&b>=0&&c>=0)||(a<=0&&b<=0&&c<=0);
            if(!arc&&!triangle)continue;
            var index=(y*size+x)/8;var mask=(byte)(128>>(x%8));and[index]&=(byte)~mask;
            if(arc&&!triangle&&Math.Abs(Math.Sqrt(dx*dx+dy*dy)-10)<.9)xor[index]|=mask;
        }
        // Monochrome AND/XOR masks supply transparency and remain legible on light/dark desktops.
        return CreateCursor(0,size/2,size/2,size,size,and,xor);
    }
    private static nint CreateGrab(int size)
    {
        // Closed palm, four curled fingers and a thumb; a white interior and
        // black outline keep the grabbing cue visible over either board color.
        (double X,double Y)[] outline=[(10,25),(7,21),(4,16),(4,13),(6,12),(9,15),(9,10),(10,8),(12,8),(13,10),(13,7),(15,6),(17,7),(18,10),(18,8),(20,7),(22,8),(23,11),(25,10),(27,12),(27,19),(24,25),(24,28),(11,28)];
        bool Inside(double x,double y)
        {
            var hit=false;
            for(int i=0,j=outline.Length-1;i<outline.Length;j=i++)
            {var a=outline[i];var b=outline[j];if((a.Y>y)!=(b.Y>y)&&x<(b.X-a.X)*(y-a.Y)/(b.Y-a.Y)+a.X)hit=!hit;}
            return hit;
        }
        var and=new byte[size*size/8];Array.Fill(and,(byte)255);var xor=new byte[and.Length];
        for(var y=0;y<size;y++)for(var x=0;x<size;x++)
        {
            var px=(x+.5)*32/size;var py=(y+.5)*32/size;if(!Inside(px,py))continue;
            var index=(y*size+x)/8;var mask=(byte)(128>>(x%8));and[index]&=(byte)~mask;
            var interior=Inside(px-1,py)&&Inside(px+1,py)&&Inside(px,py-1)&&Inside(px,py+1);
            var crease=(Math.Abs(px-13)<.5&&py>11&&py<16)||(Math.Abs(px-18)<.5&&py>11&&py<16)||(Math.Abs(px-23)<.5&&py>12&&py<17);
            if(interior&&!crease)xor[index]|=mask;
        }
        return CreateCursor(0,size/2,size/2,size,size,and,xor);
    }
    private static double Cross(double ax,double ay,double bx,double by,double x,double y)=>(bx-ax)*(y-ay)-(by-ay)*(x-ax);
    public void Dispose()
    {
        SetCursor(LoadCursor(0,new nint(32512)));
        _tools.Dispose();
        if(_rotation!=0)DestroyCursor(_rotation);if(_grab!=0)DestroyCursor(_grab);_rotation=_grab=Current=0;_rotationSize=_grabSize=0;
    }
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern nint LoadCursor(nint instance,nint name);
    [DllImport("user32.dll")] private static extern nint SetCursor(nint cursor);
    [DllImport("user32.dll")] private static extern int GetSystemMetricsForDpi(int index,uint dpi);
    [DllImport("user32.dll")] private static extern nint CreateCursor(nint instance,int x,int y,int width,int height,byte[] and,byte[] xor);
    [DllImport("user32.dll")] private static extern bool DestroyCursor(nint cursor);
}
