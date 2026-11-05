using System.Runtime.InteropServices;
using System.Globalization;
using System.Xml.Linq;
using HeiBan.Windows.Engine;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Svg;
using global::Windows.Foundation;

namespace HeiBan.Windows.Views;

/// <summary>Owned alpha cursors; bounded cache, no document or input-coordinate changes.</summary>
internal sealed class ToolCursor : IDisposable
{
    private readonly Dictionary<(string Tool,int Size,string Style),(string? Color,nint Handle)> _cursors=[];
    internal nint Get(string tool,int size,string? color=null)
    {
        var style=ToolIcons.Style;var key=(tool,size,style);
        var paint=tool is "pen" or "highlighter" or "laser"?color:null;
        if(_cursors.TryGetValue(key,out var old)&&old.Color==paint)return old.Handle;
        nint cursor=0;
        try
        {
            if(tool=="cane")
            {
                // The held sprite already follows its lower-right grip.
                var and=new byte[((size+15)/16)*2*size];Array.Fill(and,(byte)255);
                cursor=CreateCursor(0,0,0,size,size,and,new byte[and.Length]);
            }
            else if(ToolIcons.CursorPath(tool) is not null)
            {
                var layout=ToolCursorGeometry.Layout(tool,style=="duotone",size);
                var badge=ToolCursorGeometry.UsesCrosshairBadge(tool);
                var root=XElement.Parse(badge?CrosshairBadgeSvg(tool):ToolIcons.RadialSvg(tool,false,paint));
                if(!badge&&tool=="laser")
                {
                    // Hover cue only. The actual laser trail still requires the left button.
                    root.RemoveNodes();var ns=root.Name.Namespace;
                    var c=Direct2DCanvasRenderer.HexToColor(paint??"#EF4444");
                    root.Add(new XElement(ns+"circle",new XAttribute("cx",13),new XAttribute("cy",13),new XAttribute("r",3.2),new XAttribute("fill",$"#{c.R:X2}{c.G:X2}{c.B:X2}"),new XAttribute("stroke","white"),new XAttribute("stroke-width",1)));
                    root.Add(new XElement(ns+"circle",new XAttribute("cx",13),new XAttribute("cy",13),new XAttribute("r",.8),new XAttribute("fill","white")));
                }
                else if(!badge)
                {
                    var originals=root.Elements().ToArray();
                    // A narrow white halo keeps fine strokes legible on dark backgrounds.
                    foreach(var node in originals)
                    {
                        var halo=new XElement(node);halo.SetAttributeValue("fill","none");halo.SetAttributeValue("stroke","white");
                        var width=double.TryParse(node.Attribute("stroke-width")?.Value,NumberStyles.Float,CultureInfo.InvariantCulture,out var w)?w:1.6;
                        halo.SetAttributeValue("stroke-width",(width+1.4).ToString(CultureInfo.InvariantCulture));
                        root.AddFirst(halo);
                    }
                }
                var device=CanvasDevice.GetSharedDevice(true);
                using var surface=new CanvasRenderTarget(device,size,size,96);
                using var svg=CanvasSvgDocument.LoadFromXml(device,root.ToString(SaveOptions.DisableFormatting));
                using(var draw=surface.CreateDrawingSession())
                {
                    draw.Clear(Microsoft.UI.Colors.Transparent);
                    if(badge)draw.DrawSvg(svg,new Size(size,size));
                    else draw.DrawSvg(svg,new Size(size*.82,size*.82),new System.Numerics.Vector2((float)layout.Offset,(float)layout.Offset));
                }
                cursor=CreateAlpha(surface.GetPixelBytes(),size,layout.X,layout.Y);
            }
        }
        catch(Exception e) when(e is not OutOfMemoryException)
        {Diagnostics.CanvasSurfaceDiagnostics.Record("tool-cursor",e);}
        // Create first: replacing the active handle after destruction can recycle its value.
        if(old.Handle!=0){if(GetCursor()==old.Handle)SetCursor(cursor!=0?cursor:LoadCursor(0,new nint(32512)));DestroyCursor(old.Handle);}
        if(!_cursors.ContainsKey(key)&&_cursors.Count>=64)
        {
            var victim=_cursors.FirstOrDefault(p=>p.Value.Handle!=GetCursor());
            if(victim.Key.Tool is not null){if(victim.Value.Handle!=0)DestroyCursor(victim.Value.Handle);_cursors.Remove(victim.Key);}
        }
        _cursors[key]=(paint,cursor);return cursor;
    }
    private static string CrosshairBadgeSvg(string tool)
    {
        var path=ToolIcons.CursorPath(tool);
        return $"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><g fill='none' stroke-linecap='round' stroke-linejoin='round'><path d='M1,4 L7,4 M4,1 L4,7' stroke='white' stroke-width='3'/><path d='M1,4 L7,4 M4,1 L4,7' stroke='black' stroke-width='1'/><g transform='translate(8 8) scale(.85)'><path d='{path}' stroke='white' stroke-width='3.7'/><path d='{path}' stroke='black' stroke-width='1.7'/></g></g></svg>";
    }
    private static nint CreateAlpha(byte[] pixels,int size,int x,int y)
    {
        var header=new BitmapHeader{Size=40,Width=size,Height=-size,Planes=1,Bits=32};
        nint bitmap=0,mask=0;
        try
        {
            bitmap=CreateDIBSection(0,ref header,0,out var bits,0,0);
            if(bitmap==0||bits==0)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            Marshal.Copy(pixels,0,bits,pixels.Length);mask=CreateBitmap(size,size,1,1,new byte[((size+15)/16)*2*size]);
            if(mask==0)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            var info=new IconInfo{X=(uint)x,Y=(uint)y,Mask=mask,Color=bitmap};
            var cursor=CreateIconIndirect(ref info);
            if(cursor==0)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return cursor;
        }
        // CreateIconIndirect copies the bitmaps; only the returned cursor survives this method.
        finally{if(bitmap!=0)DeleteObject(bitmap);if(mask!=0)DeleteObject(mask);}
    }
    public void Dispose()
    {foreach(var cursor in _cursors.Values)if(cursor.Handle!=0){if(GetCursor()==cursor.Handle)SetCursor(LoadCursor(0,new nint(32512)));DestroyCursor(cursor.Handle);}_cursors.Clear();}
#if HEIBAN_RELEASE_VALIDATION
    internal (uint X,uint Y,byte[] Pixels,int Cached) ReadValidation(string tool,int size,string color)
    {
        var cursor=Get(tool,size,color);
        if(cursor==0||!GetIconInfo(cursor,out var info))throw new Exception("Native cursor unavailable: "+tool);
        try
        {
            var pixels=new byte[size*size*4];var header=new BitmapHeader{Size=40,Width=size,Height=-size,Planes=1,Bits=32};
            var dc=GetDC(0);
            try{if(GetDIBits(dc,info.Color,0,(uint)size,pixels,ref header,0)==0)throw new Exception("Cursor bitmap unavailable");}
            finally{if(dc!=0)ReleaseDC(0,dc);}
            return (info.X,info.Y,pixels,_cursors.Count);
        }
        finally{if(info.Mask!=0)DeleteObject(info.Mask);if(info.Color!=0)DeleteObject(info.Color);}
    }
    [DllImport("user32.dll")] private static extern bool GetIconInfo(nint cursor,out IconInfo info);
    [DllImport("gdi32.dll")] private static extern int GetDIBits(nint dc,nint bitmap,uint start,uint count,byte[] pixels,ref BitmapHeader info,uint usage);
    [DllImport("user32.dll")] private static extern nint GetDC(nint window);
    [DllImport("user32.dll")] private static extern int ReleaseDC(nint window,nint dc);
#endif
    [StructLayout(LayoutKind.Sequential)] private struct IconInfo {public int Icon;public uint X,Y;public nint Mask,Color;}
    [StructLayout(LayoutKind.Sequential)] private struct BitmapHeader {public uint Size;public int Width,Height;public ushort Planes,Bits;public uint Compression,ImageSize;public int XPels,YPels;public uint Used,Important;}
    [DllImport("user32.dll")] private static extern nint CreateCursor(nint instance,int x,int y,int width,int height,byte[] and,byte[] xor);
    [DllImport("user32.dll",SetLastError=true)] private static extern nint CreateIconIndirect(ref IconInfo info);
    [DllImport("gdi32.dll",SetLastError=true)] private static extern nint CreateDIBSection(nint dc,ref BitmapHeader info,uint usage,out nint bits,nint section,uint offset);
    [DllImport("gdi32.dll",SetLastError=true)] private static extern nint CreateBitmap(int width,int height,uint planes,uint bits,byte[] pixels);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(nint bitmap);
    [DllImport("user32.dll")] private static extern nint GetCursor();
    [DllImport("user32.dll")] private static extern nint SetCursor(nint cursor);
    [DllImport("user32.dll")] private static extern nint LoadCursor(nint instance,nint name);
    [DllImport("user32.dll")] private static extern bool DestroyCursor(nint cursor);
}
