using System.Globalization;
namespace HeiBan.Windows.Localization;

// The linked updater is tested without WinUI platform language APIs. Keep the
// transport/path/hash/cancellation implementation real; UI catalogs have their
// own native checks. This adapter only supplies deterministic diagnostic text.
internal static class Strings
{
    internal static string T(string source)=>source;
    internal static string F(FormattableString source)=>source.ToString(CultureInfo.InvariantCulture);
}
