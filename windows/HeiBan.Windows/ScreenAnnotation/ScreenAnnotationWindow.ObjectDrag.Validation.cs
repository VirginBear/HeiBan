#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal async Task<object> ValidateObjectDragAsync()
    {
        await StartAsync();var checks=0;void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        try
        {
            _rulerEnabled=false;_compass.IsEnabled=false;ChooseScreenTool("select");
            _session.Open(new(){Objects=[new(){Id="moving",Type="rect",X=200,Y=300,Width=80,Height=80,FillColor="#EF4444",ZIndex=1},new(){Id="front",Type="rect",X=250,Y=330,Width=100,Height=60,FillColor="#3366CC",ZIndex=2}]});
            _session.SelectedId="moving";Changed();Render();var original=DocumentCodec.Encode(_session.Document);
            OnPointer(new("down",220,320,LeftDown:true));
            for(var i=1;i<=8;i++){OnPointer(new("move",220+i*8,320+i*5,LeftDown:true));Render();Check(DocumentCodec.Encode(_session.Document)==original&&!_session.HasTransaction,"Screen drag mutated document during move");}
            Check(_objectDragRenderer?.Builds==1,"Screen drag rebuilt static paint cache repeatedly");
            CancelGesture();Render();Check(DocumentCodec.Encode(_session.Document)==original&&_session.Generation==0,"Cancelled screen drag changed source");
            OnPointer(new("down",220,320,LeftDown:true));OnPointer(new("move",240,340,LeftDown:true));OnPointer(new("up",240,340));
            Check(_session.Generation==1&&_session.Document.Objects[0].X==220&&_session.Document.Objects[0].Y==320,"Screen release did not commit once");
            _session.Undo();Check(DocumentCodec.Encode(_session.Document)==original,"Screen drag undo failed");
            return new{checks,independentPreview=true,staticCacheBuilds=1,cancelPreserves=true,singleCommitUndo=true};
        }
        finally{await StopAsync();}
    }
}
#endif
