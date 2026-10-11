using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using global::Windows.Foundation;

namespace HeiBan.Windows;

public partial class MainWindow
{
    // The same round indicator is used by the shelf and save status; no ListView check box chrome.
    public static UIElement SelectionCircle(bool selected, bool dashed=false,double size=20)
    {
        var grid=new Grid{Width=size,Height=size};
        var circle=new Ellipse{Width=size-3,Height=size-3,Stroke=new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255,57,115,90)),StrokeThickness=1.5};
        if(dashed)circle.StrokeDashArray=new DoubleCollection{2,2};
        grid.Children.Add(circle);
        if(selected)grid.Children.Add(new TextBlock{Text="✓",FontSize=15,Foreground=circle.Stroke,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});
        return grid;
    }

    private string _inspectorDock="right",_inspectorContext="";
    private HeiBanDocument? _inspectorDocument;
    private string? _inspectorDragSide;
    private void ApplyInspectorContext(BoardObject? o)
    {
        var type=o?.Type??(_tool=="select"?"none":_tool);
        var ink=type is "stroke" or "pen" or "highlighter" or "paint" or "curve";
        var line=ink||type is "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star" or "arc";
        var text=type is "text" or "sticky";
        var fill=type is "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star" or "sticky"||type=="arc"&&Math.Abs(o?.ArcSweepAngle??360)>=360;
        void Show(UIElement element,bool visible)=>element.Visibility=visible?Visibility.Visible:Visibility.Collapsed;
        Show(StrokeSection,line||text||type=="tape");Show(LineSection,line);Show(FillSection,fill);Show(FillToggle,type!="sticky");
        Show(ObjectSection,line||text||type is "image" or "tape");
        Show(RotationBox,o is not null&&type is not("line" or "arrow"));Show(FontSizeBox,text);
        Show(EraserSection,o is null&&_tool=="eraser");Show(RulerSection,o is null&&_rulerEnabled);
        var context=$"{_session.DocumentEpoch}:{o?.Id}:{type}";
        if(_inspectorContext!=context||!ReferenceEquals(_inspectorDocument,_session.Document))
        {
            _inspectorContext=context;_inspectorDocument=_session.Document;ExtendedSection.Children.Clear();
            if(o is not null)AddExtendedObjectSettings(ExtendedSection,o);
            else if(type is "line" or "arrow")
            {var button=new Button{Content="直線延伸設定"};button.Click+=(_,_)=>ShowExtensionSettings(button);ExtendedSection.Children.Add(button);}
            else if(type=="laser")
            {var button=new Button{Content="雷射：顏色、大小與消退"};button.Click+=(_,_)=>ShowLaserSettings(button);ExtendedSection.Children.Add(button);}
        }
        Show(ExtendedSection,ExtendedSection.Children.Count>0);
        SelectionSummary.Text=o is null?(type=="none"?"選取物件後調整屬性":"目前工具 · 設定即時生效"):$"{LayerPresentation.Build(new[]{o})[0].Description} · {(o.IsLocked==true?"已鎖定":"設定即時生效")}";
        SetInspectorDock(_inspectorDock,false);
        foreach(var section in InspectorSections.Children.OfType<FrameworkElement>()){section.IsHitTestVisible=o?.IsLocked!=true;foreach(var control in DescendantControls(section))control.IsEnabled=o?.IsLocked!=true;}
        UpdateSaveStatusLight(StatusText.Text);
    }
    private static IEnumerable<Control> DescendantControls(DependencyObject parent)
    {
        if(parent is Panel panel)foreach(var child in panel.Children){if(child is Control control)yield return control;foreach(var nested in DescendantControls(child))yield return nested;}
    }

    private void SetInspectorDock(string side,bool save=false)
    {
        _inspectorDock=side is "top" or "bottom" or "left" or "right"?side:"right";
        var horizontal=_inspectorDock is "top" or "bottom";
        // Reserve the docked toolbar, header and viewport capsule so panels do not cover their controls.
        var left=_dock=="左側"?80:12;var right=_dock=="右側"?80:12;
        var top=_dock=="上方"?80:64;var bottom=_dock=="下方"?80:64;
        var availableHeight=Math.Max(180,(Workspace.ActualHeight>0?Workspace.ActualHeight:Root.ActualHeight-32)-top-bottom);
        Inspector.Margin=new Thickness(left,top,right,bottom);
        Inspector.Width=horizontal?double.NaN:304;Inspector.Height=horizontal?270:double.NaN;
        Inspector.MaxHeight=availableHeight;
        Inspector.HorizontalAlignment=horizontal?HorizontalAlignment.Stretch:_inspectorDock=="left"?HorizontalAlignment.Left:HorizontalAlignment.Right;
        Inspector.VerticalAlignment=horizontal?(_inspectorDock=="top"?VerticalAlignment.Top:VerticalAlignment.Bottom):VerticalAlignment.Top;
        InspectorSections.Orientation=horizontal?Orientation.Horizontal:Orientation.Vertical;
        InspectorScroll.HorizontalScrollMode=horizontal?ScrollMode.Enabled:ScrollMode.Disabled;
        InspectorScroll.VerticalScrollMode=ScrollMode.Enabled;
        InspectorScroll.HorizontalScrollBarVisibility=horizontal?ScrollBarVisibility.Auto:ScrollBarVisibility.Disabled;
        InspectorScroll.VerticalScrollBarVisibility=ScrollBarVisibility.Auto;
        foreach(var section in InspectorSections.Children.OfType<FrameworkElement>())section.Width=horizontal?248:double.NaN;
        InspectorBookmark.HorizontalAlignment=_inspectorDock=="left"?HorizontalAlignment.Left:HorizontalAlignment.Right;
        LayersPanel.HorizontalAlignment=_inspectorDock=="left"?HorizontalAlignment.Right:HorizontalAlignment.Left;
        LayersPanel.Margin=new Thickness(left,top,right,bottom);LayersPanel.MaxHeight=availableHeight;
        LayerList.MaxHeight=Math.Max(80,Math.Min(420,availableHeight-180));
        if(save)QueueTeachingSettingsSave();
    }
    private void InspectorDock_Click(object sender,RoutedEventArgs e)
    {
        var menu=new MenuFlyout();foreach(var pair in new[]{("top","上方"),("left","左側"),("bottom","下方"),("right","右側")})
        {var side=pair.Item1;var item=new MenuFlyoutItem{Text=pair.Item2};item.Click+=(_,_)=>SetInspectorDock(side,true);menu.Items.Add(item);}ShowExclusiveFlyout(menu,(FrameworkElement)sender);
    }
    private void InspectorGrip_Pressed(object sender,PointerRoutedEventArgs e)
    {if(!e.GetCurrentPoint((UIElement)sender).Properties.IsLeftButtonPressed)return;_inspectorDragSide=_inspectorDock;((UIElement)sender).CapturePointer(e.Pointer);e.Handled=true;}
    private void InspectorGrip_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(_inspectorDragSide is null)return;var p=e.GetCurrentPoint(Workspace).Position;
        _inspectorDragSide=new[]{("left",p.X),("right",Workspace.ActualWidth-p.X),("top",p.Y),("bottom",Workspace.ActualHeight-p.Y)}.OrderBy(x=>x.Item2).First().Item1;
        ToolTipService.SetToolTip((FrameworkElement)sender,"放開後停靠："+_inspectorDragSide);e.Handled=true;
    }
    private void InspectorGrip_Released(object sender,PointerRoutedEventArgs e)
    {var side=_inspectorDragSide;_inspectorDragSide=null;((UIElement)sender).ReleasePointerCaptures();if(side is not null)SetInspectorDock(side,true);e.Handled=true;}
    private void InspectorGrip_Canceled(object sender,PointerRoutedEventArgs e)=>_inspectorDragSide=null;

    private string? _layerDragId,_layerDropId;
    private long _layerDragEpoch;
    private bool _layerDropAfter;
    private void LayerGrip_Pressed(object sender,PointerRoutedEventArgs e)
    {
        if(sender is not FrameworkElement{DataContext:LayerCard row} handle||!e.GetCurrentPoint(handle).Properties.IsLeftButtonPressed)return;
        CommitPropertyEdit();_layerDragId=row.ObjectId;_layerDragEpoch=_session.DocumentEpoch;_layerDropId=null;
        handle.CapturePointer(e.Pointer);e.Handled=true;
    }
    private void LayerGrip_Moved(object sender,PointerRoutedEventArgs e)
    {
        if(_layerDragId is null)return;
        var hit=Views.LayerDragTarget.Find(LayerList,e.GetCurrentPoint(LayerList).Position);
        _layerDropId=(hit.Item as LayerCard)?.ObjectId;_layerDropAfter=hit.After;
        LayerDragHint.Text=hit.Item is LayerCard row?$"放開移到「{row.Title}」{(hit.After?"下方":"上方")}":"拖到目標圖層上方或下方";e.Handled=true;
    }
    private void LayerGrip_Released(object sender,PointerRoutedEventArgs e)
    {
        var id=_layerDragId;var target=_layerDropId;var after=_layerDropAfter;_layerDragId=_layerDropId=null;LayerDragHint.Text="";((UIElement)sender).ReleasePointerCaptures();
        if(_layerDragEpoch==_session.DocumentEpoch&&id is not null&&target is not null&&LayerReorder.Move(_session,id,target,after))RefreshEditor();e.Handled=true;
    }
    private void LayerGrip_Canceled(object sender,PointerRoutedEventArgs e){_layerDragId=_layerDropId=null;LayerDragHint.Text="";}

    private async void PinAppearance(BoardPin pin)
    {
        CommitPropertyEdit();var epoch=_session.DocumentEpoch;
        var body=ColorWheel(pin.Color??"#39B9DC");var text=ColorWheel(pin.TextColor??"#397056");
        var panel=new StackPanel{Spacing=8,Children={new TextBlock{Text="圖釘顏色"},body,new TextBlock{Text="圖釘文字顏色"},text}};
        var result=await new ContentDialog{Title="個別圖釘配色",Content=new ScrollViewer{Content=panel,MaxHeight=460},PrimaryButtonText="套用",CloseButtonText="取消",XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||epoch!=_session.DocumentEpoch||!(_session.Document.Board.Pins?.Contains(pin)??false))return;
        _session.Begin();pin.Color=ColorHex(body.Color);pin.TextColor=ColorHex(text.Color);_session.Commit();RefreshEditor();
    }
    private void FillOpacity_Changed(object sender,Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {if(!_chromeEventsBound||_syncingProperties)return;ChangeProperty(()=>{if(_session.Selected is { } o)o.FillOpacity=e.NewValue;else CurrentStyle.FillOpacity=e.NewValue;});}
    private void FillGradient_Click(object sender,RoutedEventArgs e)
    {
        var o=_session.Selected;var start=ColorWheel(o?.FillGradientStart??(o?.FillColor is { } fill&&fill!="none"?fill:CurrentStyle.Fill));
        var end=ColorWheel(o?.FillGradientEnd??CurrentStyle.Fill);
        var panel=new StackPanel{Spacing=8,Children={new TextBlock{Text="漸層起點"},start,new TextBlock{Text="漸層終點"},end}};
        void Apply(){ChangeProperty(()=>SetFillGradient(ColorHex(start.Color),ColorHex(end.Color)));}
        start.ColorChanged+=(_,_)=>Apply();end.ColorChanged+=(_,_)=>Apply();
        var solid=new Button{Content="改回單色"};solid.Click+=(_,_)=>ChangeProperty(()=>SetFillColor(ColorHex(start.Color)));panel.Children.Add(solid);
        ShowExclusiveFlyout(new Flyout{Content=new ScrollViewer{Content=panel,MaxHeight=Math.Max(200,Root.ActualHeight-100)}},(FrameworkElement)sender);
    }
}
