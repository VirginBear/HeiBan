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
    // Match the Mac presentation lifetimes without altering saved tool settings.
    public double Lifetime=>Mode switch {"point"=>.3,"shortTrail"=>Math.Clamp(FadeDuration,.2,.8),_=>Math.Clamp(FadeDuration,.2,10)};
    public void Add(InkPoint point,double now)
    {
        Prune(now);
        if(!_start&&_samples.Count>0&&now-_samples[^1].Timestamp<1d/120
            &&Math.Abs(point.X-_samples[^1].Point.X)<.001&&Math.Abs(point.Y-_samples[^1].Point.Y)<.001)return;
        _samples.Add(new(DocumentCodec.Clone(point),now,_start));_start=false;
        if(_samples.Count>500)_samples.RemoveRange(0,_samples.Count-500);
    }
    public void EndTrail()=>_start=true;
    public void Prune(double now)=>_samples.RemoveAll(s=>now-s.Timestamp>Lifetime);
    public void Clear(){_samples.Clear();_start=true;}
}
