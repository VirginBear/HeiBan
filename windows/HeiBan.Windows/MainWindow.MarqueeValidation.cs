#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
namespace HeiBan.Windows;

public partial class MainWindow
{
    // Observe the actual routed input after production handlers. Calling the three
    // selection helpers directly cannot detect a Move event wired to Complete.
    private async Task PrepareMarqueeValidationAsync(string output,bool dense=false)
    {
        Directory.CreateDirectory(output);
        Title="HeiBan marquee QA";
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1200,820));
        var fixture=new HeiBanDocument{Board=new(){Id="marquee-qa",Title="Marquee QA",CanvasMode="infinite"},Objects=[
            new(){Id="a",Type="rect",X=240,Y=220,Width=80,Height=60,StrokeWidth=2,StrokeColor="#FFFFFF",FillColor="#A8CDAF"},
            new(){Id="b",Type="rect",X=380,Y=220,Width=80,Height=60,StrokeWidth=2,StrokeColor="#FFFFFF",FillColor="#F6CE75"},
            new(){Id="c",Type="rect",X=550,Y=220,Width=80,Height=60,StrokeWidth=2,StrokeColor="#FFFFFF",FillColor="#8CB8E2"}
        ]};
        if(dense)fixture.Objects.AddRange(Enumerable.Range(0,5000).Select(i=>new BoardObject{Id="dense-"+i,Type="rect",X=10000+i*10,Y=10000,Width=8,Height=8}));
        await OpenAsync(fixture);
        _rulerEnabled=false;_compass.IsEnabled=false;_readingMode=false;_viewLocked=false;
        ActivateTool("select");_viewport.X=0;_viewport.Y=0;_viewport.Zoom=1;RefreshEditor();
        InkPoint? origin=null;string[] seed=[];var moves=new List<bool>();var previews=new List<double[]>();var results=new List<object>();long sceneStart=0,generationStart=0;
        void Observe(string phase,PointerRoutedEventArgs e)
        {
            var point=e.GetCurrentPoint(CanvasSurface);var end=_viewport.ScreenToWorld(point.Position.X,point.Position.Y);
            if(phase=="down")
            {
                origin=_marquee?_start:null;seed=[.._marqueeSelection];moves.Clear();previews.Clear();
                sceneStart=_sceneBuilds;generationStart=_session.Generation;
            }
            else if(phase=="move"&&origin is not null)
            {
                moves.Add(_marquee);if(_preview is { } frame)previews.Add([frame.X,frame.Y,frame.Width,frame.Height]);
            }
            else if(phase=="up"&&origin is not null)
            {
                var distance=Math.Max(Math.Abs(end.X-origin.X),Math.Abs(end.Y-origin.Y))*_viewport.Zoom;
                var expected=(distance>3?_session.VisibleObjects.Where(o=>WindowSelection.Matches(o,origin,end)).Select(o=>o.Id).Concat(seed):seed).ToHashSet();
                var selected=_session.SelectedIds.ToArray();var previewHeld=moves.Count>0&&moves.All(p=>p)&&previews.Count==moves.Count;
                var selectedCorrectly=expected.SetEquals(selected);var finished=!_marquee&&_preview is null;
                var sceneRebuilds=_sceneBuilds-sceneStart;var generationChanges=_session.Generation-generationStart;
                results.Add(new{origin,end,moveEvents=moves.Count,previewHeld,selectedCorrectly,finished,selected,expected=expected.ToArray(),previews=previews.ToArray(),sceneRebuilds,generationChanges,success=previewHeld&&selectedCorrectly&&finished&&sceneRebuilds==0&&generationChanges==0});
                File.WriteAllText(Path.Combine(output,"gestures.json"),JsonSerializer.Serialize(results,new JsonSerializerOptions{WriteIndented=true}));
                origin=null;
            }
        }
        CanvasSurface.AddHandler(UIElement.PointerPressedEvent,new PointerEventHandler((_,e)=>Observe("down",e)),true);
        CanvasSurface.AddHandler(UIElement.PointerMovedEvent,new PointerEventHandler((_,e)=>Observe("move",e)),true);
        CanvasSurface.AddHandler(UIElement.PointerReleasedEvent,new PointerEventHandler((_,e)=>Observe("up",e)),true);
        await Task.Delay(250);PresentInteraction(true);
        File.WriteAllText(Path.Combine(output,"ready.json"),JsonSerializer.Serialize(new{title=Title,scope="Synthetic isolated canvas; actual routed pointer input",objects=_session.VisibleObjects.Select(o=>new{o.Id,o.X,o.Y,o.Width,o.Height})}));
    }
}
#endif
