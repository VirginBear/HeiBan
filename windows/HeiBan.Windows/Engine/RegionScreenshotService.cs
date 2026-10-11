using System.ComponentModel;
using System.Runtime.InteropServices;

namespace HeiBan.Windows.Engine;

/// <summary>
/// Owns one desktop snapshot and region-selection window. Returned BMP bytes belong
/// to this invocation; no clipboard watching or user screenshot-folder writes occur.
/// Win32/GDI stays on its worker thread, while the WinUI dispatcher remains responsive.
/// </summary>
public static class RegionScreenshotService
{
    public sealed record CapturedRegion(byte[] Bytes,int Left,int Top,int Width,int Height);
    public static async Task<byte[]?> CaptureAsync(CancellationToken cancellationToken)=>(await CaptureRegionAsync(cancellationToken))?.Bytes;
    public static Task<CapturedRegion?> CaptureRegionAsync(CancellationToken cancellationToken)=>Task.Run(()=>SelectRegion(cancellationToken),cancellationToken);

    private static CapturedRegion? SelectRegion(CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        var oldDpi = SetThreadDpiAwarenessContext(new nint(-4));
        nint screen = 0, snapshotDc = 0, snapshot = 0, previous = 0, window = 0;
        nint dimDc=0,dimBitmap=0,dimPrevious=0;
        var instance = GetModuleHandle(null);
        var className = "HeiBan.Region." + Guid.NewGuid().ToString("N");
        ushort registered = 0;
        Exception? failure = null;
        CapturedRegion? result = null;
        bool dragging = false, completed = false;
        Point start = default, current = default;
        var originX = GetSystemMetrics(76); var originY = GetSystemMetrics(77);
        var width = GetSystemMetrics(78); var height = GetSystemMetrics(79);

        Rect Selection() => new()
        {
            Left = Math.Clamp(Math.Min(start.X, current.X), 0, width),
            Top = Math.Clamp(Math.Min(start.Y, current.Y), 0, height),
            Right = Math.Clamp(Math.Max(start.X, current.X), 0, width),
            Bottom = Math.Clamp(Math.Max(start.Y, current.Y), 0, height)
        };
        Point Cursor()
        {
            if (!GetCursorPos(out var p)) throw new Win32Exception();
            return new Point { X = p.X - originX, Y = p.Y - originY };
        }

        WindowProc callback = (hwnd, message, wParam, lParam) =>
        {
            try
            {
                switch (message)
                {
                    case 0x000F: // WM_PAINT
                        var dc = BeginPaint(hwnd, out var paint);
                        try
                        {
                            // Compose the fog once; pointer events only copy the cached image and reveal the crop.
                            BitBlt(dc, 0, 0, width, height, dimDc, 0, 0, 0x00CC0020);
                            if(dragging){var selected=Selection();BitBlt(dc,selected.Left,selected.Top,selected.Right-selected.Left,selected.Bottom-selected.Top,snapshotDc,selected.Left,selected.Top,0x00CC0020);}
                            SetBkMode(dc, 1);
                            SetTextColor(dc, 0x00FFFFFF);
                            var help = Localization.Strings.T("拖曳框選截圖 · Esc 或右鍵取消");
                            // Measure translated guidance and wrap within the desktop; selection coordinates stay unchanged.
                            var flags = 0x10u | (Localization.Strings.RightToLeft ? 0x20000u : 0u); // DT_WORDBREAK / DT_RTLREADING
                            var textRect = new Rect { Left = 28, Top = 26, Right = Math.Max(29, width - 28), Bottom = height - 26 };
                            DrawText(dc, help, help.Length, ref textRect, flags | 0x400); // DT_CALCRECT
                            textRect.Right = Math.Min(textRect.Right, Math.Max(29, width - 28));
                            var banner = new Rect { Left = 16, Top = 16, Right = textRect.Right + 12, Bottom = textRect.Bottom + 10 };
                            FillRect(dc, ref banner, GetStockObject(4));
                            DrawText(dc, help, help.Length, ref textRect, flags);
                            if (dragging)
                            {
                                var rect = Selection();
                                var pen = CreatePen(0, 3, 0x00C47639);
                                var oldPen = SelectObject(dc, pen);
                                var oldBrush = SelectObject(dc, GetStockObject(5)); // hollow brush
                                try { Rectangle(dc, rect.Left, rect.Top, rect.Right, rect.Bottom); }
                                finally { SelectObject(dc, oldBrush); SelectObject(dc, oldPen); DeleteObject(pen); }
                            }
                        }
                        finally { EndPaint(hwnd, ref paint); }
                        return 0;
                    case 0x0201: // WM_LBUTTONDOWN
                        start = current = Cursor(); dragging = true; SetCapture(hwnd);
                        InvalidateRect(hwnd, 0, false); return 0;
                    case 0x0200: // WM_MOUSEMOVE
                        if (dragging) { current = Cursor(); InvalidateRect(hwnd, 0, false); }
                        return 0;
                    case 0x0202: // WM_LBUTTONUP
                        if (dragging)
                        {
                            current = Cursor(); dragging = false; ReleaseCapture();
                            var rect = Selection();
                            if (rect.Right - rect.Left >= 2 && rect.Bottom - rect.Top >= 2)
                            {
                                // Crop the pre-overlay snapshot, never the selection UI itself.
                                result = new CapturedRegion(EncodeBmp(snapshotDc, rect),originX+rect.Left,originY+rect.Top,rect.Right-rect.Left,rect.Bottom-rect.Top);
                            }
                            completed = true; DestroyWindow(hwnd);
                        }
                        return 0;
                    case 0x0204: // right click
                    case 0x0010: // close/cancellation
                        completed = true; DestroyWindow(hwnd); return 0;
                    case 0x0100: // WM_KEYDOWN
                        if (wParam == 27) { completed = true; DestroyWindow(hwnd); }
                        return 0;
                    case 0x0002: // WM_DESTROY
                        completed = true; return 0;
                }
            }
            catch (Exception ex)
            {
                failure = ex; completed = true; DestroyWindow(hwnd);
                return 0; // Never unwind a managed exception through the native callback.
            }
            return DefWindowProc(hwnd, message, wParam, lParam);
        };

        try
        {
            if (width <= 0 || height <= 0) throw new InvalidOperationException("沒有可擷取的桌面。");
            DwmFlush();
            screen = GetDC(0);
            snapshotDc = CreateCompatibleDC(screen);
            snapshot = CreateCompatibleBitmap(screen, width, height);
            if (screen == 0 || snapshotDc == 0 || snapshot == 0) throw new Win32Exception();
            previous = SelectObject(snapshotDc, snapshot);
            if (!BitBlt(snapshotDc, 0, 0, width, height, screen, originX, originY, 0x40CC0020))
                throw new Win32Exception();
            dimDc=CreateCompatibleDC(screen);dimBitmap=CreateCompatibleBitmap(screen,width,height);
            if(dimDc==0||dimBitmap==0)throw new Win32Exception();
            dimPrevious=SelectObject(dimDc,dimBitmap);BitBlt(dimDc,0,0,width,height,snapshotDc,0,0,0x00CC0020);
            ApplyFog(screen,dimDc,width,height);
            var wc = new WindowClass
            {
                Size = (uint)Marshal.SizeOf<WindowClass>(), Procedure = callback,
                Instance = instance, ClassName = className, Cursor = LoadCursor(0, new nint(32515))
            };
            registered = RegisterClassEx(ref wc);
            if (registered == 0) throw new Win32Exception();
            window = CreateWindowEx(0x00000008 | 0x00000080, className,
                "黑板 · 區域截圖", 0x80000000, originX, originY, width, height, 0, 0, instance, 0);
            if (window == 0) throw new Win32Exception();
            using var cancellation = token.Register(() => PostMessage(window, 0x0010, 0, 0));
            ShowWindow(window, 5); SetForegroundWindow(window); UpdateWindow(window);
            while (!completed)
            {
                var status = GetMessage(out var message, 0, 0, 0);
                if (status == -1) throw new Win32Exception();
                if (status == 0) break;
                TranslateMessage(ref message); DispatchMessage(ref message);
            }
            token.ThrowIfCancellationRequested();
            if (failure is not null) throw failure;
            return result;
        }
        finally
        {
            if (window != 0 && IsWindow(window)) DestroyWindow(window);
            if (registered != 0) UnregisterClass(className, instance);
            if (previous != 0) SelectObject(snapshotDc, previous);
            if (snapshot != 0) DeleteObject(snapshot);
            if (snapshotDc != 0) DeleteDC(snapshotDc);
            if(dimPrevious!=0)SelectObject(dimDc,dimPrevious);
            if(dimBitmap!=0)DeleteObject(dimBitmap);if(dimDc!=0)DeleteDC(dimDc);
            if (screen != 0) ReleaseDC(0, screen);
            if (oldDpi != 0) SetThreadDpiAwarenessContext(oldDpi);
            GC.KeepAlive(callback);
        }
    }

    private static void ApplyFog(nint reference,nint target,int width,int height)
    {
            var fogDc=CreateCompatibleDC(reference);var fogBitmap=CreateCompatibleBitmap(reference,1,1);var fogBrush=CreateSolidBrush(0x00909090);nint fogPrevious=0;
            try
            {
                if(fogDc==0||fogBitmap==0||fogBrush==0)throw new Win32Exception();
                fogPrevious=SelectObject(fogDc,fogBitmap);var pixel=new Rect{Right=1,Bottom=1};FillRect(fogDc,ref pixel,fogBrush);
                if(!AlphaBlend(target,0,0,width,height,fogDc,0,0,1,1,new Blend{Alpha=140}))throw new Win32Exception();
            }
            finally
            {
                if(fogPrevious!=0)SelectObject(fogDc,fogPrevious);
                if(fogBrush!=0)DeleteObject(fogBrush);if(fogBitmap!=0)DeleteObject(fogBitmap);if(fogDc!=0)DeleteDC(fogDc);
            }
    }

    internal static object ValidateMask(string outputDirectory)
    {
        nint screen=GetDC(0),original=0,dim=0,originalBitmap=0,dimBitmap=0,originalOld=0,dimOld=0,brush=0;
        try
        {
            original=CreateCompatibleDC(screen);dim=CreateCompatibleDC(screen);originalBitmap=CreateCompatibleBitmap(screen,24,24);dimBitmap=CreateCompatibleBitmap(screen,24,24);brush=CreateSolidBrush(0x00C05020);
            if(screen==0||original==0||dim==0||originalBitmap==0||dimBitmap==0||brush==0)throw new Win32Exception();
            originalOld=SelectObject(original,originalBitmap);dimOld=SelectObject(dim,dimBitmap);var frame=new Rect{Right=24,Bottom=24};FillRect(original,ref frame,brush);
            BitBlt(dim,0,0,24,24,original,0,0,0x00CC0020);ApplyFog(screen,dim,24,24);BitBlt(dim,8,8,8,8,original,8,8,0x00CC0020);
            var bytes=EncodeBmp(dim,frame);var clear=54+(10*24+10)*4;var fog=54+(2*24+2)*4;
            var expected=new byte[]{192,80,32};
            for(var i=0;i<3;i++)if(bytes[clear+i]!=expected[i]||Math.Abs(bytes[fog+i]-(expected[i]*115+144*140)/255d)>2)throw new InvalidOperationException("截圖框內清晰／框外灰霧像素錯誤。");
            File.WriteAllBytes(Path.Combine(outputDirectory,"screenshot-mask-synthetic.bmp"),bytes);
            return new{nativeGdi=true,insideOriginalPixels=true,outsideFogPixels=true,captureKeepsOriginal=true,syntheticOnly=true,interactiveCapture="未執行"};
        }
        finally
        {
            if(originalOld!=0)SelectObject(original,originalOld);if(dimOld!=0)SelectObject(dim,dimOld);
            if(brush!=0)DeleteObject(brush);if(originalBitmap!=0)DeleteObject(originalBitmap);if(dimBitmap!=0)DeleteObject(dimBitmap);
            if(original!=0)DeleteDC(original);if(dim!=0)DeleteDC(dim);if(screen!=0)ReleaseDC(0,screen);
        }
    }

    private static byte[] EncodeBmp(nint source, Rect rect)
    {
        int width = rect.Right - rect.Left, height = rect.Bottom - rect.Top;
        int length = checked(width * height * 4);
        var dc = CreateCompatibleDC(source);
        var bitmap = CreateCompatibleBitmap(source, width, height);
        nint old = 0;
        try
        {
            if (dc == 0 || bitmap == 0) throw new Win32Exception();
            old = SelectObject(dc, bitmap);
            if (!BitBlt(dc, 0, 0, width, height, source, rect.Left, rect.Top, 0x00CC0020)) throw new Win32Exception();
            SelectObject(dc, old); old = 0;
            var info = new BitmapInfo { Size = 40, Width = width, Height = -height, Planes = 1, BitCount = 32, ImageSize = (uint)length };
            var pixels = new byte[length];
            if (GetDIBits(dc, bitmap, 0, (uint)height, pixels, ref info, 0) != height) throw new Win32Exception();
            using var memory = new MemoryStream();
            using var writer = new BinaryWriter(memory);
            writer.Write((ushort)0x4D42); writer.Write(checked(54 + length));
            writer.Write(0); writer.Write(54);
            writer.Write(40); writer.Write(width); writer.Write(-height);
            writer.Write((ushort)1); writer.Write((ushort)32); writer.Write(0); writer.Write(length);
            writer.Write(0); writer.Write(0); writer.Write(0); writer.Write(0);
            writer.Write(pixels);
            return memory.ToArray();
        }
        finally
        {
            if (old != 0) SelectObject(dc, old);
            if (bitmap != 0) DeleteObject(bitmap);
            if (dc != 0) DeleteDC(dc);
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate nint WindowProc(nint hwnd, uint message, nuint wParam, nint lParam);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WindowClass
    {
        public uint Size, Style; public WindowProc Procedure; public int ClassExtra, WindowExtra;
        public nint Instance, Icon, Cursor, Background;
        public string? MenuName; public string ClassName; public nint SmallIcon;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct Message
    { public nint Window; public uint Id; public nuint WParam; public nint LParam; public uint Time; public Point Position; public uint Private; }
    [StructLayout(LayoutKind.Sequential)] private struct Paint
    { public nint DC; public int Erase; public Rect Area; public int Restore, Update; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)] public byte[] Reserved; }
    [StructLayout(LayoutKind.Sequential)] private struct BitmapInfo
    { public uint Size; public int Width, Height; public ushort Planes, BitCount; public uint Compression, ImageSize; public int XPels, YPels; public uint Used, Important; }

    [StructLayout(LayoutKind.Sequential,Pack=1)] private struct Blend{public byte Operation,Flags,Alpha,Format;}
    [DllImport("msimg32.dll",SetLastError=true)] private static extern bool AlphaBlend(nint target,int x,int y,int width,int height,nint source,int sourceX,int sourceY,int sourceWidth,int sourceHeight,Blend blend);
    [DllImport("gdi32.dll")] private static extern nint CreateSolidBrush(uint color);

    [DllImport("user32.dll")] private static extern nint SetThreadDpiAwarenessContext(nint context);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern nint GetDC(nint hwnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(nint hwnd, nint dc);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern nint GetModuleHandle(string? module);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern ushort RegisterClassEx(ref WindowClass wc);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool UnregisterClass(string name, nint instance);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern nint CreateWindowEx(uint exStyle, string className, string name, uint style, int x, int y, int width, int height, nint parent, nint menu, nint instance, nint parameter);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool IsWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindow(nint hwnd, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool UpdateWindow(nint hwnd);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern nint SetCapture(nint hwnd);
    [DllImport("user32.dll")] private static extern bool ReleaseCapture();
    [DllImport("user32.dll")] private static extern bool InvalidateRect(nint hwnd, nint rect, bool erase);
    [DllImport("user32.dll")] private static extern nint BeginPaint(nint hwnd, out Paint paint);
    [DllImport("user32.dll")] private static extern bool EndPaint(nint hwnd, ref Paint paint);
    [DllImport("user32.dll")] private static extern int FillRect(nint dc, ref Rect rect, nint brush);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint DefWindowProc(nint hwnd, uint message, nuint wParam, nint lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetMessage(out Message message, nint hwnd, uint min, uint max);
    [DllImport("user32.dll")] private static extern bool TranslateMessage(ref Message message);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint DispatchMessage(ref Message message);
    [DllImport("user32.dll")] private static extern void PostQuitMessage(int exitCode);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool PostMessage(nint hwnd, uint message, nuint wParam, nint lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern nint LoadCursor(nint instance, nint cursor);
    [DllImport("dwmapi.dll")] private static extern int DwmFlush();
    [DllImport("gdi32.dll")] private static extern nint CreateCompatibleDC(nint dc);
    [DllImport("gdi32.dll")] private static extern nint CreateCompatibleBitmap(nint dc, int width, int height);
    [DllImport("gdi32.dll")] private static extern nint SelectObject(nint dc, nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(nint obj);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(nint dc);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern bool BitBlt(nint target, int x, int y, int width, int height, nint source, int sourceX, int sourceY, uint operation);
    [DllImport("gdi32.dll")] private static extern nint GetStockObject(int index);
    [DllImport("gdi32.dll")] private static extern nint CreatePen(int style, int width, uint color);
    [DllImport("gdi32.dll")] private static extern bool Rectangle(nint dc, int left, int top, int right, int bottom);
    [DllImport("gdi32.dll")] private static extern int SetBkMode(nint dc, int mode);
    [DllImport("gdi32.dll")] private static extern uint SetTextColor(nint dc, uint color);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int DrawText(nint dc, string text, int count, ref Rect rect, uint format);
    [DllImport("gdi32.dll", SetLastError = true)] private static extern int GetDIBits(nint dc, nint bitmap, uint start, uint lines, [Out] byte[] pixels, ref BitmapInfo info, uint usage);
}
