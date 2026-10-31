using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

// Isolated data/geometry checks only: no WinUI startup and no user's work library.
if(args.Length!=1)throw new ArgumentException("Supply an empty output directory inside the task scratch folder.");
var output=Path.GetFullPath(args[0]);
if(Directory.Exists(output))throw new IOException("Keep previous evidence; choose a new empty output directory.");
Directory.CreateDirectory(output);
var assertions=0;
void Check(bool value,string message){assertions++;if(!value)throw new InvalidOperationException(message);}
HeiBanDocument Fixture(int count)
{
    var doc=new HeiBanDocument{Board=new(){Id="optimization-fixture-"+count,Title="Performance practice "+count,CanvasMode="infinite",GridStyle="dot"},ExtraFields=new(){["futureDocument"]=JsonSerializer.SerializeToElement(new{keep=true})}};
    for(var i=0;i<count;i++)
    {
        var x=i%40*110d;var y=i/40*90d;
        var item=new BoardObject{Id="object-"+i,Type=i%5==0?"rect":"stroke",X=x,Y=y,Width=85,Height=40,StrokeWidth=4,StrokeColor="#39735A",Rotation=i%7==0?23:0,ZIndex=i,IsLocked=i%83==0,IsVisible=i%97!=0,ExtraFields=new(){["futureObject"]=JsonSerializer.SerializeToElement(i)}};
        if(item.Type=="stroke")item.SetCompletedInkPoints(new[]{new InkPoint(x,y),new InkPoint(x+45,y+30),new InkPoint(x+85,y+10)});
        doc.Objects.Add(item);
    }
    return doc;
}
string Signature(HeiBanDocument d)=>JsonSerializer.Serialize(d.Objects.Select(o=>new{o.Type,o.X,o.Y,o.Width,o.Height,o.Rotation,o.StrokeWidth,o.StrokeColor,o.IsLocked,o.IsVisible,o.PageId,Points=o.ParsedPoints.Select(p=>new{p.X,p.Y,p.Pressure}),o.ExtraFields}));
var baseDoc=Fixture(850);
// Include shared/other pages and a global object crossing many grid cells.
baseDoc.Board.CanvasMode="notebook";baseDoc.Board.ActivePageId="page-a";
for(var i=0;i<baseDoc.Objects.Count;i++)baseDoc.Objects[i].PageId=i%11==0?"page-b":i%3==0?null:"page-a";
baseDoc.Objects.Add(new(){Id="global",Type="line",X=0,Y=5000,Width=5000,Height=0,X1=0,Y1=5000,X2=5000,Y2=5000,Extension="both"});
var measurements=new List<object>();
foreach(var whole in new[]{false,true})foreach(var rectangle in new[]{false,true})
{
    var baseline=new EditorSession();baseline.Open(DocumentCodec.Clone(baseDoc));
    var indexed=new EditorSession();indexed.Open(DocumentCodec.Clone(baseDoc));indexed.EnableEraserCandidateIndex();
    var locked=Signature(new(){Objects=baseDoc.Objects.Where(o=>o.IsLocked==true).ToList()});
    for(var n=0;n<30;n++)
    {
        var at=new InkPoint(100+n*4,100+n*3);
        if(rectangle)
        {
            var contact=new EraserFootprint(new[]{new InkPoint(at.X-25,at.Y),new InkPoint(at.X,at.Y-25),new InkPoint(at.X+25,at.Y),new InkPoint(at.X,at.Y+25)});
            baseline.EraseFootprintChanged(contact,whole);indexed.EraseFootprintChanged(contact,whole);
        }
        else {baseline.EraseChanged(at,18,whole);indexed.EraseChanged(at,18,whole);}
    }
    Check(Signature(baseline.Document)==Signature(indexed.Document),"Indexed erase differs from the scan reference");
    Check(locked==Signature(new(){Objects=indexed.Document.Objects.Where(o=>o.IsLocked==true).ToList()}),"Locked object changed");
    Check(indexed.EraserCandidateVisits<baseline.EraserCandidateVisits/4,"Sparse scene candidate work did not fall sufficiently");
    measurements.Add(new{whole,rectangle,scanVisits=baseline.EraserCandidateVisits,indexedVisits=indexed.EraserCandidateVisits});
}
// Dense erase fallback must keep the reference order and avoid stale slots.
var denseBase=new EditorSession();denseBase.Open(Fixture(700));
var denseIndex=new EditorSession();denseIndex.Open(DocumentCodec.Clone(denseBase.Document));denseIndex.EnableEraserCandidateIndex();
var largeContact=EraserFootprint.Rectangle(-100,-100,6000,6000);
denseBase.EraseFootprintChanged(largeContact,true);denseIndex.EraseFootprintChanged(largeContact,true);
Check(Signature(denseBase.Document)==Signature(denseIndex.Document),"Dense erase fallback differs");
// Extended lines must remain global even when contact is outside stored bounds.
var rayBase=new EditorSession();rayBase.Open(DocumentCodec.Clone(baseDoc));
var rayIndex=new EditorSession();rayIndex.Open(DocumentCodec.Clone(baseDoc));rayIndex.EnableEraserCandidateIndex();
rayBase.EraseChanged(new(8000,5000),10,true);rayIndex.EraseChanged(new(8000,5000),10,true);
Check(Signature(rayBase.Document)==Signature(rayIndex.Document)&&rayIndex.Document.Objects.All(o=>o.Id!="global"),"Extended-line candidate lost");
var editor=new EditorSession();var original=Fixture(700);editor.Open(original);
var shape=new BoardObject{Id="added-rectangle",Type="rect",X=20,Y=20,Width=80,Height=50,ExtraFields=new(){["unknownShape"]=JsonSerializer.SerializeToElement("keep")}};
editor.AppendShape(shape);Check(editor.SelectedId==shape.Id,"Shape selection changed");
editor.Begin();shape.Width=120;editor.Commit();editor.Undo();Check(editor.Document.Objects.Single(o=>o.Id==shape.Id).Width==80,"Edit undo failed");
editor.Undo();Check(editor.Document.Objects.All(o=>o.Id!=shape.Id),"Added-object undo failed");
editor.Redo();Check(editor.Document.Objects.Single(o=>o.Id==shape.Id).ExtraFields!["unknownShape"].GetString()=="keep","Redo lost unknown fields");
editor.Redo();Check(editor.Document.Objects.Single(o=>o.Id==shape.Id).Width==120,"Mixed snapshot/delta redo failed");
Check(editor.Document.ExtraFields!["futureDocument"].GetProperty("keep").GetBoolean(),"Document unknown field lost");
var oldGeneration=editor.Generation;
try{editor.AppendShape(new(){Type="image"});throw new Exception("Invalid shape accepted");}catch(ArgumentException){}
Check(editor.Generation==oldGeneration,"Rejected append changed generation");
editor.AppendInk(new(){Type="stroke"});Check(editor.SelectedId is null,"Ink now selects itself");
Environment.SetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY",Path.Combine(output,"storage-data"));
var manager=new DocumentSessionManager();
var initialRevision=baseDoc.Board.Revision;
var owned=DocumentCodec.Clone(baseDoc);await manager.SaveOwnedSnapshotAsync(owned);
Check(owned.Board.Revision==initialRevision+1&&baseDoc.Board.Revision==initialRevision,"Owned save mutated live source");
var loaded=await manager.LoadAsync(owned.Board.Id);Check(Signature(loaded)==Signature(owned),"Saved geometry changed");
var copied=DocumentCodec.Clone(owned);await manager.SaveAsync(copied);Check(copied.Board.Revision==initialRevision+2,"Regular save revision contract changed");
var before=await File.ReadAllBytesAsync(manager.BoardPath(owned.Board.Id));
try{await manager.SaveOwnedSnapshotAsync(DocumentCodec.Clone(baseDoc));throw new Exception("Stale save accepted");}catch(IOException){}
var after=await File.ReadAllBytesAsync(manager.BoardPath(owned.Board.Id));
Check(before.AsSpan().SequenceEqual(after),"Conflict overwrote a newer board");
await RadialChecks.Run(Check,output);
foreach(var count in new[]{100,5000})await File.WriteAllTextAsync(Path.Combine(output,$"practice-{count}.heiban"),DocumentCodec.Encode(Fixture(count)));
await File.WriteAllTextAsync(Path.Combine(output,"results.json"),JsonSerializer.Serialize(new{assertions,passed=true,measurements,scope="Isolated Core checks; candidate visits are operation counts, not latency measurements; App/manual/device tests not run"},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"Passed {assertions} targeted data checks. Evidence: {output}");
