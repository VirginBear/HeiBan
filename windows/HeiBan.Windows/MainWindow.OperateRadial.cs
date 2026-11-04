using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows;
public partial class MainWindow
{
    internal ToggleMenuFlyoutItem CreateOperateRadialMenuItem()
    {
        var item=new ToggleMenuFlyoutItem{Text=T("操作模式右鍵輪盤"),IsChecked=_toolbarPrefs.OperateRadialEnabled};
        ToolTipService.SetToolTip(item,T("操作模式：右鍵長按開啟輪盤；短按保留原右鍵功能"));
        item.Click+=async(_,_)=>
        {
            item.IsEnabled=false;
            try{var draft=DocumentCodec.Clone(_toolbarPrefs);draft.OperateRadialEnabled=item.IsChecked;await SaveToolbarPreferencesAsync(draft);}
            catch(Exception error){await Error(error);}
            finally{item.IsChecked=_toolbarPrefs.OperateRadialEnabled;item.IsEnabled=true;}
        };return item;
    }
}
