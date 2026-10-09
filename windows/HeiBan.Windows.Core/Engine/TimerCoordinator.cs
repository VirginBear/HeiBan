using System.Diagnostics;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public enum TimerMode
{
    Stopwatch,
    Countdown
}

public enum TimerStatus
{
    Stopped,
    Running,
    Paused,
    TimesUp
}

/// <summary>
/// W-N05: 畫布內建計時器與碼表引擎 (對齊 TimerCoordinator.swift)
/// 支援正計時、倒數計時、5/15/25 分鐘預設、暫停/重設、單次到時提示、
/// 採用單調時間基準防睡眠偏差，支援將用時插入為畫布文字物件。
/// </summary>
public sealed class TimerCoordinator
{
    public TimerMode Mode { get; set; } = TimerMode.Stopwatch;
    public TimerStatus Status { get; set; } = TimerStatus.Stopped;
    public double ElapsedSeconds { get; private set; } = 0.0;
    public double CountdownDuration { get; set; } = 300.0; // 預設 5 分鐘
    public double RemainingSeconds { get; private set; } = 300.0;
    public bool IsVisible { get; set; } = false;
    public bool IsCollapsed { get; set; } = false;
    public double OffsetX { get; set; } = 80;
    public double OffsetY { get; set; } = 160;
    public bool DidAlertTimesUp { get; set; } = false;

    private long _sessionStartTimestamp = 0;
    private double _accumulatedElapsed = 0.0;

    public void Start()
    {
        if (Status == TimerStatus.Running) return;

        _sessionStartTimestamp = Stopwatch.GetTimestamp();
        Status = TimerStatus.Running;
        DidAlertTimesUp = false;
    }

    public void Pause()
    {
        if (Status != TimerStatus.Running) return;

        double currentSession = GetCurrentSessionSeconds();
        _accumulatedElapsed += currentSession;
        Status = TimerStatus.Paused;
        UpdateDisplayTimes();
    }

    public void Resume()
    {
        if (Status != TimerStatus.Paused) return;
        Start();
    }

    public void Reset()
    {
        _sessionStartTimestamp = 0;
        _accumulatedElapsed = 0.0;
        ElapsedSeconds = 0.0;
        RemainingSeconds = CountdownDuration;
        Status = TimerStatus.Stopped;
        DidAlertTimesUp = false;
    }

    public void TogglePlayPause()
    {
        switch (Status)
        {
            case TimerStatus.Stopped:
                Start();
                break;
            case TimerStatus.Running:
                Pause();
                break;
            case TimerStatus.Paused:
                Resume();
                break;
            case TimerStatus.TimesUp:
                Reset();
                Start();
                break;
        }
    }

    public void SetCountdownDuration(double seconds)
    {
        if (seconds <= 0 || double.IsNaN(seconds) || double.IsInfinity(seconds)) return;
        CountdownDuration = seconds;
        if (Status == TimerStatus.Stopped)
        {
            RemainingSeconds = seconds;
        }
    }

    public void SelectPresetMinutes(int minutes)
    {
        Mode = TimerMode.Countdown;
        Reset();
        SetCountdownDuration(minutes * 60.0);
    }

    public void UpdateDisplayTimes(double? simulatedElapsed = null)
    {
        double totalElapsed;
        if (simulatedElapsed.HasValue)
        {
            totalElapsed = simulatedElapsed.Value;
        }
        else
        {
            double currentSession = (Status == TimerStatus.Running) ? GetCurrentSessionSeconds() : 0.0;
            totalElapsed = _accumulatedElapsed + currentSession;
        }

        ElapsedSeconds = totalElapsed;

        if (Mode == TimerMode.Countdown)
        {
            double remain = Math.Max(0, CountdownDuration - totalElapsed);
            RemainingSeconds = remain;
            if (remain <= 0 && Status == TimerStatus.Running)
            {
                Status = TimerStatus.TimesUp;
                DidAlertTimesUp = true;
            }
        }
    }

    public string FormattedTimeString()
    {
        double targetSeconds = (Mode == TimerMode.Countdown) ? RemainingSeconds : ElapsedSeconds;
        int total = Math.Max(0, (int)Math.Floor(targetSeconds));
        int hours = total / 3600;
        int minutes = (total % 3600) / 60;
        int seconds = total % 60;
        int tenths = (int)((targetSeconds % 1.0) * 10);

        if (hours > 0)
        {
            return $"{hours:D2}:{minutes:D2}:{seconds:D2}";
        }
        else if (Mode == TimerMode.Countdown)
        {
            return $"{minutes:D2}:{seconds:D2}";
        }
        else
        {
            return $"{minutes:D2}:{seconds:D2}.{tenths:D1}";
        }
    }

    public BoardObject CreateBoardObject(double centerX, double centerY, string boardId, string? pageId)
    {
        string timeStr = FormattedTimeString();
        string prefix = (Mode == TimerMode.Countdown) ? "⏳ 倒數計時" : "⏱️ 正計時用時";
        string fullText = $"{prefix}：{timeStr}";

        return new BoardObject
        {
            Id = Guid.NewGuid().ToString("N"),
            BoardId = boardId,
            PageId = pageId,
            Type = "text",
            X = centerX - 80,
            Y = centerY - 20,
            Width = 180,
            Height = 44,
            Text = fullText,
            FontSize = 20,
            FontFamily = "Segoe UI Variable, Consolas, monospace",
            IsBold = true,
            StrokeColor = "#24533D",
            FillColor = "none"
        };
    }

    private double GetCurrentSessionSeconds()
    {
        if (_sessionStartTimestamp == 0) return 0.0;
        long elapsedTicks = Stopwatch.GetTimestamp() - _sessionStartTimestamp;
        return (double)elapsedTicks / Stopwatch.Frequency;
    }
}
