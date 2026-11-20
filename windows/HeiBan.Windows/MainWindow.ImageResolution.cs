using static HeiBan.Windows.Localization.Strings;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.Graphics.Imaging;
using global::Windows.Storage;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private (long Epoch, string? Page) CurrentImagePage =>
        (_session.DocumentEpoch, _session.Document.Board.ActivePageId);

    private bool CanEditImages => _workspaceOpen && !_readingMode && !_closing && !_preparingClose && !_saveBoundaryBusy;

    private async Task<bool> InsertImageFileAsync(string path, InkPoint location, bool isCenter)
    {
        var page = CurrentImagePage;
        var file = await StorageFile.GetFileFromPathAsync(path);
        using var stream = await file.OpenReadAsync();
        return page == CurrentImagePage && await InsertImageStreamAsync(stream, location, isCenter);
    }

    private async Task<bool> InsertImageStreamAsync(IRandomAccessStream stream, InkPoint location, bool isCenter,
        string? expectedRequestId = null, string? expectedBoardId = null, string? expectedPageId = null)
    {
        if (!CanEditImages) return false;
        var page = CurrentImagePage;
        var image = await CanvasImageDecoding.ReadAsync(stream, CanvasSurface.Device.MaximumBitmapSizeInPixels);
        if (!CanEditImages || page != CurrentImagePage) return false;
        return await ApplyImageInsertionAsync(image.Width, image.Height, image.DataUri, location, isCenter,
            expectedRequestId, expectedBoardId, expectedPageId);
    }

    private static bool HasImageTransfer(DataPackageView data) =>
        data.Contains(StandardDataFormats.StorageItems) || data.Contains(StandardDataFormats.Bitmap);

    private async Task<bool> InsertTransferredImagesAsync(DataPackageView data, InkPoint location)
    {
        if (!CanEditImages) return false;
        var page = CurrentImagePage;
        var inserted = false;
        // Explorer provides storage items. Browser and screenshot copy commands usually provide a bitmap.
        if (data.Contains(StandardDataFormats.StorageItems))
        {
            foreach (var file in (await data.GetStorageItemsAsync()).OfType<StorageFile>())
            {
                if (!CanEditImages || page != CurrentImagePage) return inserted;
                if (!file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase) &&
                    file.FileType.ToLowerInvariant() is not (".png" or ".jpg" or ".jpeg" or ".gif" or ".bmp" or ".tif" or ".tiff" or ".webp"))
                    continue;
                using var stream = await file.OpenReadAsync();
                if (page != CurrentImagePage) return inserted;
                inserted |= await InsertImageStreamAsync(stream, location, isCenter: true);
            }
        }
        if (inserted || page != CurrentImagePage || !data.Contains(StandardDataFormats.Bitmap)) return inserted;
        using var bitmap = await (await data.GetBitmapAsync()).OpenReadAsync();
        return page == CurrentImagePage && await InsertImageStreamAsync(bitmap, location, isCenter: true);
    }

    private async Task FitImageResolutionAsync(BoardObject image)
    {
        try
        {
            if (!CanEditImages || image.IsLocked == true || image.ImageUrl is not { } source) return;
            CommitPropertyEdit();
            FinishText();
            if (_gesture) CancelGesture();
            var page = CurrentImagePage;
            var generation = _session.Generation;
            var board = _session.Document.Board;
            var bounded = board.CanvasMode is "fixed" or "notebook";
            var widthLimit = bounded ? board.CanvasWidth ?? 595 : Math.Max(1, CanvasSurface.ActualWidth);
            var heightLimit = bounded ? board.CanvasHeight ?? 842 : Math.Max(1, CanvasSurface.ActualHeight);

            using var memory = new MemoryStream(Convert.FromBase64String(source[(source.IndexOf(',') + 1)..]));
            using var stream = memory.AsRandomAccessStream();
            var decoder = await BitmapDecoder.CreateAsync(stream);
            var width = decoder.OrientedPixelWidth;
            var height = decoder.OrientedPixelHeight;
            var fitted = CanvasImageDecoding.Fit(width, height, widthLimit, heightLimit);
            fitted = CanvasImageDecoding.FitTexture(fitted.Width, fitted.Height, CanvasSurface.Device.MaximumBitmapSizeInPixels);
            if (!IsCurrent()) return;
            if (fitted == (width, height))
            {
                StatusText.Text = T("圖片解析度已符合畫布，無須縮減。");
                return;
            }
            var data = await CanvasImageDecoding.EncodeAsync(decoder, fitted.Width, fitted.Height,
                decoder.DecoderInformation.CodecId == BitmapDecoder.JpegDecoderId);
            if (!IsCurrent()) return;

            _session.Begin();
            // Rescale the source crop rectangle with the pixels. World bounds, rotation and flips stay as drawn.
            (image.CropX, image.CropWidth) = ScaleCrop(image.CropX, image.CropWidth, width, fitted.Width);
            (image.CropY, image.CropHeight) = ScaleCrop(image.CropY, image.CropHeight, height, fitted.Height);
            image.ImageUrl = image.OriginalImageUrl = data;
            image.OriginalWidth = fitted.Width;
            image.OriginalHeight = fitted.Height;
            _session.Commit();
            RefreshEditor();
            StatusText.Text = string.Format(T("圖片解析度已調整為 {0} × {1}，可復原。"), fitted.Width, fitted.Height);

            bool IsCurrent() => CanEditImages && !_gesture && CurrentImagePage == page && _session.Generation == generation
                && _session.SelectedId == image.Id && _session.Document.Objects.Contains(image) && image.IsLocked != true;
        }
        catch (Exception error) { await Error(error); }
    }

    private static (double? Offset, double? Length) ScaleCrop(double? offset, double? length, uint before, uint after)
    {
        var scale = after / (double)before;
        var start = Math.Clamp((offset ?? 0) * scale, 0, after - 1);
        return (offset.HasValue ? start : null,
            length.HasValue ? Math.Clamp(length.Value * scale, 1, after - start) : null);
    }
}
