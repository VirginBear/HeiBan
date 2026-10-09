using System.ComponentModel;
using System.Runtime.InteropServices;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed class NativeOverlayWindow : IDisposable
{
    public readonly record struct PointerEvent(string Kind,double X,double Y);
    public event Action<PointerEvent>? Pointer;
    public event Action? BoundsChanged;
    public event Action<int>? Hotkey;
    public event Action<Exception>? Failed;
    private readonly WindowProc _procedure;
    private readonly string _className="HeiBan.Screen."+Guid.NewGuid().ToString("N");
    private nint _window,_dc,_bitmap,_oldBitmap,_pixels;
    private readonly nint _instance=GetModuleHandle(null);
    private bool _drawing,_disposed;
    public int Left { get; private set; }
    public int Top { get; private set; }
    public int Width { get; private set; }
    public int Height { get; private set; }
    public nint Handle=>_window;
    public NativeOverlayWindow()
    {
        _procedure=Procedure;
        var wc=new WindowClass {Size=(uint)Marshal.SizeOf<WindowClass>(),Procedure=_procedure,Instance=_instance,ClassName=_className,Cursor=LoadCursor(0,new nint(32515))};
        if(RegisterClassEx(ref wc)==0)throw new Win32Exception(Marshal.GetLastWin32Error());
        _window=CreateWindowEx(0x08000000|0x00080000|0x00000080|0x00000008,_className,"黑板 · 我的螢幕就是我的畫布",0x80000000,0,0,1,1,0,0,_instance,0);
        if(_window==0)throw new Win32Exception(Marshal.GetLastWin32Error());
        ResizeDesktop();
    }
    public bool RegisterShortcut(int id,uint modifiers,uint key)=>RegisterHotKey(_window,id,modifiers|0x4000,key);
    public void Show(bool drawing){SetDrawing(drawing);ShowWindow(_window,4);}
    public void Hide()=>ShowWindow(_window,0);
    public void SetDrawing(bool value)
    {
        _drawing=value;
        var style=GetWindowLongPtr(_window,-20).ToInt64();
        style=value?style&~0x20L:style|0x20L;
        SetWindowLongPtr(_window,-20,new nint(style));
        SetWindowPos(_window,new nint(-1),Left,Top,Width,Height,0x0010|0x0020);
    }
    public void Present(byte[] bytes)
    {
        if(_disposed)return;
        if(bytes.Length!=checked(Width*Height*4))throw new ArgumentException("Overlay pixels do not match desktop dimensions.");
        Marshal.Copy(bytes,0,_pixels,bytes.Length);
        var destination=new Point {X=Left,Y=Top};var size=new Size {Width=Width,Height=Height};var source=new Point();
        var blend=new Blend {Operation=0,Alpha=255,Format=1};
        if(!UpdateLayeredWindow(_window,0,ref destination,ref size,_dc,ref source,0,ref blend,2))throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    private void ResizeDesktop()
    {
        Left=GetSystemMetrics(76);Top=GetSystemMetrics(77);Width=GetSystemMetrics(78);Height=GetSystemMetrics(79);
        if(Width<=0||Height<=0||(long)Width*Height>40_000_000)throw new InvalidOperationException("螢幕尺寸超出可用範圍。");
        ReleasePixels();
        _dc=CreateCompatibleDC(0);
        var info=new BitmapInfo {Size=40,Width=Width,Height=-Height,Planes=1,BitCount=32,ImageSize=checked((uint)(Width*Height*4))};
        _bitmap=CreateDIBSection(_dc,ref info,0,out _pixels,0,0);
        if(_dc==0||_bitmap==0||_pixels==0)throw new Win32Exception(Marshal.GetLastWin32Error());
        _oldBitmap=SelectObject(_dc,_bitmap);
    }
    private nint Procedure(nint hwnd,uint message,nuint wParam,nint lParam)
    {
        try
        {
            if(message==0x0312){Hotkey?.Invoke((int)wParam);return 0;}
            if(message==0x007E){ResizeDesktop();BoundsChanged?.Invoke();return 0;}
            if(message==0x0021)return new nint(3); // Never take the underlying app's keyboard focus.
            if(message==0x0084)return _drawing?new nint(1):new nint(-1);
            if(message==0x0010){Hide();return 0;}
            if(_drawing&&message is 0x0201 or 0x0200 or 0x0202 or 0x0205)
            {
                if(!GetCursorPos(out var p))return 0;
                var kind=message switch {0x0201=>"down",0x0202=>"up",0x0205=>"right",_=>"move"};
                if(message==0x0201)SetCapture(hwnd);
                if(message==0x0202)ReleaseCapture();
                Pointer?.Invoke(new(kind,p.X-Left,p.Y-Top));return 0;
            }
        }
        catch(Exception e){Failed?.Invoke(e);}
        return DefWindowProc(hwnd,message,wParam,lParam);
    }
    private void ReleasePixels()
    {
        if(_oldBitmap!=0){SelectObject(_dc,_oldBitmap);_oldBitmap=0;}
        if(_bitmap!=0){DeleteObject(_bitmap);_bitmap=0;}
        if(_dc!=0){DeleteDC(_dc);_dc=0;}_pixels=0;
    }
    public void Dispose()
    {
        if(_disposed)return;_disposed=true;
        for(var id=1;id<=4;id++)UnregisterHotKey(_window,id);
        if(_window!=0){DestroyWindow(_window);_window=0;}ReleasePixels();UnregisterClass(_className,_instance);GC.KeepAlive(_procedure);
    }
    [UnmanagedFunctionPointer(CallingConvention.Winapi)] private delegate nint WindowProc(nint hwnd,uint message,nuint wParam,nint lParam);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] private struct WindowClass
    {public uint Size,Style;public WindowProc Procedure;public int ClassExtra,WindowExtra;public nint Instance,Icon,Cursor,Background;public string? MenuName;public string ClassName;public nint SmallIcon;}
    [StructLayout(LayoutKind.Sequential)] private struct Point {public int X,Y;}
    [StructLayout(LayoutKind.Sequential)] private struct Size {public int Width,Height;}
    [StructLayout(LayoutKind.Sequential,Pack=1)] private struct Blend {public byte Operation,Flags,Alpha,Format;}
    [StructLayout(LayoutKind.Sequential)] private struct BitmapInfo {public uint Size;public int Width,Height;public ushort Planes,BitCount;public uint Compression,ImageSize;public int XPels,YPels;public uint Used,Important;}
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] private static extern nint GetModuleHandle(string? name);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] private static extern ushort RegisterClassEx(ref WindowClass wc);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern bool UnregisterClass(string name,nint instance);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] private static extern nint CreateWindowEx(uint exStyle,string className,string title,uint style,int x,int y,int width,int height,nint parent,nint menu,nint instance,nint parameter);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(nint hwnd,int command);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(nint hwnd,nint after,int x,int y,int width,int height,uint flags);
    [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] private static extern nint GetWindowLongPtr(nint hwnd,int index);
    [DllImport("user32.dll",EntryPoint="SetWindowLongPtrW")] private static extern nint SetWindowLongPtr(nint hwnd,int index,nint value);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point p);
    [DllImport("user32.dll")] private static extern nint SetCapture(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ReleaseCapture();
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern nint DefWindowProc(nint hwnd,uint message,nuint wParam,nint lParam);
    [DllImport("user32.dll",SetLastError=true)] private static extern bool RegisterHotKey(nint hwnd,int id,uint modifiers,uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(nint hwnd,int id);
    [DllImport("user32.dll",SetLastError=true)] private static extern bool UpdateLayeredWindow(nint hwnd,nint dc,ref Point dst,ref Size size,nint source,ref Point origin,uint key,ref Blend blend,uint flags);
    [DllImport("gdi32.dll")] private static extern nint CreateCompatibleDC(nint dc);
    [DllImport("gdi32.dll",SetLastError=true)] private static extern nint CreateDIBSection(nint dc,ref BitmapInfo info,uint usage,out nint pixels,nint section,uint offset);
    [DllImport("gdi32.dll")] private static extern nint SelectObject(nint dc,nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(nint dc);
}
