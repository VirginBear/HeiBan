using System.Diagnostics;
using System.Text.Json;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.Foundation;
using global::Windows.UI;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private async Task<object> MeasureSupplementalScenesAsync()
    {
        const float width=1024,height=640;
        var images=new List<string>();
        // Four distinct embedded images: decode memory is 4*128*128*4, reused by 80 image objects.
        for(var i=0;i<4;i++)
        {
            using var image=new CanvasRenderTarget(CanvasSurface,128,128,96);
            using(var drawing=image.CreateDrawingSession()){drawing.Clear(Color.FromArgb(255,(byte)(40+i*40),90,120));drawing.FillCircle(64,64,20+i*5,Color.FromArgb(180,255,220,30));}
            using var stream=new MemoryStream();await image.SaveAsync(stream.AsRandomAccessStream(),CanvasBitmapFileFormat.Png);
            images.Add("data:image/png;base64,"+Convert.ToBase64String(stream.ToArray()));
        }
        var objects=Enumerable.Range(0,80).Select(i=>new BoardObject{Id="mixed-image-"+i,Type="image",ImageUrl=images[i%4],X=i%10*95,Y=i/10*72,Width=80,Height=60,ZIndex=i%9,Opacity=.7}).ToList();
        objects.AddRange(Enumerable.Range(0,100).Select(i=>new BoardObject{Id="mixed-text-"+i,Type="text",Text="中文效能 "+i,X=i%10*95,Y=i/10*58,Width=90,Height=35,FontSize=14,StrokeColor="#39735A",ZIndex=4}));
        var points=Enumerable.Range(0,12000).Select(i=>new InkPoint(i*.075,310+Math.Sin(i*.009)*90,.7){TiltX=10,TiltY=-3}).ToList();
        objects.Add(new BoardObject{Id="mixed-long-ink",Type="stroke",X=0,Y=220,Width=900,Height=180,StrokeWidth=3,Opacity=.6,StrokeColor="#2563eb",ZIndex=7,Points=JsonSerializer.Serialize(points,DocumentCodec.Options)});
        _session.Open(new(){Board=new BoardMetadata{BackgroundColor="#ffffff",GridStyle="blank",CanvasMode="infinite"},Objects=objects});
        _viewport.X=_viewport.Y=0;_viewport.Zoom=1;_renderer.ClearCache();ClearScene();
        var decodeStart=Stopwatch.GetTimestamp();await _renderer.LoadImagesAsync(CanvasSurface,objects);var coldImageDecodeMs=Stopwatch.GetElapsedTime(decodeStart).TotalMilliseconds;
        using var target=new CanvasRenderTarget(CanvasSurface,width,height,CanvasSurface.Dpi);
        void Draw(){using(var ds=target.CreateDrawingSession())RenderMainScene(CanvasSurface,ds,width,height);_ = target.GetPixelBytes(0,0,1,1);}
        var coldStart=Stopwatch.GetTimestamp();Draw();var coldSceneMs=Stopwatch.GetElapsedTime(coldStart).TotalMilliseconds;
        var stable=PerformanceMeasurement.Measure(Draw);
        var rebuild=PerformanceMeasurement.Measure(()=>{_sceneDirty=true;Draw();});
        var pan=PerformanceMeasurement.Measure(()=>{_viewport.X=_viewport.X==0?-30:0;Draw();});
        var zoom=PerformanceMeasurement.Measure(()=>{_viewport.Zoom=_viewport.Zoom==1?1.1:1;Draw();});
        var pixelEquivalentFrames=0;
        void Compare()
        {
            using(var ds=target.CreateDrawingSession())
            {
                _renderer.RenderBackground(ds,_session.Document.Board,_viewport,width,height);
                using(var clip=ds.CreateLayer(1,new Rect(0,0,width,height)))_renderer.RenderObjects(ds,_session.VisibleObjects,_viewport,width,height);
            }
            var expected=target.GetPixelBytes();_sceneDirty=true;Draw();
            if(!expected.AsSpan().SequenceEqual(target.GetPixelBytes()))throw new InvalidOperationException("混合圖片／文字／长筆跡順序或scene像素不一致。");
            pixelEquivalentFrames++;
        }
        Compare();_session.Document.Objects[0].ZIndex=1000;Compare();_session.Document.Objects.Reverse();Compare();
        _viewport.X=_viewport.Y=0;_viewport.Zoom=1;
        void Live(){using(var ds=target.CreateDrawingSession()){ds.Clear(Color.FromArgb(0,0,0,0));_renderer.RenderLiveStroke(ds,points,_viewport,"#39735A",3,.6,"solid");}_ = target.GetPixelBytes(0,0,1,1);}
        var liveInk=PerformanceMeasurement.Measure(Live);
        var preview=new BoardObject{Type="rect",X=100,Y=100,Width=180,Height=80,Rotation=25,StrokeColor="#39735A",Opacity=.6,StrokeWidth=3};
        void Preview(bool original){using(var ds=target.CreateDrawingSession()){ds.Clear(Color.FromArgb(0,0,0,0));if(original)_renderer.RenderObjects(ds,new[]{preview},_viewport,width,height);else _renderer.RenderPreview(ds,preview,_viewport,width,height);}_ = target.GetPixelBytes(0,0,1,1);}
        Preview(true);var previewPixels=target.GetPixelBytes();Preview(false);
        if(!previewPixels.AsSpan().SequenceEqual(target.GetPixelBytes()))throw new InvalidOperationException("單物件預覽像素不一致。");
        var arrayPreviewReference=PerformanceMeasurement.Measure(()=>Preview(true));var singlePreview=PerformanceMeasurement.Measure(()=>Preview(false));
        return new{objects=181,imageObjects=80,uniqueImages=4,imagePixelWidth=128,imagePixelHeight=128,decodedImageBytes=262144,embeddedPngBytes=images.Sum(s=>Convert.FromBase64String(s[(s.IndexOf(',')+1)..]).Length),textObjects=100,strokePoints=12000,coldImageDecodeMs,coldSceneMs,stable,rebuild,pan,zoom,liveInk,arrayPreviewReference,singlePreview,pixelEquivalentFrames,previewPixelEquivalent=true,scope="Supplemental same-binary reference comparisons; cold timings one sample; live ink is a warm fixed 12000-point stroke, not pointer latency"};
    }
}
