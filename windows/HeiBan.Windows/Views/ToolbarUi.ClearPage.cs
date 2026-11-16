using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal static ContentDialog CreateClearPageDialog(XamlRoot root) => new()
    {
        XamlRoot=root,
        FlowDirection=Localization.Strings.RightToLeft?FlowDirection.RightToLeft:FlowDirection.LeftToRight,
        Title=T("清除目前頁面？"),
        Content=new TextBlock{Text=T("可用復原恢復。其他頁面不受影響。"),TextWrapping=TextWrapping.Wrap},
        PrimaryButtonText=T("全部清除"),
        SecondaryButtonText=T("僅清除筆跡"),
        CloseButtonText=T("取消"),
        DefaultButton=ContentDialogButton.Close
    };
}
