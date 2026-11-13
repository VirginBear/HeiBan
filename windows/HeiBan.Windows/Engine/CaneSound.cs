namespace HeiBan.Windows.Engine;

internal static class CaneSound
{
    private static readonly LocalEffectSound Swing=new("CaneSnap.wav"),Snap=new("CaneImpact1.wav"),Second=new("CaneImpact2.wav"),Crack=new("CaneRockBreak.wav");
    internal static bool IsMuted {get=>Snap.IsMuted;set{Swing.IsMuted=value;Snap.IsMuted=value;Second.IsMuted=value;Crack.IsMuted=value;}}
    internal static void Prepare(){Swing.Prepare();Snap.Prepare();Second.Prepare();Crack.Prepare();}
    internal static void Play(Action<string> report)=>Snap.Play(report);
    internal static void PlaySwing(Action<string> report)=>Swing.Play(report);
    internal static void PlayImpact(int number,Action<string> report)=>(number==3?Crack:number==2?Second:Snap).Play(report);
    internal static void PlayCrack(Action<string> report)=>Crack.Play(report);
    internal static void Stop(){Swing.Stop();Snap.Stop();Second.Stop();Crack.Stop();}
    internal static void Dispose(){Swing.Dispose();Snap.Dispose();Second.Dispose();Crack.Dispose();}
#if HEIBAN_RELEASE_VALIDATION
    internal static bool ValidationSwingRequested=>Swing.ValidationRequested;
    internal static bool ValidationRequested=>Snap.ValidationRequested;
    internal static bool ValidationCrackRequested=>Crack.ValidationRequested;
    internal static bool ValidationSecondRequested=>Second.ValidationRequested;
#endif
}
