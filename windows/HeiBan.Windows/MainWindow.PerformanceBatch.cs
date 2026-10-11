using System.Runtime.InteropServices;
using System.Text.Json;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;

namespace HeiBan.Windows;

public partial class MainWindow
{
    // This explicit command runs only with an isolated data root. It never reads a user's board for benchmarks.
    private async Task RunPerformanceBatchAsync(string outputDirectory)
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")))
            throw new InvalidOperationException("效能診斷需要獨立資料根。");
        Directory.CreateDirectory(outputDirectory);
        _autosave.Stop(); _thumbnailTimer.Stop(); _screenshotWatchTimer.Stop();
        try
        {
            await Task.Delay(250);
            const float width = 1024, height = 640;
            using var target = new CanvasRenderTarget(CanvasSurface, width, height, CanvasSurface.Dpi);
            var cases = new List<object>();
            foreach (var count in new[] { 0, 300, 1000, 10000 })
            {
                var doc = new HeiBanDocument { Board = new BoardMetadata { BackgroundColor = "#ffffff", GridStyle = "blank" },
                    Objects = Enumerable.Range(0, count).Select(i => new BoardObject
                    {
                        Id = "synthetic-" + i, Type = "rect", X = i % 100 * 10, Y = i / 100 * 10,
                        Width = 8, Height = 8, ZIndex = (i * 7919) % 101, StrokeColor = "#24533d", StrokeWidth = 1
                    }).ToList() };
                _session.Open(doc); _viewport.X = _viewport.Y = 0; _viewport.Zoom = 1; ClearScene();
                void Draw() { using (var ds = target.CreateDrawingSession()) RenderMainScene(CanvasSurface, ds, width, height); _ = target.GetPixelBytes(0, 0, 1, 1); }
                var buildsBefore=_sceneBuilds;
                var stable = PerformanceMeasurement.Measure(Draw);
                var stableBuilds=_sceneBuilds-buildsBefore;buildsBefore=_sceneBuilds;
                var rebuild = PerformanceMeasurement.Measure(() => { _sceneDirty = true; Draw(); });
                var rebuildBuilds=_sceneBuilds-buildsBefore;buildsBefore=_sceneBuilds;
                var pan = PerformanceMeasurement.Measure(() => { _viewport.X = _viewport.X == 0 ? -30 : 0; Draw(); });
                var panBuilds=_sceneBuilds-buildsBefore;buildsBefore=_sceneBuilds;
                var zoom = PerformanceMeasurement.Measure(() => { _viewport.Zoom = _viewport.Zoom == 1 ? 1.1 : 1; Draw(); });
                cases.Add(new { objects = count, stable, rebuild, pan, zoom, stableBuilds, rebuildBuilds, panBuilds, zoomBuilds=_sceneBuilds-buildsBefore });
            }
            var existingMain = ValidateCanvasPerformance();
            // Preserve completed stages even when a later compatibility check fails.
            await File.WriteAllTextAsync(Path.Combine(outputDirectory, "main-performance.json"), JsonSerializer.Serialize(new { cases, existingMain }, new JsonSerializerOptions { WriteIndented = true }));
            var spatial=MeasureSpatialScenes();
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"spatial.json"),JsonSerializer.Serialize(spatial,new JsonSerializerOptions{WriteIndented=true}));
            var supplemental=await MeasureSupplementalScenesAsync();
            await File.WriteAllTextAsync(Path.Combine(outputDirectory,"supplemental.json"),JsonSerializer.Serialize(supplemental,new JsonSerializerOptions{WriteIndented=true}));
            EnsureScreenAnnotation();
            var screen = await _screenAnnotation!.RunPerformanceBatchAsync();
            var result = new
            {
                success = true, schemaVersion = 1, sourceCommit = Environment.GetEnvironmentVariable("HEIBAN_PERFORMANCE_SOURCE"),
                architecture = RuntimeInformation.ProcessArchitecture.ToString(), runtime = RuntimeInformation.FrameworkDescription,
                os = RuntimeInformation.OSDescription, capturedUtc = DateTime.UtcNow, dpi = CanvasSurface.Dpi, width, height,
                scope = "Synthetic native Win2D actions with 1-pixel readback synchronization; screen overlay synthetic frames; not physical input-to-display latency",
                workingSetBytes = Environment.WorkingSet, cases, existingMain, spatial, supplemental, screen
            };
            await File.WriteAllTextAsync(Path.Combine(outputDirectory, "performance.json"), JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception e)
        {
            await File.WriteAllTextAsync(Path.Combine(outputDirectory, "performance.json"), JsonSerializer.Serialize(new { success = false, error = e.ToString() }));
        }
        finally { _renderer.BypassViewportCache=false;_closing = true; Close(); }
    }
}
