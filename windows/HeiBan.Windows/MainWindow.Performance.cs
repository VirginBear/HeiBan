using System.Diagnostics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.Foundation;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private object ValidateCanvasPerformance()
    {
        var saved=DocumentCodec.Clone(_session.Document);var x=_viewport.X;var y=_viewport.Y;var zoom=_viewport.Zoom;
        const float width=1024,height=640;
        var texts=Enumerable.Range(0,140).Select(i=>new BoardObject{Id="perf-text-"+i,Type=i%4==0?"sticky":"text",X=(i%10)*100,Y=(i/10)*43,Width=95,Height=42,Text="中文文字\n流暢度",FontSize=12,StrokeColor="#24533d",IsUnderline=i%3==0,RichTextSpans=[new TextSpan{Text="中文文字",Color="#3b82f6",IsBold=true,HighlightColor=i%5==0?"#fef08a":null}],ZIndex=i}).ToList();
        var strokes=Enumerable.Range(0,160).Select(i=>new BoardObject{Id="perf-ink-"+i,Type=i%6==0?"highlighter":"stroke",X=i%16*60,Y=i/16*58,Width=54,Height=30,StrokeWidth=2,Opacity=.5,StrokeColor="#a855f7",ZIndex=140+i,
            Points=JsonSerializer.Serialize(Enumerable.Range(0,120).Select(j=>new InkPoint(i%16*60+j*.45,i/16*58+Math.Sin(j*.07)*12+15)),DocumentCodec.Options)}).ToList();
        var document=new HeiBanDocument{Board=new BoardMetadata{CanvasMode="infinite",BackgroundColor="#f8faf6",GridStyle="dots"},Objects=texts.Concat(strokes).ToList()};
        using var target=new CanvasRenderTarget(CanvasSurface,width,height,CanvasSurface.Dpi);
        void DrawReference()
        {
            using(var ds=target.CreateDrawingSession())
            {
                _renderer.RenderBackground(ds,_session.Document.Board,_viewport,width,height);
                var board=_session.Document.Board;var clip=board.CanvasMode=="infinite"?new Rect(0,0,width,height):new Rect(_viewport.X,_viewport.Y,(board.CanvasWidth??595)*_viewport.Zoom,(board.CanvasHeight??842)*_viewport.Zoom);
                using(var layer=ds.CreateLayer(1,clip))_renderer.RenderObjects(ds,_session.VisibleObjects,_viewport,width,height);
            }
        }
        void DrawCached(){using var ds=target.CreateDrawingSession();RenderMainScene(CanvasSurface,ds,width,height);}
        (double Median,double P95,long Allocations) Measure(Action draw)
        {
            draw();draw();var times=new List<double>();var before=GC.GetAllocatedBytesForCurrentThread();
            for(var i=0;i<40;i++){var timer=Stopwatch.StartNew();draw();_ = target.GetPixelBytes(0,0,1,1);times.Add(timer.Elapsed.TotalMilliseconds);}
            var bytes=GC.GetAllocatedBytesForCurrentThread()-before;times.Sort();return(times[20],times[38],bytes);
        }
        var frames=0;
        void Compare()
        {
            _renderer.BypassTextCache=true;DrawReference();var expected=target.GetPixelBytes();
            _renderer.BypassTextCache=false;_sceneDirty=true;DrawCached();var actual=target.GetPixelBytes();
            if(!expected.AsSpan().SequenceEqual(actual))throw new InvalidOperationException("普通畫布快取像素不一致，案例 "+frames);
            frames++;
        }
        try
        {
            _session.Open(document);_viewport.X=_viewport.Y=0;_viewport.Zoom=1;ClearScene();
            _renderer.BypassTextCache=true;var original=Measure(DrawReference);
            _renderer.BypassTextCache=false;_sceneDirty=true;var builds=_sceneBuilds;var optimized=Measure(DrawCached);
            if(_sceneBuilds!=builds+1)throw new InvalidOperationException("穩定畫布重建了已完成scene。");
            var textBuilds=_renderer.TextLayoutBuilds;DrawCached();DrawCached();if(textBuilds!=_renderer.TextLayoutBuilds)throw new InvalidOperationException("懸停重建文字排版。");
            Compare();_viewport.X=-72;_viewport.Y=20;_viewport.Zoom=.8;Compare();_viewport.Zoom=1.35;Compare();
            document.Board.CanvasMode="notebook";document.Board.CanvasWidth=700;document.Board.CanvasHeight=550;Compare();
            document.Board.CanvasMode="infinite";texts[1].FontSize=16;texts[1].Opacity=.4;texts[1].RichTextSpans![0].IsUnderline=true;Compare();
            var stroke=strokes[10];_session.SelectedId=stroke.Id;_session.PreviewMoveSelection(15,12);Compare();_session.PreviewMoveSelection(-8,5);Compare();_session.Commit();Compare();_session.Undo();Compare();
            return new{objects=300,textObjects=140,strokePoints=19200,samplesPerRun=40,originalMedianMs=original.Median,originalP95Ms=original.P95,
                cachedMedianMs=optimized.Median,cachedP95Ms=optimized.P95,originalAllocatedBytes=original.Allocations,cachedAllocatedBytes=optimized.Allocations,
                pixelEquivalentFrames=frames,stableSceneBuilds=1,idleTextLayoutRebuilds=0,scope="同機原生完整／快取scene同步繪製，含GPU同步；此binary內參考比較，非本批前測或實體輸入端到端延遲"};
        }
        finally{_renderer.BypassTextCache=false;_session.Open(saved);_viewport.X=x;_viewport.Y=y;_viewport.Zoom=zoom;ClearScene();RefreshEditor();}
    }
}
