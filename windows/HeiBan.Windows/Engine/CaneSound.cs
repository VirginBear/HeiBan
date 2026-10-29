using System.Runtime.InteropServices;

namespace HeiBan.Windows.Engine;

internal static class CaneSound
{
    private static readonly string FileName=System.IO.Path.Combine(AppContext.BaseDirectory,"Assets","CaneSnap.wav");
    internal static void Play()
    {
        // ASYNC returns before playback finishes. Rapid taps replace the previous
        // short cue; missing audio stays silent instead of playing a Windows beep.
        PlaySound(FileName,0,0x00020000|0x0001|0x0002);
    }
    internal static void Stop()=>PlaySound(null,0,0);
    [DllImport("winmm.dll",CharSet=CharSet.Unicode,EntryPoint="PlaySoundW")]
    [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool PlaySound(string? sound,nint module,uint flags);
}
