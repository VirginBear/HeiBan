#if HEIBAN_RELEASE_VALIDATION
using static HeiBan.Windows.Localization.Strings;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private async Task RunSelectionFeedbackValidationAsync(string output)
    {
        Directory.CreateDirectory(output);
        try
        {
            var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
            var fixture=new HeiBanDocument{Board=new(){CanvasMode="fixed",CanvasWidth=600,CanvasHeight=500,GridStyle="blank",BackgroundColor="#183B2B"},Objects=[
                new(){Id="outer",Type="rect",X=180,Y=220,Width=150,Height=100,StrokeWidth=2,StrokeColor="#D2E5D5",FillColor="none",ZIndex=1},
                new(){Id="top",Type="rect",X=220,Y=240,Width=80,Height=70,StrokeWidth=2,StrokeColor="#F6CE75",FillColor="none",ZIndex=2},
                new(){Id="separate",Type="rect",X=400,Y=220,Width=80,Height=90,StrokeWidth=2,StrokeColor="#8CB8E2",FillColor="none",ZIndex=3}]};
            await OpenAsync(fixture);await Task.Delay(200);
            Check(await CopyCanvasAreaAsync(new(0,0,600,500),new(_session.DocumentEpoch,null)) is not null,"Capture failed");
            Check(CanvasCaptureToast.Visibility==Visibility.Visible&&CanvasCaptureToastText.Text==T("畫布已截圖"),"Central success toast missing");
            await Task.Delay(2200);Check(CanvasCaptureToast.Visibility==Visibility.Collapsed,"Success toast did not dismiss");
            var draft=DocumentCodec.Clone(_toolbarPrefs);draft.CaneMuted=true;await SaveToolbarPreferencesAsync(draft);
            Check(ToolbarPreferencesStore.Load(_storage.DataDirectory).CaneMuted&&CaneSound.IsMuted,"Mute did not persist");
            Check(_screenAnnotation?.ValidationCaneMuted==true,"Hidden screen preferences stale");
            CaneSound.Play(_=>{});Check(!CaneSound.ValidationRequested,"Muted strike requested playback");
            draft=DocumentCodec.Clone(_toolbarPrefs);draft.CaneMuted=false;await SaveToolbarPreferencesAsync(draft);
            Check(!ToolbarPreferencesStore.Load(_storage.DataDirectory).CaneMuted&&!CaneSound.IsMuted&&_screenAnnotation?.ValidationCaneMuted==false,"Unmute did not persist/shared");
            var screen=await _screenAnnotation!.ValidatePointSelectionAsync();
            await OpenAsync(fixture);_rulerEnabled=false;_compass.IsEnabled=false;_readingMode=false;_viewLocked=false;
            ActivateTool("select");_viewport.X=_viewport.Y=0;_viewport.Zoom=1;
            _session.SetSelection(new[]{"outer","top"});RefreshEditor();AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1200,820));Title="HeiBan selection feedback QA";
            await File.WriteAllTextAsync(Path.Combine(output,"result.json"),JsonSerializer.Serialize(new{success=true,checks,centralToast=true,toastAutoDismiss=true,muteSaved=true,sharedMute=true,mutedPlaybackSuppressed=true,screen}));
            var previous="";var timer=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(150)};
            timer.Tick+=(_,_)=>
            {
                var state=JsonSerializer.Serialize(new{selected=_session.SelectedIds.Order().ToArray(),generation=_session.Generation,undo=_session.CanUndo,muted=_toolbarPrefs.CaneMuted,audioMuted=CaneSound.IsMuted,screenMuted=_screenAnnotation.ValidationCaneMuted,toast=CanvasCaptureToast.Visibility==Visibility.Visible,objects=_session.Document.Objects.Select(o=>new{o.Id,o.X,o.Y})});
                if(state==previous)return;previous=state;File.WriteAllText(Path.Combine(output,"live.json"),state);
            };timer.Start();Closed+=(_,_)=>timer.Stop();
            File.WriteAllText(Path.Combine(output,"ready.txt"),"Select a hollow interior; seed group outer/top should collapse on a plain click.");
        }
        catch(Exception error){await File.WriteAllTextAsync(Path.Combine(output,"error.txt"),error.ToString());}
    }
}
#endif
