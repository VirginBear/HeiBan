using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.UI;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private object MeasureSpatialScenes()
    {
        const float width=1024,height=640;
        using var target=new CanvasRenderTarget(CanvasSurface,width,height,CanvasSurface.Dpi);
        var cases=new List<object>();var equivalentFrames=0;
        var gridFirst=Environment.GetEnvironmentVariable("HEIBAN_PERFORMANCE_GRID_FIRST")=="1";
        foreach(var count in new[]{0,300,1000,10000})
        {
            var doc=new HeiBanDocument{Objects=Enumerable.Range(0,count).Select(i=>new BoardObject
            {Id="spatial-"+i,Type="rect",X=i%100*100,Y=i/100*100,Width=20,Height=20,
                Rotation=i%4*25,StrokeWidth=2,ZIndex=i%11,StrokeColor="#24533d",FillColor="#39735a"}).ToList()};
            _session.Open(doc);_viewport.X=_viewport.Y=0;_viewport.Zoom=1;ClearScene();
            void Draw(bool reference)
            {
                using(var ds=target.CreateDrawingSession())
                {
                    ds.Clear(Color.FromArgb(0,0,0,0));
                    _renderer.RenderObjects(ds,reference?_session.VisibleObjects.OrderBy(o=>o.ZIndex):_session.DrawingObjects,_viewport,width,height);
                }
                _=target.GetPixelBytes(0,0,1,1);
            }
            // Same-binary reference uses the stable LINQ scan; timed native stage includes one-pixel GPU synchronization.
            var scan=PerformanceMeasurement.Measure(()=>Draw(true));
            var candidates=PerformanceMeasurement.Measure(()=>Draw(false));
            var pan=PerformanceMeasurement.Measure(()=>{_viewport.X=_viewport.X==0?-30:0;Draw(false);});
            var zoom=PerformanceMeasurement.Measure(()=>{_viewport.Zoom=_viewport.Zoom==1?1.1:1;Draw(false);});
            void DrawScene(){using(var ds=target.CreateDrawingSession())RenderMainScene(CanvasSurface,ds,width,height);_=target.GetPixelBytes(0,0,1,1);}
            (PerformanceMeasurement Pan,PerformanceMeasurement Zoom) MeasureScene(bool bypass)
            {
                _renderer.BypassViewportCache=bypass;
                _viewport.X=_viewport.Y=0;_viewport.Zoom=1;ClearScene();
                var p=PerformanceMeasurement.Measure(()=>{_viewport.X=_viewport.X==0?-30:0;DrawScene();});
                var z=PerformanceMeasurement.Measure(()=>{_viewport.Zoom=_viewport.Zoom==1?1.1:1;DrawScene();});
                return(p,z);
            }
            var first=MeasureScene(!gridFirst);var second=MeasureScene(gridFirst);
            var scanScene=gridFirst?second:first;var gridScene=gridFirst?first:second;
            var sceneScanPan=scanScene.Pan;var sceneScanZoom=scanScene.Zoom;var sceneGridPan=gridScene.Pan;var sceneGridZoom=gridScene.Zoom;
            _renderer.BypassViewportCache=false;
            void Compare()
            {
                Draw(true);var expected=target.GetPixelBytes();Draw(false);
                if(!expected.AsSpan().SequenceEqual(target.GetPixelBytes()))throw new InvalidOperationException("視野候選像素與掃描參考不一致。");
                equivalentFrames++;
            }
            Compare();_viewport.X=-370;_viewport.Y=-170;Compare();_viewport.Zoom=.7;Compare();
            if(count>0)
            {
                doc.Objects[0].X=500;doc.Objects[0].Y=350;doc.Objects[0].Width=240;doc.Objects[0].Rotation=75;Compare();
                doc.Objects[0].ZIndex=999;doc.Objects.Reverse();Compare();
                doc.Board.CanvasMode="notebook";doc.Board.ActivePageId="p1";
                foreach(var item in doc.Objects){item.PageId=item.ZIndex%2==0?"p1":"p2";item.IsVisible=item.ZIndex%3==0?false:null;}
                Compare();doc.Board.ActivePageId="p2";Compare();
                _session.Begin();_session.Document.Objects[0].X=4000;Compare();_session.Cancel();Compare();
                _session.Begin();_session.Document.Objects[0].X=300;_session.Commit();Compare();_session.Undo();Compare();_session.Redo();Compare();
                _session.Document.Board.CanvasMode="infinite";_viewport.X=_viewport.Y=0;_viewport.Zoom=1;
                _session.Document.Objects.AddRange(new BoardObject[]
                {
                    new(){Type="line",X=12000,Y=250,Width=30,Height=0,X1=12000,Y1=250,X2=12030,Y2=250,Extension="both",StrokeWidth=3},
                    new(){Type="curve",X=5,Y=5,Width=150,Height=150,StrokeWidth=15,Points="[{\"x\":5,\"y\":5},{\"x\":150,\"y\":50},{\"x\":20,\"y\":150}]"},
                    new(){Type="text",Text="中文候選邊界",X=780,Y=250,Width=200,Height=80,FontSize=30},
                    new(){Type="sticky",StickyStyle="cat",X=500,Y=500,Width=80,Height=80,Rotation=30},
                    new(){Type="arc",X=500,Y=100,Width=100,Height=100,ArcRadius=130},
                    new(){Type="arrow",X=5,Y=500,Width=100,Height=50,ArrowHeadLength=150,ArrowHeadWidth=180},
                    new(){Type="future-unknown",X=0,Y=0,Width=20,Height=20}
                });
                Compare();_viewport.X=-500;_viewport.Y=-200;_viewport.Zoom=1.25;Compare();
                _session.Begin();_session.SetSelection(new[]{_session.Document.Objects.First(o=>o.Type=="curve").Id});
                _session.PreviewMoveSelection(600,120);Compare();_session.Cancel();Compare();
                foreach(var mode in new[]{"fixed","notebook"})
                {
                    _session.Document.Board.CanvasMode=mode;_session.Document.Board.CanvasWidth=595;_session.Document.Board.CanvasHeight=842;
                    _renderer.BypassViewportCache=true;_sceneDirty=true;DrawScene();var expected=target.GetPixelBytes();
                    _renderer.BypassViewportCache=false;_sceneDirty=true;DrawScene();
                    if(!expected.AsSpan().SequenceEqual(target.GetPixelBytes()))throw new InvalidOperationException("固定／多頁畫布候選裁切像素不一致。");
                    equivalentFrames++;
                }
            }
            cases.Add(new{objects=count,spacingWorld=100,scan,candidates,pan,zoom,sceneScanPan,sceneScanZoom,sceneGridPan,sceneGridZoom});
        }
        return new{cases,equivalentFrames,sceneTimingOrder=gridFirst?"grid then scan":"scan then grid",scope="Synthetic sparse viewport rendering, stable reference order, strict BGRA equality; no physical input latency"};
    }
}
