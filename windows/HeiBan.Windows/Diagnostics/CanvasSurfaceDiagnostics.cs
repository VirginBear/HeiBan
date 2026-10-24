using System.Text.Json;

namespace HeiBan.Windows.Diagnostics;

internal static class CanvasSurfaceDiagnostics
{
    internal static void Record(string stage,Exception error)
    {
        try
        {
            // One bounded diagnostic file. Exception messages/stacks may contain
            // document paths or text, so only type, code and renderer stage enter it.
            var root=Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY");
            if(string.IsNullOrWhiteSpace(root))root=Path.Combine(Path.GetTempPath(),"HeiBan","CanvasLogs");
            Directory.CreateDirectory(root);
            File.WriteAllText(Path.Combine(root,"last-canvas-error.json"),JsonSerializer.Serialize(new
            {schema=1,utc=DateTime.UtcNow,stage,errorType=error.GetType().FullName,hresult=$"0x{error.HResult:X8}"}));
        }
        catch{ /* Diagnostic I/O must not become another presentation failure. */ }
    }
}
