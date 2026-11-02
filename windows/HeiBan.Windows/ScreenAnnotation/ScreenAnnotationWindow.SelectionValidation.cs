#if HEIBAN_RELEASE_VALIDATION
using HeiBan.Windows.Engine;
namespace HeiBan.Windows.ScreenAnnotation;
internal sealed partial class ScreenAnnotationWindow
{
    internal bool ValidationCaneMuted=>_toolbarPreferences.CaneMuted;
    internal async Task<object> ValidatePointSelectionAsync()
    {
        await StartAsync();var checks=0;
        void Check(bool ok,string message){checks++;if(!ok)throw new Exception(message);}
        try
        {
            _session.Open(new(){Objects=[new(){Id="lower",Type="rect",X=100,Y=300,Width=160,Height=120,FillColor="none",ZIndex=1},new(){Id="upper",Type="rect",X=120,Y=320,Width=80,Height=60,FillColor="none",ZIndex=2},new(){Id="other",Type="rect",X=400,Y=300,Width=80,Height=80,FillColor="none",ZIndex=3}]});
            _rulerEnabled=false;_compass.IsEnabled=false;ChooseScreenTool("select");
            void Click(double x,double y,bool ctrl=false){OnPointer(new("down",x,y,LeftDown:true,Control:ctrl));OnPointer(new("up",x,y,Control:ctrl));}
            Click(160,350);Check(_session.SelectedIds.SetEquals(new[]{"upper"}),"Hollow topmost screen click failed");
            Click(440,340,true);Check(_session.SelectedIds.SetEquals(new[]{"upper","other"}),"Screen Ctrl did not add");
            Click(160,350,true);Check(_session.SelectedIds.SetEquals(new[]{"other"}),"Screen Ctrl did not remove");
            Click(160,350,true);Click(160,350);Check(_session.SelectedIds.SetEquals(new[]{"upper"}),"Screen plain click did not collapse group");
            Check(_session.Generation==0&&!_session.CanUndo,"Screen point clicks created document edits");
            Click(440,340,true);OnPointer(new("down",160,350,LeftDown:true));OnPointer(new("move",180,370,LeftDown:true));OnPointer(new("up",180,370));
            Check(_session.SelectedIds.Count==2&&_session.Document.Objects.Single(o=>o.Id=="upper").X==140&&_session.Document.Objects.Single(o=>o.Id=="other").X==420,"Screen group drag regressed");
            return new{checks,productionPointerAdapter=true,controlAddRemove=true,topmostBounds=true,plainClickCollapses=true,groupDrag=true};
        }
        finally{await StopAsync();}
    }
}
#endif
