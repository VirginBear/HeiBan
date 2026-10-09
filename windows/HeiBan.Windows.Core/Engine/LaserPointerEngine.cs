using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public sealed record LaserSample(InkPoint Point, double Timestamp, bool StartsTrail);

/// <summary>Bounded transient samples; never become document objects or undo transactions.</summary>
public sealed class LaserPointerEngine
{
    public string Mode { get; set; } = "shortTrail";
    public string Color { get; set; } = "#EF4444";
    public double Width { get; set; } = 8;
    public double PointDiameter { get; set; } = 16;
    public double FadeDuration { get; set; } = .8;
    public bool WhiteCore { get; set; } = true;
    private readonly List<LaserSample> _samples=[];
    private bool _start=true;
    public IReadOnlyList<LaserSample> Samples => _samples;
    public void Add(InkPoint point,double now)
    {
        Prune(now);
        _samples.Add(new(DocumentCodec.Clone(point),now,_start));_start=false;
        if(_samples.Count>500)_samples.RemoveRange(0,_samples.Count-500);
    }
    public void EndTrail()=>_start=true;
    public void Prune(double now)=>_samples.RemoveAll(s=>now-s.Timestamp>Math.Clamp(FadeDuration,.1,10));
    public void Clear(){_samples.Clear();_start=true;}
}
