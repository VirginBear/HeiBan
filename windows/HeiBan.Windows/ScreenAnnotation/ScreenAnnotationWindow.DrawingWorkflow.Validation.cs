using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<object> ValidateDrawingWorkflowAsync()
    {
        if(string.IsNullOrEmpty(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))throw new InvalidOperationException("Isolated data required.");
        await StartAsync();
        try
        {
            _toolbarPreferences.DisplayMode="labels";foreach(var key in HeiBan.Windows.Engine.ToolbarContentPolicy.ScreenCanvasTools)_toolbarPreferences.ShowTool(key);
            foreach(var side in new[]{"left","bottom","right","top"}){DockChrome(side);Render();}
            ChooseScreenTool("triangle");var before=_session.Document.Objects.Count;
            foreach(var p in new[]{(300d,250d),(500d,400d),(250d,420d)}){OnPointer(new("down",p.Item1,p.Item2));OnPointer(new("up",p.Item1,p.Item2));}
            if(_session.Document.Objects.Count!=before+1||_session.Selected?.Type!="triangle"||_session.Selected.ParsedPoints.Count!=3||_tool!="triangle")throw new InvalidOperationException("Screen three-point triangle failed.");
            ChooseScreenTool("rect");before=_session.Document.Objects.Count;
            for(var index=0;index<2;index++){OnPointer(new("down",600+index*100,200));OnPointer(new("move",670+index*100,270));OnPointer(new("up",670+index*100,270));}
            if(_session.Document.Objects.Count!=before+2||_tool!="rect")throw new InvalidOperationException("Screen continuous rectangles failed.");
            _session.Begin();_session.Add(new BoardObject{Type="line",X1=50,Y1=50,X2=80,Y2=80,X=50,Y=50,Width=30,Height=30});_session.Commit();
            _toolbarPreferences.MagnetEnabled=true;ChooseScreenTool("line");OnPointer(new("down",54,52));OnPointer(new("move",150,120));OnPointer(new("up",160,130));
            if(_session.Document.Objects.LastOrDefault() is not {Type:"line",X1:50,Y1:50})throw new InvalidOperationException("Screen construction anchor did not snap.");
            Render();return new{threePointTriangle=true,continuousShapes=true,magnet=true,labeledFourSideLayout=true,hardwarePointer="Not executed"};
        }
        finally{await StopAsync();}
    }
}
