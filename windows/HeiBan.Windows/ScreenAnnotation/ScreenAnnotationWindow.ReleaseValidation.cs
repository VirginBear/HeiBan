#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<object> ValidateRelease110Async()
    {
        await StartAsync();var assertions=0;var pixelFrames=0;
        void Check(bool condition,string message){assertions++;if(!condition)throw new InvalidOperationException(message);}
        try
        {
            foreach(var dock in new[]{"left","right","bottom","top"}){_chromeDock=dock;RebuildChromeLayout();ResizeChrome();PositionChrome();Check(_chromeTools.Children.Count>0,"Toolbar reparent failed: "+dock);}
            _session.Open(new());_rulerEnabled=true;_rulerCenter=new(600,450);_owner.SetSharedRulerLength(640);_rulerAngle=0;ChooseScreenTool("pen");
            var edgeY = 450 - RulerHeight / 2;
            OnPointer(new("down",500,edgeY));OnPointer(new("move",520,443));OnPointer(new("up",540,edgeY));
            Check(_session.Document.Objects.Single().ParsedPoints.All(p=>Math.Abs(p.Y-edgeY)<.001),"Ruler did not remain latched");
            OnPointer(new("down",500,edgeY-38*RulerScale));OnPointer(new("move",520,437));OnPointer(new("up",540,450));
            Check(_session.Document.Objects.Last().ParsedPoints.Any(p=>Math.Abs(p.Y-437)<.001),"Ruler attracted a stroke begun outside its edge");
            _rulerEnabled=false;CancelGesture();
            _session.Open(new(){Objects=[new(){Id="erase-me",Type="rect",X=100,Y=100,Width=40,Height=40,FillColor="#5F9E71"},new(){Id="below",Type="rect",X=80,Y=80,Width=100,Height=100,IsLocked=true,StrokeColor="#336699",FillColor="#336699",ZIndex=-1}]});
            ChooseScreenTool("eraser");_eraserWhole=true;_eraserSize=40;Changed();Render();
            OnPointer(new("down",110,110));var gesture=_circularEraser??throw new Exception("No eraser gesture");
            gesture.PreviewChanged+=()=>
            {
                Render();var regional=_target!.GetPixelBytes();_benchmarkFullFrames=true;
                try{Render();Check(regional.AsSpan().SequenceEqual(_target.GetPixelBytes()),"Regional eraser differs from full-frame reference");pixelFrames++;}
                finally{_benchmarkFullFrames=false;}
            };
            OnPointer(new("up",110,110));
            await InsertScreenObjectAsync(new(){Id="inserted",Type="text",Text="2+2=4",X=300,Y=300,Width=100,Height=30},_session.DocumentEpoch);
            Check(_session.Document.Objects.All(o=>o.Id!="erase-me")&&_session.Document.Objects.Any(o=>o.Id=="inserted"),"Completed eraser lost during insertion");
            Check(pixelFrames>0,"No partial erase preview compared");
            _session.Undo();Check(_session.Document.Objects.All(o=>o.Id!="erase-me"&&o.Id!="inserted"),"Insert undo restored an earlier erase");
            _session.Undo();Check(_session.Document.Objects.Any(o=>o.Id=="erase-me"),"Erase undo failed");
            var stale=_session.DocumentEpoch;_session.Open(new());await InsertScreenObjectAsync(new(){Id="late"},stale);Check(_session.Document.Objects.Count==0,"Late edit crossed document epoch");
            ShowScreenCalculatorPanel();Check(IsAuxiliaryToolWindow(_screenCalcWindow!.Handle),"Calculator mistaken for external app");
            ShowScreenTimerPanel();Check(IsAuxiliaryToolWindow(_screenTimerWindow!.Handle),"Timer mistaken for external app");
            ShowScreenCustomizeToolbarWindow();Check(IsAuxiliaryToolWindow(_customizeToolbarWindow!.Handle),"Customize window mistaken for external app");
            _customizeToolbarWindow.Close();_timerCoordinator.TogglePlayPause();EnsureScreenTimerTick();Check(_screenTimerTick!.IsEnabled,"Running timer did not tick");
            CloseFloatingTeachingTools();Check(!_screenTimerTick.IsEnabled&&_timerCoordinator.Status!=TimerStatus.Running,"Screen close left timer running");
            Changed();return new{assertions,pixelFrames,rulerLatch=true,eraserInsertion=true,independentUndo=true,staleEditRejected=true,auxiliaryWindows=true,timerStopped=true};
        }
        finally{await StopAsync();}
    }
}
#endif
