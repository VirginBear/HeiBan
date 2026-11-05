namespace HeiBan.Windows.Engine;

/// <summary>Artwork coordinates are 26×26; input coordinates never move with cursor artwork.</summary>
public static class ToolCursorGeometry
{
    public static (double X,double Y) Anchor(string tool,bool duotone)=>tool switch
    {
        "pen"=>(duotone?4:3,21),
        "highlighter"=>(duotone?7.5:7,duotone?20.5:19.5),
        "paint"=>(3,21),
        "eraser"=>(11,duotone?23:21),
        "line"=>(4,duotone?22:20),"arrow"=>(duotone?23:21,3),
        "triangle"=>(12,3),"rect"=>(4,4),"diamond"=>(12,2),
        _=>(13,13)
    };
    public static (int X,int Y,double Offset,double Scale) Layout(string tool,bool duotone,int size)
    {
        var scale=size*.82/26;var offset=size*.09;var a=Anchor(tool,duotone);
        return ((int)Math.Round(offset+a.X*scale),(int)Math.Round(offset+a.Y*scale),offset,scale);
    }
}
