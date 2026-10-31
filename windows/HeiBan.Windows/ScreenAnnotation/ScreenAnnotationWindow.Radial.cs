using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using global::Windows.Foundation;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    private readonly RadialGesture _radialGesture=new();
    private readonly Dictionary<string,Action> _screenCommands=[];
    private readonly DispatcherTimer _rightClickTimer=new(){Interval=TimeSpan.FromMilliseconds(NativeOverlayWindow.DoubleClickMilliseconds+25)};
    private readonly DispatcherTimer _radialSaveTimer=new(){Interval=TimeSpan.FromMilliseconds(350)};
    private InkPoint? _pendingRightClick;
    private string? _pendingRightTool;
    private RadialWheelSettingsWindow? _radialSettings;
    private RadialToolProfile RadialProfile=>_owner.RadialTools.Value.Screen;
    private void InitializeScreenRadial()
    {
        RadialProfile.Reconcile(_tool);_radialInitialized=true;
        _radialSaveTimer.Tick+=async(_,_)=>{if(_start is not null||_radialGesture.Holding||_circularEraser is not null)return;_radialSaveTimer.Stop();try{await _owner.RadialTools.SaveAsync();}catch(Exception error){_status.Text=T("輪盤設定尚未保存：")+error.Message;}};
        _rightClickTimer.Tick+=(_,_)=>
        {
            _rightClickTimer.Stop();var point=_pendingRightClick;_pendingRightClick=null;
            if(point is not null&&IsActive&&_drawing&&!_radialGesture.Holding&&_tool==_pendingRightTool&&_tool is not("laser" or "cane"))ScreenRightClick(point);
        };
    }
    private void DamageRadial()
    {
        var c=_radialGesture.Center;var r=(RadialGesture.Radius+10)*_dpiScale;
        AddScreenDamage(new Rect(c.X-r,c.Y-r,r*2,r*2));_dirty=true;
    }
    private void CancelRadial()
    {
        _rightClickTimer.Stop();_pendingRightClick=null;
        if(!_radialGesture.Holding)return;DamageRadial();_radialGesture.Cancel();_overlay.ReleasePointerCapture();RestoreRadialCursor();
    }
    private void PollScreenRadial()
    {
        if(!_radialGesture.Holding)return;
        if(NativeOverlayWindow.EscapeDown){CancelRadial();return;}
        var wasVisible=_radialGesture.Visible;_radialGesture.Poll(Now);
        if(wasVisible!=_radialGesture.Visible)DamageRadial();
    }
    private bool HandleRadialInput(NativeOverlayWindow.PointerEvent input,InkPoint point)
    {
        if(input.Kind=="rightdouble"&&!_radialGesture.PreviousWasWheel)
        {CancelRadial();FinishScreenText();SetDrawing(false);return true;}
        if(input.Kind is "rightdown" or "rightdouble")
        {
            _rightClickTimer.Stop();_pendingRightClick=null;FinishScreenText();
            if(_circularEraser?.IsFinishing!=true)CancelGesture();
            _chromeFlyout?.Hide();_radialGesture.Press(point,Now,_overlay.Width,_overlay.Height,_dpiScale);_overlay.SetManipulationCursor(null,null,"select");return true;
        }
        if(input.Kind=="down"){_rightClickTimer.Stop();_pendingRightClick=null;}
        if(!_radialGesture.Holding)return input.Kind=="rightup";
        if(input.Kind=="move")
        {var wasVisible=_radialGesture.Visible;var old=_radialGesture.Hover;_radialGesture.Move(point,Now,_dpiScale);if(wasVisible!=_radialGesture.Visible||old!=_radialGesture.Hover)DamageRadial();return true;}
        if(input.Kind=="rightup")
        {
            DamageRadial();var result=_radialGesture.Release();RestoreRadialCursor();
            if(result.WasWheel)
            {
                var before=string.Join(",",RadialProfile.Slots);var target=RadialProfile.Take(result.Slot,_tool);
                if(target=="operate")SetDrawing(false);
                else if(target is not null){if(RadialToolProfile.IsTool(target))ChooseScreenTool(target);else if(_screenCommands.TryGetValue(target,out var command))command();}
                if(before!=string.Join(",",RadialProfile.Slots))PersistScreenRadial();
            }
            else{_pendingRightClick=point;_pendingRightTool=_tool;_rightClickTimer.Start();}
            return true;
        }
        return true;
    }
    private void PersistScreenRadial(){_radialSettings?.RefreshSlots();_radialSaveTimer.Stop();_radialSaveTimer.Start();}
    private void TrackRadialTool(string previous,string current){_rightClickTimer.Stop();_pendingRightClick=null;if(RadialProfile.TrackTool(previous,current))PersistScreenRadial();}
    private void RestoreRadialCursor()
    {
        _overlay.SetManipulationCursor(null,null,_tool);
        if(_drawing&&_tool=="cane"){var p=NativeOverlayWindow.CurrentPointer;_cane.Move(new(p.X-_overlay.Left,p.Y-_overlay.Top));_dirty=true;}
    }
    private void ShowRadialSettings()
    {
        if(_radialSettings is null){_radialSettings=new(RadialProfile,true,_owner.RadialTools.SaveAsync);_radialSettings.Closed+=(_,_)=>_radialSettings=null;}
        _radialSettings.Activate();
    }
}
