using System.Numerics;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 幾何運算、三次方貝茲曲線、尺規吸附與碰撞檢測引擎
/// 純 C# 幾何核心；世界座標使用 double
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
        // Hit testing only reads the sample. Unrotated objects already use world axes;
        // keep the input reference here instead of allocating a center and a rotated copy per candidate.
        if(obj.Rotation!=0)p=ObjectHandles.ToLocal(obj,p);
        var pt = new Vector2((float)p.X, (float)p.Y);
        var hitDist=obj.StrokeWidth/2+threshold;
        var box = new RectBounds(obj.X - hitDist, obj.Y - hitDist, obj.X + obj.Width + hitDist, obj.Y + obj.Height + hitDist);

        if(obj.Type is "line" or "arrow")
        {
            var a=new Vector2((float)(obj.X1??obj.X),(float)(obj.Y1??obj.Y));
            var b=new Vector2((float)(obj.X2??obj.X+obj.Width),(float)(obj.Y2??obj.Y+obj.Height));
            var ab=b-a;var lengthSquared=ab.LengthSquared();
            if(lengthSquared>.0001f&&obj.Extension is "start" or "end" or "both")
            {var t=Vector2.Dot(pt-a,ab)/lengthSquared;if((t>=0||obj.Extension is "start" or "both")&&(t<=1||obj.Extension is "end" or "both")&&Vector2.Distance(pt,a+ab*t)<=hitDist)return true;}
            if(DistanceToSegment(pt,a,b)<=hitDist)return true;
            if(obj.Type=="arrow"&&Vector2.Distance(a,b)>.01f)
            {
                var d=Vector2.Normalize(b-a);var n=new Vector2(-d.Y,d.X);
                var length=(float)(obj.ArrowHeadLength??Math.Max(12,obj.StrokeWidth*4));var width=(float)(obj.ArrowHeadWidth??length*.5);
                return DistanceToSegment(pt,b,b-d*length+n*width/2)<=hitDist||DistanceToSegment(pt,b,b-d*length-n*width/2)<=hitDist;
            }
            return false;
        }

        if (obj.Type == "arc")
        {
            var radius = obj.ArcRadius ?? (obj.Width / 2.0);
            var center = new InkPoint(obj.X + obj.Width / 2.0, obj.Y + obj.Height / 2.0);
            var dist = Math.Sqrt(Math.Pow(p.X - center.X, 2) + Math.Pow(p.Y - center.Y, 2));
            if (Math.Abs(dist - radius) > hitDist) return false;
            var sweep = obj.ArcSweepAngle ?? 360.0;
            if (Math.Abs(sweep) >= 360.0) return true;
            var start = obj.ArcStartAngle ?? 0.0;
            var ptAngleDeg = Math.Atan2(p.Y - center.Y, p.X - center.X) * 180.0 / Math.PI;
            if (ptAngleDeg < 0) ptAngleDeg += 360.0;
            return IsAngleInSpan(ptAngleDeg, start, sweep);
        }

        // 若為筆跡類物件，執行高精度分段線段距離判定
        if (obj.Type is "stroke" or "pen" or "highlighter" or "paint" or "curve" && !string.IsNullOrEmpty(obj.Points))
        {
            try
            {
                pt-=new Vector2((float)obj.PreviewOffsetX,(float)obj.PreviewOffsetY);
                var geometry=CurvePreview.ForObject(obj);var pts = geometry.Points;
                if (pts.Count == 0) return false;
                if(!new RectBounds(geometry.Bounds.MinX-hitDist,geometry.Bounds.MinY-hitDist,geometry.Bounds.MaxX+hitDist,geometry.Bounds.MaxY+hitDist).Contains(pt.X,pt.Y))return false;

                if(pts.Count==1)return Vector2.Distance(pt,new((float)pts[0].X,(float)pts[0].Y))<=hitDist;
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

        if (!box.Contains(p.X, p.Y)) return false;
        var filled=obj.FillColor is not (null or "none")&&(obj.FillOpacity??obj.Opacity)>0;
        if(obj.Type=="circle")
        {
            var rx=Math.Max(.0001,obj.Width/2);var ry=Math.Max(.0001,obj.Height/2);
            var nx=(p.X-obj.X-rx)/rx;var ny=(p.Y-obj.Y-ry)/ry;var radial=Math.Sqrt(nx*nx+ny*ny);
            if(filled&&radial<=1)return true;
            // Project to the ellipse; sufficient hit tolerance is applied in world units.
            if(radial<1e-12)return Math.Min(rx,ry)<=hitDist;
            return Math.Sqrt(Math.Pow(nx*rx-nx*rx/radial,2)+Math.Pow(ny*ry-ny*ry/radial,2))<=hitDist;
        }
        if(obj.Type is "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star")
        {
            var n=obj.Type=="triangle"?3:obj.Type=="pentagon"?5:obj.Type=="star"?10:4;
            IReadOnlyList<InkPoint> points=obj.ParsedPoints;
            if(points.Count==0)
            {
                var generated=new InkPoint[n];
                for(var i=0;i<n;i++){var angle=-Math.PI/2+i*Math.PI*2/n;var r=obj.Type=="star"&&i%2==1?.45:1;generated[i]=new(obj.X+obj.Width/2+Math.Cos(angle)*obj.Width/2*r,obj.Y+obj.Height/2+Math.Sin(angle)*obj.Height/2*r);}
                points=generated;
            }
            if(filled&&LassoSelection.Contains(p,points))return true;
            for(var i=0;i<points.Count;i++)if(DistanceToSegment(pt,new((float)points[i].X,(float)points[i].Y),new((float)points[(i+1)%points.Count].X,(float)points[(i+1)%points.Count].Y))<=hitDist)return true;
            return false;
        }
        if(obj.Type=="rect"&&!filled)
        {
            // Capturing lambdas here allocated a closure even for candidates rejected above.
            var a=new Vector2((float)obj.X,(float)obj.Y);var b=new Vector2((float)(obj.X+obj.Width),(float)obj.Y);
            var c=new Vector2(b.X,(float)(obj.Y+obj.Height));var d=new Vector2(a.X,c.Y);
            return DistanceToSegment(pt,a,b)<=hitDist||DistanceToSegment(pt,b,c)<=hitDist||DistanceToSegment(pt,c,d)<=hitDist||DistanceToSegment(pt,d,a)<=hitDist;
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

    /// <summary>
    /// 檢驗目標角度是否落在自 startAngle 起、跨度 sweepAngle 之角域區間內
    /// </summary>
    public static bool IsAngleInSpan(double angle, double start, double sweep)
    {
        if (Math.Abs(sweep) >= 360.0) return true;
        if (sweep == 0) return false;
        double normA = angle % 360.0;
        if (normA < 0) normA += 360.0;
        double normStart = start % 360.0;
        if (normStart < 0) normStart += 360.0;

        if (sweep > 0)
        {
            double diff = normA - normStart;
            if (diff < 0) diff += 360.0;
            return diff <= sweep;
        }
        else
        {
            double diff = normStart - normA;
            if (diff < 0) diff += 360.0;
            return diff <= -sweep;
        }
    }

    /// <summary>
    /// 計算圓弧的精確 AABB 包圍盒 (含起點、終點與區間內 Cardinal 極值點)
    /// </summary>
    public static RectBounds ComputeArcBoundingBox(InkPoint center, double radius, double startAngle, double sweepAngle, double strokeWidth = 2.0)
    {
        if (Math.Abs(sweepAngle) >= 360.0)
        {
            var pad = strokeWidth / 2.0;
            return new RectBounds(center.X - radius - pad, center.Y - radius - pad, center.X + radius + pad, center.Y + radius + pad);
        }

        double rad = Math.PI / 180.0;
        var p1 = new InkPoint(center.X + radius * Math.Cos(startAngle * rad), center.Y + radius * Math.Sin(startAngle * rad));
        double endAngle = startAngle + sweepAngle;
        var p2 = new InkPoint(center.X + radius * Math.Cos(endAngle * rad), center.Y + radius * Math.Sin(endAngle * rad));
        var pts = new List<InkPoint> { p1, p2 };

        foreach (var cardinal in new[] { 0.0, 90.0, 180.0, 270.0 })
        {
            if (IsAngleInSpan(cardinal, startAngle, sweepAngle))
            {
                pts.Add(new InkPoint(center.X + radius * Math.Cos(cardinal * rad), center.Y + radius * Math.Sin(cardinal * rad)));
            }
        }
        return ComputeBoundingBox(pts, strokeWidth);
    }

    /// <summary>
    /// 計算旋轉螢幕尺規的精確 AABB 屏幕包圍盒 (用於操作列避讓演算法)
    /// </summary>
    public static (double X, double Y, double W, double H) ComputeRotatedRulerBounds(InkPoint center, double angleDeg, double length = 1000.0, double thickness = 64.0)
    {
        double rad = angleDeg * Math.PI / 180.0;
        double cos = Math.Cos(rad);
        double sin = Math.Sin(rad);
        double halfL = length / 2.0;
        double halfT = thickness / 2.0;

        double[] dx = [halfL, -halfL, -halfL, halfL];
        double[] dy = [halfT, halfT, -halfT, -halfT];

        double minX = double.MaxValue, minY = double.MaxValue;
        double maxX = double.MinValue, maxY = double.MinValue;

        for (int i = 0; i < 4; i++)
        {
            double rx = center.X + dx[i] * cos - dy[i] * sin;
            double ry = center.Y + dx[i] * sin + dy[i] * cos;
            if (rx < minX) minX = rx;
            if (rx > maxX) maxX = rx;
            if (ry < minY) minY = ry;
            if (ry > maxY) maxY = ry;
        }

        return (minX, minY, maxX - minX, maxY - minY);
    }
}
