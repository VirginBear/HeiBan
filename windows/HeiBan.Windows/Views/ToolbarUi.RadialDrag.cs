using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml.Controls;
using global::Windows.ApplicationModel.DataTransfer;
namespace HeiBan.Windows.Views;
internal static partial class ToolbarUi
{
    private sealed class DragKey {internal string Key="";}
    private static readonly ConditionalWeakTable<Button,DragKey> RadialDragKeys=new();
    private static void EnableRadialDrag(Button button,string key)
    {
        if(RadialDragKeys.TryGetValue(button,out var existing)){existing.Key=key;return;}
        var entry=new DragKey{Key=key};RadialDragKeys.Add(button,entry);button.CanDrag=true;
        button.DragStarting+=(_,args)=>{args.Data.SetData(RadialWheelSettingsWindow.DragFormat,entry.Key);args.Data.RequestedOperation=DataPackageOperation.Copy;};
    }
}
