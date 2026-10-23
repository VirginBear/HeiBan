using System.Runtime.InteropServices;
using Microsoft.Graphics.Canvas;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class NativeOverlayWindow
{
    private global::Windows.Storage.Streams.Buffer? _readbackBuffer;
    private nint _readbackAccess,_readbackPixels;

    internal unsafe void PresentBitmap(CanvasRenderTarget bitmap,int x,int y,int width,int height)
    {
        if(_disposed)return;
        if(x<0||y<0||width<=0||height<=0||(long)x+width>Width||(long)y+height>Height)
            throw new ArgumentException("Overlay region does not match pixel dimensions.");
        var required=checked((uint)(width*height*4));
        if(_readbackBuffer is null||_readbackBuffer.Capacity<required)
        {
            ReleaseReadback();
            // Grow geometrically up to this desktop's size. Small dirty regions
            // must not allocate a fresh large managed array on every frame.
            var capacity=Math.Min((long)Width*Height*4,Math.Max(65536L,(long)required*2));
            var buffer=new global::Windows.Storage.Streams.Buffer(checked((uint)capacity));
            using var marshaler=WinRT.MarshalInterface<IBuffer>.CreateMarshaler(buffer);
            var iid=new Guid("905a0fef-bc53-11df-8c49-001e4fc686da");
            Marshal.ThrowExceptionForHR(Marshal.QueryInterface(marshaler.ThisPtr,in iid,out _readbackAccess));
            try
            {
                // robuffer.h IBufferByteAccess derives from IUnknown (3 slots).
                // Hold its COM reference while retaining the address; the DIB
                // only receives a copy, never a pointer into transient storage.
                byte* pixels=null;
                var getBuffer=(delegate* unmanaged[Stdcall]<nint,byte**,int>)(*(nint**)_readbackAccess)[3];
                Marshal.ThrowExceptionForHR(getBuffer(_readbackAccess,&pixels));
                if(pixels is null)throw new InvalidOperationException("Readback buffer has no storage.");
                _readbackPixels=(nint)pixels;_readbackBuffer=buffer;
            }
            catch{ReleaseReadback();throw;}
        }
        _readbackBuffer.Length=required;
        using var trace=global::HeiBan.Windows.Diagnostics.InputLatencyTrace.Measure(global::HeiBan.Windows.Diagnostics.InputStage.ScreenReadback);
        bitmap.GetPixelBytes(_readbackBuffer,x,y,width,height);
        CopyAndPresent((byte*)_readbackPixels,x,y,width,height);
    }
    private void ReleaseReadback()
    {
        _readbackPixels=0;_readbackBuffer=null;
        if(_readbackAccess!=0){Marshal.Release(_readbackAccess);_readbackAccess=0;}
    }
}
