namespace HeiBan.Windows.Engine;

/// <summary>Angles measured from the screen horizontal; grip stays at the lower right.</summary>
public static class CanePose
{
    public const double RestDegrees=45;
    public const double RaisedDegrees=75;
    public const double ImpactSeconds=.075;
    public static double ArtworkRestRotationDegrees(double width,double height)
        =>RestDegrees-Math.Atan2(height*.83,width*.87)*180/Math.PI;
    public static double SwingDegrees(double elapsed)
    {
        if(elapsed<0||elapsed>=CaneFeedback.Duration)return 0;
        if(elapsed<.035)return (RaisedDegrees-RestDegrees)*Math.Sin(elapsed/.035*Math.PI*.5);
        if(elapsed<ImpactSeconds)return (RaisedDegrees-RestDegrees)*(1-Math.Sin((elapsed-.035)/.04*Math.PI*.5));
        // Keep the small elastic rebound within the requested 45–75 degree envelope.
        return 8*Math.Sin((elapsed-ImpactSeconds)/(CaneFeedback.Duration-ImpactSeconds)*Math.PI);
    }
    // Convex hull of the shipped sprite's alpha>=128 body, not its transparent frame.
    private static readonly (double X,double Y)[] Body=[(0.0450281,0.0762195),(0.0462789,0.0721545),(0.0481551,0.0691057),(0.0506567,0.0670732),(0.0569106,0.0670732),(0.0606629,0.0691057),(0.0656660,0.0731707),(0.8799250,0.8760163),(0.8893058,0.8861789),(0.8936836,0.8932927),(0.8955597,0.8993902),(0.8961851,0.9024390),(0.8961851,0.9156504),(0.8955597,0.9186992),(0.8943089,0.9237805),(0.8930582,0.9268293),(0.8905566,0.9319106),(0.8880550,0.9359756),(0.8855535,0.9390244),(0.8836773,0.9400407),(0.8811757,0.9410569),(0.8767980,0.9410569),(0.8742964,0.9400407),(0.8624140,0.9308943),(0.7617261,0.8333333),(0.5215760,0.5853659),(0.3320826,0.3892276),(0.0562852,0.1026423),(0.0525328,0.0985772),(0.0469043,0.0894309),(0.0456535,0.0853659),(0.0450281,0.0823171)];
    public static ToolArtBounds DockBounds(double width,double height)
    {
        var radians=ArtworkRestRotationDegrees(width,height)*Math.PI/180;var c=Math.Cos(radians);var s=Math.Sin(radians);
        return ToolArtBounds.From(Body.Select(p=>
        {var x=(p.X-.5)*width;var y=(p.Y-.5)*height;return (X:width/2+x*c-y*s,Y:height/2+x*s+y*c);}));
    }
}
