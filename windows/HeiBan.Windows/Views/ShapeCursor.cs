using System.Runtime.InteropServices;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Views;

internal sealed class ShapeCursor : IDisposable
{
    private nint _rotation;
    private int _rotationSize;
    internal nint Current {get;private set;}
    internal void Update(BoardObject? selected,ObjectHandles.Handle? handle,uint dpi=96,int defaultResource=32512)
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
        if(handle is {Kind:"rotate"})
        {
            var size=Math.Clamp((int)Math.Ceiling(GetSystemMetricsForDpi(13,dpi)/8d)*8,32,128);
            if(_rotationSize!=size){SetCursor(LoadCursor(0,new nint(32512)));if(_rotation!=0)DestroyCursor(_rotation);_rotation=CreateRotation(size);_rotationSize=size;}
            Current=_rotation!=0?_rotation:LoadCursor(0,new nint(32646));
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
    private static double Cross(double ax,double ay,double bx,double by,double x,double y)=>(bx-ax)*(y-ay)-(by-ay)*(x-ax);
    public void Dispose()
    {
        SetCursor(LoadCursor(0,new nint(32512)));
        if(_rotation!=0)DestroyCursor(_rotation);_rotation=Current=0;_rotationSize=0;
    }
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern nint LoadCursor(nint instance,nint name);
    [DllImport("user32.dll")] private static extern nint SetCursor(nint cursor);
    [DllImport("user32.dll")] private static extern int GetSystemMetricsForDpi(int index,uint dpi);
    [DllImport("user32.dll")] private static extern nint CreateCursor(nint instance,int x,int y,int width,int height,byte[] and,byte[] xor);
    [DllImport("user32.dll")] private static extern bool DestroyCursor(nint cursor);
}
