#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using global::Windows.UI;
namespace HeiBan.Windows;
public partial class App
{
    private Window? _operateProbe;
    private void ShowOperateInputProbe(string output)
    {
        Directory.CreateDirectory(output);
        var down=0;var up=0;var contexts=0;var left=0;var rightHeld=false;
        var label=new TextBlock{Text="Owned input test receiver\nRight-click the empty area to test forwarding.\nNo documents or external actions are used.",TextWrapping=TextWrapping.Wrap,FontSize=18,Margin=new Thickness(24)};
        var root=new Grid{Background=new SolidColorBrush(Color.FromArgb(255,246,248,244))};root.Children.Add(label);
        var button=new Button{Content="Test left click",HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Bottom,Margin=new Thickness(24)};root.Children.Add(button);
        void Save(){label.Text=$"Owned input test receiver\nRight down {down} / up {up} / menus {contexts}\nLeft clicks {left}\nHold right button in the empty area for the wheel.";File.WriteAllText(Path.Combine(output,"input.json"),JsonSerializer.Serialize(new{down,up,contexts,left}));}
        root.PointerPressed+=(_,e)=>{if(e.GetCurrentPoint(root).Properties.IsRightButtonPressed){rightHeld=true;down++;Save();}};
        root.PointerReleased+=(_,e)=>{if(rightHeld){rightHeld=false;up++;Save();}};
        root.RightTapped+=(_,e)=>{contexts++;Save();var menu=new MenuFlyout();menu.Items.Add(new MenuFlyoutItem{Text="QA right-click menu"});menu.ShowAt(root,new Microsoft.UI.Xaml.Controls.Primitives.FlyoutShowOptions{Position=e.GetPosition(root)});e.Handled=true;};
        button.Click+=(_,_)=>{left++;Save();};
        _operateProbe=new Window{Title="HeiBan operate input probe",Content=root};_operateProbe.AppWindow.Resize(new global::Windows.Graphics.SizeInt32(900,650));_operateProbe.Activate();Save();
    }
}
#endif
