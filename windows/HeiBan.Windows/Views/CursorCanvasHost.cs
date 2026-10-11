using System.Runtime.InteropServices;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows.Views;

// WinUI owns the pointer source for CanvasControl. Set its inherited XAML cursor;
// a Win32 SetCursor/WM_SETCURSOR override can be replaced by that pointer source.
public sealed class CursorCanvasHost : Grid
{
    private InputCursor? _cursor;
    private nint _native;
    private uint _dpi;
    internal void SetNativeCursor(nint native,uint dpi)
    {
        if(native==0||(_native==native&&_dpi==dpi))return;
        var next=CreateInputCursor(native);
        var previous=_cursor;ProtectedCursor=next;_cursor=next;_native=native;_dpi=dpi;
        previous?.Dispose();
    }
    internal void ReleaseCursor()
    {ProtectedCursor=null;_cursor?.Dispose();_cursor=null;_native=0;}

    private static unsafe InputCursor CreateInputCursor(nint native)
    {
        var iid=new Guid("ac6f5065-90c4-46ce-beb7-05e138e54117");
        // Use the same activation path as the C#/WinRT SDK projection, including its
        // registration-free DLL fallback for self-contained desktop distributions.
        using var factory=WinRT.ActivationFactory.Get("Microsoft.UI.Input.InputCursor",iid);
        nint result=0;
        try
        {
            // The SDK's IInputCursorStaticsInterop derives from IInspectable (six ABI slots).
            // CreateFromHCursor copies a custom cursor; its WinRT lifetime is independent of HCURSOR.
            var factoryPointer=factory.ThisPtr;
            var method=(delegate* unmanaged[Stdcall]<nint,nint,nint*,int>)(*(nint**)factoryPointer)[6];
            Marshal.ThrowExceptionForHR(method(factoryPointer,native,&result));
            return WinRT.MarshalInterface<InputCursor>.FromAbi(result);
        }
        finally
        {if(result!=0)Marshal.Release(result);}
    }
}
