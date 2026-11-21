using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

internal static class TextPasteAndAppearanceChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var style=new BoardObject{FontSize=24,FontFamily="Consolas",StrokeColor="#123456",Opacity=.75,
            ExtraFields=new(){["futureText"]=JsonSerializer.SerializeToElement(true)}};
        var pasted=TextStyles.CreatePastedText("中文\r\nA 😀\rB",style,new(320,240),640)!;
        check(pasted.Type=="text"&&pasted.Text=="中文\nA 😀\nB","External text paste preserves Unicode and normalizes line endings");
        check(style.Text is null&&pasted.Id!=style.Id,"Pasting does not mutate its style template");
        check(pasted.Width<=640&&pasted.FontSize==24&&pasted.StrokeColor=="#123456","Pasted text uses current style and a bounded initial width");
        check(TextStyles.CreatePastedText("  ",style,new(0,0),640) is null,"Whitespace-only paste creates no empty object");
        check(pasted.ExtraFields!["futureText"].GetBoolean(),"Pasted text template extension data survives");
        pasted.TextBorderColor="#FF0000";
        pasted.TextBorderWidth=3;
        pasted.TextBorderStyle="dashed";
        pasted.FillColor="#FFFFAA";
        pasted.Align="justify";
        var session=new EditorSession();
        session.Open(new());
        session.Begin();
        session.Add(pasted);
        session.Commit();
        var document=DocumentCodec.Decode(DocumentCodec.Encode(session.Document));
        var loaded=document.Objects.Single();
        check(loaded.TextBorderColor=="#FF0000"&&loaded.TextBorderWidth==3&&loaded.TextBorderStyle=="dashed","Text border round trip");
        check(loaded.Align=="justify"&&loaded.FillColor=="#FFFFAA","Text fill and justified alignment round trip");
        var svg=BoardExporter.Svg(document,document.Objects,new(0,0,640,480));
        check(svg.Contains("text-align:justify")&&svg.Contains("stroke=\"#FF0000\" stroke-width=\"3\""),"SVG retains alignment and separate text border color");
        check(svg.Contains("stroke-dasharray=\"6 4\""),"SVG retains text border dashes");
        session.Undo();
        check(session.Document.Objects.Count==0,"Pasted text is one undo transaction");
        session.Redo();
        check(session.Selected is null&&session.Document.Objects.Single().TextBorderWidth==3,"Redo retains text appearance");
        var legacy=DocumentCodec.Encode(new(){Objects=[new(){Type="text",Text="legacy"}]});
        check(!legacy.Contains("textBorder"),"Old text needs no border extension fields");
        loaded.TextDirection="vertical-rl";loaded.TextVerticalAlignment="bottom";
        var vertical=DocumentCodec.Decode(DocumentCodec.Encode(document)).Objects.Single();
        check(vertical.TextDirection=="vertical-rl"&&vertical.TextVerticalAlignment=="bottom","Text direction and block alignment round trip");
        var height=vertical.Height;TextStyles.GrowHeight(vertical);
        check(vertical.Height==height,"Vertical columns do not use horizontal automatic height growth");
        var verticalSvg=BoardExporter.Svg(new(){Objects=[vertical]},[vertical],new(0,0,640,480));
        check(verticalSvg.Contains("writing-mode:vertical-rl")&&verticalSvg.Contains("vertical-align:bottom"),"SVG retains writing direction and block alignment");
    }
}
