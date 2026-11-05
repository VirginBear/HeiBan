namespace HeiBan.Windows.Engine;

/// <summary>Artwork coordinates are 26×26; input coordinates never move with cursor artwork.</summary>
public static class ToolCursorGeometry
{
    public static bool UsesCrosshairBadge(string tool)=>tool is "curve" or "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
    public static (double X,double Y) Anchor(string tool,bool duotone)=>tool switch
    {
        "pen"=>(duotone?4:3,21),
        "highlighter"=>(duotone?7.5:7,duotone?20.5:19.5),
        "paint"=>(3,21),
        "eraser"=>(11,duotone?23:21),
        _=>(13,13)
    };
    public static (int X,int Y,double Offset,double Scale) Layout(string tool,bool duotone,int size)
    {
        // Construction tools retain the original 32-unit cross at (4,4), with
        // their badge offset from it. Brushes use artwork nib/contact anchors.
        if(UsesCrosshairBadge(tool))return ((int)Math.Round(size/8d),(int)Math.Round(size/8d),size/4d,size*.85/32);
        var scale=size*.82/26;var offset=size*.09;var a=Anchor(tool,duotone);
        return ((int)Math.Round(offset+a.X*scale),(int)Math.Round(offset+a.Y*scale),offset,scale);
    }
}
