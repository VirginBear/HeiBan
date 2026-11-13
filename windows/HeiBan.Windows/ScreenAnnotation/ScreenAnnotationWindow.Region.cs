using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private bool _regionChromeExpanded;
    private double ScreenWheelScale(double scale)=>_region is null?scale:
        Math.Min(scale,Math.Max(.4,(Math.Min(_overlay.Width,_overlay.Height)-16)/(2*Engine.RadialGesture.Radius)));
    private void ExpandRegionChrome()
    {
        if(_region is not { } area||_regionChromeExpanded)return;
        var position=AppWindow.Position;
        var size=AppWindow.Size;
        _regionChromeExpanded=true;
        SystemBackdrop=null;
        // XAML can now constrain its popup to a root the size of the selected
        // region, while the actual toolbar stays at its previous screen location.
        _chromeBody.HorizontalAlignment=HorizontalAlignment.Left;
        _chromeBody.VerticalAlignment=VerticalAlignment.Top;
        _chromeBody.Width=size.Width/_dpiScale;
        _chromeBody.Height=size.Height/_dpiScale;
        _chromeBody.Margin=new Thickness((position.X-area.X)/_dpiScale,(position.Y-area.Y)/_dpiScale,0,0);
        NativeOverlayWindow.PlaceCompactWindow(WinRT.Interop.WindowNative.GetWindowHandle(this),area);
        ((FrameworkElement)Content).UpdateLayout();
    }

    private void RestoreRegionChrome()
    {
        if(!_regionChromeExpanded)return;
        _regionChromeExpanded=false;
        _chromeBody.Width=_chromeBody.Height=double.NaN;
        _chromeBody.Margin=new Thickness(0);
        _chromeBody.HorizontalAlignment=HorizontalAlignment.Stretch;
        _chromeBody.VerticalAlignment=VerticalAlignment.Stretch;
        ResizeChrome();
        PositionChrome();
        SystemBackdrop=new DesktopAcrylicBackdrop();
    }

    private void ResizeScreenWindow(Window window,int width,int height)
    {
        var handle=WinRT.Interop.WindowNative.GetWindowHandle(window);
        if(_region is not { } bounds)
        {
            NativeOverlayWindow.ResizeCompactWindow(handle,width,height);
            return;
        }
        width=Math.Min(width,bounds.Width);
        height=Math.Min(height,bounds.Height);
        var position=window.AppWindow.Position;
        var x=Math.Clamp(position.X,bounds.X,bounds.X+bounds.Width-width);
        var y=Math.Clamp(position.Y,bounds.Y,bounds.Y+bounds.Height-height);
        NativeOverlayWindow.PlaceCompactWindow(handle,new RectInt32(x,y,width,height));
    }

    private void PlaceRegionWindow(Window window)
    {
        if(_region is not { } region)return;
        var size=window.AppWindow.Size;
        var width=Math.Min(size.Width,region.Width);
        var height=Math.Min(size.Height,region.Height);
        NativeOverlayWindow.PlaceCompactWindow(WinRT.Interop.WindowNative.GetWindowHandle(window),
            new RectInt32(region.X+(region.Width-width)/2,region.Y+(region.Height-height)/2,width,height));
    }
}
