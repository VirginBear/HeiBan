using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

// Owned by one sequential background task. Neither its mutable document nor
// pointer list is shared with rendering: only isolated snapshots cross to UI.
internal sealed class BoardEraserWork
{
    private readonly EditorSession _editor=new();
    private readonly ViewportTransform _viewport;
    private readonly double _gripX,_gripY;
    private readonly bool _whole;
    private InkPoint? _last;
    private int _cancelled;
    public bool Changed {get;private set;}
    internal void Cancel()=>Volatile.Write(ref _cancelled,1);
    internal BoardEraserWork(HeiBanDocument document,ViewportTransform viewport,double gripX,double gripY,bool whole)
    {_editor.Open(document);_viewport=viewport;_gripX=gripX;_gripY=gripY;_whole=whole;}

    internal HeiBanDocument? Apply(IReadOnlyList<InkPoint> samples)
    {
        using var trace=InputLatencyTrace.Measure(InputStage.EraserApply);
        var changed=false;
        foreach(var point in samples)
        {
            if(Volatile.Read(ref _cancelled)!=0)return null;
            if(_last is { } previous&&Math.Abs(point.X-previous.X)+Math.Abs(point.Y-previous.Y)<.01)continue;
            var from=_last??point;var dx=point.X-from.X;var dy=point.Y-from.Y;
            var steps=Math.Max(1,(int)Math.Ceiling(Math.Sqrt(dx*dx+dy*dy)/BoardEraserGeometry.SweepStep));
            for(var i=1;i<=steps;i++)
            {
                if(Volatile.Read(ref _cancelled)!=0)return null;
                var x=from.X+dx*i/steps-_gripX;var y=from.Y+dy*i/steps-_gripY;
                var contact=BoardEraserGeometry.ContactAt(x,y);
                for(var j=0;j<contact.Length;j++)contact[j]=_viewport.ScreenToWorld(contact[j].X,contact[j].Y);
                changed|=_editor.EraseFootprintChanged(new EraserFootprint(contact),_whole);
            }
            _last=point;
        }
        Changed|=changed;
        return changed?DocumentCodec.Clone(_editor.Document):null;
    }
}
