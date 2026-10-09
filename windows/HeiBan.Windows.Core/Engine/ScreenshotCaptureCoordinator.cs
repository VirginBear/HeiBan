using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public enum ScreenshotSessionState
{
    Idle,
    Capturing,
    Processing,
    Completed,
    Cancelled,
    TimedOut
}

public sealed record ScreenshotRequest(
    string RequestId,
    string BoardId,
    string? PageId,
    InkPoint TargetCenter,
    uint BaselineClipboardSequence,
    DateTime CreatedAt
);

/// <summary>
/// 一次性截圖工作階段協調器：
/// 負責管理截圖請求生命週期、狀態機、上下文綁定（作品/頁面）、剪貼簿變更去重與非同步解碼期間的有效性保護。
/// </summary>
public sealed class ScreenshotCaptureCoordinator
{
    private ScreenshotRequest? _activeRequest;
    private ScreenshotSessionState _state = ScreenshotSessionState.Idle;
    private bool _windowDeactivated;
    private bool _windowReactivated;
    private int _reactivatedCheckTicks;

    public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(60);

    public ScreenshotSessionState State => _state;

    public ScreenshotRequest? ActiveRequest => _activeRequest;

    public bool IsExpired => _activeRequest != null && (DateTime.UtcNow - _activeRequest.CreatedAt) > Timeout;

    public bool IsCapturing => _state == ScreenshotSessionState.Capturing && _activeRequest != null && !IsExpired;

    public bool IsProcessing => _state == ScreenshotSessionState.Processing && _activeRequest != null && !IsExpired;

    public bool HasActiveSession => (_state == ScreenshotSessionState.Capturing || _state == ScreenshotSessionState.Processing) && _activeRequest != null && !IsExpired;

    public bool WindowWasDeactivated => _windowDeactivated;

    public bool WindowIsReactivated => _windowReactivated;

    public int ReactivatedCheckTicks => _reactivatedCheckTicks;

    /// <summary>
    /// 啟動單次截圖請求。若已有有效請求進行中則回傳 null 阻止重複啟動。
    /// </summary>
    public ScreenshotRequest? BeginCapture(string boardId, string? pageId, InkPoint targetCenter, uint baselineClipboardSequence)
    {
        CheckTimeout();

        if (HasActiveSession)
        {
            return null;
        }

        var req = new ScreenshotRequest(
            RequestId: Guid.NewGuid().ToString("N"),
            BoardId: boardId,
            PageId: pageId,
            TargetCenter: targetCenter,
            BaselineClipboardSequence: baselineClipboardSequence,
            CreatedAt: DateTime.UtcNow
        );

        _activeRequest = req;
        _state = ScreenshotSessionState.Capturing;
        _windowDeactivated = false;
        _windowReactivated = false;
        _reactivatedCheckTicks = 0;
        return req;
    }

    /// <summary>
    /// 檢查逾時狀態並明確轉換至 TimedOut。
    /// </summary>
    public bool CheckTimeout()
    {
        if ((_state == ScreenshotSessionState.Capturing || _state == ScreenshotSessionState.Processing) && _activeRequest != null && IsExpired)
        {
            _state = ScreenshotSessionState.TimedOut;
            _activeRequest = null;
            return true;
        }
        return false;
    }

    /// <summary>
    /// 記錄視窗失去啟用（進入系統剪取工具浮層）。
    /// </summary>
    public void NotifyWindowDeactivated()
    {
        if (IsCapturing)
        {
            _windowDeactivated = true;
            _windowReactivated = false;
            _reactivatedCheckTicks = 0;
        }
    }

    /// <summary>
    /// 記錄視窗重新獲得啟用。
    /// </summary>
    public void NotifyWindowReactivated()
    {
        if (IsCapturing && _windowDeactivated)
        {
            _windowReactivated = true;
            _reactivatedCheckTicks = 0;
        }
    }

    /// <summary>
    /// 視窗在剪取浮層結束回到黑板後，累計檢查次數。
    /// 若剪取工具已關閉回到黑板，但剪貼簿 sequence 數個 tick 後仍未改變，代表使用者取消了剪取（如按 Esc）。
    /// </summary>
    public bool RecordReactivatedTickAndShouldCancel(int maxTicks = 4)
    {
        if (!IsCapturing || !_windowDeactivated || !_windowReactivated) return false;
        _reactivatedCheckTicks++;
        return _reactivatedCheckTicks >= maxTicks;
    }

    /// <summary>
    /// 判定傳入的剪貼簿更新是否為本次截圖請求的有效結果。
    /// 嚴格驗證：請求 ID、作品 ID、頁面 ID 必須相符，且剪貼簿版號必須異於啟動前基線（防舊圖誤入）。
    /// </summary>
    public bool CanAcceptResult(string requestId, string currentBoardId, string? currentPageId, uint currentClipboardSequence)
    {
        if (!IsCapturing || _activeRequest == null) return false;
        if (_activeRequest.RequestId != requestId) return false;
        if (_activeRequest.BoardId != currentBoardId) return false;
        if (_activeRequest.PageId != currentPageId) return false;
        if (currentClipboardSequence == _activeRequest.BaselineClipboardSequence) return false;
        if (IsExpired) return false;
        return true;
    }

    /// <summary>
    /// 進入結果處理階段（開始非同步解碼），保持請求有效並防重複觸發，但允許情境變更時取消。
    /// </summary>
    public bool BeginProcessing(string requestId)
    {
        if (!IsCapturing || _activeRequest == null || _activeRequest.RequestId != requestId) return false;
        _state = ScreenshotSessionState.Processing;
        return true;
    }

    /// <summary>
    /// 非同步解碼完成後，最終核對請求、作品及頁面有效性，並正式標記為完成。
    /// </summary>
    public bool ValidateAndComplete(string requestId, string currentBoardId, string? currentPageId)
    {
        if (_activeRequest == null || _activeRequest.RequestId != requestId) return false;
        if (_state != ScreenshotSessionState.Processing && _state != ScreenshotSessionState.Capturing) return false;
        if (_activeRequest.BoardId != currentBoardId || _activeRequest.PageId != currentPageId) return false;
        if (IsExpired) return false;

        _state = ScreenshotSessionState.Completed;
        _activeRequest = null;
        return true;
    }

    /// <summary>
    /// 完成本次截圖請求（單步驟完成相容）。
    /// </summary>
    public bool Complete(string requestId)
    {
        if (_activeRequest == null || _activeRequest.RequestId != requestId) return false;
        if (_state != ScreenshotSessionState.Capturing && _state != ScreenshotSessionState.Processing) return false;

        _state = ScreenshotSessionState.Completed;
        _activeRequest = null;
        return true;
    }

    /// <summary>
    /// 主動撤銷本次截圖工作階段（取消、逾時、切換或關閉視窗）。
    /// </summary>
    public bool Cancel(string? reason = null)
    {
        if (_activeRequest == null && _state == ScreenshotSessionState.Idle) return false;
        _state = ScreenshotSessionState.Cancelled;
        _activeRequest = null;
        _windowDeactivated = false;
        _reactivatedCheckTicks = 0;
        return true;
    }

    /// <summary>
    /// 僅在請求 ID 相符時撤銷（防止舊請求的非同步例外誤殺已啟動的新請求）。
    /// </summary>
    public bool CancelIfMatching(string requestId, string? reason = null)
    {
        if (_activeRequest == null || _activeRequest.RequestId != requestId) return false;
        return Cancel(reason);
    }

    /// <summary>
    /// 當使用者切換作品或頁面時，立即撤銷截圖工作階段，防止圖片置入到錯誤的文件或首頁。
    /// </summary>
    public void InvalidateIfContextChanged(string currentBoardId, string? currentPageId)
    {
        if (_activeRequest != null && (_activeRequest.BoardId != currentBoardId || _activeRequest.PageId != currentPageId))
        {
            Cancel("內容情境變更");
        }
    }
}
