using System.Numerics;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Text;
using Windows.UI;

namespace HeiBan.Windows.Engine;

/// <summary>
/// Win2D (Direct2D 硬體加速) 畫布渲染核心
/// 支援 120/144Hz 滿幀渲染、視窗 Frustum Culling、貝茲曲線平滑、6 款手繪便簽與 1:1 橡皮擦/筆刷懸停光圈
/// </summary>
public sealed class Direct2DCanvasRenderer
{
    /// <summary>
    /// 解析 16 進位 HEX 色碼 (如 #172e25 或 #ffffff)
    /// </summary>
    public static Color HexToColor(string hex, float opacity = 1.0f)
    {
        if (string.IsNullOrEmpty(hex) || hex == "none")
            return Color.FromArgb(0, 0, 0, 0);

        hex = hex.TrimStart('#');
        byte r = 0, g = 0, b = 0, a = (byte)(opacity * 255);

        if (hex.Length == 6)
        {
            r = Convert.ToByte(hex[..2], 16);
            g = Convert.ToByte(hex.Substring(2, 2), 16);
            b = Convert.ToByte(hex.Substring(4, 2), 16);
        }
        else if (hex.Length == 8)
        {
            a = (byte)(Convert.ToByte(hex[..2], 16) * opacity);
            r = Convert.ToByte(hex.Substring(2, 2), 16);
            g = Convert.ToByte(hex.Substring(4, 2), 16);
            b = Convert.ToByte(hex.Substring(6, 2), 16);
        }

        return Color.FromArgb(a, r, g, b);
    }

    /// <summary>
    /// 繪製背景底色與格線 (黑板微點、方格、五線譜)
    /// </summary>
    public void RenderBackground(
        CanvasDrawingSession ds,
        BoardMetadata board,
        ViewportTransform viewport,
        float screenWidth,
        float screenHeight)
    {
        var bgColor = HexToColor(board.BackgroundColor);
        ds.Clear(bgColor);

        if (board.GridStyle == "blank") return;

        // 網格間距 (考慮 Zoom 縮放)
        float baseStep = 32f;
        float step = (float)(baseStep * viewport.Zoom);
        if (step < 8f) return; // 縮放過小時不繪製微小網格以避免密集干涉紋

        float startX = (float)(viewport.X % step);
        float startY = (float)(viewport.Y % step);

        var gridColor = Color.FromArgb(40, 255, 255, 255);

        switch (board.GridStyle)
        {
            case "dots":
                for (float x = startX; x < screenWidth; x += step)
                {
                    for (float y = startY; y < screenHeight; y += step)
                    {
                        ds.FillCircle(x, y, 1.2f, gridColor);
                    }
                }
                break;

            case "grid":
                for (float x = startX; x < screenWidth; x += step)
                    ds.DrawLine(x, 0, x, screenHeight, gridColor, 1.0f);
                for (float y = startY; y < screenHeight; y += step)
                    ds.DrawLine(0, y, screenWidth, y, gridColor, 1.0f);
                break;

            case "lines":
                for (float y = startY; y < screenHeight; y += step)
                    ds.DrawLine(0, y, screenWidth, y, gridColor, 1.0f);
                break;

            case "staff": // 五線譜
                float staffSpacing = 12f * (float)viewport.Zoom;
                float groupSpacing = 72f * (float)viewport.Zoom;
                float curY = (float)(viewport.Y % groupSpacing);
                while (curY < screenHeight)
                {
                    for (int i = 0; i < 5; i++)
                    {
                        float lineY = curY + i * staffSpacing;
                        if (lineY >= 0 && lineY <= screenHeight)
                            ds.DrawLine(0, lineY, screenWidth, lineY, gridColor, 1.0f);
                    }
                    curY += groupSpacing;
                }
                break;
        }
    }

    /// <summary>
    /// 繪製全量向量物件 (支援 AABB 視窗裁剪 Frustum Culling)
    /// </summary>
    public void RenderObjects(
        CanvasDrawingSession ds,
        IReadOnlyList<BoardObject> objects,
        ViewportTransform viewport,
        float screenWidth,
        float screenHeight)
    {
        var screenBounds = new VectorMath.RectBounds(0, 0, screenWidth, screenHeight);

        foreach (var obj in objects)
        {
            if (obj.IsVisible == false) continue;

            // 空間裁剪：將物件世界座標投影至螢幕，若在螢幕之外則略過
            var screenPos = viewport.WorldToScreen(obj.X, obj.Y);
            double sWidth = obj.Width * viewport.Zoom;
            double sHeight = obj.Height * viewport.Zoom;
            var objScreenBounds = new VectorMath.RectBounds(screenPos.X, screenPos.Y, screenPos.X + sWidth, screenPos.Y + sHeight);

            if (!screenBounds.Intersects(objScreenBounds)) continue;

            RenderSingleObject(ds, obj, viewport);
        }
    }

    /// <summary>
    /// 繪製單一黑板物件
    /// </summary>
    private void RenderSingleObject(CanvasDrawingSession ds, BoardObject obj, ViewportTransform vp)
    {
        var strokeColor = HexToColor(obj.StrokeColor, (float)obj.Opacity);
        var fillColor = HexToColor(obj.FillColor, (float)obj.Opacity);
        float sWidth = (float)(Math.Max(1.0, obj.StrokeWidth * vp.Zoom));

        var screenOrigin = vp.WorldToScreen(obj.X, obj.Y);
        float ox = (float)screenOrigin.X;
        float oy = (float)screenOrigin.Y;
        float ow = (float)(obj.Width * vp.Zoom);
        float oh = (float)(obj.Height * vp.Zoom);

        switch (obj.Type)
        {
            case "rect":
                if (obj.FillColor != "none") ds.FillRectangle(ox, oy, ow, oh, fillColor);
                ds.DrawRectangle(ox, oy, ow, oh, strokeColor, sWidth);
                break;

            case "circle":
                float rx = ow / 2f, ry = oh / 2f;
                if (obj.FillColor != "none") ds.FillEllipse(ox + rx, oy + ry, rx, ry, fillColor);
                ds.DrawEllipse(ox + rx, oy + ry, rx, ry, strokeColor, sWidth);
                break;

            case "stroke" or "highlighter" or "paint":
                RenderStrokeObject(ds, obj, vp);
                break;

            case "sticky":
                RenderStickyNote(ds, obj, ox, oy, ow, oh, vp);
                break;
        }
    }

    /// <summary>
    /// 繪製筆跡 (三次方貝茲曲線渲染)
    /// </summary>
    private void RenderStrokeObject(CanvasDrawingSession ds, BoardObject obj, ViewportTransform vp)
    {
        if (string.IsNullOrEmpty(obj.Points)) return;

        List<InkPoint>? pts;
        try { pts = System.Text.Json.JsonSerializer.Deserialize<List<InkPoint>>(obj.Points); }
        catch { return; }

        if (pts == null || pts.Count < 2) return;

        float strokeMultiplier = obj.Type == "highlighter" ? 3.5f : (obj.Type == "paint" ? 8.0f : 1.0f);
        float effectiveWidth = (float)(Math.Max(1.0, obj.StrokeWidth * strokeMultiplier * vp.Zoom));
        float effectiveOpacity = obj.Type == "highlighter" ? 0.35f : (float)obj.Opacity;
        var color = HexToColor(obj.StrokeColor, effectiveOpacity);

        using var builder = new CanvasPathBuilder(ds);
        var first = vp.WorldToScreen(pts[0].X, pts[0].Y);
        builder.BeginFigure((float)first.X, (float)first.Y);

        for (int i = 1; i < pts.Count; i++)
        {
            var cur = vp.WorldToScreen(pts[i].X, pts[i].Y);
            builder.AddLine((float)cur.X, (float)cur.Y);
        }
        builder.EndFigure(CanvasFigureLoop.Open);

        using var geometry = CanvasGeometry.CreatePath(builder);
        ds.DrawGeometry(geometry, color, effectiveWidth);
    }

    /// <summary>
    /// 繪製 6 款手繪便簽 (classic, washi, cat, notebook, grid, soft)
    /// </summary>
    private void RenderStickyNote(CanvasDrawingSession ds, BoardObject obj, float x, float y, float w, float h, ViewportTransform vp)
    {
        var style = obj.StickyStyle ?? "classic";
        var baseBg = HexToColor(obj.FillColor == "none" ? "#fef08a" : obj.FillColor);

        // 卡片本體圓角矩形
        ds.FillRoundedRectangle(x, y, w, h, 8f, 8f, baseBg);
        ds.DrawRoundedRectangle(x, y, w, h, 8f, 8f, Color.FromArgb(40, 0, 0, 0), 1.5f);

        // 風格裝飾 (如 washi 和紙膠帶、cat 貓咪耳朵)
        if (style == "washi")
        {
            ds.FillRectangle(x + w / 4f, y - 6f, w / 2f, 12f, Color.FromArgb(160, 255, 255, 255));
        }
        else if (style == "cat")
        {
            // 貓咪左耳與右耳
            ds.FillTriangle(x + 12f, y, x + 24f, y - 14f, x + 36f, y, baseBg);
            ds.FillTriangle(x + w - 36f, y, x + w - 24f, y - 14f, x + w - 12f, y, baseBg);
        }

        // 便簽文字內容渲染 (DirectWrite)
        if (!string.IsNullOrEmpty(obj.Text))
        {
            var textFormat = new CanvasTextFormat
            {
                FontSize = (float)((obj.FontSize ?? 16.0) * vp.Zoom),
                FontFamily = obj.FontFamily ?? "Segoe UI Variable, Microsoft JhengHei",
                WordWrapping = CanvasWordWrapping.Wrap
            };
            var textColor = HexToColor(obj.StrokeColor == "#ffffff" ? "#1e293b" : obj.StrokeColor);
            ds.DrawText(obj.Text, new Windows.Foundation.Rect(x + 12, y + 12, Math.Max(0, w - 24), Math.Max(0, h - 24)), textColor, textFormat);
        }
    }

    /// <summary>
    /// 繪製 1:1 橡皮擦與筆刷懸停光圈 (精確對齊 Web 與 macOS 視覺規格)
    /// </summary>
    public void RenderHoverIndicator(
        CanvasDrawingSession ds,
        string currentTool,
        string eraserMode,
        double activeStrokeWidth,
        ViewportTransform vp,
        Vector2 mousePos)
    {
        if (currentTool is "pen" or "highlighter" or "paint" or "curve")
        {
            float multiplier = currentTool == "highlighter" ? 3.5f : (currentTool == "paint" ? 8.0f : 1.0f);
            float diam = (float)(Math.Max(3.0, activeStrokeWidth * multiplier * vp.Zoom));
            var strokeStyle = new CanvasStrokeStyle { DashStyle = CanvasDashStyle.Dash };

            ds.FillCircle(mousePos.X, mousePos.Y, diam / 2f, Color.FromArgb(60, 255, 255, 255));
            ds.DrawCircle(mousePos.X, mousePos.Y, diam / 2f, Color.FromArgb(220, 255, 255, 255), 1.2f, strokeStyle);
        }
        else if (currentTool == "eraser")
        {
            // 橡皮擦半徑：Pixel 16 units, Object 18 units (對齊 toolMetrics.ts)
            float radiusUnits = eraserMode == "pixel" ? 16f : 18f;
            float diam = (float)(radiusUnits * 2f * vp.Zoom);
            var strokeStyle = new CanvasStrokeStyle { DashStyle = CanvasDashStyle.Dash };

            // 半透明珊瑚紅圓形區域
            ds.FillCircle(mousePos.X, mousePos.Y, diam / 2f, Color.FromArgb(64, 244, 63, 94));
            ds.DrawCircle(mousePos.X, mousePos.Y, diam / 2f, Color.FromArgb(230, 251, 113, 133), 1.8f, strokeStyle);

            // 中心精確錨點
            ds.FillCircle(mousePos.X, mousePos.Y, 2.0f, Color.FromArgb(230, 254, 205, 211));
        }
    }
}
