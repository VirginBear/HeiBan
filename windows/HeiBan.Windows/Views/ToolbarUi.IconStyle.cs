using static HeiBan.Windows.Localization.Strings;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows.Views;
internal static partial class ToolbarUi
{
    internal static ComboBox IconStyleSelector(string style,Action<string> changed)
    {
        var picker=new ComboBox{Header=T("圖示風格"),HorizontalAlignment=HorizontalAlignment.Stretch};
        foreach(var (key,label) in new[]{("classic","原本描邊"),("duotone","A · 彩色雙色描邊")})
        {
            var row=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8};
            foreach(var tool in new[]{"pen","highlighter","cane"})row.Children.Add(ToolIcons.Create(tool,key));
            row.Children.Add(new TextBlock{Text=T(label),VerticalAlignment=VerticalAlignment.Center,TextWrapping=TextWrapping.Wrap,MaxWidth=240});
            picker.Items.Add(new ComboBoxItem{Tag=key,Content=row});
        }
        picker.SelectedIndex=style=="duotone"?1:0;
        picker.SelectionChanged+=(_,_)=>changed(picker.SelectedIndex==1?"duotone":"classic");return picker;
    }
}
