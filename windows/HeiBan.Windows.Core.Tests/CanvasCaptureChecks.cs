using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
internal static class CanvasCaptureChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var page=CanvasCapturePlan.WholePage(new(){CanvasMode="fixed",CanvasWidth=1920,CanvasHeight=1080});
        check(page==new ExportArea(0,0,1920,1080),"Canvas capture uses full page, not viewport/object bounds");
        check(CanvasCapturePlan.WholePage(new(){CanvasMode="notebook"})==new ExportArea(0,0,595,842),"Notebook page capture has A4 fallback");
        check(CanvasCapturePlan.WholePage(new(){CanvasMode="infinite"}) is null,"Infinite canvas requires explicit region");
        check(CanvasCapturePlan.Drag(new(50,80),new(-10,-20),2)==new ExportArea(-10,-20,60,100),"Capture normalizes reverse and negative-coordinate drags");
        check(CanvasCapturePlan.Drag(new(0,0),new(2,40),1) is null,"Capture rejects too-thin screen region");
        check(CanvasCapturePlan.Drag(new(0,0),new(2,40),2) is not null,"Capture threshold uses screen zoom");
        var normal=CanvasCapturePlan.Create(page!,16384);
        check(normal.PixelWidth==3840&&normal.PixelHeight==2160,"Full HD page produces independent sharp bitmap");
        foreach(var area in new[]{new ExportArea(0,0,100000,60000),new ExportArea(0,0,1e8,1),new ExportArea(-500,-900,997.5,551.25)})
        {
            var plan=CanvasCapturePlan.Create(area,8192);
            check(plan.PixelWidth>0&&plan.PixelHeight>0&&plan.PixelWidth<=8192&&plan.PixelHeight<=8192,"Canvas bitmap respects device dimensions");
            check((long)plan.PixelWidth*plan.PixelHeight<=40_000_000,"Canvas bitmap allocation stays bounded");
        }
        var tinyBudget=CanvasCapturePlan.Create(new(0,0,1e8,1),8192,1);check((long)tinyBudget.PixelWidth*tinyBudget.PixelHeight==1,"Thin regions respect even one-pixel budgets");
        var rejected=false;try{CanvasCapturePlan.Create(new(0,0,double.NaN,12),8192);}catch(ArgumentOutOfRangeException){rejected=true;}
        check(rejected,"Invalid capture geometry rejected before GPU allocation");
        var prefs=new ToolbarPreferences();prefs.Normalize();
        check(prefs.VisibleTools.Contains("canvasCapture"),"New canvas capture command is discoverable");
        prefs.HideTool("canvasCapture");prefs.Normalize();check(prefs.HiddenTools.Contains("canvasCapture"),"Explicit capture hiding survives normalize");
        check(!ToolbarContentPolicy.IsAvailableOnScreen("canvasCapture")&&!RadialToolProfile.Allowed("canvasCapture",true),"Screen host cannot dispatch canvas-only capture command");
    }
}
