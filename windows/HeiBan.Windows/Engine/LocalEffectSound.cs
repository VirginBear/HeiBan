using System.Runtime.InteropServices;
using global::Windows.Media.Core;
using global::Windows.Media.Playback;

namespace HeiBan.Windows.Engine;

internal sealed class LocalEffectSound
{
    private readonly string _asset;
    internal LocalEffectSound(string asset)=>_asset=asset;
    private volatile bool _muted;
    internal bool IsMuted
    {
        get=>_muted;
        set
        {
            _muted=value;if(value)Stop();
            if(_player is not null)_player.IsMuted=value;
        }
    }
    private MediaPlayer? _player;
    private MediaSource? _source;
    private GCHandle _wave;
    private bool _prepared;
    private volatile bool _opened,_mediaFailed,_requested;
    private static readonly object FallbackGate=new();
    private Action<string>? _report;
#if HEIBAN_RELEASE_VALIDATION
    internal bool ValidationRequested=>_requested;
#endif
    internal void Prepare()
    {
        if(_prepared)return;_prepared=true;
        try
        {
            var file=System.IO.Path.Combine(AppContext.BaseDirectory,"Assets",_asset);
            // Retain a pinned in-memory fallback until playback is stopped at shutdown.
            // This also avoids PlaySound's filename-length limit in extracted trials.
            _wave=GCHandle.Alloc(File.ReadAllBytes(file),GCHandleType.Pinned);
            var player=new MediaPlayer{AutoPlay=false,AudioCategory=MediaPlayerAudioCategory.SoundEffects,Volume=1,IsMuted=_muted};
            _player=player;player.CommandManager.IsEnabled=false;
            player.MediaOpened+=(sender,_)=>{if(ReferenceEquals(_player,sender))_opened=true;};
            player.MediaFailed+=(sender,args)=>
            {
                if(!ReferenceEquals(_player,sender))return;
                _mediaFailed=true;var error=args.ExtendedErrorCode??new InvalidOperationException(args.ErrorMessage);
                Diagnostics.CanvasSurfaceDiagnostics.Record("effect-media",error);
                if(_requested&&!PlayFallback())Report(error);
            };
            _source=MediaSource.CreateFromUri(new Uri(file));player.Source=_source;
        }
        catch(Exception e) when(e is not OutOfMemoryException)
        {_mediaFailed=true;Diagnostics.CanvasSurfaceDiagnostics.Record("effect-prepare",e);}
    }
    internal void Play(Action<string> report)
    {
        if(_muted)return;
        _report=report;_requested=true;Prepare();
        try
        {
            if(_mediaFailed||_player is null){if(!PlayFallback())Report(new InvalidOperationException("Audio output unavailable"));return;}
            if(_opened){_player.Pause();_player.PlaybackSession.Position=TimeSpan.Zero;}
            _player.Play();
        }
        catch(Exception e) when(e is not OutOfMemoryException)
        {Diagnostics.CanvasSurfaceDiagnostics.Record("effect-play",e);if(!PlayFallback())Report(e);}
    }
    private bool PlayFallback(){lock(FallbackGate)return !_muted&&_requested&&_wave.IsAllocated&&PlaySound(_wave.AddrOfPinnedObject(),0,0x0004|0x0001|0x0002); }
    private void Report(Exception e)=>_report?.Invoke($"0x{e.HResult:X8}");
    internal void Stop()
    {
        _requested=false;
        try{_player?.Pause();}catch(Exception e) when(e is not OutOfMemoryException){Diagnostics.CanvasSurfaceDiagnostics.Record("effect-stop",e);}
        lock(FallbackGate){if(_wave.IsAllocated)PlaySound(0,0,0);}
    }
    internal void Dispose()
    {
        Stop();var player=_player;_player=null;
        try{player?.Dispose();_source?.Dispose();}
        catch(Exception e) when(e is not OutOfMemoryException){Diagnostics.CanvasSurfaceDiagnostics.Record("effect-dispose",e);}
        _source=null;
        lock(FallbackGate){if(_wave.IsAllocated)_wave.Free();}_prepared=_opened=_mediaFailed=false;_report=null;
    }
    [DllImport("winmm.dll",EntryPoint="PlaySoundW",ExactSpelling=true)]
    [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool PlaySound(nint sound,nint module,uint flags);
}
