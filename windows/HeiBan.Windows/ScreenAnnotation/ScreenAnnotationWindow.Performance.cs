using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using System.Diagnostics;
using System.Text.Json;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<object> RunPerformanceBatchAsync()
    {
        await StartAsync();
        try { return new { width=_overlay.Width,height=_overlay.Height,pixelDpi=96,dpiScale=_dpiScale,preview = ValidatePreviewPerformance(), stroke = ValidateStrokePerformance() }; }
        finally { await StopAsync(); }
    }
    // Opt-in native validation only: isolated data, deterministic samples, no hardware input claim.
    private void DamageSelectedObjects()
    {
        foreach(var o in _session.SelectedObjects)
        {
            if(o.Extension is "start" or "end" or "both"){_fullDamage=true;continue;}
            var corners=ObjectHandles.Outline(o);var pad=Math.Max(40*_dpiScale,o.StrokeWidth+(o.ArrowHeadLength??0));
            // Catmull-Rom curves can extend beyond point bounds; include their control hull after rotation.
            if(o.Type is "stroke" or "pen" or "highlighter" or "paint" or "curve")pad+=Math.Sqrt(o.Width*o.Width+o.Height*o.Height)/3;
            var left=Math.Max(0,Math.Floor(corners.Min(p=>p.X)-pad));var top=Math.Max(0,Math.Floor(corners.Min(p=>p.Y)-pad));
            var right=Math.Min(_overlay.Width,Math.Ceiling(corners.Max(p=>p.X)+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(corners.Max(p=>p.Y)+pad));
            if(right<=left||bottom<=top)continue;
            if(_damage is { } old){left=Math.Min(left,old.Left);top=Math.Min(top,old.Top);right=Math.Max(right,old.Right);bottom=Math.Max(bottom,old.Bottom);}
            _damage=new(left,top,right-left,bottom-top);
        }
    }
    private void DamagePreview()
    {
        if(_preview is null)return;var corners=ObjectHandles.Outline(_preview);var pad=_preview.StrokeWidth+40*_dpiScale;
        var left=Math.Max(0,Math.Floor(corners.Min(p=>p.X)-pad));var top=Math.Max(0,Math.Floor(corners.Min(p=>p.Y)-pad));
        var right=Math.Min(_overlay.Width,Math.Ceiling(corners.Max(p=>p.X)+pad));var bottom=Math.Min(_overlay.Height,Math.Ceiling(corners.Max(p=>p.Y)+pad));
        if(_damage is { } old){left=Math.Min(left,old.Left);top=Math.Min(top,old.Top);right=Math.Max(right,old.Right);bottom=Math.Max(bottom,old.Bottom);}
        if(right>left&&bottom>top)_damage=new(left,top,right-left,bottom-top);
    }
    private object ValidatePreviewPerformance()
    {
        var saved=DocumentCodec.Clone(_session.Document);var tool=_tool;_renderTimer.Stop();var frames=0;var bytes=0L;var regionalTimes=new List<double>();var fullTimes=new List<double>();
        try
        {
            CancelGesture();_session.SelectedId=null;_tool="pen";Render();var idleFrames=_renderedFrames;ChooseScreenTool("rect");if(_dirty||_renderedFrames!=idleFrames)throw new InvalidOperationException("無手勢換工具仍造成整屏重繪。");
            foreach(var key in new[]{"rect","circle","line","select"})
            {
                CancelGesture();_tool=key;_session.SelectedId=null;Changed();Render();OnPointer(new("down",1400,900));Render();
                for(var i=1;i<=8;i++)
                {
                    OnPointer(new("move",1400+i*12,900+i*8));var startBytes=_presentedBytes;var clock=Stopwatch.StartNew();Render();regionalTimes.Add(clock.Elapsed.TotalMilliseconds);bytes+=_presentedBytes-startBytes;
                    var pixels=_overlay.ReadPresentedPixels();_benchmarkFullFrames=true;clock.Restart();Render();fullTimes.Add(clock.Elapsed.TotalMilliseconds);_benchmarkFullFrames=false;
                    if(!pixels.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("圖形／框選局部預覽與整屏像素不一致："+key);frames++;
                }
                OnPointer(new("up",1500,970));Render();var committed=_overlay.ReadPresentedPixels();_benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
                var fullCommitted=_overlay.ReadPresentedPixels();
                if(!committed.AsSpan().SequenceEqual(fullCommitted))
                {
                    var first=-1;var different=0;var maxDelta=0;var channels=new int[4];
                    for(var pixel=0;pixel<committed.Length;pixel++)if(committed[pixel]!=fullCommitted[pixel])
                    {if(first<0)first=pixel;different++;channels[pixel%4]++;maxDelta=Math.Max(maxDelta,Math.Abs(committed[pixel]-fullCommitted[pixel]));}
                    throw new InvalidOperationException($"圖形／框選收筆局部重繪殘影：{key}; first=({first/4%_overlay.Width},{first/4/_overlay.Width}) channel={first%4} actual={committed[first]} expected={fullCommitted[first]} differences={different} maxDelta={maxDelta} BGRA={string.Join(',',channels)}");
                }
                frames++;
                _session.Open(DocumentCodec.Clone(saved));
            }
            var originalBytes=32L*_overlay.Width*_overlay.Height*4;if(bytes>=originalBytes*.25)throw new InvalidOperationException("圖形／框選預覽傳輸未減少75%。");
            var regionalSamplesMs=regionalTimes.ToArray();var fullSamplesMs=fullTimes.ToArray();
            regionalTimes.Sort();fullTimes.Sort();return new{pixelEquivalentFrames=frames,previewFrames=32,idleToolSwitchDoesNotRender=true,originalReadbackBytes=originalBytes,regionalReadbackBytes=bytes,regionalMedianMs=regionalTimes[regionalTimes.Count/2],fullMedianMs=fullTimes[fullTimes.Count/2],regionalSamplesMs,fullSamplesMs,regionalP95Ms=regionalTimes[(int)Math.Ceiling(regionalTimes.Count*.95)-1],regionalP99Ms=regionalTimes[(int)Math.Ceiling(regionalTimes.Count*.99)-1],fullP95Ms=fullTimes[(int)Math.Ceiling(fullTimes.Count*.95)-1],fullP99Ms=fullTimes[(int)Math.Ceiling(fullTimes.Count*.99)-1],scope="同步原生圖形／框選幀，非硬體輸入延遲"};
        }
        finally{_benchmarkFullFrames=false;CancelGesture();_session.Open(saved);_tool=tool;Changed();Render();_renderTimer.Start();}
    }
    private object ValidateStrokePerformance()
    {
        _renderTimer.Stop();
        var savedTool=_tool;var savedOpacity=_opacity;var savedLaserMode=_laser.Mode;var savedFade=_laser.FadeDuration;
        (double MedianMs,double P95Ms,double P99Ms,long Bytes,double[] SamplesMs,long InputRenderAllocatedBytes,int[] Collections) Measure(bool original)
        {
            CancelGesture();_tool="pen";_benchmarkFullFrames=original;Render();
            OnPointer(new("down",350,500));Render();
            var bytesBefore=_presentedBytes;var times=new List<double>(80);var collections=new[]{GC.CollectionCount(0),GC.CollectionCount(1),GC.CollectionCount(2)};var allocated=GC.GetAllocatedBytesForCurrentThread();
            for(var i=1;i<=80;i++)
            {
                OnPointer(new("move",350+i*8,500+Math.Sin(i*.13)*55));
                var timer=Stopwatch.StartNew();Render();times.Add(timer.Elapsed.TotalMilliseconds);
            }
            allocated=GC.GetAllocatedBytesForCurrentThread()-allocated;for(var g=0;g<3;g++)collections[g]=GC.CollectionCount(g)-collections[g];
            var samples=times.ToArray();times.Sort();var result=(times[times.Count/2],times[(int)Math.Ceiling(times.Count*.95)-1],times[(int)Math.Ceiling(times.Count*.99)-1],_presentedBytes-bytesBefore,samples,allocated,collections);
            CancelGesture();_benchmarkFullFrames=false;Render();return result;
        }
        try
        {
            var original=Measure(true);var optimized=Measure(false);
            if(optimized.Bytes>=original.Bytes*.2)throw new InvalidOperationException("局部像素傳輸未減少至少80%。");
            var verifiedFrames=0;
            foreach(var tool in new[]{"pen","highlighter"})
            {
                _tool=tool;_opacity=.65;CancelGesture();Render();OnPointer(new("down",500,650));Render();
                // Include sharp reversals, large jumps, screen edges and translucent joins.
                var samples=new[]{(510d,652d),(530d,720d),(510d,620d),(900d,650d),(901d,651d),(12d,12d),(2d,2d),(600d,680d)};
                foreach(var (x,y) in samples)
                {
                    OnPointer(new("move",x,y));Render();var regional=_overlay.ReadPresentedPixels();
                    _benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
                    if(!regional.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("局部重繪與完整重繪像素不一致："+tool);
                    verifiedFrames++;
                }
                OnPointer(new("up",610,690));Render();var committed=_overlay.ReadPresentedPixels();
                _benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
                if(!committed.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("收筆局部重繪像素不一致："+tool);
                verifiedFrames++;_session.Undo();Changed();CancelGesture();Render();
            }
            // Exercise the real pointer selection path, including preview offsets and old/new rotated bounds.
            _session.Begin();var movable=new BoardObject{Type="stroke",X=500,Y=400,Width=240,Height=120,Rotation=25,StrokeWidth=4,StrokeColor="#2563eb",
                Points=JsonSerializer.Serialize(new[]{new InkPoint(500,400),new InkPoint(620,460),new InkPoint(740,520)},DocumentCodec.Options)};
            _session.Add(movable);_session.Commit();_session.SelectedId=movable.Id;_tool="select";Changed();Render();
            var originalPoints=movable.Points;OnPointer(new("down",620,460));Render();var selectionBytes=0L;var selectionFrames=0;
            foreach(var (x,y) in new[]{(632d,468d),(646d,476d),(654d,482d)})
            {
                var beforeBytes=_presentedBytes;OnPointer(new("move",x,y));Render();selectionBytes+=_presentedBytes-beforeBytes;
                if(!ReferenceEquals(movable.Points,originalPoints))throw new InvalidOperationException("拖曳中重寫永久筆點。");
                var regional=_overlay.ReadPresentedPixels();_benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
                if(!regional.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("旋轉筆跡拖曳局部重繪有殘影。");
                selectionFrames++;
            }
            if(selectionBytes>=selectionFrames*_overlay.Width*(long)_overlay.Height)throw new InvalidOperationException("物件拖曳未減少至少75%像素傳輸。");
            OnPointer(new("up",654,482));Render();
            if(movable.PreviewOffsetX!=0||movable.ParsedPoints[0].X!=534||movable.ParsedPoints[0].Y!=422)throw new InvalidOperationException("螢幕拖曳筆點未正確提交。");
            _session.Undo();_session.Undo();Changed();CancelGesture();Render();
            _session.Begin();var broad=new BoardObject{Type="stroke",X=850,Y=500,Width=1000,Height=600,StrokeWidth=8,StrokeColor="#a855f7",
                Points=JsonSerializer.Serialize(new[]{new InkPoint(850,500),new InkPoint(1850,500),new InkPoint(1850,1100),new InkPoint(850,1100)},DocumentCodec.Options)};
            _session.Add(broad);_session.Commit();_session.SelectedId=broad.Id;Changed();Render();OnPointer(new("down",850,500));Render();if(_marquee||_session.SelectedId!=broad.Id)throw new InvalidOperationException("大曲線拖曳檢查未命中實際曲線。");
            OnPointer(new("move",862,508));Render();var broadRegional=_overlay.ReadPresentedPixels();_benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
            if(!broadRegional.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("大幅彎曲筆跡拖曳留下邊界外殘影。");
            OnPointer(new("up",862,508));_session.Undo();_session.Undo();Changed();CancelGesture();Render();
            _tool="laser";_laser.Mode="point";_laser.FadeDuration=.1;
            var laserBytesBefore=_presentedBytes;OnPointer(new("move",1000,500));Render();OnPointer(new("move",1010,505));Render();
            var laserReadbackBytes=_presentedBytes-laserBytesBefore;
            if(laserReadbackBytes>_overlay.Width*_overlay.Height*4/10)throw new InvalidOperationException("雷射未使用局部傳輸。");
            _laser.Clear();Render();var cleared=_overlay.ReadPresentedPixels();_benchmarkFullFrames=true;Render();_benchmarkFullFrames=false;
            if(!cleared.AsSpan().SequenceEqual(_overlay.ReadPresentedPixels()))throw new InvalidOperationException("雷射消退後殘影。");
            _tool="pen";var frames=_renderedFrames;OnPointer(new("move",700,700));
            if(_dirty||_renderedFrames!=frames)throw new InvalidOperationException("畫筆懸停造成無效重繪。");
            return new{samplesPerRun=80,originalMedianMs=original.MedianMs,originalP95Ms=original.P95Ms,originalP99Ms=original.P99Ms,optimizedMedianMs=optimized.MedianMs,optimizedP95Ms=optimized.P95Ms,optimizedP99Ms=optimized.P99Ms,originalSamplesMs=original.SamplesMs,optimizedSamplesMs=optimized.SamplesMs,originalInputRenderAllocatedBytes=original.InputRenderAllocatedBytes,optimizedInputRenderAllocatedBytes=optimized.InputRenderAllocatedBytes,originalCollections=original.Collections,optimizedCollections=optimized.Collections,allocationScope="Pointer handler + render + diagnostic Stopwatch allocations on UI thread; excludes async worker allocations",originalReadbackBytes=original.Bytes,optimizedReadbackBytes=optimized.Bytes,pixelEquivalentFrames=verifiedFrames,selectionPixelEquivalentFrames=selectionFrames,selectionReadbackBytes=selectionBytes,selectionPreviewCommitUndo=true,largeCurveOvershootPixelEquivalent=true,laserReadbackBytes,laserClearsWithoutGhosting=true,idleHoverDoesNotRender=true,scheduledIntervalMs=16,scope="同步原生幀測量，非實體滑鼠／手寫端到端延遲；original為此binary的完整重繪參考，不是本批前測"};
        }
        finally{_benchmarkFullFrames=false;_laser.Clear();_laser.Mode=savedLaserMode;_laser.FadeDuration=savedFade;CancelGesture();_tool=savedTool;_opacity=savedOpacity;Render();_renderTimer.Start();}
    }
}
