using System.Diagnostics;
using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>Opt-in synthetic CPU comparison against the previous JSON-based paths; no user document is sampled.</summary>
public static class InteractionBenchmark
{
    public static object Run()
    {
        static T LegacyClone<T>(T value)=>JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(value,DocumentCodec.Options),DocumentCodec.Options)!;
        static (double Ms,long Bytes) Measure(Action action,int count)
        {
            action();var allocated=GC.GetAllocatedBytesForCurrentThread();var clock=Stopwatch.StartNew();
            for(var i=0;i<count;i++)action();clock.Stop();return(clock.Elapsed.TotalMilliseconds,GC.GetAllocatedBytesForCurrentThread()-allocated);
        }
        var image="data:image/png;base64,"+new string('A',2*1024*1024);
        var document=new HeiBanDocument{Objects=Enumerable.Range(0,600).Select(i=>new BoardObject{Id="fixture-"+i,Type=i==599?"image":"text",ImageUrl=i==599?image:null,Text="中文文字與效能量測",ZIndex=i}).ToList()};
        var cloneOld=Measure(()=>_ = LegacyClone(document),8);var cloneNew=Measure(()=>_ = DocumentCodec.Clone(document),8);
        var session=new EditorSession();session.Open(document);session.SelectedId="fixture-598";
        var selectedOld=Measure(()=>_ = document.Objects.FirstOrDefault(o=>o.Id==session.SelectedObjects.OrderBy(o=>o.IsLocked==true).ThenByDescending(o=>o.ZIndex).FirstOrDefault()?.Id),100);
        var selectedNew=Measure(()=>_ = session.Selected,100);
        var points=Enumerable.Range(0,2000).Select(i=>new InkPoint(i,Math.Sin(i*.02)*50,1)).ToArray();
        var stroke=new BoardObject{Type="stroke",Points=JsonSerializer.Serialize(points,DocumentCodec.Options),Width=2000,Height=100};
        var original=LegacyClone(stroke);var pointStorage=stroke.Points;
        var oldMove=Measure(()=>
        {
            original.X+=1;original.Y+=.5;
            original.Points=JsonSerializer.Serialize(original.ParsedPoints.Select(p=>{var copy=LegacyClone(p);copy.X+=1;copy.Y+=.5;return copy;}),DocumentCodec.Options);
        },40);
        var preview=new EditorSession();preview.Open(new(){Objects=[stroke]});preview.SelectedId=stroke.Id;preview.Begin();
        var newMove=Measure(()=>preview.PreviewMoveSelection(1,.5),40);
        if(!ReferenceEquals(pointStorage,preview.Document.Objects[0].Points))throw new InvalidOperationException("Preview changed point storage.");
        var finish=Stopwatch.StartNew();preview.Commit();finish.Stop();
        return new{scope="同程序合成CPU／配置量比較，非硬體輸入延遲",snapshotCopies=8,imagePayloadBytes=image.Length,objects=600,
            legacyCloneMs=cloneOld.Ms,snapshotCloneMs=cloneNew.Ms,legacyCloneAllocatedBytes=cloneOld.Bytes,snapshotCloneAllocatedBytes=cloneNew.Bytes,
            selectionLookups=100,legacySelectionMs=selectedOld.Ms,selectionMs=selectedNew.Ms,
            dragEvents=40,strokePoints=2000,legacyDragMs=oldMove.Ms,previewDragMs=newMove.Ms,legacyDragAllocatedBytes=oldMove.Bytes,previewDragAllocatedBytes=newMove.Bytes,dragCommitMs=finish.Elapsed.TotalMilliseconds};
    }
}
