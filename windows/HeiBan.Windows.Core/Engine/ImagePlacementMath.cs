using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 圖片置入幾何計算：嚴格保持原生寬高比，不因最小尺寸破壞細長比例。
/// </summary>
public static class ImagePlacementMath
{
    public static (double Width, double Height, double X, double Y) ComputePlacement(
        double naturalW,
        double naturalH,
        double viewportW,
        double viewportH,
        string canvasMode,
        double? canvasW,
        double? canvasH,
        InkPoint location,
        bool isCenter)
    {
        if (naturalW <= 0 || naturalH <= 0) return (0, 0, 0, 0);

        var vpW = Math.Max(200, viewportW);
        var vpH = Math.Max(200, viewportH);
        var maxW = vpW * 0.75;
        var maxH = vpH * 0.75;

        if (canvasMode != "infinite")
        {
            if (canvasW.HasValue && canvasW.Value > 0) maxW = Math.Min(maxW, canvasW.Value * 0.85);
            if (canvasH.HasValue && canvasH.Value > 0) maxH = Math.Min(maxH, canvasH.Value * 0.85);
        }

        // 以單一縮放因子縮放，嚴格維持原圖長寬比
        var scale = Math.Min(1.0, Math.Min(maxW / naturalW, maxH / naturalH));
        var w = Math.Max(1.0, Math.Round(naturalW * scale, 2));
        var h = Math.Max(1.0, Math.Round(naturalH * scale, 2));

        var posX = isCenter ? location.X - w / 2 : location.X;
        var posY = isCenter ? location.Y - h / 2 : location.Y;

        if (canvasMode != "infinite")
        {
            var bw = canvasW ?? 595;
            var bh = canvasH ?? 842;
            posX = Math.Clamp(posX, 0, Math.Max(0, bw - w));
            posY = Math.Clamp(posY, 0, Math.Max(0, bh - h));
        }

        return (w, h, posX, posY);
    }
}
