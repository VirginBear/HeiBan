using System.Numerics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.Foundation;

namespace HeiBan.Windows.Engine;

public sealed partial class Direct2DCanvasRenderer
{
    private CanvasTextFormat? _rulerTickText;
    private CanvasTextFormat? _rulerBadgeText;

    // Hosts supply coordinates in their render target's units. The screen overlay
    // uses physical pixels and owns its stretch handles and matching hit tests.
    internal void RenderRuler(CanvasDrawingSession ds, Vector2 center, double angle, float length, float height,
        double opacity, double pivotRatio, float pivotY, string? color, bool light, bool screen)
    {
        var old = ds.Transform;
        ds.Transform = Matrix3x2.CreateRotation((float)(angle * Math.PI / 180)) * Matrix3x2.CreateTranslation(center);
        try
        {
            var ink = Direct2DCanvasRenderer.HexToColor(color ?? (light ? "#244C38" : "#F6F3DF"));
            var left = -length / 2;
            var top = -height / 2;
            ds.FillRoundedRectangle(left, top, length, height, 8, 8, Direct2DCanvasRenderer.HexToColor(light ? "#C9D7C1" : "#6D8B72", (float)opacity));
            ds.DrawRoundedRectangle(left, top, length, height, 8, 8, ink, 1);
            var small = _rulerTickText ??= new CanvasTextFormat { FontFamily = "Consolas", FontSize = 9 };
            var badge = _rulerBadgeText ??= new CanvasTextFormat { FontFamily = "Consolas", FontSize = 12, HorizontalAlignment = CanvasHorizontalAlignment.Center, VerticalAlignment = CanvasVerticalAlignment.Center };
            for (var i = 0; i <= length; i += 10)
            {
                var major = i % 50 == 0;
                ds.DrawLine(left + i, top, left + i, top + (major ? 23 : i % 20 == 0 ? 15 : 8), ink, major ? 1.3f : 1);
                if (major) ds.DrawText(i.ToString(), left + i + 4, top + height - 15, ink, small);
            }
            var rotateOffset = screen ? 28 : 14;
            for (var side = -1; side <= 1; side += 2)
            {
                var x = side * (length / 2 - rotateOffset);
                ds.FillCircle(x, 0, 13, Direct2DCanvasRenderer.HexToColor("#39735A"));
                ds.DrawText("↻", new Rect(x - 13, -13, 26, 26), Direct2DCanvasRenderer.HexToColor("#FFFFFF"), badge);
            }
            var moveX = -length * (screen ? .16f : .28f);
            ds.FillRoundedRectangle(moveX - 19, -14, 38, 28, 14, 14, Direct2DCanvasRenderer.HexToColor("#39735A"));
            ds.DrawText(screen ? "✥" : "↔", new Rect(moveX - 19, -14, 38, 28), Direct2DCanvasRenderer.HexToColor("#FFFFFF"), badge);

            if (screen)
            {
                // Stretch handle grip ticks at left and right edges
                ds.DrawLine(left + 5, -16, left + 5, 16, ink, 2);
                ds.DrawLine(left + 9, -16, left + 9, 16, ink, 2);
                var right = length / 2;
                ds.DrawLine(right - 5, -16, right - 5, 16, ink, 2);
                ds.DrawLine(right - 9, -16, right - 9, 16, ink, 2);
            }
            var pivotX = (float)((pivotRatio - .5) * length);
            ds.FillCircle(pivotX, pivotY, 6, Direct2DCanvasRenderer.HexToColor("#DDA548", .95f));
            ds.DrawCircle(pivotX, pivotY, 6, Direct2DCanvasRenderer.HexToColor("#FFFFFF", .9f), 1.5f);
            var badgeX = length / 2 - 136;
            ds.FillRoundedRectangle(badgeX, top + 4, 90, 26, 13, 13, Direct2DCanvasRenderer.HexToColor(light ? "#F8FAF4" : "#203A2C", .95f));
            ds.DrawText($"{angle:F1}°", new Rect(badgeX, top + 4, 90, 26), ink, badge);
        }
        finally { ds.Transform = old; }
    }
}
