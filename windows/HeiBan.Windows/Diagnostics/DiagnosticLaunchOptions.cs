namespace HeiBan.Windows.Diagnostics;

internal sealed record DiagnosticLaunchOptions(string Name, string Output)
{
    internal static readonly IReadOnlySet<string> Names = new HashSet<string>(StringComparer.Ordinal)
    {
        "performance-output", "validation-output", "drawing-workflow-output", "guide-view",
        "release-validation-output", "marquee-validation-output", "canvas-capture-validation-output",
        "selection-feedback-validation-output", "object-drag-validation-output",
        "operate-radial-validation-output", "operate-input-probe-output",
        "cursor-cane-validation-output", "icon-style-validation-output"
    };

    internal bool RequiresValidationBuild => Name is not
        ("performance-output" or "validation-output" or "drawing-workflow-output" or "guide-view");

    internal string? OutputFor(string name) => Name == name ? Output : null;

    internal static DiagnosticLaunchOptions? Parse(IEnumerable<string> arguments)
    {
        DiagnosticLaunchOptions? result = null;
        foreach (var argument in arguments)
        {
            if (!argument.StartsWith("--", StringComparison.Ordinal)) continue;
            var equals = argument.IndexOf('=');
            if (equals < 0 || !Names.Contains(argument[2..equals])) continue;
            if (result is not null) throw new ArgumentException("Only one diagnostic mode can run per process.");
            var output = argument[(equals + 1)..];
            if (string.IsNullOrWhiteSpace(output)) throw new ArgumentException("A diagnostic output path is required.");
            result = new(argument[2..equals], Path.GetFullPath(output));
        }
        return result;
    }

    internal static void RequireFreshDataDirectory(string? directory)
    {
        // Called before constructing storage or restoring screen annotations.
        if (string.IsNullOrWhiteSpace(directory) || Directory.Exists(directory) || File.Exists(directory))
            throw new InvalidOperationException("Diagnostics require a new HEIBAN_WINDOWS_DATA_DIRECTORY.");
    }
}
