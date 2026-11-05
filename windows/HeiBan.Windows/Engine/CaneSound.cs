namespace HeiBan.Windows.Engine;

internal static class CaneSound
{
    private static readonly LocalEffectSound Snap=new("CaneImpact1.wav"),Second=new("CaneImpact2.wav"),Crack=new("CaneRockBreak.wav");
    internal static bool IsMuted {get=>Snap.IsMuted;set{Snap.IsMuted=value;Second.IsMuted=value;Crack.IsMuted=value;}}
    internal static void Prepare(){Snap.Prepare();Second.Prepare();Crack.Prepare();}
    internal static void Play(Action<string> report)=>Snap.Play(report);
    internal static void PlayImpact(int number,Action<string> report)=>(number==3?Crack:number==2?Second:Snap).Play(report);
    internal static void PlayCrack(Action<string> report)=>Crack.Play(report);
    internal static void Stop(){Snap.Stop();Second.Stop();Crack.Stop();}
    internal static void Dispose(){Snap.Dispose();Second.Dispose();Crack.Dispose();}
#if HEIBAN_RELEASE_VALIDATION
    internal static bool ValidationRequested=>Snap.ValidationRequested;
    internal static bool ValidationCrackRequested=>Crack.ValidationRequested;
    internal static bool ValidationSecondRequested=>Second.ValidationRequested;
#endif
}
