using System.Diagnostics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
namespace HeiBan.Windows;
public partial class MainWindow
{
    private readonly DispatcherTimer _laserTimer=new(){Interval=TimeSpan.FromMilliseconds(16)};
    private static double LaserNow=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    private void InitializeTeachingTools()
    {
        LoadTeachingSettings();
        _laserTimer.Tick+=(_,_)=>{if(_tool=="pen"&&_ink.TrySnapStraight(_viewport.Zoom)){_renderer.ResetLive();InvalidateCanvas(false);}if(_laser.Samples.Count==0)return;_laser.Prune(LaserNow);if(_workspaceOpen)InvalidateCanvas(false);};_laserTimer.Start();
    }
    private async void ClearPage()
    {
        CommitPropertyEdit();FinishText();if(_gesture)CancelGesture();
        var board=_session.Document.Board.Id;var page=_session.Document.Board.ActivePageId;
        var result=await new ContentDialog{Title="清除目前頁面？",Content="可用復原恢復。其他頁面不受影響。",PrimaryButtonText="清除",CloseButtonText="取消",XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result!=ContentDialogResult.Primary||board!=_session.Document.Board.Id||page!=_session.Document.Board.ActivePageId)return;
        _session.Begin();foreach(var o in _session.PageObjects.ToArray())_session.Document.Objects.Remove(o);_session.SelectedId=null;_session.Commit();RefreshEditor();
    }
    private void Visibility_Click(object sender,RoutedEventArgs e)
    {if(_session.Selected is not { } o)return;CommitPropertyEdit();_session.Begin();o.IsVisible=o.IsVisible==false;_session.Commit();RefreshEditor();}
    private void ShowExtensionSettings(FrameworkElement anchor)
    {
        var box=new ComboBox{Header="直線延伸",ItemsSource=new[]{"線段","向 A 延伸","向 B 延伸","雙向延伸"},SelectedIndex=Array.IndexOf(new[]{"none","start","end","both"},_session.Selected?.Extension??CurrentStyle.Extension)};
        box.SelectionChanged+=(_,_)=>ChangeProperty(()=>{var extension=new[]{"none","start","end","both"}[Math.Max(0,box.SelectedIndex)];if(_session.Selected is {Type:"line" or "arrow"} o)o.Extension=extension;else CurrentStyle.Extension=extension;});
        ShowExclusiveFlyout(new Flyout{Content=box},anchor);
    }
    private void ShowLaserSettings(FrameworkElement anchor)
    {
        var panel=new StackPanel{Width=280,Spacing=8};
        var mode=new ComboBox{Header="雷射模式",ItemsSource=new[]{"光點","短尾跡","線條"},SelectedIndex=Array.IndexOf(new[]{"point","shortTrail","line"},_laser.Mode)};
        mode.SelectionChanged+=(_,_)=>{_laser.Mode=new[]{"point","shortTrail","line"}[Math.Max(0,mode.SelectedIndex)];_laser.Clear();};panel.Children.Add(mode);
        var wheel=ColorWheel(_laser.Color);wheel.ColorChanged+=(_,e)=>_laser.Color=ColorHex(e.NewColor);panel.Children.Add(wheel);
        var diameter=new Slider{Header="光點直徑",Minimum=4,Maximum=64,Value=_laser.PointDiameter};diameter.ValueChanged+=(_,_)=>_laser.PointDiameter=diameter.Value;panel.Children.Add(diameter);
        var width=new Slider{Header="尾跡粗細",Minimum=1,Maximum=32,Value=_laser.Width};width.ValueChanged+=(_,_)=>_laser.Width=width.Value;panel.Children.Add(width);
        var fade=new Slider{Header="消退時間（秒）",Minimum=.1,Maximum=5,StepFrequency=.1,Value=_laser.FadeDuration};fade.ValueChanged+=(_,_)=>_laser.FadeDuration=fade.Value;panel.Children.Add(fade);
        var white=new CheckBox{Content="白色光芯",IsChecked=_laser.WhiteCore};white.Checked+=(_,_)=>_laser.WhiteCore=true;white.Unchecked+=(_,_)=>_laser.WhiteCore=false;panel.Children.Add(white);
        var flyout=new Flyout{Content=panel};flyout.Closed+=async(_,_)=>await SaveTeachingSettingsAsync();ShowExclusiveFlyout(flyout,anchor);
    }
    private void AddExtendedObjectSettings(StackPanel panel,BoardObject? selected)
    {
        if(selected is null||selected.Type is "stroke" or "pen" or "highlighter" or "paint")
        {
            var kinds=new[]{"pen","fountain","pencil","watercolor","highlighter","crayon","calligraphy","paint"};
            var brush=new ComboBox{Header="筆刷",ItemsSource=new[]{"向量筆","鋼筆","鉛筆","水彩","螢光筆","蠟筆","書法","油漆"},SelectedIndex=Math.Max(0,Array.IndexOf(kinds,selected?.BrushKind??CurrentStyle.BrushKind))};
            brush.SelectionChanged+=(_,_)=>ChangeProperty(()=>{var kind=kinds[Math.Max(0,brush.SelectedIndex)];if(_session.Selected is { } o)o.BrushKind=kind;else CurrentStyle.BrushKind=kind;});panel.Children.Add(brush);
        }
        if(selected?.Type is "line" or "arrow")
        {var b=new Button{Content="延伸直線設定"};b.Click+=(_,_)=>ShowExtensionSettings(b);panel.Children.Add(b);}
        if(selected?.Type=="arrow")
        {
            var length=new Slider{Header="箭頭頭部長度",Minimum=4,Maximum=128,Value=selected.ArrowHeadLength??16,StepFrequency=1};
            length.ValueChanged+=(_,e)=>ChangeProperty(()=>selected.ArrowHeadLength=e.NewValue);panel.Children.Add(length);
            var width=new Slider{Header="箭頭頭部寬度",Minimum=4,Maximum=96,Value=selected.ArrowHeadWidth??10,StepFrequency=1};
            width.ValueChanged+=(_,e)=>ChangeProperty(()=>selected.ArrowHeadWidth=e.NewValue);panel.Children.Add(width);
        }
        if(selected?.Type is "text" or "sticky")
        {
            var edit=new Button{Content="編輯局部文字格式"};edit.Click+=async(_,_)=>await EditRichTextAsync(selected);panel.Children.Add(edit);
            var row=new StackPanel{Orientation=Orientation.Vertical,Spacing=4};
            foreach(var pair in new[]{("粗體","IsBold"),("斜體","IsItalic"),("底線","IsUnderline"),("刪除線","IsStrikethrough")})
            {var prop=typeof(BoardObject).GetProperty(pair.Item2)!;var cb=new CheckBox{Content=pair.Item1,IsChecked=(bool?)prop.GetValue(selected)==true};cb.Checked+=(_,_)=>ChangeProperty(()=>{prop.SetValue(selected,true);selected.RichTextSpans=null;});cb.Unchecked+=(_,_)=>ChangeProperty(()=>{prop.SetValue(selected,false);selected.RichTextSpans=null;});row.Children.Add(cb);}
            panel.Children.Add(row);
            var alignment=new ComboBox{Header="對齊",ItemsSource=new[]{"靠左","置中","靠右"},SelectedIndex=Array.IndexOf(new[]{"left","center","right"},selected.Align??"left")};alignment.SelectionChanged+=(_,_)=>ChangeProperty(()=>selected.Align=new[]{"left","center","right"}[Math.Max(0,alignment.SelectedIndex)]);panel.Children.Add(alignment);
            var font=new ComboBox{Header="字型",ItemsSource=new[]{"Microsoft JhengHei","Microsoft YaHei","Segoe UI","Consolas"},SelectedItem=selected.FontFamily??"Microsoft JhengHei"};font.SelectionChanged+=(_,_)=>ChangeProperty(()=>selected.FontFamily=font.SelectedItem?.ToString());panel.Children.Add(font);
            if(selected.Type=="sticky")
            {var styles=new[]{"classic","washi","cat","notebook","grid","soft"};var sticky=new ComboBox{Header="便簽風格",ItemsSource=new[]{"經典","紙膠帶","貓咪","筆記本","方格","柔和"},SelectedIndex=Math.Max(0,Array.IndexOf(styles,selected.StickyStyle??"classic"))};sticky.SelectionChanged+=(_,_)=>ChangeProperty(()=>selected.StickyStyle=styles[Math.Max(0,sticky.SelectedIndex)]);panel.Children.Add(sticky);}
        }
        if(selected?.Type=="image")
        {var b=new Button{Content="裁切圖片／恢復原圖"};b.Click+=async(_,_)=>await ShowImageCropAsync(selected);panel.Children.Add(b);}
        if(selected?.Type=="tape")
        {var b=new Button{Content=selected.IsRevealed==true?"遮住題目":"揭示題目"};b.Click+=(_,_)=>ChangeProperty(()=>selected.IsRevealed=selected.IsRevealed!=true);panel.Children.Add(b);}
    }
    private async Task ShowImageCropAsync(BoardObject image)
    {
        CommitPropertyEdit();var boardId=_session.Document.Board.Id;
        var ow=image.OriginalWidth??image.Width;var oh=image.OriginalHeight??image.Height;
        var panel=new StackPanel{Spacing=8};
        var x=new NumberBox{Header="左側（原圖像素）",Minimum=0,Maximum=Math.Max(0,ow-1),Value=image.CropX??0};
        var y=new NumberBox{Header="上側（原圖像素）",Minimum=0,Maximum=Math.Max(0,oh-1),Value=image.CropY??0};
        var w=new NumberBox{Header="寬度（原圖像素）",Minimum=1,Maximum=ow,Value=image.CropWidth??ow};
        var h=new NumberBox{Header="高度（原圖像素）",Minimum=1,Maximum=oh,Value=image.CropHeight??oh};
        foreach(var control in new[]{x,y,w,h})panel.Children.Add(control);
        var result=await new ContentDialog{Title="圖片裁切",Content=panel,PrimaryButtonText="套用裁切",SecondaryButtonText="恢復原圖",CloseButtonText="取消",XamlRoot=Root.XamlRoot}.ShowAsync();
        if(result==ContentDialogResult.None||_session.Document.Board.Id!=boardId||!_session.Document.Objects.Contains(image)||image.IsLocked==true)return;
        _session.Begin();
        if(result==ContentDialogResult.Secondary){var scale=image.Width/Math.Max(1,image.CropWidth??ow);image.CropX=image.CropY=image.CropWidth=image.CropHeight=null;image.Width=ow*scale;image.Height=oh*scale;}
        else if(new[]{x.Value,y.Value,w.Value,h.Value}.All(double.IsFinite)){var scale=image.Width/Math.Max(1,image.CropWidth??ow);image.CropX=Math.Clamp(x.Value,0,ow-1);image.CropY=Math.Clamp(y.Value,0,oh-1);image.CropWidth=Math.Clamp(w.Value,1,ow-image.CropX.Value);image.CropHeight=Math.Clamp(h.Value,1,oh-image.CropY.Value);image.Width=image.CropWidth.Value*scale;image.Height=image.CropHeight.Value*scale;}
        _session.Commit();RefreshEditor();
    }
}
