using static HeiBan.Windows.Localization.Strings;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed class ScreenFloatingToolWindow : Window
{
    internal nint Handle => WinRT.Interop.WindowNative.GetWindowHandle(this);

    internal ScreenFloatingToolWindow(string title, FrameworkElement content, int widthDips, int heightDips, Action? onClosed = null)
    {
        Title = title;

        var header = new Grid
        {
            Height = 36,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 232, 239, 230)),
            Padding = new Thickness(12, 0, 8, 0)
        };
        header.Children.Add(new TextBlock
        {
            Text = "⋮⋮  " + title,
            VerticalAlignment = VerticalAlignment.Center,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 45, 90, 70))
        });

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 4 };
        var collapseBtn = new Button
        {
            Content = "−",
            Width = 28,
            Height = 28,
            Padding = new Thickness(0),
            FontSize = 14,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0, 0, 0, 0)),
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(6)
        };
        ToolTipService.SetToolTip(collapseBtn, T("收合／展開"));

        var closeBtn = new Button
        {
            Content = "✕",
            Width = 28,
            Height = 28,
            Padding = new Thickness(0),
            FontSize = 12,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0, 0, 0, 0)),
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(6)
        };
        ToolTipService.SetToolTip(closeBtn, T("關閉"));

        buttons.Children.Add(collapseBtn);
        buttons.Children.Add(closeBtn);
        header.Children.Add(buttons);

        var headerBorder = new Border
        {
            Child = header,
            CornerRadius = new CornerRadius(10, 10, 0, 0),
            Background = header.Background
        };

        var scroll = new ScrollViewer
        {
            Content = content,
            MaxHeight = heightDips - 44,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Padding = new Thickness(8)
        };

        var root = new Grid
        {
            RowDefinitions =
            {
                new RowDefinition { Height = GridLength.Auto },
                new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }
            },
            RequestedTheme = ElementTheme.Light,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 252, 252, 250))
        };
        root.Children.Add(headerBorder);
        Grid.SetRow(scroll, 1);
        root.Children.Add(scroll);

        var border = new Border
        {
            Child = root,
            BorderBrush = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 212, 219, 209)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10)
        };

        Content = border;

        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.SetBorderAndTitleBar(false, false);
            presenter.IsAlwaysOnTop = true;
            presenter.IsResizable = false;
            presenter.IsMaximizable = false;
        }

        var scale = NativeOverlayWindow.DpiScale(Handle);
        var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Nearest).WorkArea;
        AppWindow.Resize(new SizeInt32(Math.Min(area.Width - 24, (int)(widthDips * scale)), Math.Min(area.Height - 24, (int)(heightDips * scale))));

        header.PointerPressed += (_, e) =>
        {
            var pt = e.GetCurrentPoint(header);
            if (!pt.Properties.IsLeftButtonPressed) return;
            var src = e.OriginalSource as DependencyObject;
            while (src != null && src != header)
            {
                if (src is Button) return;
                src = VisualTreeHelper.GetParent(src);
            }
            NativeOverlayWindow.ReleaseCapture();
            NativeOverlayWindow.SendMessage(Handle, 0x00A1, 2, 0); // WM_NCLBUTTONDOWN, HTCAPTION
        };

        var isCollapsed = false;
        collapseBtn.Click += (_, _) =>
        {
            isCollapsed = !isCollapsed;
            scroll.Visibility = isCollapsed ? Visibility.Collapsed : Visibility.Visible;
            var targetHeight = isCollapsed ? (int)(38 * scale) : Math.Min(area.Height - 24, (int)(heightDips * scale));
            AppWindow.Resize(new SizeInt32(AppWindow.Size.Width, targetHeight));
        };

        closeBtn.Click += (_, _) =>
        {
            Close();
        };

        Closed += (_, _) =>
        {
            onClosed?.Invoke();
        };
    }
}
