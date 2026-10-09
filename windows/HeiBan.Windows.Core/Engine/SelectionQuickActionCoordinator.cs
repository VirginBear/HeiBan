using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public enum QuickActionItem
{
    StrokeColor,
    StrokeWidth,
    FillColor,
    DashStyle,
    FontSize,
    Opacity,
    EditText,
    Copy,
    Duplicate,
    Delete,
    Unlock,
    Lock
}

public sealed record BarPosition(double X, double Y);

/// <summary>
/// 選取物件快速操作列協調器：
/// 負責根據選取物件型別計算可用操作，並計算最佳 HUD 浮層座標（避開把手、視窗邊緣與尺規）。
/// </summary>
public static class SelectionQuickActionCoordinator
{
    public static IReadOnlyList<QuickActionItem> GetAvailableActions(BoardObject? obj)
    {
        if (obj is null) return [];
        if (obj.IsLocked == true) return [QuickActionItem.Unlock, QuickActionItem.Copy, QuickActionItem.Duplicate];

        return obj.Type switch
        {
            "pen" or "curve" or "highlighter" or "paint" =>
                [QuickActionItem.StrokeColor, QuickActionItem.StrokeWidth, QuickActionItem.Opacity, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            "line" or "arrow" =>
                [QuickActionItem.StrokeColor, QuickActionItem.StrokeWidth, QuickActionItem.DashStyle, QuickActionItem.Opacity, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star" or "arc" =>
                [QuickActionItem.StrokeColor, QuickActionItem.StrokeWidth, QuickActionItem.FillColor, QuickActionItem.DashStyle, QuickActionItem.Opacity, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            "image" =>
                [QuickActionItem.Opacity, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            "text" =>
                [QuickActionItem.StrokeColor, QuickActionItem.FontSize, QuickActionItem.Opacity, QuickActionItem.EditText, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            "sticky" =>
                [QuickActionItem.StrokeColor, QuickActionItem.FillColor, QuickActionItem.Opacity, QuickActionItem.EditText, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete],

            _ =>
                [QuickActionItem.StrokeColor, QuickActionItem.StrokeWidth, QuickActionItem.Opacity, QuickActionItem.Copy, QuickActionItem.Duplicate, QuickActionItem.Delete]
        };
    }

    /// <summary>
    /// 計算快速列的最佳位置（螢幕座標）。
    /// 預設置於選取包圍盒（含旋轉/縮放把手）上方 12px 處；
    /// 若超出視窗頂部或被遮蔽，自動翻轉至下方；左右邊界適當靠齊並避開視窗外框。
    /// </summary>
    public static BarPosition ComputeBarPosition(
        double objScreenX, double objScreenY, double objScreenW, double objScreenH,
        IReadOnlyList<InkPoint>? handlePoints,
        double viewportW, double viewportH,
        double barW, double barH,
        (double X, double Y, double W, double H)? rulerBounds = null,
        (double X, double Y, double W, double H)? textEditorBounds = null)
    {
        var top = objScreenY;
        var bottom = objScreenY + objScreenH;
        var left = objScreenX;
        var right = objScreenX + objScreenW;

        if (handlePoints != null && handlePoints.Count > 0)
        {
            foreach (var h in handlePoints)
            {
                if (h.Y < top) top = h.Y;
                if (h.Y > bottom) bottom = h.Y;
                if (h.X < left) left = h.X;
                if (h.X > right) right = h.X;
            }
        }

        if (textEditorBounds.HasValue)
        {
            var te = textEditorBounds.Value;
            if (te.Y < top) top = te.Y;
            if (te.Y + te.H > bottom) bottom = te.Y + te.H;
        }

        // 預設置於上方（上方預留 12px 邊距）
        var targetY = top - barH - 12;
        var targetX = left + ((right - left) - barW) / 2;

        // 若上方空間不足（小於 56px，避免與作品標頭或視窗頂重疊），翻轉至選取包圍盒下方
        if (targetY < 56)
        {
            targetY = bottom + 12;
        }

        // 若下方也超出視窗邊界，強制收納在視窗可用安全區內
        if (targetY + barH > viewportH - 40)
        {
            targetY = Math.Max(56, viewportH - barH - 44);
        }

        // 水平方向限制在視窗內
        targetX = Math.Clamp(targetX, 16, Math.Max(16, viewportW - barW - 16));

        // 尺規避讓：若與尺規重疊，往下推移
        if (rulerBounds.HasValue)
        {
            var r = rulerBounds.Value;
            var intersects = targetX < r.X + r.W && targetX + barW > r.X &&
                             targetY < r.Y + r.H && targetY + barH > r.Y;
            if (intersects)
            {
                if (targetY < r.Y)
                {
                    targetY = Math.Max(56, r.Y - barH - 8);
                }
                else
                {
                    targetY = Math.Min(viewportH - barH - 44, r.Y + r.H + 8);
                }
            }
        }

        return new BarPosition(Math.Round(targetX, 1), Math.Round(targetY, 1));
    }
}
