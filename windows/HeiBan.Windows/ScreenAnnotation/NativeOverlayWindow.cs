using System.ComponentModel;
using System.Runtime.InteropServices;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class NativeOverlayWindow : IDisposable
{
    public readonly record struct PointerEvent(string Kind,double X,double Y,bool Shift=false,bool LeftDown=false);
    public event Action<PointerEvent>? Pointer;
    public event Action? BoundsChanged;
    public event Action<int>? Hotkey;
    public event Action<Exception>? Failed;
    private readonly WindowProc _procedure;
    private readonly string _className="HeiBan.Screen."+Guid.NewGuid().ToString("N");
    private nint _window,_dc,_bitmap,_oldBitmap,_pixels;
    private readonly nint _instance=GetModuleHandle(null);
    private readonly HeiBan.Windows.Views.ShapeCursor _shapeCursor=new();
    private string _cursorTool="pen";
    internal void SetManipulationCursor(HeiBan.Windows.Models.BoardObject? selected,HeiBan.Windows.Engine.ObjectHandles.Handle? handle,string tool)
    {_cursorTool=tool;_shapeCursor.Update(selected,handle,(uint)Math.Round(DpiScale(_window)*96),tool:tool);}
    private bool _drawing,_disposed,_pointerCaptured;
    public int Left { get; private set; }
    public int Top { get; private set; }
    public int Width { get; private set; }
    public int Height { get; private set; }
    public nint Handle=>_window;
    public static double DpiScale(nint window)=>Math.Max(1,GetDpiForWindow(window)/96d);
    public static nint CurrentForeground=>GetForegroundWindow();
    public static bool MouseButtonDown=>(GetAsyncKeyState(1)&0x8000)!=0;
    public static (int X,int Y) CurrentPointer {get{GetCursorPos(out var p);return(p.X,p.Y);}}
    public static void RestoreFocus(nint window){if(window!=0&&IsWindowVisible(window))SetForegroundWindow(window);}
    public static void ResizeCompactWindow(nint window,int width,int height)
    {
        // AppWindow.Resize applies the caption's tracking minimum even to this borderless tool window.
        // Keep normal WM_SIZE/layout notifications, bypass only WM_WINDOWPOSCHANGING's caption constraint.
        if(!SetWindowPos(window,0,0,0,width,height,0x0002|0x0004|0x0010|0x0400))throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public NativeOverlayWindow()
    {
        _procedure=Procedure;
        var wc=new WindowClass {Size=(uint)Marshal.SizeOf<WindowClass>(),Style=8,Procedure=_procedure,Instance=_instance,ClassName=_className,Cursor=LoadCursor(0,new nint(32515))};
        if(RegisterClassEx(ref wc)==0)throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            _window=CreateWindowEx(0x08000000|0x00080000|0x00000080|0x00000008,_className,"黑板 · 我的螢幕就是我的畫布",0x80000000,0,0,1,1,0,0,_instance,0);
            if(_window==0)throw new Win32Exception(Marshal.GetLastWin32Error());
            ResizeDesktop();
        }
        catch{Dispose();throw;}
    }
    public bool RegisterShortcut(int id,uint modifiers,uint key)=>RegisterHotKey(_window,id,modifiers|0x4000,key);
    public void Show(bool drawing){SetDrawing(drawing);ShowWindow(_window,4);}
    public void Hide(){CancelPointerCapture();ShowWindow(_window,0);ReleaseReadback();}
    public void SetDrawing(bool value)
    {
        _drawing=value;
        if(!value)CancelPointerCapture();
        var style=GetWindowLongPtr(_window,-20).ToInt64();
        style=value?style&~0x20L:style|0x20L;
        SetWindowLongPtr(_window,-20,new nint(style));
        // Keep the control window above this input surface when changing hit testing.
        // Raising the overlay again would leave visible controls underneath its alpha-1 input pixels.
        SetWindowPos(_window,new nint(-1),Left,Top,Width,Height,0x0004|0x0010|0x0020);
    }
    public bool IsBelow(nint upperWindow)
    {var next=GetWindow(upperWindow,2);for(var i=0;next!=0&&i<512;i++,next=GetWindow(next,2))if(next==_window)return true;return false;}
    public void Present(byte[] bytes)=>Present(bytes,0,0,Width,Height);
    public unsafe void Present(byte[] bytes,int x,int y,int width,int height)
    {
        if(_disposed)return;
        if(x<0||y<0||width<=0||height<=0||x+width>Width||y+height>Height||bytes.Length!=checked(width*height*4))throw new ArgumentException("Overlay region does not match pixel dimensions.");
        fixed(byte* sourcePixels=bytes)
            CopyAndPresent(sourcePixels,x,y,width,height);
    }
    private unsafe void CopyAndPresent(byte* sourcePixels,int x,int y,int width,int height)
    {
        for(var row=0;row<height;row++)Buffer.MemoryCopy(sourcePixels+row*width*4,(byte*)_pixels+((y+row)*Width+x)*4,width*4,width*4);
        var destination=new Point {X=Left,Y=Top};var size=new Size {Width=Width,Height=Height};var source=new Point();
        var blend=new Blend {Operation=0,Alpha=255,Format=1};var dirty=new Rectangle{Left=x,Top=y,Right=x+width,Bottom=y+height};
        var info=new LayeredWindowInfo{Size=(uint)Marshal.SizeOf<LayeredWindowInfo>(),Destination=(nint)(&destination),Dimensions=(nint)(&size),SourceDc=_dc,Source=(nint)(&source),Blend=(nint)(&blend),Flags=2,Dirty=(nint)(&dirty)};
        if(!UpdateLayeredWindowIndirect(_window,ref info))throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    internal byte[] ReadPresentedPixels()
    {var result=new byte[checked(Width*Height*4)];Marshal.Copy(_pixels,result,0,result.Length);return result;}
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
    private bool _trackingMouse;
    [StructLayout(LayoutKind.Sequential)] private struct MouseTracking{public uint Size,Flags;public nint Window;public uint HoverTime;}
    [DllImport("user32.dll")] private static extern bool TrackMouseEvent(ref MouseTracking tracking);
    private nint Procedure(nint hwnd,uint message,nuint wParam,nint lParam)
    {
        try
        {
            if(message==0x0020&&_drawing&&_shapeCursor.Current!=0){_shapeCursor.Apply();return 1;}
            if(message==0x02A3){_trackingMouse=false;if(!_pointerCaptured)Pointer?.Invoke(new("leave",0,0));return 0;}
            if(message==0x0200&&!_trackingMouse){var tracking=new MouseTracking{Size=(uint)Marshal.SizeOf<MouseTracking>(),Flags=2,Window=hwnd};_trackingMouse=TrackMouseEvent(ref tracking);}
            if(message==0x0312){Hotkey?.Invoke((int)wParam);return 0;}
            if(message==0x007E){ResizeDesktop();BoundsChanged?.Invoke();return 0;}
            if(message==0x0021)return new nint(3); // Never take the underlying app's keyboard focus.
            if(message==0x0084)return _drawing?new nint(1):new nint(-1);
            if(message==0x0010){Hide();return 0;}
            if((message is 0x0215 or 0x001F)&&_pointerCaptured){_pointerCaptured=false;Pointer?.Invoke(new("cancel",0,0));}
            if(_drawing&&message is 0x0201 or 0x0200 or 0x0202 or 0x0205 or 0x0203)
            {
                // Message coordinates belong to this sample; querying the current cursor can skip queued movement.
                var coordinates=lParam.ToInt64();var p=new Point{X=(short)(coordinates&0xffff),Y=(short)((coordinates>>16)&0xffff)};
                var kind=message switch {0x0201=>"down",0x0202=>"up",0x0205=>"right",0x0203=>"double",_=>"move"};
                if(message==0x0201||(message==0x0203&&_cursorTool is "laser" or "cane")){_pointerCaptured=true;SetCapture(hwnd);}
                if(message==0x0202){_pointerCaptured=false;ReleaseCapture();}
                Pointer?.Invoke(new(kind,p.X,p.Y,(wParam&4)!=0,(wParam&1)!=0));return 0;
            }
        }
        catch(Exception e){Failed?.Invoke(e);}
        return DefWindowProc(hwnd,message,wParam,lParam);
    }
    private void ReleasePixels()
    {
        ReleaseReadback();
        if(_oldBitmap!=0){SelectObject(_dc,_oldBitmap);_oldBitmap=0;}
        if(_bitmap!=0){DeleteObject(_bitmap);_bitmap=0;}
        if(_dc!=0){DeleteDC(_dc);_dc=0;}_pixels=0;
    }
    private void CancelPointerCapture()
    {if(!_pointerCaptured)return;_pointerCaptured=false;ReleaseCapture();Pointer?.Invoke(new("cancel",0,0));}
    public void Dispose()
    {
        if(_disposed)return;_disposed=true;_shapeCursor.Dispose();
        for(var id=1;id<=5;id++)UnregisterHotKey(_window,id);
        if(_window!=0){DestroyWindow(_window);_window=0;}ReleasePixels();UnregisterClass(_className,_instance);GC.KeepAlive(_procedure);
    }
    [UnmanagedFunctionPointer(CallingConvention.Winapi)] private delegate nint WindowProc(nint hwnd,uint message,nuint wParam,nint lParam);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] private struct WindowClass
    {public uint Size,Style;public WindowProc Procedure;public int ClassExtra,WindowExtra;public nint Instance,Icon,Cursor,Background;public string? MenuName;public string ClassName;public nint SmallIcon;}
    [StructLayout(LayoutKind.Sequential)] private struct Point {public int X,Y;}
    [StructLayout(LayoutKind.Sequential)] private struct Rectangle {public int Left,Top,Right,Bottom;}
    [StructLayout(LayoutKind.Sequential)] private struct LayeredWindowInfo
    {public uint Size;public nint DestinationDc,Destination,Dimensions,SourceDc,Source;public uint ColorKey;public nint Blend;public uint Flags;public nint Dirty;}
    [StructLayout(LayoutKind.Sequential)] private struct Size {public int Width,Height;}
    [StructLayout(LayoutKind.Sequential,Pack=1)] private struct Blend {public byte Operation,Flags,Alpha,Format;}
    [StructLayout(LayoutKind.Sequential)] private struct BitmapInfo {public uint Size;public int Width,Height;public ushort Planes,BitCount;public uint Compression,ImageSize;public int XPels,YPels;public uint Used,Important;}
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] private static extern nint GetModuleHandle(string? name);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] private static extern ushort RegisterClassEx(ref WindowClass wc);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern bool UnregisterClass(string name,nint instance);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] private static extern nint CreateWindowEx(uint exStyle,string className,string title,uint style,int x,int y,int width,int height,nint parent,nint menu,nint instance,nint parameter);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern nint LoadCursor(nint instance,nint name);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] private static extern uint GetDpiForWindow(nint window);
    [DllImport("user32.dll")] private static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] private static extern nint GetWindow(nint window,uint command);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(nint window);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint window);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(nint hwnd,int command);
    [DllImport("user32.dll",SetLastError=true)] private static extern bool SetWindowPos(nint hwnd,nint after,int x,int y,int width,int height,uint flags);
    [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] private static extern nint GetWindowLongPtr(nint hwnd,int index);
    [DllImport("user32.dll",EntryPoint="SetWindowLongPtrW")] private static extern nint SetWindowLongPtr(nint hwnd,int index,nint value);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point p);
    [DllImport("user32.dll")] private static extern nint SetCapture(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ReleaseCapture();
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern nint DefWindowProc(nint hwnd,uint message,nuint wParam,nint lParam);
    [DllImport("user32.dll",SetLastError=true)] private static extern bool RegisterHotKey(nint hwnd,int id,uint modifiers,uint key);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(nint hwnd,int id);
    [DllImport("user32.dll",SetLastError=true)] private static extern bool UpdateLayeredWindowIndirect(nint hwnd,ref LayeredWindowInfo info);
    [DllImport("gdi32.dll")] private static extern nint CreateCompatibleDC(nint dc);
    [DllImport("gdi32.dll",SetLastError=true)] private static extern nint CreateDIBSection(nint dc,ref BitmapInfo info,uint usage,out nint pixels,nint section,uint offset);
    [DllImport("gdi32.dll")] private static extern nint SelectObject(nint dc,nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(nint dc);
}
