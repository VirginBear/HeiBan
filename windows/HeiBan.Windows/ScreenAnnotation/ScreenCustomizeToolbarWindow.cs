using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using global::Windows.Graphics;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed class ScreenCustomizeToolbarWindow : Window
{
    internal nint Handle => WinRT.Interop.WindowNative.GetWindowHandle(this);

    internal ScreenCustomizeToolbarWindow(ToolbarPreferences preferences, Func<Task> onSaved)
    {
        Title = T("自訂工具列 · 螢幕畫布");

        var allKeys = preferences.VisibleTools
            .Concat(preferences.HiddenTools)
            .Concat(ToolbarPreferences.AllDefaultTools)
            .Distinct().Where(key => key != "extension" && ToolbarContentPolicy.IsAvailableOnScreen(key))
            .ToList();

        var visibleSet = new HashSet<string>(preferences.VisibleTools.Where(ToolbarContentPolicy.IsAvailableOnScreen));
        var commonSet = new HashSet<string>(preferences.CommonTools.Where(ToolbarContentPolicy.IsAvailableOnScreen));
        var displayMode = preferences.DisplayMode;
        var panel = new StackPanel { Spacing = 6 };

        void RebuildList()
        {
            panel.Children.Clear();
            for (var i = 0; i < allKeys.Count; i++)
            {
                var idx = i;
                var key = allKeys[i];
                var grid = new Grid { ColumnSpacing = 8, VerticalAlignment = VerticalAlignment.Center };
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var left = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, VerticalAlignment = VerticalAlignment.Center };
                var visibleBox = new CheckBox
                {
                    IsChecked = visibleSet.Contains(key),
                    IsEnabled = !ToolbarPreferences.IsFixedTool(key),
                    MinWidth = 0,
                    Padding = new Thickness(0),
                    VerticalAlignment = VerticalAlignment.Center
                };
                visibleBox.Checked += (_, _) => visibleSet.Add(key);
                visibleBox.Unchecked += (_, _) => visibleSet.Remove(key);
                left.Children.Add(visibleBox);

                var icon = ToolIcons.CreateIcon(key);
                icon.Width = icon.Height = 18;
                icon.VerticalAlignment = VerticalAlignment.Center;
                left.Children.Add(icon);

                var label = ToolbarUi.ScreenTools.FirstOrDefault(p => p.Key == key).Label ?? (ToolbarPreferences.ToolNames.TryGetValue(key, out var tn) ? tn : key);
                left.Children.Add(new TextBlock { Text = T(label), VerticalAlignment = VerticalAlignment.Center, FontSize = 13 });
                grid.Children.Add(left);

                var commonBox = new CheckBox
                {
                    Content = T("常用"),
                    IsChecked = commonSet.Contains(key),
                    IsEnabled = !ToolbarPreferences.IsFixedTool(key),
                    FontSize = 12,
                    VerticalAlignment = VerticalAlignment.Center
                };
                commonBox.Checked += (_, _) => commonSet.Add(key);
                commonBox.Unchecked += (_, _) => commonSet.Remove(key);
                Grid.SetColumn(commonBox, 1);
                grid.Children.Add(commonBox);

                var upBtn = new Button { Content = "↑", Padding = new Thickness(8, 4, 8, 4), IsEnabled = !ToolbarPreferences.IsFixedTool(key) && idx > 0 };
                upBtn.Click += (_, _) =>
                {
                    (allKeys[idx - 1], allKeys[idx]) = (allKeys[idx], allKeys[idx - 1]);
                    RebuildList();
                };
                Grid.SetColumn(upBtn, 2);
                grid.Children.Add(upBtn);

                var downBtn = new Button { Content = "↓", Padding = new Thickness(8, 4, 8, 4), IsEnabled = !ToolbarPreferences.IsFixedTool(key) && idx < allKeys.Count - 1 };
                downBtn.Click += (_, _) =>
                {
                    (allKeys[idx + 1], allKeys[idx]) = (allKeys[idx], allKeys[idx + 1]);
                    RebuildList();
                };
                Grid.SetColumn(downBtn, 3);
                grid.Children.Add(downBtn);

                panel.Children.Add(new Border
                {
                    Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 243, 247, 241)),
                    BorderBrush = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 224, 232, 222)),
                    BorderThickness = new Thickness(1),
                    CornerRadius = new CornerRadius(10),
                    Padding = new Thickness(10, 6, 10, 6),
                    Child = grid
                });
            }
        }

        RebuildList();

        var headerBar = new Grid
        {
            Height = 36,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 232, 239, 230)),
            Padding = new Thickness(12, 0, 8, 0)
        };
        headerBar.Children.Add(new TextBlock
        {
            Text = "⋮⋮  " + T("自訂工具列 · 螢幕畫布"),
            VerticalAlignment = VerticalAlignment.Center,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 45, 90, 70))
        });
        var closeBtn = new Button
        {
            Content = "✕",
            Width = 28,
            Height = 28,
            Padding = new Thickness(0),
            FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Background = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0, 0, 0, 0)),
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(6)
        };
        ToolTipService.SetToolTip(closeBtn, T("關閉"));
        closeBtn.Click += (_, _) => Close();
        headerBar.Children.Add(closeBtn);

        var headerBorder = new Border
        {
            Child = headerBar,
            CornerRadius = new CornerRadius(10, 10, 0, 0),
            Background = headerBar.Background
        };

        var header = new StackPanel { Spacing = 8 };

        var format = new ComboBox
        {
            Header = T("工具列格式"),
            ItemsSource = new[] { T("只有圖示"), T("圖示與文字（分頁）") },
            SelectedIndex = displayMode == "labels" ? 1 : 0,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        format.SelectionChanged += (_, _) => displayMode = format.SelectedIndex == 1 ? "labels" : "icons";
        header.Children.Add(format);

        var commands = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var all = new Button { Content = T("全選") };
        all.Click += (_, _) => { visibleSet.UnionWith(allKeys); RebuildList(); };
        var defaults = new Button { Content = T("預設") };
        defaults.Click += (_, _) =>
        {
            visibleSet.Clear();
            visibleSet.UnionWith(ToolbarPreferences.AllDefaultTools.Where(ToolbarContentPolicy.IsAvailableOnScreen));
            allKeys.Clear();
            allKeys.AddRange(ToolbarPreferences.AllDefaultTools.Where(k => k != "extension" && ToolbarContentPolicy.IsAvailableOnScreen(k)));
            format.SelectedIndex = 1;
            displayMode = "labels";
            commonSet.Clear();
            commonSet.UnionWith(ToolbarPreferences.DefaultCommonTools.Where(ToolbarContentPolicy.IsAvailableOnScreen));
            RebuildList();
        };
        commands.Children.Add(all);
        commands.Children.Add(defaults);
        header.Children.Add(commands);

        var hint = new TextBlock
        {
            Text = T("勾選顯示工具，勾選「常用」加入常用分頁；選取、雷射與藤條固定顯示。"),
            TextWrapping = TextWrapping.Wrap,
            FontSize = 12,
            Foreground = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 80, 105, 90))
        };

        var scroll = new ScrollViewer
        {
            Content = panel,
            MaxHeight = 380,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Padding = new Thickness(2)
        };

        void ApplyChanges()
        {
            var newVisible = new List<string>();
            var newHidden = new List<string>();
            foreach (var key in allKeys)
            {
                if (visibleSet.Contains(key)) newVisible.Add(key);
                else newHidden.Add(key);
            }
            if (newVisible.Count == 0) newVisible.Add("select");

            preferences.DisplayMode = displayMode;
            preferences.CommonTools = allKeys.Where(commonSet.Contains).ToList();
            preferences.VisibleTools = newVisible;
            preferences.HiddenTools = newHidden;
        }

        var bottomBar = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8, Margin = new Thickness(0, 10, 0, 0) };
        var cancelBtn = new Button { Content = T("取消"), MinWidth = 80 };
        var applyBtn = new Button { Content = T("套用"), MinWidth = 80 };
        var saveBtn = new Button { Content = T("儲存"), MinWidth = 80, Style = (Style)Application.Current.Resources["AccentButtonStyle"] };

        cancelBtn.Click += (_, _) => Close();
        applyBtn.Click += async (_, _) =>
        {
            ApplyChanges();
            await onSaved();
        };
        saveBtn.Click += async (_, _) =>
        {
            ApplyChanges();
            await onSaved();
            Close();
        };

        bottomBar.Children.Add(cancelBtn);
        bottomBar.Children.Add(applyBtn);
        bottomBar.Children.Add(saveBtn);

        var mainLayout = new StackPanel
        {
            Spacing = 10,
            Padding = new Thickness(16),
            Children = { header, hint, scroll, bottomBar }
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
        Grid.SetRow(mainLayout, 1);
        root.Children.Add(mainLayout);

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
        AppWindow.Resize(new SizeInt32(Math.Min(area.Width - 24, (int)(520 * scale)), Math.Min(area.Height - 24, (int)(640 * scale))));

        headerBar.PointerPressed += (_, e) =>
        {
            var pt = e.GetCurrentPoint(headerBar);
            if (!pt.Properties.IsLeftButtonPressed) return;
            var src = e.OriginalSource as DependencyObject;
            while (src != null && src != headerBar)
            {
                if (src is Button) return;
                src = VisualTreeHelper.GetParent(src);
            }
            NativeOverlayWindow.ReleaseCapture();
            NativeOverlayWindow.SendMessage(Handle, 0x00A1, 2, 0); // WM_NCLBUTTONDOWN, HTCAPTION
        };
    }
}
