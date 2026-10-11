using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;

namespace HeiBan.Windows.Localization;

/// <summary>Attached keys keep static XAML text live without touching user bindings or retaining closed controls.</summary>
public static class Ui
{
    private sealed record Entry(WeakReference<DependencyObject> Target, DependencyProperty Property);
    private static readonly List<Entry> Entries = [];
    private static DependencyProperty Register(string property) => DependencyProperty.RegisterAttached(property, typeof(string), typeof(Ui), new PropertyMetadata(null, Changed));
    public static readonly DependencyProperty TextProperty = Register("Text");
    public static readonly DependencyProperty ContentProperty = Register("Content");
    public static readonly DependencyProperty HeaderProperty = Register("Header");
    public static readonly DependencyProperty PlaceholderProperty = Register("Placeholder");
    public static readonly DependencyProperty ToolTipProperty = Register("ToolTip");
    public static readonly DependencyProperty NameProperty = Register("Name");
    public static string GetText(DependencyObject target) => (string)target.GetValue(TextProperty);
    public static void SetText(DependencyObject target, string value) => target.SetValue(TextProperty, value);
    public static string GetContent(DependencyObject target) => (string)target.GetValue(ContentProperty);
    public static void SetContent(DependencyObject target, string value) => target.SetValue(ContentProperty, value);
    public static string GetHeader(DependencyObject target) => (string)target.GetValue(HeaderProperty);
    public static void SetHeader(DependencyObject target, string value) => target.SetValue(HeaderProperty, value);
    public static string GetPlaceholder(DependencyObject target) => (string)target.GetValue(PlaceholderProperty);
    public static void SetPlaceholder(DependencyObject target, string value) => target.SetValue(PlaceholderProperty, value);
    public static string GetToolTip(DependencyObject target) => (string)target.GetValue(ToolTipProperty);
    public static void SetToolTip(DependencyObject target, string value) => target.SetValue(ToolTipProperty, value);
    public static string GetName(DependencyObject target) => (string)target.GetValue(NameProperty);
    public static void SetName(DependencyObject target, string value) => target.SetValue(NameProperty, value);
    private static void Changed(DependencyObject target, DependencyPropertyChangedEventArgs args)
    {
        Entries.RemoveAll(entry => !entry.Target.TryGetTarget(out _));
        if (!Entries.Any(entry => entry.Property == args.Property && entry.Target.TryGetTarget(out var existing) && ReferenceEquals(target, existing)))
            Entries.Add(new(new(target), args.Property));
        Apply(target, args.Property);
    }
    public static void Refresh()
    {
        Entries.RemoveAll(entry => !entry.Target.TryGetTarget(out _));
        foreach (var entry in Entries.ToArray()) if (entry.Target.TryGetTarget(out var target)) Apply(target, entry.Property);
    }
    private static void Apply(DependencyObject target, DependencyProperty property)
    {
        if (target.GetValue(property) is not string source) return;
        var text = Strings.T(source);
        if (property == TextProperty && target is TextBlock block) block.Text = text;
        else if (property == ContentProperty && target is ContentControl content) content.Content = text;
        else if (property == HeaderProperty)
        {
            if (target is ComboBox combo) combo.Header = text;
            else if (target is Slider slider) slider.Header = text;
            else if (target is NumberBox number) number.Header = text;
            else if (target is TextBox input) input.Header = text;
            else if (target is ToggleSwitch toggle) toggle.Header = text;
        }
        else if (property == PlaceholderProperty && target is TextBox input) input.PlaceholderText = text;
        else if (property == ToolTipProperty) ToolTipService.SetToolTip(target, text);
        else if (property == NameProperty) AutomationProperties.SetName(target, text);
    }
}
