#if HEIBAN_RELEASE_VALIDATION
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.Graphics.Canvas;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Graphics.Imaging;
using global::Windows.Storage;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private async Task ValidateImageResolutionAsync(string output, string path)
    {
        var file = await StorageFile.GetFileFromPathAsync(path);
        using var fileStream = await file.OpenReadAsync();
        var native = await BitmapDecoder.CreateAsync(fileStream);
        var maximumTexture = CanvasSurface.Device.MaximumBitmapSizeInPixels;
        bool oldLoadRejected = false;
        try { using var bitmap = await CanvasBitmap.LoadAsync(CanvasSurface, path); }
        catch (Exception error) when (error is ArgumentException or System.Runtime.InteropServices.COMException)
        { oldLoadRejected = true; }

        await OpenAsync(new()
        {
            Board = new() { Title = "Image transfer QA", CanvasMode = "fixed", CanvasWidth = 400, CanvasHeight = 300 }
        });
        var point = new InkPoint(200, 150);
        var files = new DataPackage();
        files.SetStorageItems([file]);
        Check(await InsertTransferredImagesAsync(files.GetView(), point), "storage-item transfer");
        Check(_session.Selected is { } fromFile && fromFile.OriginalHeight == native.OrientedPixelHeight, "source size preserved");
        var bitmapTransfer = new DataPackage();
        bitmapTransfer.SetBitmap(RandomAccessStreamReference.CreateFromFile(file));
        Check(await InsertTransferredImagesAsync(bitmapTransfer.GetView(), point), "bitmap transfer");
        var image = _session.Selected ?? throw new InvalidOperationException("Pasted image was not selected");
        Check(image.OriginalWidth == native.OrientedPixelWidth && image.OriginalHeight == native.OrientedPixelHeight, "clipboard source size preserved");
        Check(image.Width <= 400 && image.Height <= 300, "placed in the bounded canvas");
        Check(Math.Abs(image.Width / image.Height - native.OrientedPixelWidth / (double)native.OrientedPixelHeight) < 0.001, "aspect ratio");
        Check(await IsVisibleAsync(image), "oversized image produces visible canvas pixels");

        _session.Begin();
        image.CropX = native.OrientedPixelWidth / 8.0;
        image.CropY = native.OrientedPixelHeight / 8.0;
        image.CropWidth = native.OrientedPixelWidth / 2.0;
        image.CropHeight = native.OrientedPixelHeight / 2.0;
        image.FlipX = true;
        image.Rotation = 15;
        _session.Commit();
        var geometry = (image.X, image.Y, image.Width, image.Height, image.Rotation, image.FlipX, image.ZIndex);
        var id = image.Id;
        var original = image.ImageUrl;
        await FitImageResolutionAsync(image);
        var expected = CanvasImageDecoding.Fit(native.OrientedPixelWidth, native.OrientedPixelHeight, 400, 300);
        Check(image.OriginalWidth == expected.Width && image.OriginalHeight == expected.Height && image.ImageUrl != original, "encoded image reduced");
        Check((image.X, image.Y, image.Width, image.Height, image.Rotation, image.FlipX, image.ZIndex) == geometry, "world geometry preserved");
        Check(Math.Abs(image.CropX!.Value - expected.Width / 8.0) < 0.01 &&
            Math.Abs(image.CropHeight!.Value - expected.Height / 2.0) < 0.01, "crop preserved");
        Check(await IsVisibleAsync(image), "adapted crop produces canvas pixels");
        _session.Undo();
        Check(_session.Document.Objects.Single(o => o.Id == id).ImageUrl == original, "undo restores encoded source");
        _session.Redo();
        var serialized = DocumentCodec.Clone(_session.Document);
        await OpenAsync(serialized);
        Check(await IsVisibleAsync(_session.Document.Objects.Single(o => o.Id == id)), "adapted image renders after reopening");
        await File.WriteAllTextAsync(Path.Combine(output, "image-resolution.json"), JsonSerializer.Serialize(new
        {
            success = true, native.OrientedPixelWidth, native.OrientedPixelHeight, maximumTexture, oldLoadRejected,
            adaptedWidth = expected.Width, adaptedHeight = expected.Height,
            originalEncodedLength = original?.Length, adaptedEncodedLength = image.ImageUrl?.Length
        }));

        async Task<bool> IsVisibleAsync(BoardObject item)
        {
            await LoadCurrentPageImagesAsync(CanvasSurface);
            using var target = new CanvasRenderTarget(CanvasSurface, 400, 300, 96);
            using (var drawing = target.CreateDrawingSession())
            {
                drawing.Clear(Microsoft.UI.Colors.Transparent);
                _renderer.RenderPreview(drawing, item, new ViewportTransform { X = 0, Y = 0, Zoom = 1 }, 400, 300);
            }
            var pixels = target.GetPixelBytes();
            for(var alpha = 3; alpha < pixels.Length; alpha += 4)
                if (pixels[alpha] != 0) return true;
            return false;
        }

        static void Check(bool condition, string name)
        {
            if (!condition) throw new InvalidOperationException("Image QA failed: " + name);
        }
    }
}
#endif
