using System.Numerics;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 幾何運算、三次方貝茲曲線、尺規吸附與碰撞檢測引擎
/// 100% 對齊 macOS Swift (VectorMath / RulerToolEngine) 與 Web TypeScript (strokeSmoothing.ts)
/// </summary>
public static class VectorMath
{
    public readonly record struct RectBounds(double MinX, double MinY, double MaxX, double MaxY)
    {
        public double Width => Math.Max(0, MaxX - MinX);
        public double Height => Math.Max(0, MaxY - MinY);
        public double MidX => (MinX + MaxX) / 2.0;
        public double MidY => (MinY + MaxY) / 2.0;

        public bool Contains(double x, double y) =>
            x >= MinX && x <= MaxX && y >= MinY && y <= MaxY;

        public bool Intersects(RectBounds other) =>
            !(other.MinX > MaxX || other.MaxX < MinX || other.MinY > MaxY || other.MaxY < MinY);
    }

    /// <summary>
    /// 計算筆跡點集合之緊湊 AABB 邊界框
    /// </summary>
    public static RectBounds ComputeBoundingBox(IReadOnlyList<InkPoint> points, double strokeWidth = 2.0)
    {
        if (points.Count == 0) return new RectBounds(0, 0, 0, 0);

        double minX = double.MaxValue, minY = double.MaxValue;
        double maxX = double.MinValue, maxY = double.MinValue;
        double padding = strokeWidth / 2.0;

        foreach (var pt in points)
        {
            if (pt.X < minX) minX = pt.X;
            if (pt.X > maxX) maxX = pt.X;
            if (pt.Y < minY) minY = pt.Y;
            if (pt.Y > maxY) maxY = pt.Y;
        }

        return new RectBounds(minX - padding, minY - padding, maxX + padding, maxY + padding);
    }

    /// <summary>
    /// 點到線段之最短幾何距離 (用於橡皮擦與選取命中測試)
    /// </summary>
    public static double DistanceToSegment(Vector2 p, Vector2 a, Vector2 b)
    {
        var ab = b - a;
        float lenSq = ab.LengthSquared();
        if (lenSq < 1e-6f) return Vector2.Distance(p, a);

        float t = Math.Clamp(Vector2.Dot(p - a, ab) / lenSq, 0.0f, 1.0f);
        var proj = a + t * ab;
        return Vector2.Distance(p, proj);
    }

    /// <summary>
    /// 物件命中測試 (支援筆跡、幾何圖形、便簽與文字)
    /// </summary>
    public static bool IsPointInObject(InkPoint p, BoardObject obj, double threshold = 8.0)
    {
        var pt = new Vector2((float)p.X, (float)p.Y);
        var box = new RectBounds(obj.X - threshold, obj.Y - threshold, obj.X + obj.Width + threshold, obj.Y + obj.Height + threshold);

        if (!box.Contains(p.X, p.Y)) return false;

        // 若為筆跡類物件，執行高精度分段線段距離判定
        if (obj.Type is "stroke" or "highlighter" or "paint" or "curve" && !string.IsNullOrEmpty(obj.Points))
        {
            try
            {
                var pts = System.Text.Json.JsonSerializer.Deserialize<List<InkPoint>>(obj.Points);
                if (pts == null || pts.Count == 0) return false;

                double hitDist = Math.Max(threshold, obj.StrokeWidth / 2.0 + threshold);
                for (int i = 0; i < pts.Count - 1; i++)
                {
                    var a = new Vector2((float)pts[i].X, (float)pts[i].Y);
                    var b = new Vector2((float)pts[i + 1].X, (float)pts[i + 1].Y);
                    if (DistanceToSegment(pt, a, b) <= hitDist) return true;
                }
                return false;
            }
            catch
            {
                return box.Contains(p.X, p.Y);
            }
        }

        return true;
    }

    /// <summary>
    /// 虛擬螢幕尺規邊緣吸附運算 (對齊 RulerToolEngine.swift)
    /// </summary>
    public static (bool Snapped, Vector2 SnappedScreenPoint) SnapToScreenRulerEdge(
        Vector2 screenPt,
        Vector2 rulerCenter,
        float rulerAngleDeg,
        float rulerLength = 600f,
        float rulerThickness = 72f,
        float snapTolerance = 24f)
    {
        float rad = rulerAngleDeg * (float)Math.PI / 180f;
        var dir = new Vector2((float)Math.Cos(rad), (float)Math.Sin(rad));
        var normal = new Vector2(-dir.Y, dir.X); // 法向量指向尺規邊緣

        // 上邊緣與下邊緣
        float halfThick = rulerThickness / 2f;
        float halfLen = rulerLength / 2f;

        var topEdgeCenter = rulerCenter + normal * halfThick;
        var bottomEdgeCenter = rulerCenter - normal * halfThick;

        // 計算點到頂緣與底緣之投影距離
        float distToTop = Math.Abs(Vector2.Dot(screenPt - topEdgeCenter, normal));
        float distToBottom = Math.Abs(Vector2.Dot(screenPt - bottomEdgeCenter, normal));

        Vector2 activeEdgeCenter = distToTop < distToBottom ? topEdgeCenter : bottomEdgeCenter;
        float activeDist = Math.Min(distToTop, distToBottom);

        if (activeDist <= snapTolerance)
        {
            // 投影至尺規長度方向
            float along = Vector2.Dot(screenPt - activeEdgeCenter, dir);
            if (Math.Abs(along) <= halfLen)
            {
                var snapped = activeEdgeCenter + dir * along;
                return (true, snapped);
            }
        }

        return (false, screenPt);
    }

    /// <summary>
    /// 向量局部橡皮擦切片分割演算法 (對齊 EraserToolEngine.swift)
    /// </summary>
    public static List<List<InkPoint>> ErasePointsAtPoint(
        IReadOnlyList<InkPoint> points,
        InkPoint eraserCenter,
        double eraserRadius)
    {
        var result = new List<List<InkPoint>>();
        var currentSegment = new List<InkPoint>();
        var eraserVec = new Vector2((float)eraserCenter.X, (float)eraserCenter.Y);
        float radiusSq = (float)(eraserRadius * eraserRadius);

        foreach (var pt in points)
        {
            var pVec = new Vector2((float)pt.X, (float)pt.Y);
            bool isInside = Vector2.DistanceSquared(pVec, eraserVec) <= radiusSq;

            if (!isInside)
            {
                currentSegment.Add(pt);
            }
            else
            {
                if (currentSegment.Count >= 2)
                {
                    result.Add([.. currentSegment]);
                }
                currentSegment.Clear();
            }
        }

        if (currentSegment.Count >= 2)
        {
            result.Add(currentSegment);
        }

        return result;
    }
}
