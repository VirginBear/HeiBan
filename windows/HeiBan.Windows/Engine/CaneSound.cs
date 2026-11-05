namespace HeiBan.Windows.Engine;

internal static class CaneSound
{
    private static readonly LocalEffectSound Snap=new("CaneSnap.wav"),Crack=new("CaneCrack.wav");
    internal static bool IsMuted {get=>Snap.IsMuted;set{Snap.IsMuted=value;Crack.IsMuted=value;}}
    internal static void Prepare(){Snap.Prepare();Crack.Prepare();}
    internal static void Play(Action<string> report)=>Snap.Play(report);
    internal static void PlayCrack(Action<string> report)=>Crack.Play(report);
    internal static void Stop(){Snap.Stop();Crack.Stop();}
    internal static void Dispose(){Snap.Dispose();Crack.Dispose();}
#if HEIBAN_RELEASE_VALIDATION
    internal static bool ValidationRequested=>Snap.ValidationRequested;
    internal static bool ValidationCrackRequested=>Crack.ValidationRequested;
#endif
}
