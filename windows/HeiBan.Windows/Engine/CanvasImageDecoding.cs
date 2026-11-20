using global::Windows.Graphics.Imaging;
using global::Windows.Storage.Streams;

namespace HeiBan.Windows.Engine;

internal static class CanvasImageDecoding
{
    internal sealed record EncodedImage(string DataUri, uint Width, uint Height);

    internal static async Task<EncodedImage> ReadAsync(IRandomAccessStream stream, int maximumSide)
    {
        stream.Seek(0);
        var decoder = await BitmapDecoder.CreateAsync(stream);
        var width = decoder.OrientedPixelWidth;
        var height = decoder.OrientedPixelHeight;
        var codec = decoder.DecoderInformation.CodecId;
        var subtype = codec == BitmapDecoder.PngDecoderId ? "png"
            : codec == BitmapDecoder.JpegDecoderId ? "jpeg"
            : codec == BitmapDecoder.GifDecoderId ? "gif"
            : codec == BitmapDecoder.TiffDecoderId ? "tiff"
            : codec == BitmapDecoder.BmpDecoderId ? "bmp" : null;
        if (subtype is not null)
            return new(await ReadDataUriAsync(stream, subtype), width, height);

        // Export readers share the same encoded format. Normalize other Windows codecs once at import.
        (width, height) = FitTexture(width, height, maximumSide);
        return new(await EncodeAsync(decoder, width, height), width, height);
    }

    // Bound the decoded texture as well as either dimension. The encoded original stays in the document.
    private const double PreviewPixelBudget = 16_000_000;

    internal static (uint Width, uint Height) Fit(uint width, uint height, double limitWidth, double limitHeight)
    {
        var scale = Math.Min(1, Math.Min(limitWidth / width, limitHeight / height));
        return Scale(width, height, scale);
    }

    internal static (uint Width, uint Height) FitTexture(uint width, uint height, int maximumSide)
    {
        var scale = Math.Min(1, Math.Min(maximumSide / (double)Math.Max(width, height),
            Math.Sqrt(PreviewPixelBudget / ((double)width * height))));
        return Scale(width, height, scale);
    }

    private static (uint Width, uint Height) Scale(uint width, uint height, double scale) =>
        ((uint)Math.Max(1, Math.Floor(width * scale)), (uint)Math.Max(1, Math.Floor(height * scale)));

    internal static async Task<SoftwareBitmap> DecodeAsync(BitmapDecoder decoder, uint width, uint height)
    {
        // The scaler runs before EXIF rotation, so pass dimensions in the decoder's native axes.
        var swapped = decoder.PixelWidth != decoder.OrientedPixelWidth;
        return await decoder.GetSoftwareBitmapAsync(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied,
            new BitmapTransform
            {
                ScaledWidth = swapped ? height : width,
                ScaledHeight = swapped ? width : height,
                InterpolationMode = BitmapInterpolationMode.Fant
            }, ExifOrientationMode.RespectExifOrientation, ColorManagementMode.ColorManageToSRgb);
    }

    internal static async Task<string> EncodeAsync(BitmapDecoder decoder, uint width, uint height, bool jpeg = false)
    {
        using var bitmap = await DecodeAsync(decoder, width, height);
        using var output = new InMemoryRandomAccessStream();
        var encoder = await BitmapEncoder.CreateAsync(jpeg ? BitmapEncoder.JpegEncoderId : BitmapEncoder.PngEncoderId, output);
        encoder.SetSoftwareBitmap(bitmap);
        await encoder.FlushAsync();
        return await ReadDataUriAsync(output, jpeg ? "jpeg" : "png");
    }

    internal static async Task<string> ReadDataUriAsync(IRandomAccessStream stream, string subtype)
    {
        stream.Seek(0);
        using var input = stream.GetInputStreamAt(0).AsStreamForRead();
        var bytes = new byte[checked((int)stream.Size)];
        await input.ReadExactlyAsync(bytes);
        return $"data:image/{subtype};base64," + Convert.ToBase64String(bytes);
    }
}
