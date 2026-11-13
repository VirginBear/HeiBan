using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Windows.ApplicationModel.DataTransfer;
using Windows.System;

namespace HeiBan.Windows.ScreenAnnotation;

internal sealed partial class ScreenAnnotationWindow
{
    private readonly CalculatorModel _calculator = new();
    private readonly TimerCoordinator _timerCoordinator = new();
    private DispatcherTimer? _screenTimerTick;
    private ScreenFloatingToolWindow? _screenCalcWindow;
    private ScreenFloatingToolWindow? _screenTimerWindow;
    private Action? _screenTimerDisplayUpdater;

    internal void CloseFloatingTeachingTools()
    {
        _screenTimerTick?.Stop();_timerCoordinator.Pause();_screenTimerDisplayUpdater=null;
        _screenCalcWindow?.Close();
        _screenCalcWindow = null;
        _screenTimerWindow?.Close();
        _screenTimerWindow = null;
    }

    private void EnsureScreenTimerTick()
    {
        if(_screenTimerTick is null)
        {
            _screenTimerTick=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(100)};
            _screenTimerTick.Tick+=(_,_)=>
            {
                if(!IsActive||_stopping){_screenTimerTick.Stop();return;}
                _timerCoordinator.UpdateDisplayTimes();_screenTimerDisplayUpdater?.Invoke();
                if(_timerCoordinator.DidAlertTimesUp)_status.Text=T("計時器：時間到！");
                if(_timerCoordinator.Status!=TimerStatus.Running)_screenTimerTick.Stop();
            };
        }
        if(IsActive&&_timerCoordinator.Status==TimerStatus.Running)_screenTimerTick.Start();else _screenTimerTick.Stop();
    }

    private void ShowScreenCalculatorPanel(FrameworkElement? anchor = null)
    {
        if (_screenCalcWindow is not null)
        {
            _screenCalcWindow.Activate();
            return;
        }

        var panel = new StackPanel { Width = 310, Spacing = 8, Padding = new Thickness(4), RequestedTheme = ElementTheme.Light };
        var titleRow = new Grid();
        titleRow.Children.Add(new TextBlock { Text = T("計算機"), FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        var modeBtn = new Button { Content = _calculator.IsDegreeMode ? "DEG" : "RAD", FontSize = 11, Padding = new Thickness(6, 2, 6, 2), HorizontalAlignment = HorizontalAlignment.Right };
        titleRow.Children.Add(modeBtn);
        panel.Children.Add(titleRow);

        var exprText = new TextBlock { Text = _calculator.Expression, FontSize = 12, Foreground = ChromeBrush(255, 104, 117, 108), TextAlignment = TextAlignment.Right, Height = 18 };
        panel.Children.Add(exprText);

        var displayBox = new TextBox { Text = _calculator.Display, FontSize = 22, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextAlignment = TextAlignment.Right, Margin = new Thickness(0, 0, 0, 4) };
        displayBox.KeyDown += (_, e) =>
        {
            if (e.Key == VirtualKey.Enter)
            {
                _calculator.EvaluateCurrentExpression(displayBox.Text);
                RefreshCalcDisplay();
                e.Handled = true;
            }
            else if (e.Key == VirtualKey.Escape)
            {
                _calculator.Clear();
                RefreshCalcDisplay();
                e.Handled = true;
            }
        };
        panel.Children.Add(displayBox);

        void RefreshCalcDisplay()
        {
            exprText.Text = _calculator.Expression;
            displayBox.Text = _calculator.Display;
            modeBtn.Content = _calculator.IsDegreeMode ? "DEG" : "RAD";
        }

        modeBtn.Click += (_, _) => { _calculator.ToggleDegreeMode(); RefreshCalcDisplay(); };

        var grid = new Grid { RowSpacing = 4, ColumnSpacing = 4 };
        for (var r = 0; r < 7; r++) grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        for (var c = 0; c < 5; c++) grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var btnDefs = new (string text, int col, int row, Action action)[]
        {
            ("(", 0, 0, () => _calculator.InputParenthesis("(")),
            (")", 1, 0, () => _calculator.InputParenthesis(")")),
            ("CE", 2, 0, () => _calculator.ClearEntry()),
            ("C", 3, 0, () => _calculator.Clear()),
            ("⌫", 4, 0, () => _calculator.Backspace()),

            ("sin", 0, 1, () => _calculator.SinFunction()),
            ("cos", 1, 1, () => _calculator.CosFunction()),
            ("tan", 2, 1, () => _calculator.TanFunction()),
            ("^", 3, 1, () => _calculator.InputOperator("^")),
            ("÷", 4, 1, () => _calculator.InputOperator("/")),

            ("ln", 0, 2, () => _calculator.LnFunction()),
            ("7", 1, 2, () => _calculator.InputDigit("7")),
            ("8", 2, 2, () => _calculator.InputDigit("8")),
            ("9", 3, 2, () => _calculator.InputDigit("9")),
            ("×", 4, 2, () => _calculator.InputOperator("*")),

            ("log", 0, 3, () => _calculator.Log10Function()),
            ("4", 1, 3, () => _calculator.InputDigit("4")),
            ("5", 2, 3, () => _calculator.InputDigit("5")),
            ("6", 3, 3, () => _calculator.InputDigit("6")),
            ("−", 4, 3, () => _calculator.InputOperator("-")),

            ("√", 0, 4, () => _calculator.SquareRoot()),
            ("1", 1, 4, () => _calculator.InputDigit("1")),
            ("2", 2, 4, () => _calculator.InputDigit("2")),
            ("3", 3, 4, () => _calculator.InputDigit("3")),
            ("＋", 4, 4, () => _calculator.InputOperator("+")),

            ("1/x", 0, 5, () => _calculator.Reciprocal()),
            ("x²", 1, 5, () => _calculator.Square()),
            ("0", 2, 5, () => _calculator.InputDigit("0")),
            (".", 3, 5, () => _calculator.InputDecimal()),
            ("＝", 4, 5, () => _calculator.CalculateResult()),

            ("±", 0, 6, () => _calculator.ToggleSign()),
            ("%", 1, 6, () => _calculator.InputPercentage()),
            ("π", 2, 6, () => _calculator.InputDigit("3.14159265")),
            ("e", 3, 6, () => _calculator.InputDigit("2.71828183")),
            ("Ans", 4, 6, () => { if (_calculator.History.Count > 0) _calculator.SetResult(_calculator.History[0].Result); }),
        };

        foreach (var (txt, col, row, act) in btnDefs)
        {
            var b = new Button
            {
                Content = txt,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Stretch,
                Padding = new Thickness(0),
                Height = 32,
                FontSize = txt.Length > 2 ? 11 : 13
            };
            var isEquals = txt is "=" or "＝";
            if (isEquals)
            {
                b.Style = (Style)Application.Current.Resources["AccentButtonStyle"];
            }
            else
            {
                var isDigit = char.IsDigit(txt[0]) || txt is "." or "0";
                if (!isDigit) b.Background = ChromeBrush(255, 240, 244, 236);
            }
            b.Click += (_, _) => { act(); RefreshCalcDisplay(); };
            Grid.SetColumn(b, col);
            Grid.SetRow(b, row);
            grid.Children.Add(b);
        }
        panel.Children.Add(grid);

        var actionsRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Margin = new Thickness(0, 6, 0, 0) };
        var insertBtn = new Button { Content = T("插入畫布"), Style = (Style)Application.Current.Resources["AccentButtonStyle"], FontSize = 12 };
        insertBtn.Click += async (_, _) =>
        {
            var epoch=_session.DocumentEpoch;var board=_session.Document.Board;
            var textObj=_calculator.CreateBoardObject(_overlay.Width/2,_overlay.Height/2,board.Id,board.ActivePageId,asExpression:true);
            await InsertScreenObjectAsync(textObj,epoch);
        };
        actionsRow.Children.Add(insertBtn);

        var copyBtn = new Button { Content = T("複製結果"), FontSize = 12 };
        copyBtn.Click += (_, _) =>
        {
            var dp = new DataPackage();
            dp.SetText(_calculator.Display);
            Clipboard.SetContent(dp);
            _status.Text = T("已複製計算結果至剪貼簿");
        };
        actionsRow.Children.Add(copyBtn);

        var historyBtn = new Button { Content = T("歷史"), FontSize = 12 };
        historyBtn.Click += (_, _) =>
        {
            var histMenu = new MenuFlyout();
            if (_calculator.History.Count == 0)
            {
                histMenu.Items.Add(new MenuFlyoutItem { Text = T("尚無歷史紀錄"), IsEnabled = false });
            }
            else
            {
                foreach (var item in _calculator.History.Take(10))
                {
                    var mi = new MenuFlyoutItem { Text = $"{item.Expression} {item.Result}" };
                    mi.Click += (_, _) =>
                    {
                        _calculator.SetResult(item.Result);
                        RefreshCalcDisplay();
                    };
                    histMenu.Items.Add(mi);
                }
                histMenu.Items.Add(new MenuFlyoutSeparator());
                var clearHist = new MenuFlyoutItem { Text = T("清除歷史紀錄") };
                clearHist.Click += (_, _) => { _calculator.History.Clear(); };
                histMenu.Items.Add(clearHist);
            }
            histMenu.ShouldConstrainToRootBounds=_region is not null;
            histMenu.ShowAt(historyBtn);
        };
        actionsRow.Children.Add(historyBtn);
        panel.Children.Add(actionsRow);

        _screenCalcWindow = new ScreenFloatingToolWindow(T("計算機"), panel, 340, 520, () => _screenCalcWindow = null,_region);
        PlaceRegionWindow(_screenCalcWindow);
        _screenCalcWindow.Activate();
    }

    private void ShowScreenTimerPanel(FrameworkElement? anchor = null)
    {
        EnsureScreenTimerTick();
        if (_screenTimerWindow is not null)
        {
            _screenTimerWindow.Activate();
            return;
        }

        var panel = new StackPanel { Width = 280, Spacing = 10, Padding = new Thickness(4), RequestedTheme = ElementTheme.Light };
        panel.Children.Add(new TextBlock { Text = T("計時器"), FontSize = 15, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });

        var modeRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var swBtn = new Button { Content = T("碼表正計時"), FontSize = 12, Background = _timerCoordinator.Mode == TimerMode.Stopwatch ? ChromeBrush(255, 220, 235, 221) : ChromeBrush(255, 252, 252, 250) };
        var cdBtn = new Button { Content = T("倒數計時"), FontSize = 12, Background = _timerCoordinator.Mode == TimerMode.Countdown ? ChromeBrush(255, 220, 235, 221) : ChromeBrush(255, 252, 252, 250) };
        modeRow.Children.Add(swBtn);
        modeRow.Children.Add(cdBtn);
        panel.Children.Add(modeRow);

        var timeDisplay = new TextBlock
        {
            Text = _timerCoordinator.FormattedTimeString(),
            FontSize = 36,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 4, 0, 4)
        };
        panel.Children.Add(timeDisplay);

        var countdownPresets = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Visibility = _timerCoordinator.Mode == TimerMode.Countdown ? Visibility.Visible : Visibility.Collapsed };
        foreach (var m in new[] { 1, 3, 5, 10, 15, 20, 30 })
        {
            var pb = new Button { Content = $"{m}m", Padding = new Thickness(6, 2, 6, 2), FontSize = 11 };
            var min = m;
            pb.Click += (_, _) =>
            {
                _timerCoordinator.SelectPresetMinutes(min);
                timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            };
            countdownPresets.Children.Add(pb);
        }
        panel.Children.Add(countdownPresets);

        var customDuration = new NumberBox { Header = T("自訂倒數（秒）"), Minimum = 1, Maximum = 86400, Value = _timerCoordinator.CountdownDuration };
        var applyDuration = new Button { Content = T("套用自訂倒數") };
        applyDuration.Click += (_, _) =>
        {
            if (!double.IsFinite(customDuration.Value)) return;
            _timerCoordinator.Mode = TimerMode.Countdown;
            _timerCoordinator.Reset();EnsureScreenTimerTick();
            _timerCoordinator.SetCountdownDuration(customDuration.Value);
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
        };
        var customRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Visibility = _timerCoordinator.Mode == TimerMode.Countdown ? Visibility.Visible : Visibility.Collapsed };
        customRow.Children.Add(customDuration);
        customRow.Children.Add(applyDuration);
        panel.Children.Add(customRow);

        var playBtn = new Button
        {
            Content = _timerCoordinator.Status == TimerStatus.Running ? T("暫停") : T("開始"),
            Style = (Style)Application.Current.Resources["AccentButtonStyle"],
            HorizontalAlignment = HorizontalAlignment.Stretch,
            Height = 36
        };
        var resetBtn = new Button { Content = T("重設"), HorizontalAlignment = HorizontalAlignment.Stretch };

        _screenTimerDisplayUpdater=()=>
        {
            timeDisplay.Text=_timerCoordinator.FormattedTimeString();
            playBtn.Content=_timerCoordinator.Status==TimerStatus.Running?T("暫停"):T("開始");
        };

        playBtn.Click += (_, _) =>
        {
            _timerCoordinator.TogglePlayPause();EnsureScreenTimerTick();
            playBtn.Content = _timerCoordinator.Status == TimerStatus.Running ? T("暫停") : T("開始");
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
        };

        resetBtn.Click += (_, _) =>
        {
            _timerCoordinator.Reset();EnsureScreenTimerTick();
            playBtn.Content = T("開始");
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
        };

        swBtn.Click += (_, _) =>
        {
            _timerCoordinator.Mode = TimerMode.Stopwatch;
            _timerCoordinator.Reset();EnsureScreenTimerTick();
            swBtn.Background = ChromeBrush(255, 220, 235, 221);
            cdBtn.Background = ChromeBrush(255, 252, 252, 250);
            countdownPresets.Visibility = Visibility.Collapsed;
            customRow.Visibility = Visibility.Collapsed;
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            playBtn.Content = T("開始");
        };

        cdBtn.Click += (_, _) =>
        {
            _timerCoordinator.Mode = TimerMode.Countdown;
            _timerCoordinator.Reset();EnsureScreenTimerTick();
            cdBtn.Background = ChromeBrush(255, 220, 235, 221);
            swBtn.Background = ChromeBrush(255, 252, 252, 250);
            countdownPresets.Visibility = Visibility.Visible;
            customRow.Visibility = Visibility.Visible;
            timeDisplay.Text = _timerCoordinator.FormattedTimeString();
            playBtn.Content = T("開始");
        };

        var ctrlRow = new Grid { ColumnSpacing = 8 };
        ctrlRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        ctrlRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        Grid.SetColumn(playBtn, 0);
        Grid.SetColumn(resetBtn, 1);
        ctrlRow.Children.Add(playBtn);
        ctrlRow.Children.Add(resetBtn);
        panel.Children.Add(ctrlRow);

        var insertTimerBtn = new Button { Content = T("插入畫布"), HorizontalAlignment = HorizontalAlignment.Stretch, Margin = new Thickness(0, 4, 0, 0) };
        insertTimerBtn.Click += async (_, _) =>
        {
            var epoch=_session.DocumentEpoch;var board=_session.Document.Board;
            var textObj=_timerCoordinator.CreateBoardObject(_overlay.Width/2,_overlay.Height/2,board.Id,board.ActivePageId);
            await InsertScreenObjectAsync(textObj,epoch);
        };
        panel.Children.Add(insertTimerBtn);

        _screenTimerWindow = new ScreenFloatingToolWindow(T("計時器"), panel, 320, 460, () =>
        {
            _screenTimerDisplayUpdater=null;
            _screenTimerWindow = null;
        },_region);
        PlaceRegionWindow(_screenTimerWindow);
        _screenTimerWindow.Activate();
    }
}
