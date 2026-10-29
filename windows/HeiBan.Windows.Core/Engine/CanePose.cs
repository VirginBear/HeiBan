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
}
