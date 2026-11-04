using Microsoft.UI.Xaml.Media.Imaging;
namespace HeiBan.Windows.Views;

internal static partial class ToolIcons
{
    internal static string Style {get;private set;}="classic";
    private static readonly Dictionary<string,string> DuotoneXml=[];
    private static readonly Dictionary<string,SvgImageSource> IconSources=[];
    // Style is shared by the application's two hosts. Sources may be shared;
    // UIElements never are. Preload small XML once at an explicit settings/startup
    // boundary so drawing frames never open files or parse the full icon catalog.
    internal static void SetStyle(string style)
    {
        Style=style=="duotone"?"duotone":"classic";
        if(Style=="duotone")EnsureDuotone();
    }
    private static void EnsureDuotone()
    {
        if(DuotoneXml.Count!=0)return;
        foreach(var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory,"Assets","MenuIcons","Duotone"),"*.svg"))
            DuotoneXml.Add(Path.GetFileNameWithoutExtension(file),File.ReadAllText(file).Replace(" width=\"26\" height=\"26\"", ""));
    }
    private static string ResolvedKey(string name)=>CommandPath(name) is not null?CommandKey(name):"settings";
    private static SvgImageSource SvgSource(string name,string style)
    {
        var key=ResolvedKey(name);var folder=style=="duotone"?"Duotone/":"";var asset=folder+key;
        if(!IconSources.TryGetValue(asset,out var source))IconSources[asset]=source=new(new Uri("ms-appx:///Assets/MenuIcons/"+asset+".svg"));
        return source;
    }
    internal static string RadialSvg(string name,bool active)
    {
        if(Style=="duotone")return DuotoneXml[ResolvedKey(name)];
        var path=CommandPath(name)??Paths["settings"];
        return $"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 26 26'><path d='{path}' fill='none' stroke='{(active?"#184530":"#28543F")}' stroke-width='{(active?"2.2":"1.6")}' stroke-linecap='round' stroke-linejoin='round'/></svg>";
    }
}
