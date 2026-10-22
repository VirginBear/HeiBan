using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private string? _objectDetailsId;
    private string _toolbarPage="common";
    private Button? _arrangedSelectionButton;
    private bool _arrangedLabels,_arrangedVertical,_arrangingToolbar;
    private ToolbarFlowPanel? _labeledToolbarFlow;
    private MagnetSnapIndex? _magnetIndex;
    private InkPoint? _magnetTarget;
    private long _magnetGeneration=-1,_magnetEpoch=-1;
    private string? _magnetPage;
    private double _magnetZoom;
    private void EnsureMagnetIndex(bool force=false)
    {
        if(!_toolbarPrefs.MagnetEnabled){_magnetIndex=null;_magnetTarget=null;return;}
        if(!force&&_magnetIndex is not null&&_magnetGeneration==_session.Generation&&_magnetEpoch==_session.DocumentEpoch&&_magnetPage==_session.Document.Board.ActivePageId&&_magnetZoom==_viewport.Zoom)return;
        _magnetIndex=new MagnetSnapIndex(_session.VisibleObjects,10/_viewport.Zoom);
        _magnetGeneration=_session.Generation;_magnetEpoch=_session.DocumentEpoch;_magnetPage=_session.Document.Board.ActivePageId;_magnetZoom=_viewport.Zoom;
    }
    private static bool IsDrawingTool(string tool)=>tool is "pen" or "highlighter" or "paint" or "curve" or "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
    private void BeginDrawingWorkflow()
    {
        _objectDetailsId=null;Inspector.Visibility=Visibility.Collapsed;SelectionBar.Visibility=Visibility.Collapsed;
        _session.SelectedId=null;_magnetTarget=null;
        EnsureMagnetIndex();
    }
    private InkPoint SnapDrawingPoint(InkPoint point)
    {
        if(_magnetIndex is null||!_toolbarPrefs.MagnetEnabled){_magnetTarget=null;return point;}
        var result=_magnetIndex.Snap(point,out var snapped);_magnetTarget=snapped?result:null;return result;
    }
    private void ArrangeMainToolbar()
    {
        var labels=_toolbarPrefs.DisplayMode=="labels";var vertical=_dock is "左側" or "右側";
        if(labels)
        {
            ToolScroll.MaxWidth=Math.Max(180,DrawingArea.ActualWidth-80);
            ToolScroll.HorizontalScrollBarVisibility=ToolScroll.VerticalScrollBarVisibility=ScrollBarVisibility.Disabled;
            ToolScroll.HorizontalScrollMode=ToolScroll.VerticalScrollMode=ScrollMode.Disabled;
        }
        if(_arrangingToolbar)return;
        _toolButtons.TryGetValue("select",out var selection);
        // SizeChanged can run inside XAML layout. Resize the existing flow there; moving
        // the same live controls into another panel during that callback can fail fast.
        if(!ReferenceEquals(selection,_arrangedSelectionButton)||labels!=_arrangedLabels||vertical!=_arrangedVertical)
        {
            _arrangingToolbar=true;
            try
            {
                _labeledToolbarFlow=ToolbarUi.Arrange(Tools,_toolButtons.Select(p=>(p.Key,p.Value)),labels,vertical,_toolbarPage,p=>_toolbarPage=p,40,_toolbarPrefs.CommonTools);
                _arrangedSelectionButton=selection;_arrangedLabels=labels;_arrangedVertical=vertical;
            }
            finally{_arrangingToolbar=false;}
        }
        if(_labeledToolbarFlow is { } flow)
        {flow.RunLength=vertical?Math.Max(72,DrawingArea.ActualHeight-460):Math.Max(84,DrawingArea.ActualWidth-320);flow.InvalidateMeasure();}
    }
    private FrameworkElement CustomizeToolbarHeader(HashSet<string> visible,List<string> order,Action rebuild,string mode,Action<string> setMode,Action resetCommon)
    {
        var panel=new StackPanel{Spacing=8};
        var format=new ComboBox{Header=Localization.Strings.T("工具列格式"),ItemsSource=new[]{Localization.Strings.T("只有圖示"),Localization.Strings.T("圖示與文字（分頁）")},SelectedIndex=mode=="labels"?1:0,HorizontalAlignment=HorizontalAlignment.Stretch};
        format.SelectionChanged+=(_,_)=>setMode(format.SelectedIndex==1?"labels":"icons");panel.Children.Add(format);
        var commands=new StackPanel{Orientation=Orientation.Horizontal,Spacing=8};
        var all=new Button{Content=Localization.Strings.T("全選")};all.Click+=(_,_)=>{visible.UnionWith(order);rebuild();};
        var defaults=new Button{Content=Localization.Strings.T("預設")};defaults.Click+=(_,_)=>{visible.Clear();visible.UnionWith(ToolbarPreferences.AllDefaultTools);order.Clear();order.AddRange(ToolbarPreferences.AllDefaultTools.Where(key=>key!="extension"));format.SelectedIndex=0;resetCommon();rebuild();};
        commands.Children.Add(all);commands.Children.Add(defaults);panel.Children.Add(commands);return panel;
    }
    private async void ToggleMagnet()
    {
        var previous=_toolbarPrefs.MagnetEnabled;_toolbarPrefs.MagnetEnabled=!previous;
        try{await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);RefreshChrome();}
        catch(Exception ex){_toolbarPrefs.MagnetEnabled=previous;await Error(ex);}
    }
    private async Task SaveToolbarDockAsync()
    {
        try{await ToolbarPreferencesStore.SaveAsync(_storage.DataDirectory,_toolbarPrefs);}
        catch(Exception error){StatusText.Text=Localization.Strings.T("工具列設定未保存：")+error.Message;}
    }
}
