using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

static class TextAndArrowChecks
{
    public static void Run(Action<bool,string> check)
    {
        var arrow=new BoardObject{Type="arrow",SolidArrow=true,ArrowHeadLength=200,ArrowHeadWidth=24,StrokeWidth=80};
        ObjectHandles.SetEndpoints(arrow,new(10,30),new(110,30));
        var outline=ArrowGeometry.Outline(arrow);
        check(outline.Length==7&&outline[3].X==110&&outline.All(point=>point.X>=10&&point.X<=110),
            "Solid arrow is one continuous polygon and its head stays between the endpoints");
        check(outline[0].Y<outline[2].Y&&outline[6].Y>outline[4].Y,
            "Oversized shaft stays inside the head width");
        check(VectorMath.IsPointInObject(new(17,39),arrow,0)&&RectangularEraser.Intersects(arrow,15,37,19,40),
            "Solid shaft interior is available to hit and erase");
        check(WindowSelection.Matches(arrow,new(19,37),new(15,40)),"Crossing frame inside filled shaft selects it");
        var tip=ObjectHandles.Endpoint(arrow,1);
        arrow.ArrowHeadLength=22;
        ArrowGeometry.SetShaftLength(arrow,35);
        check(Math.Abs(ArrowGeometry.ShaftLength(arrow)-35)<.01&&ObjectHandles.Endpoint(arrow,1).X==tip.X,
            "Setting shaft length preserves the tip and independent head dimensions");

        var text=new BoardObject{Type="text",Text="ABC",FontSize=12,Width=120,Height=24,
            RichTextSpans=[new(){Text="A"},new(){Text="B",FontFamily="Consolas",FontSize=36},new(){Text="C"}]};
        TextStyles.GrowHeight(text);
        var doc=new HeiBanDocument{Objects=[arrow,text]};
        var restored=DocumentCodec.Decode(DocumentCodec.Encode(doc));
        check(restored.Objects[0].SolidArrow==true&&restored.Objects[1].RichTextSpans?[1].FontSize==36&&text.Height>=48,
            "Arrow and mixed font values survive a document round trip");
        var svg=BoardExporter.Svg(restored,restored.Objects,new(0,0,200,160));
        check(svg.Contains("<polygon points=")&&svg.Contains("font-size:36px")&&svg.Contains("Consolas"),
            "SVG keeps solid arrow and selected font size and family");
    }
}
