using System.Globalization;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 畫布 HUD 格式化與位置計算：尺寸、0.1° 旋轉與游標近端提示。
/// </summary>
public static class CanvasHUDFormatter
{
    public static string FormatDimensions(double width, double height)
    {
        var w = Math.Round(Math.Abs(width), 1);
        var h = Math.Round(Math.Abs(height), 1);
        return string.Create(CultureInfo.InvariantCulture, $"{w:0.#} × {h:0.#} pt");
    }

    public static string FormatRotation(double degrees)
    {
        // 正規化至 [-180, 180] 或 [0, 360]，維持 0.1° 精度
        var norm = degrees % 360;
        if (norm > 180) norm -= 360;
        if (norm <= -180) norm += 360;
        norm = Math.Round(norm, 1);
        if (Math.Abs(norm) < 0.05) norm = 0;
        return string.Create(CultureInfo.InvariantCulture, $"{norm:0.0}°");
    }

    /// <summary>
    /// 計算 HUD 標籤的螢幕座標，避開指標與把手，並約束在畫布視野內。
    /// </summary>
    public static InkPoint ComputeBadgePosition(
        double pointerScreenX, double pointerScreenY,
        double badgeW, double badgeH,
        double viewportW, double viewportH)
    {
        // 預設位於指標右上方 16px
        var x = pointerScreenX + 16;
        var y = pointerScreenY - badgeH - 16;

        // 若右邊界超出，轉至指標左側
        if (x + badgeW > viewportW - 16)
        {
            x = pointerScreenX - badgeW - 16;
        }

        // 若頂部超出，轉至指標下方
        if (y < 48)
        {
            y = pointerScreenY + 24;
        }

        x = Math.Clamp(x, 16, Math.Max(16, viewportW - badgeW - 16));
        y = Math.Clamp(y, 48, Math.Max(48, viewportH - badgeH - 16));

        return new InkPoint(Math.Round(x, 1), Math.Round(y, 1));
    }
}
