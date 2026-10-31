using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using global::Windows.System;
using System.Numerics;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows;
public partial class MainWindow
{
    internal RadialPreferencesStore RadialTools {get;private set;}=null!;
    private readonly RadialGesture _radialGesture=new();
    private readonly DispatcherTimer _radialHoldTimer=new(){Interval=TimeSpan.FromMilliseconds(230)};
    private readonly DispatcherTimer _radialSaveTimer=new(){Interval=TimeSpan.FromMilliseconds(350)};
    private RadialWheelSettingsWindow? _radialSettings;
    private RadialToolProfile RadialProfile=>RadialTools.Value.Canvas;
    private void InitializeRadialInput()
    {
        RadialTools=new(_storage.DataDirectory);RadialProfile.Reconcile(_tool);
        _radialHoldTimer.Tick+=(_,_)=>{_radialHoldTimer.Stop();_radialGesture.Poll(LaserNow);if(_radialGesture.Visible)PresentInteraction();};
        _radialSaveTimer.Tick+=async(_,_)=>{if(_gesture||_radialGesture.Holding)return;_radialSaveTimer.Stop();try{await RadialTools.SaveAsync();}catch(Exception error){await Error(error);}};
        Activated+=(_,args)=>{if(args.WindowActivationState==WindowActivationState.Deactivated)CancelRadial();};
        Closed+=(_,_)=>{_radialSaveTimer.Stop();CancelRadial();_radialSettings?.Close();};
    }
    private void BeginRadial(PointerRoutedEventArgs e)
    {
        if(_preparingClose||_saveBoundaryBusy){e.Handled=true;return;}
        FinishPinRename();if(_editor is not null)FinishText();CommitPropertyEdit();FocusCanvasSurface();
        if(_circularEraser?.IsFinishing!=true)CancelGesture();
        _activeFlyout?.Hide();var p=e.GetCurrentPoint(CanvasSurface);
        _mouse=new((float)p.Position.X,(float)p.Position.Y);
        _radialGesture.Press(new(p.Position.X,p.Position.Y),LaserNow,CanvasSurface.ActualWidth,CanvasSurface.ActualHeight,1);
        CanvasSurface.CapturePointer(e.Pointer);_radialHoldTimer.Start();UpdateShapeCursor();e.Handled=true;
    }
    private void CancelRadial()
    {
        if(!_radialGesture.Holding)return;_radialHoldTimer.Stop();_radialGesture.Cancel();CanvasSurface.ReleasePointerCaptures();
        UpdateShapeCursor();if(CanvasSurface.IsRenderingAvailable)PresentInteraction();
    }
    private bool MoveRadial(PointerRoutedEventArgs e)
    {
        if(!_radialGesture.Holding)return false;var p=e.GetCurrentPoint(CanvasSurface).Position;
        var old=_radialGesture.Hover;var visible=_radialGesture.Visible;_mouse=new((float)p.X,(float)p.Y);
        _radialGesture.Move(new(p.X,p.Y),LaserNow,1);if(old!=_radialGesture.Hover||visible!=_radialGesture.Visible)PresentInteraction();e.Handled=true;return true;
    }
    private bool ReleaseRadial(PointerRoutedEventArgs e)
    {
        if(!_radialGesture.Holding)return false;
        var p=e.GetCurrentPoint(CanvasSurface);if(p.Properties.IsRightButtonPressed){e.Handled=true;return true;}
        _mouse=new((float)p.Position.X,(float)p.Position.Y);var result=_radialGesture.Release();_radialHoldTimer.Stop();CanvasSurface.ReleasePointerCaptures();UpdateShapeCursor();PresentInteraction();
        if(result.WasWheel)
        {
            var before=string.Join(",",RadialProfile.Slots);var target=RadialProfile.Take(result.Slot,_tool);
            if(target is not null){if(RadialToolProfile.IsTool(target))ActivateTool(target);else InvokeToolByKey(target);}
            if(before!=string.Join(",",RadialProfile.Slots))PersistRadial();
        }
        else if(_tool is not("laser" or "cane"))
        {
            var position=new Vector2((float)p.Position.X,(float)p.Position.Y);
            if(_rulerEnabled&&(RulerHit(position)||RulerRotationHit(position)))ShowRulerSettings(CanvasSurface,p.Position);else ShowContext(position);
        }
        e.Handled=true;return true;
    }
    private void PersistRadial(){_radialSettings?.RefreshSlots();_radialSaveTimer.Stop();_radialSaveTimer.Start();}
    private void TrackRadialTool(string previous,string current){if(RadialProfile.TrackTool(previous,current))PersistRadial();}
    private void ShowRadialSettings()
    {
        if(_radialSettings is null){_radialSettings=new(RadialProfile,false,RadialTools.SaveAsync);_radialSettings.Closed+=(_,_)=>_radialSettings=null;}
        _radialSettings.Activate();
    }
    internal void CloseRadialSettings()=>_radialSettings?.Close();
}
