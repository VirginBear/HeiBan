using System.Numerics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.System;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private TextBox? _pinNameEditor;
    private string? _pinNameId;
    private long _pinNameEpoch;

    private BoardPin? PinAt(Vector2 point)=>_session.Document.Board.Pins?.LastOrDefault(pin=>
    {
        var screen=_viewport.WorldToScreen(pin.X,pin.Y);
        if(Vector2.Distance(point,new((float)screen.X,(float)screen.Y))<18)return true;
        using var format=new CanvasTextFormat{FontSize=14};
        using var text=new CanvasTextLayout(CanvasSurface,pin.Name,format,10000,30);
        return point.X>=screen.X+12&&point.X<=screen.X+20+text.LayoutBounds.Width&&point.Y>=screen.Y-3&&point.Y<=screen.Y+23;
    });

    private void StartPinRename(BoardPin pin)
    {
        FinishText();CommitPropertyEdit();CancelGesture();
        if(_session.Document.Board.Pins?.Any(p=>p.Id==pin.Id)!=true)return;
        _pinNameId=pin.Id;_pinNameEpoch=_session.DocumentEpoch;
        var point=_viewport.WorldToScreen(pin.X,pin.Y);
        var editor=new TextBox{Text=pin.Name,MinWidth=180,MaxWidth=360,PlaceholderText="圖釘名稱"};
        _pinNameEditor=editor;Canvas.SetLeft(editor,Math.Clamp(point.X+12,0,Math.Max(0,CanvasSurface.ActualWidth-360)));Canvas.SetTop(editor,Math.Clamp(point.Y-8,0,Math.Max(0,CanvasSurface.ActualHeight-40)));
        TextOverlay.IsHitTestVisible=true;TextOverlay.Children.Add(editor);
        editor.KeyDown+=(_,e)=>{if(e.Key==VirtualKey.Enter){FinishPinRename();e.Handled=true;}else if(e.Key==VirtualKey.Escape){FinishPinRename(false);e.Handled=true;}};
        editor.LostFocus+=(_,_)=>{if(ReferenceEquals(_pinNameEditor,editor))FinishPinRename();};
        editor.Focus(FocusState.Programmatic);editor.SelectAll();
    }

    private void FinishPinRename(bool commit=true)
    {
        if(_pinNameEditor is not { } editor)return;
        var id=_pinNameId;_pinNameEditor=null;_pinNameId=null;TextOverlay.Children.Remove(editor);TextOverlay.IsHitTestVisible=_editor is not null;
        var pin=_pinNameEpoch==_session.DocumentEpoch?_session.Document.Board.Pins?.FirstOrDefault(p=>p.Id==id):null;
        var name=editor.Text.Trim();
        if(commit&&pin is not null&&name.Length>0&&pin.Name!=name){_session.Begin();pin.Name=name;_session.Commit();RefreshEditor();}
    }

    private void BeginWindowSelection(InkPoint start,bool additive)
    {
        _marquee=true;_marqueeSelection=additive?_session.SelectedIds.ToArray():[];
        _preview=new BoardObject{Type="rect",X=start.X,Y=start.Y,Width=0,Height=0,StrokeColor="#39735A",StrokeWidth=1/_viewport.Zoom,FillColor="none"};
    }
    private void UpdateWindowSelection(InkPoint end)
    {
        if(_preview is null||_start is null)return;
        _preview.X=Math.Min(_start.X,end.X);_preview.Y=Math.Min(_start.Y,end.Y);_preview.Width=Math.Abs(end.X-_start.X);_preview.Height=Math.Abs(end.Y-_start.Y);
        _preview.LineStyle=end.X<_start.X?"dashed":"solid";_preview.StrokeColor=end.X<_start.X?"#39735A":"#3976C4";
    }
    private void CompleteWindowSelection(InkPoint end)
    {
        if(_start is not null&&Math.Max(Math.Abs(end.X-_start.X),Math.Abs(end.Y-_start.Y))*_viewport.Zoom>3)
            _session.SetSelection(_session.VisibleObjects.Where(o=>WindowSelection.Matches(o,_start,end)).Select(o=>o.Id).Concat(_marqueeSelection));
        _preview=null;_marquee=false;
    }
}
