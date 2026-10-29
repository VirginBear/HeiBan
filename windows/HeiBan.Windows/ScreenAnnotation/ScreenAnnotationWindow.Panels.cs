using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using global::Windows.Foundation;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private LayerDragPreview? _screenLayerPreview;
    private ListView? _screenLayers;
    private TextBlock? _screenLayerHint;
    private bool _refreshingScreenLayers;
    private string? _screenDragId,_screenDropId;
    private bool _screenDropAfter;
    private long _screenDragEpoch;
    private Button _paletteButton=null!;
    private void ShowScreenLayers()
    {
        _screenLayerPreview?.End();_screenDragId=_screenDropId=null;
        _chromeFlyout?.Hide();FinishScreenText();CommitScreenStyle();
        _screenLayers=new ListView{SelectionMode=ListViewSelectionMode.Multiple,IsMultiSelectCheckBoxEnabled=false,MaxHeight=400};
        var template="""
            <DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
             <Grid ColumnSpacing="8" Padding="0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="24"/><ColumnDefinition Width="24"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Border Tag="grip" Width="22" Background="Transparent"><TextBlock Text="═" Foreground="#909890" FontSize="16" VerticalAlignment="Center"/></Border>
              <ContentControl Grid.Column="1" Content="{Binding Icon}"/><StackPanel Grid.Column="2"><TextBlock Text="{Binding Title}" TextTrimming="CharacterEllipsis"/><TextBlock Text="{Binding Description}" FontSize="11" Foreground="#68756C"/></StackPanel>
             </Grid>
            </DataTemplate>
            """;
        _screenLayers.ItemTemplate=(DataTemplate)Microsoft.UI.Xaml.Markup.XamlReader.Load(template);
        _screenLayers.ContainerContentChanging+=(_,e)=>
        {
            if(e.InRecycleQueue)return;
            e.RegisterUpdateCallback((_,args)=>
            {
                var handle=FindGrip(args.ItemContainer);
                if(handle is null)return;
                handle.PointerPressed-=ScreenLayerGrip_Pressed;handle.PointerPressed+=ScreenLayerGrip_Pressed;
                handle.PointerMoved-=ScreenLayerGrip_Moved;handle.PointerMoved+=ScreenLayerGrip_Moved;
                handle.PointerReleased-=ScreenLayerGrip_Released;handle.PointerReleased+=ScreenLayerGrip_Released;
                handle.PointerCanceled-=ScreenLayerGrip_Canceled;handle.PointerCanceled+=ScreenLayerGrip_Canceled;
                handle.PointerCaptureLost-=ScreenLayerGrip_Canceled;handle.PointerCaptureLost+=ScreenLayerGrip_Canceled;
            });
        };
        _screenLayers.SelectionChanged+=(_,_)=>
        {
            if(_refreshingScreenLayers||_screenLayers is null)return;
            if(_tool is "laser" or "cane"){RefreshScreenLayers();return;}
            FinishScreenText();CancelGesture();_session.SetSelection(_screenLayers.SelectedItems.OfType<LayerCard>().Select(row=>row.ObjectId));
            _tool="select";if(!_drawing)SetDrawing(true);RefreshButtons();_dirty=_fullDamage=true;
        };
        _screenLayerHint=new TextBlock{Text=T("上層在前；拖曳灰色雙槓調整順序"),FontSize=12,TextWrapping=TextWrapping.Wrap};
        var overlay=new Canvas{IsHitTestVisible=false};var layerHost=new Grid();layerHost.Children.Add(_screenLayers);layerHost.Children.Add(overlay);
        _screenLayerPreview=new LayerDragPreview(_screenLayers,overlay);
        var panel=new StackPanel{Width=300,Spacing=8,Children={new TextBlock{Text=T("物件圖層"),FontSize=16},_screenLayerHint,layerHost}};
        var controls=new StackPanel{Orientation=Orientation.Horizontal,Spacing=4};
        void Command(string label,Action action){var button=new Button{Content=label,Padding=new Thickness(8,4,8,4)};button.Click+=(_,_)=>{action();RefreshScreenLayers();};controls.Children.Add(button);}
        Command(T("上移"),()=>ShiftScreenLayer(false));Command(T("下移"),()=>ShiftScreenLayer(true));
        Command(T("鎖定"),()=>{CommitScreenStyle();if(_session.Selected is not { } o)return;_session.Begin();o.IsLocked=o.IsLocked!=true;_session.Commit();Changed();});
        Command(T("顯示"),()=>{CommitScreenStyle();if(_session.Selected is not { } o)return;_session.Begin();o.IsVisible=o.IsVisible==false;_session.Commit();Changed();});
        panel.Children.Add(controls);
        var rename=new Button{Content=T("重新命名圖層…")};rename.Click+=async(_,_)=>
        {
            if(_session.Selected is not { } o)return;var epoch=_session.DocumentEpoch;var box=new TextBox{Text=o.Name??"",MaxLength=120};
            _chromeFlyout?.Hide();
            if(await new ContentDialog{Title=T("圖層名稱"),Content=box,PrimaryButtonText=T("儲存"),CloseButtonText=T("取消"),XamlRoot=((FrameworkElement)Content).XamlRoot}.ShowAsync()!=ContentDialogResult.Primary||epoch!=_session.DocumentEpoch)return;
            _session.Begin();o.Name=string.IsNullOrWhiteSpace(box.Text)?null:box.Text.Trim();_session.Commit();Changed();
        };panel.Children.Add(rename);RefreshScreenLayers();
        var flyout=new Flyout{Content=new ScrollViewer{Content=panel,MaxHeight=520}};
        var list=_screenLayers;flyout.Closed+=(_,_)=>{if(ReferenceEquals(_screenLayers,list)){_screenLayerPreview?.End();_screenLayerPreview=null;_screenDragId=_screenDropId=null;_screenLayers=null;_screenLayerHint=null;}};ShowChromeFlyout(flyout,_moreButton);
    }
    private static Border? FindGrip(DependencyObject parent)
    {
        for(var i=0;i<VisualTreeHelper.GetChildrenCount(parent);i++)
        {var child=VisualTreeHelper.GetChild(parent,i);if(child is Border{Tag:"grip"} grip)return grip;if(FindGrip(child) is { } found)return found;}return null;
    }
    private void RefreshScreenLayers()
    {
        if(_screenLayers is null)return;_screenLayerPreview?.End();_screenDragId=_screenDropId=null;_refreshingScreenLayers=true;
        try{_screenLayers.ItemsSource=LayerPresentation.Build(_session.Document.Objects, Localization.Strings.T).Select(entry=>new LayerCard(entry)).ToList();foreach(var row in _screenLayers.Items.OfType<LayerCard>().Where(row=>_session.SelectedIds.Contains(row.ObjectId)))_screenLayers.SelectedItems.Add(row);}
        finally{_refreshingScreenLayers=false;}
    }
    private void ShiftScreenLayer(bool down)
    {
        if(_session.Selected is not { } o)return;var order=_session.Document.Objects.OrderByDescending(item=>item.ZIndex).ToList();var target=order.IndexOf(o)+(down?1:-1);
        if(target>=0&&target<order.Count&&LayerReorder.Move(_session,o.Id,order[target].Id,down))Changed();
    }
    private void ScreenLayerGrip_Pressed(object sender,PointerRoutedEventArgs e)
    {
        if(sender is not FrameworkElement{DataContext:LayerCard row} handle||!e.GetCurrentPoint(handle).Properties.IsLeftButtonPressed)return;
        CommitScreenStyle();_screenDragId=row.ObjectId;_screenDragEpoch=_session.DocumentEpoch;_screenDropId=null;_screenLayerPreview?.Begin(row,e.GetCurrentPoint(_screenLayers).Position);handle.CapturePointer(e.Pointer);e.Handled=true;
    }
    private void ScreenLayerGrip_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(_screenDragId is null||_screenLayers is null)return;var position=e.GetCurrentPoint(_screenLayers).Position;_screenLayerPreview?.Move(position);var hit=LayerDragTarget.Find(_screenLayers,position);
        _screenDropId=(hit.Item as LayerCard)?.ObjectId;_screenDropAfter=hit.After;if(_screenLayerHint is not null)_screenLayerHint.Text=hit.Item is LayerCard row?F($"放開移到「{row.Title}」{T(hit.After?"下方":"上方")}"):T("拖到目標圖層");e.Handled=true;
    }
    private void ScreenLayerGrip_Released(object sender,PointerRoutedEventArgs e)
    {
        var id=_screenDragId;var target=_screenDropId;var after=_screenDropAfter;_screenDragId=_screenDropId=null;_screenLayerPreview?.End();if(_screenLayerHint is not null)_screenLayerHint.Text=T("上層在前；拖曳灰色雙槓調整順序");((UIElement)sender).ReleasePointerCaptures();
        if(_screenDragEpoch==_session.DocumentEpoch&&id is not null&&target is not null&&LayerReorder.Move(_session,id,target,after))Changed();e.Handled=true;
    }
    private void ScreenLayerGrip_Canceled(object sender,PointerRoutedEventArgs e){_screenDragId=_screenDropId=null;_screenLayerPreview?.End();if(_screenLayerHint is not null)_screenLayerHint.Text=T("上層在前；拖曳灰色雙槓調整順序");}

    private void ShowScreenPalette()
    {
        var panel=new StackPanel{Width=260,Spacing=10,Children={new TextBlock{Text=T("調色盤 · 線條／文字色"),FontSize=16}}};
        var wheel=new ColorPicker{Color=Direct2DCanvasRenderer.HexToColor(StyleSelection?.StrokeColor??_color),Width=260,ColorSpectrumShape=ColorSpectrumShape.Ring,IsHexInputVisible=true,IsColorChannelTextInputVisible=false,IsAlphaEnabled=true};
        panel.Children.Add(new PaletteEditor(_owner.ProfilePalette,()=>$"#{wheel.Color.R:X2}{wheel.Color.G:X2}{wheel.Color.B:X2}{wheel.Color.A:X2}",c=>wheel.Color=Direct2DCanvasRenderer.HexToColor(c),wheel));
        wheel.ColorChanged+=(_,e)=>SetScreenColor($"#{e.NewColor.R:X2}{e.NewColor.G:X2}{e.NewColor.B:X2}{e.NewColor.A:X2}");panel.Children.Add(wheel);
        panel.Children.Add(new TextBlock{Text=T("填色請使用工具列的填滿按鈕。"),FontSize=12});ShowChromeFlyout(new Flyout{Content=panel},_paletteButton);
    }

    private System.Numerics.Vector2? _screenEraserPointer;
    private Rect? _lastEraserDamage;
    private void UpdateScreenEraser()
    {
        System.Numerics.Vector2? point=null;
        if(_drawing&&_tool=="eraser"&&_chromeFlyout is null&&_captureCancellation is null)
        {
            var p=NativeOverlayWindow.CurrentPointer;var chrome=AppWindow.Position;var size=AppWindow.Size;
            if(!(p.X>=chrome.X&&p.X<chrome.X+size.Width&&p.Y>=chrome.Y&&p.Y<chrome.Y+size.Height))point=new(p.X-_overlay.Left,p.Y-_overlay.Top);
        }
        if(point==_screenEraserPointer)return;
        _screenEraserPointer=point;_dirty=true;
    }
}
