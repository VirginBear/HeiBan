#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.UI.Xaml.Input;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task RunObjectDragValidationAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var checks=0;var maxDifference=0;var frames=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
            var doc=new HeiBanDocument{Board=new(){BackgroundColor="#FFFFFF",GridStyle="blank"},Objects=[
                new(){Id="below",Type="rect",X=0,Y=0,Width=320,Height=240,FillColor="#D8E9DE",ZIndex=0},
                new(){Id="moving-a",Type="rect",X=30,Y=30,Width=70,Height=60,FillColor="#EF4444",Opacity=.8,ZIndex=1},
                new(){Id="between",Type="rect",X=90,Y=50,Width=80,Height=120,FillColor="#3366CC",ZIndex=2},
                new(){Id="moving-b",Type="rect",X=180,Y=80,Width=60,Height=60,FillColor="#F6CE75",ZIndex=3},
                new(){Id="front",Type="rect",X=210,Y=120,Width=80,Height=50,FillColor="#824C95",ZIndex=4}]};
            foreach(var budget in new[]{0L,64L*1024*1024})
            {
                var session=new EditorSession();session.Open(DocumentCodec.Clone(doc));session.SetSelection(new[]{"moving-a","moving-b"});
                var original=DocumentCodec.Encode(session.Document);var drag=new ObjectDragPreview(session,new(0,0));var vp=new ViewportTransform();
                using var cache=new ObjectDragRenderer(budget);using var renderer=new Direct2DCanvasRenderer();using var referenceRenderer=new Direct2DCanvasRenderer();
                using var target=new CanvasRenderTarget(CanvasSurface,320,240,96);using var reference=new CanvasRenderTarget(CanvasSurface,320,240,96);
                foreach(var offset in new[]{new InkPoint(0,0),new(20,10),new(60,40),new(-15,-10),new(20,10)})
                {
                    drag.Move(offset);
                    using(var ds=target.CreateDrawingSession()){renderer.RenderBackground(ds,session.Document.Board,vp,320,240);cache.Draw(ds,target,renderer,drag,vp,320,240);}
                    var expected=new EditorSession();expected.Open(DocumentCodec.Clone(doc));foreach(var item in expected.Document.Objects.Where(o=>o.Id is "moving-a" or "moving-b"))expected.Move(item,offset.X,offset.Y);
                    using(var ds=reference.CreateDrawingSession()){referenceRenderer.RenderBackground(ds,expected.Document.Board,vp,320,240);referenceRenderer.RenderObjects(ds,expected.DrawingObjects,vp,320,240);}
                    var actual=target.GetPixelBytes();var want=reference.GetPixelBytes();var difference=actual.Zip(want,(a,b)=>Math.Abs(a-b)).Max();maxDifference=Math.Max(maxDifference,difference);frames++;
                    Check(difference<=2,"Cached drag differs from full reference: "+difference);
                    Check(DocumentCodec.Encode(session.Document)==original&&!session.HasTransaction,"GPU preview changed document");
                }
                Check(cache.Builds==1&&cache.BitmapBytes<=budget,"Static paint runs rebuilt per move or exceeded bitmap budget");
                if(budget==0)Check(cache.BitmapBytes==0,"Command-list fallback allocated raster cache");
                await target.SaveAsync(Path.Combine(output,"drag-"+budget+".png"),CanvasBitmapFileFormat.Png);
            }
            var screen=await _screenAnnotation!.ValidateObjectDragAsync();
            await PrepareMarqueeValidationAsync(Path.Combine(output,"fixture"),true);Title="HeiBan object drag QA";
            var stroke=new BoardObject{Id="drag-stroke",Type="stroke",X=236,Y=216,Width=88,Height=68,StrokeColor="#EF4444",StrokeWidth=8,ZIndex=100};stroke.SetCompletedInkPoints([new(240,220),new(320,280),new(240,280),new(320,220)]);_session.AppendInk(stroke);_session.SelectedId=stroke.Id;RefreshEditor();PresentInteraction(true);
            var results=new List<object>();InkPoint? origin=null;var sceneStart=0L;var generation=0L;var previewUnchanged=true;var cacheBuilds=0;var moves=0;var dragFrames=0;
            CanvasSurface.PointerPressed+=(_,e)=>
            {
                if(!_objectDragArmed)return;var p=e.GetCurrentPoint(CanvasSurface).Position;origin=_viewport.ScreenToWorld(p.X,p.Y);sceneStart=_sceneBuilds;generation=_session.Generation;previewUnchanged=true;cacheBuilds=moves=dragFrames=0;
            };
            CanvasSurface.Draw+=(_,_)=>{if(_objectDrag is not null){dragFrames++;cacheBuilds=Math.Max(cacheBuilds,_objectDragRenderer?.Builds??0);previewUnchanged&=stroke.X==236&&stroke.Y==216&&!_session.HasTransaction&&_session.Generation==generation;}};
            CanvasSurface.PointerMoved+=(_,_)=>{if(_objectDrag is not null)moves++;};
            CanvasSurface.PointerReleased+=async(_,e)=>
            {
                if(origin is not { } start)return;origin=null;var p=e.GetCurrentPoint(CanvasSurface).Position;var end=_viewport.ScreenToWorld(p.X,p.Y);var rebuildDuring=_sceneBuilds-sceneStart;
                await Task.Delay(100);var deltaX=end.X-start.X;var deltaY=end.Y-start.Y;
                var correct=Math.Abs(stroke.X-(236+deltaX))<.01&&Math.Abs(stroke.Y-(216+deltaY))<.01;
                results.Add(new{moves,dragFrames,cacheBuilds,previewUnchanged,rebuildDuring,oneCommit=_session.Generation==generation+1,correct,success=moves>0&&dragFrames>0&&cacheBuilds==1&&previewUnchanged&&rebuildDuring==0&&correct&&_session.Generation==generation+1});
                await File.WriteAllTextAsync(Path.Combine(output,"gestures.json"),JsonSerializer.Serialize(results));
            };
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,checks,frames,maxDifference,screen}));
            File.WriteAllText(Path.Combine(output,"ready.txt"),"Drag the selected red stroke, then click cane twice to inspect mute.");
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());}
    }
}
#endif
