using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows.Views;

internal sealed partial class TextDraftEditor
{
    private CanvasControl? _layoutPreview;
    private Direct2DCanvasRenderer? _previewRenderer;
    private DispatcherTimer? _previewTimer;
    private BoardObject? _previewDraft;
    private bool _layoutPreviewVisible;
    private FrameworkElement CreateLayoutPreview()
    {
        // CanvasControl has no intrinsic width. Give its ContentControl host a
        // nonzero desired width before the first native toolbar measurement.
        _layoutPreview=new CanvasControl{Width=520,Height=120};
        _layoutPreview.Draw+=(_,args)=>
        {
            args.DrawingSession.Clear(Microsoft.UI.Colors.White);
            if(_previewDraft is not {} draft)return;
            _previewRenderer??=new();
            var zoom=Math.Min((_layoutPreview.ActualWidth-16)/Math.Max(1,draft.Width),104/Math.Max(1,draft.Height));
            var viewport=new ViewportTransform{Zoom=Math.Max(.01,zoom),X=8,Y=8};
            _previewRenderer.RenderPreview(args.DrawingSession,draft,viewport,(float)_layoutPreview.ActualWidth,120);
        };
        return new Border{Child=_layoutPreview,BorderBrush=Brush("#D4DBD1"),BorderThickness=new(1),CornerRadius=new(6)};
    }
    private void QueueLayoutPreview()
    {
        if(!_layoutPreviewVisible||_layoutPreview is null||_draft is null||!IsLoaded||_awaitingInitialFormat)return;
        if(_previewTimer is null)
        {
            _previewTimer=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(80)};
            _previewTimer.Tick+=(_,_)=>
            {
                _previewTimer.Stop();
                if(!_layoutPreviewVisible||_draft is null||!IsLoaded)return;
                _previewDraft=DocumentCodec.Clone(_draft);ReadDraft(_previewDraft);_previewDraft.X=_previewDraft.Y=0;
                _previewDraft.Rotation=0;_layoutPreview?.Invalidate();
            };
        }
        // One pending preview samples the most recent native document; typing never saves the board.
        if(!_previewTimer.IsEnabled)_previewTimer.Start();
    }
    private void StopLayoutPreview()
    {
        _previewTimer?.Stop();_previewRenderer?.Dispose();_previewRenderer=null;_previewDraft=null;
        _layoutPreview?.RemoveFromVisualTree();_layoutPreview=null;
    }
}
