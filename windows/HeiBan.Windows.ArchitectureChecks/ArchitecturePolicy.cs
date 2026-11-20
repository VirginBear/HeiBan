using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

internal sealed record Violation(string Rule, string File, int Line, string Message);

internal static class ArchitecturePolicy
{
    internal static IReadOnlyList<Violation> Inspect(string file, string source, bool core)
    {
        var root = CSharpSyntaxTree.ParseText(source).GetRoot();
        var violations = new List<Violation>();
        void Reject(string rule, SyntaxNode node, string message) =>
            violations.Add(new(rule, file, node.GetLocation().GetLineSpan().StartLinePosition.Line + 1, message));

        if (core)
        {
            foreach (var directive in root.DescendantNodes().OfType<UsingDirectiveSyntax>())
                if (IsUiNamespace(directive.Name?.ToString() ?? ""))
                    Reject("HB001", directive, "Keep Core independent of WinUI, Win2D and platform UI namespaces.");
            foreach (var name in root.DescendantNodes().OfType<QualifiedNameSyntax>())
                if (IsUiNamespace(name.ToString()) && name.Parent is not QualifiedNameSyntax and not UsingDirectiveSyntax)
                    Reject("HB001", name, "Move platform UI access to the Windows host.");
        }

        foreach (var call in root.DescendantNodes().OfType<InvocationExpressionSyntax>())
        {
            if (call.Expression is not MemberAccessExpressionSyntax access) continue;
            var receiver = access.Expression.ToString();
            var method = access.Name.Identifier.ValueText;
            if ((receiver == "Thread" && method == "Sleep") || (receiver == "GC" && method == "Collect") ||
                ((method is "Wait" or "GetResult") && receiver.Contains("GetAwaiter(", StringComparison.Ordinal)))
                Reject("HB002", call, "Avoid blocking the UI. Await completion or use the existing worker boundary.");
            if (receiver == "CanvasBitmap" && method == "LoadAsync" &&
                !file.EndsWith("Engine/Direct2DCanvasRenderer.ToolArt.cs", StringComparison.Ordinal))
                Reject("HB003", call, "Decode user images through CanvasImageDecoding with a device-size limit.");
        }

        foreach (var method in root.DescendantNodes().OfType<MethodDeclarationSyntax>())
        {
            var type = method.Ancestors().OfType<TypeDeclarationSyntax>().FirstOrDefault()?.Identifier.ValueText;
            var name = method.Identifier.ValueText;
            var hotPath = type == "MainWindow" && name == "CanvasSurface_PointerMoved" ||
                type == "WindowsInkCoordinator" && name is "Append" or "ProcessPointerUpdate";
            if (!hotPath) continue;
            foreach (var call in method.DescendantNodes().OfType<InvocationExpressionSyntax>())
            {
                var expression = call.Expression.ToString();
                if (expression.StartsWith("File.", StringComparison.Ordinal) ||
                    expression.StartsWith("Directory.", StringComparison.Ordinal) ||
                    expression.StartsWith("JsonSerializer.", StringComparison.Ordinal) ||
                    expression.StartsWith("DocumentCodec.", StringComparison.Ordinal) ||
                    expression is "_session.Begin" or "_session.Commit" or "BuildChrome" or "RebuildChromeLayout")
                    Reject("HB004", call, "Keep pointer sampling separate from I/O, serialization, undo commits and toolbar rebuilds.");
            }
        }
        return violations;
    }

    private static bool IsUiNamespace(string name)
    {
        name = name.Replace("global::", "", StringComparison.Ordinal);
        return new[] { "Microsoft.UI", "Microsoft.Graphics", "Windows.UI", "Windows.Graphics" }
            .Any(prefix => name == prefix || name.StartsWith(prefix + ".", StringComparison.Ordinal));
    }
}
