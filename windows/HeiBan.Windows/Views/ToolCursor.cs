using System.Runtime.InteropServices;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Svg;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;

/// <summary>Owned native cursors, cached per tool and physical size, outside ink/render loops.</summary>
internal sealed class ToolCursor : IDisposable
{
    private readonly Dictionary<(string Tool,int Size),nint> _cursors=[];
    internal nint Get(string tool,int size)
    {
        if(_cursors.TryGetValue((tool,size),out var cursor))return cursor;
        if(tool=="cane")
        {
            // The held sprite is drawn at the pointer's lower-right grip; hide
            // the duplicate tool badge without changing input coordinates.
            var transparent=new byte[size*size/8];Array.Fill(transparent,(byte)255);
            cursor=CreateCursor(0,0,0,size,size,transparent,new byte[transparent.Length]);
            _cursors[(tool,size)]=cursor;return cursor;
        }
        var path=ToolIcons.CursorPath(tool);
        if(path is null)return 0;
        try
        {
            // A shared software device avoids recreating a D3D device for every new tool
            // or DPI size. Cursor pixels remain independent of document GPU resources.
            // The small cross is the exact input hotspot; the tool badge sits below/right.
            var device=CanvasDevice.GetSharedDevice(true);
            using var surface=new CanvasRenderTarget(device,size,size,96);
            using var svg=CanvasSvgDocument.LoadFromXml(device,
                $"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><g fill='none' stroke-linecap='round' stroke-linejoin='round'><path d='M1,4 L7,4 M4,1 L4,7' stroke='white' stroke-width='3'/><path d='M1,4 L7,4 M4,1 L4,7' stroke='black' stroke-width='1'/><g transform='translate(8 8) scale(.85)'><path d='{path}' stroke='white' stroke-width='3.7'/><path d='{path}' stroke='black' stroke-width='1.7'/></g></g></svg>");
            using(var draw=surface.CreateDrawingSession())
            {draw.Clear(Microsoft.UI.Colors.Transparent);draw.DrawSvg(svg,new Size(size,size));}
            var pixels=surface.GetPixelBytes();
            var and=new byte[size*size/8];Array.Fill(and,(byte)255);var xor=new byte[and.Length];
            for(var y=0;y<size;y++)for(var x=0;x<size;x++)
            {
                var at=(y*size+x)*4;if(pixels[at+3]<96)continue;
                var index=(y*size+x)/8;var mask=(byte)(128>>(x%8));and[index]&=(byte)~mask;
                if(pixels[at]+pixels[at+1]+pixels[at+2]>pixels[at+3]*1.5)xor[index]|=mask;
            }
            cursor=CreateCursor(0,(int)Math.Round(size/8d),(int)Math.Round(size/8d),size,size,and,xor);
        }
        catch(Exception e) when(e is not OutOfMemoryException)
        {
            // Optional cursor art must not disable drawing on a graphics/interop failure.
            // Cache the failure for this size so pointer moves never retry resource creation.
            cursor=0;
        }
        _cursors[(tool,size)]=cursor;return cursor;
    }
    public void Dispose()
    {foreach(var cursor in _cursors.Values)if(cursor!=0)DestroyCursor(cursor);_cursors.Clear();}
    [DllImport("user32.dll")] private static extern nint CreateCursor(nint instance,int x,int y,int width,int height,byte[] and,byte[] xor);
    [DllImport("user32.dll")] private static extern bool DestroyCursor(nint cursor);
}
