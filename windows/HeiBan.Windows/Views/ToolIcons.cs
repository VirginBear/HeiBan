using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Markup;
using Microsoft.UI.Xaml.Media;

namespace HeiBan.Windows.Views;

/// <summary>Original outline vectors using the Mac toolbar's visual vocabulary.
/// No Apple symbol font or external icon asset is required on Windows.</summary>
internal static class ToolIcons
{
    private static readonly Dictionary<string,string> Paths=new()
    {
        ["screen"]="M3,3 L23,3 L23,17 L3,17 Z M13,17 L13,22 M8,22 L18,22 M7,11 L11,7 L15,11 L19,7",
        ["laser"]="M12,7 L12,1 M12,17 L12,23 M7,12 L1,12 M17,12 L23,12 M4,4 L8,8 M16,16 L20,20 M4,20 L8,16 M16,8 L20,4",
        ["tape"]="M3,6 L23,6 L23,19 L3,19 Z M5,7 L10,18 M12,7 L17,18 M19,7 L22,13",
        ["lasso"]="M21,10 C21,2 2,2 2,10 C2,18 21,18 21,10 M6,16 C4,20 7,25 12,21",
        ["notebook"]="M5,3 L21,3 L21,22 L5,22 Z M8,3 L8,22 M2,7 L6,7 M2,12 L6,12 M2,17 L6,17",
        ["infinite"]="M12,12 C2,-3 -8,27 12,12 C32,-3 32,27 12,12",
        ["select"]="M5,3 L19,13 L12,14 L9,21 Z M12,14 L16,21",
        ["palette"]="M12,2 C0,2 -1,20 9,22 C14,24 12,16 17,17 C26,19 27,2 12,2 Z M7,7 L7,8 M13,5 L13,6 M19,8 L19,9 M5,13 L5,14",
        ["pen"]="M4,16 L3,21 L8,20 L20,8 Q22,6 20,4 Q18,2 16,4 Z M14,6 L18,10 M4,16 L8,20",
        ["curve"]="M4,18 C4,4 20,20 20,6 M2,18 L6,18 M20,4 L20,8",
        ["highlighter"]="M8,15 L17,4 L21,8 L12,19 Z M8,15 L5,18 L9,21 L12,19 M3,22 L13,22",
        ["paint"]="M12,14 L19,3 L22,6 L15,17 Z M12,14 C6,12 9,19 3,21 C11,23 16,21 15,17",
        ["eraser"]="M4,14 L13,4 Q14,3 15,4 L21,10 Q22,11 21,12 L13,21 L9,21 Z M8,10 L17,17 M13,21 L22,21",
        ["ruler"]="M3,16 L16,3 L22,9 L9,22 Z M6,13 L9,16 M10,9 L13,12 M14,5 L17,8",
        ["shapes"]="M4,3 L15,3 L15,14 L4,14 Z M17,9 C25,9 25,22 17,22 C10,22 9,17 11,14",
        ["rect"]="M4,4 L20,4 L20,20 L4,20 Z",
        ["circle"]="M12,3 C24,3 24,21 12,21 C0,21 0,3 12,3 Z",
        ["triangle"]="M12,3 L22,21 L2,21 Z",
        ["quadrilateral"]="M5,4 L21,7 L18,21 L2,17 Z",
        ["diamond"]="M12,2 L22,12 L12,22 L2,12 Z",
        ["pentagon"]="M12,2 L22,10 L18,22 L6,22 L2,10 Z",
        ["star"]="M12,2 L15,9 L22,9 L16,14 L18,21 L12,17 L6,21 L8,14 L2,9 L9,9 Z",
        ["line"]="M4,20 L20,4",
        ["arrow"]="M3,20 L21,3 M11,3 L21,3 L21,13",
        ["sticky"]="M4,3 L20,3 L20,16 L14,22 L4,22 Z M14,22 L14,16 L20,16 M8,8 L16,8 M8,12 L14,12",
        ["text"]="M4,4 L20,4 M12,4 L12,21 M8,21 L16,21",
        ["image"]="M3,4 L21,4 L21,20 L3,20 Z M4,17 L9,12 L13,16 L17,11 L21,15 M8,7 L8,8",
        ["screenshot"]="M3,9 L3,3 L9,3 M15,3 L21,3 L21,9 M21,15 L21,21 L15,21 M9,21 L3,21 L3,15 M8,8 L16,8 L16,16 L8,16 Z",
        ["undo"]="M8,4 L3,9 L8,14 M3,9 L14,9 C23,9 23,21 14,21",
        ["redo"]="M16,4 L21,9 L16,14 M21,9 L10,9 C1,9 1,21 10,21",
        ["home"]="M2,11 L12,3 L22,11 M5,9 L5,21 L10,21 L10,14 L15,14 L15,21 L20,21 L20,9",
        ["layers"]="M2,8 L12,2 L22,8 L12,14 Z M2,13 L12,19 L22,13 M2,18 L12,24 L22,18",
        ["settings"]="M3,6 L21,6 M3,12 L21,12 M3,18 L21,18 M8,3 L8,9 M16,9 L16,15 M10,15 L10,21",
        ["export"]="M5,12 L5,21 L19,21 L19,12 M12,16 L12,2 M7,7 L12,2 L17,7",
        ["save"]="M4,3 L17,3 L21,7 L21,21 L3,21 L3,3 Z M7,3 L7,9 L16,9 L16,3 M7,21 L7,14 L17,14 L17,21",
        ["close"]="M5,5 L19,19 M19,5 L5,19",
        ["dock"]="M3,3 L21,3 L21,21 L3,21 Z M3,8 L21,8 M9,8 L9,21",
        ["dash"]="M2,12 L6,12 M10,12 L14,12 M18,12 L22,12",
        ["dash-solid"]="M2,12 L24,12",
        ["dash-dotted"]="M2,12 L2.1,12 M7,12 L7.1,12 M12,12 L12.1,12 M17,12 L17.1,12 M22,12 L22.1,12",
        ["dash-dot"]="M2,12 L8,12 M12,12 L12.1,12 M16,12 L22,12",
        ["background"]="M5,3 L17,15 L9,23 L1,15 Z M1,15 L17,15 M20,14 C15,20 25,20 20,14",
        ["more"]="M5,13 A1.5,1.5 0 1,1 5,10 A1.5,1.5 0 1,1 5,13 Z M13,13 A1.5,1.5 0 1,1 13,10 A1.5,1.5 0 1,1 13,13 Z M21,13 A1.5,1.5 0 1,1 21,10 A1.5,1.5 0 1,1 21,13 Z",
        ["calculator"]="M5,3 L19,3 L19,21 L5,21 Z M8,6 L16,6 L16,9 L8,9 Z M8,12 L10,12 M14,12 L16,12 M8,15 L10,15 M14,15 L16,15 M8,18 L16,18",
        ["timer"]="M12,2 L12,5 M10,2 L14,2 M12,13 L15,10 M12,22 C6.5,22 2,17.5 2,12 C2,6.5 6.5,2 12,2 C17.5,2 22,6.5 22,12 C22,17.5 17.5,22 12,22 Z",
        ["compass"]="M16,5 L6,20 L4,23 M16,5 L21,17 L19,22 L17,18 L16,9 M13,4 A3,3 0 1,0 19,4 A3,3 0 1,0 13,4 M16,0 L16,1",
        ["magnet"]="M5,3 L5,13 C5,24 21,24 21,13 L21,3 L16,3 L16,13 C16,18 10,18 10,13 L10,3 Z M5,8 L10,8 M16,8 L21,8",
        ["copy"]="M8,8 L19,8 L19,21 L8,21 Z M5,16 L5,5 L16,5",
        ["duplicate"]="M7,7 L17,7 L17,19 L7,19 Z M10,4 L20,4 L20,16",
        ["delete"]="M4,7 L22,7 M10,11 L10,17 M16,11 L16,17 M6,7 L7,21 L19,21 L20,7 M9,7 L9,4 L17,4 L17,7",
        ["lock"]="M7,11 L7,7 C7,4 9,3 13,3 C17,3 19,4 19,7 L19,11 M5,11 L21,11 L21,22 L5,22 Z",
        ["unlock"]="M7,11 L7,7 C7,4 9,3 13,3 C17,3 19,4 19,7 M5,11 L21,11 L21,22 L5,22 Z",
        ["text-edit"]="M4,20 L8,20 L20,8 L16,4 L4,16 Z M14,6 L18,10",
        ["pins"]="M8,3 L19,3 L17,6 L17,12 L21,16 L6,16 L10,12 L10,6 Z M13,16 L13,23",
        ["reading"]="M4,4 L11,4 C12,4 12,5 12,6 L12,20 C12,19 11,18 10,18 L4,18 Z M13,6 C13,5 13,4 14,4 L21,4 L21,18 L15,18 C14,18 13,19 13,20 Z",
        ["plus"]="M12,4 L12,20 M4,12 L20,12",
        ["chevron-left"]="M15,4 L7,12 L15,20",
        ["chevron-down"]="M4,8 L12,16 L20,8",
        ["chevron-up"]="M4,16 L12,8 L20,16",
        ["info"]="M12,2 C17.5,2 22,6.5 22,12 C22,17.5 17.5,22 12,22 C6.5,22 2,17.5 2,12 C2,6.5 6.5,2 12,2 Z M12,7 L12,9 M12,11 L12,17",
    };

    public static UIElement CreateDash(string? style)=>Create(DashKey(style));
    public static IconElement CreateDashIcon(string? style)
    {
        // PathIcon fills geometry; open stroked paths would be invisible in menu rows.
        var path=style switch
        {
            "dashed"=>"M2,11 L7,11 L7,13 L2,13 Z M10,11 L15,11 L15,13 L10,13 Z M18,11 L23,11 L23,13 L18,13 Z",
            "dotted"=>"M2,11 L4,11 L4,13 L2,13 Z M7,11 L9,11 L9,13 L7,13 Z M12,11 L14,11 L14,13 L12,13 Z M17,11 L19,11 L19,13 L17,13 Z M22,11 L24,11 L24,13 L22,13 Z",
            "dashdot"=>"M2,11 L8,11 L8,13 L2,13 Z M12,11 L14,11 L14,13 L12,13 Z M18,11 L24,11 L24,13 L18,13 Z",
            _=>"M2,11 L24,11 L24,13 L2,13 Z"
        };
        return new PathIcon{Data=(Geometry)XamlReader.Load($"<Geometry xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>{path}</Geometry>")};
    }
    private static string DashKey(string? style)=>style switch{"dashed"=>"dash","dotted"=>"dash-dotted","dashdot"=>"dash-dot",_=>"dash-solid"};

    public static UIElement Create(string name)
    {
        var path=Paths.GetValueOrDefault(name,Paths["settings"]);
        return (UIElement)XamlReader.Load($"<Viewbox xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='18' Height='18'><Canvas Width='26' Height='26'><Path Data='{path}' Stroke='#26372F' StrokeThickness='1.7' StrokeStartLineCap='Round' StrokeEndLineCap='Round' StrokeLineJoin='Round'/></Canvas></Viewbox>");
    }

    public static IconElement CreateIcon(string name)
    {
        var path=Paths.GetValueOrDefault(name,Paths["settings"]);
        var geom=(Geometry)XamlReader.Load($"<Geometry xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>{path}</Geometry>");
        return new PathIcon { Data = geom };
    }
}
