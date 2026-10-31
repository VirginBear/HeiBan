using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
internal static class RadialChecks
{
    internal static async Task Run(Action<bool,string> check,string directory)
    {
        var canvas=new RadialToolProfile();canvas.Normalize(false);canvas.Reconcile("select");
        var screen=new RadialToolProfile();screen.Normalize(true);
        check(canvas.Slots.Count==8&&screen.Slots.Count==8&&canvas.Slots.Contains("pen")&&!canvas.Slots.Contains("operate")&&screen.Slots[7]=="operate","Host presets/startup reconciliation");
        check(!screen.Assign(7,"pen",true)&&screen.Slots[7]=="operate","Fixed operation wedge overwritten");
        var cane=canvas.Slots.IndexOf("cane");var chosen=canvas.Take(cane,"laser");
        check(chosen=="cane"&&canvas.Slots[cane]=="laser"&&!canvas.Slots.Contains("cane")&&canvas.Slots.Count(k=>k=="laser")==1,"Laser->cane toolbox exchange");
        check(canvas.Take(cane,"cane")=="laser"&&canvas.Slots[cane]=="cane","Return exchange lost previous tool");
        var original=canvas.Slots.ToArray();var a=0;var b=4;canvas.Assign(a,original[b],false);
        check(canvas.Slots[a]==original[b]&&canvas.Slots[b]==original[a],"Dragging an existing tool must exchange positions");
        var before=string.Join(",",screen.Slots);
        check(!screen.Assign(1,"pins",true)&&!screen.Assign(1,"calculator",true)&&!screen.Assign(1,"arbitrary.exe",true)&&!screen.Assign(-1,"pen",true)&&before==string.Join(",",screen.Slots),"Unsupported drag modified screen profile");
        check(!RadialToolProfile.Allowed("extension",false),"Deprecated toolbar action exposed");
        var brush=screen.Slots.IndexOf("brush");before=string.Join(",",screen.Slots);
        check(screen.Take(brush,"laser")=="brush"&&before==string.Join(",",screen.Slots),"Settings command incorrectly exchanges held tool");
        check(screen.Take(7,"pen")=="operate"&&screen.Slots[7]=="operate"&&screen.Take(-1,"pen") is null,"Mode action/center cancel contract");
        canvas=new(){Slots=["shapes","line","laser","cane","eraser","brush","rect","highlighter"],LastShape="line"};
        check(canvas.Take(0,"laser")=="line"&&canvas.Slots[0]=="laser"&&canvas.Slots.Count(k=>k=="laser")==1&&!canvas.Slots.Contains("line"),"Shape alias creates duplicates or replaces wrong wedge");
        canvas.TrackTool("line","cane");check(canvas.Slots[3]=="line"&&canvas.LastActive=="cane","External toolbar selection does not synchronize toolbox");
        canvas.LastShape="rect";canvas.TrackTool("cane","curve");check(canvas.LastShape=="rect","Curve incorrectly replaced the last geometric-shape shortcut");
        canvas.Reset(false);check(!canvas.Slots.Contains("curve")&&canvas.LastActive=="curve","Reset lost held-tool reconciliation");
        foreach(var scale in new[]{1d,1.5,2.5})
        {
            var center=new InkPoint(600,500);
            check(Enumerable.Range(0,8).All(i=>RadialGesture.Hit(RadialGesture.SlotCenter(i,center,scale),center,scale)==i),"Sector/DPI geometry mismatch");
            check(RadialGesture.Hit(new(center.X+31*scale,center.Y),center,scale)==-1,"Dead zone selects tool");
        }
        var gesture=new RadialGesture();gesture.Press(new(500,500),1,1600,900,1);gesture.Poll(1.1);var shortClick=gesture.Release();
        check(!shortClick.WasWheel&&shortClick.Slot==-1&&!gesture.Holding&&!gesture.PreviousWasWheel,"Short click consumed as wheel");
        gesture.Press(new(4,4),2,1600,900,1);gesture.Poll(2.23);var held=gesture.Release();
        check(held.WasWheel&&held.Slot==-1,"Clamped wheel selects a tool without deliberate movement");
        gesture.Press(new(500,500),3,1600,900,1);gesture.Move(new(500,400),3.01,1);var flick=gesture.Release();
        check(flick.WasWheel&&flick.Slot==0&&gesture.PreviousWasWheel,"Fast radial flick not recognized");
        gesture.Press(new(500,500),4,1600,900,1);gesture.Move(new(600,500),4.3,1);gesture.Cancel();var cancelled=gesture.Release();
        check(!cancelled.WasWheel&&cancelled.Slot==-1&&!gesture.Visible,"Escape/capture cancel applies stale choice");
        gesture.Press(new(500,500),5,1600,900,1);gesture.Poll(5.3);gesture.Cancel();check(gesture.PreviousWasWheel,"Cancelled wheel can trigger an unintended double-right mode switch");
        gesture.Press(new(500,500),6,1600,900,1);check(!gesture.PreviousWasWheel,"Next native press did not reset double-click sequence");gesture.Cancel();
        var store=new RadialPreferencesStore(Path.Combine(directory,"wheel-settings"));
        store.Value.ExtraFields=new(){["futureRoot"]=JsonSerializer.SerializeToElement(new{keep=true})};
        store.Value.Canvas.ExtraFields=new(){["futureProfile"]=JsonSerializer.SerializeToElement(7)};
        store.Value.Canvas.Assign(2,"rect",false);var canvasSlot=store.Value.Canvas.Slots[2];
        store.Value.Screen.Assign(2,"arrow",true);await store.SaveAsync();
        var restored=new RadialPreferencesStore(Path.Combine(directory,"wheel-settings"));
        check(restored.Value.Canvas.Slots[2]==canvasSlot&&restored.Value.Screen.Slots[2]=="arrow"&&restored.Value.Screen.Slots[7]=="operate","Independent configurations did not survive restart");
        check(restored.Value.ExtraFields!["futureRoot"].GetProperty("keep").GetBoolean()&&restored.Value.Canvas.ExtraFields!["futureProfile"].GetInt32()==7,"Unknown settings fields lost");
        var jobs=new List<Task>();for(var i=0;i<12;i++){store.Value.Canvas.LastShape=i%2==0?"circle":"arrow";jobs.Add(store.SaveAsync());}await Task.WhenAll(jobs);
        check(new RadialPreferencesStore(Path.Combine(directory,"wheel-settings")).Value.Canvas.LastShape=="arrow","Queued settings save overwrote latest change");
        var corrupt=Path.Combine(directory,"bad-wheel","Settings");Directory.CreateDirectory(corrupt);await File.WriteAllTextAsync(Path.Combine(corrupt,"radial.json"),"{broken");
        var damaged=new RadialPreferencesStore(Path.GetDirectoryName(corrupt)!);check(damaged.LoadError is not null,"Invalid JSON load not reported");await damaged.SaveAsync();
        check(Directory.GetFiles(corrupt,"radial.json.unreadable-*").Length==1&&await File.ReadAllTextAsync(Directory.GetFiles(corrupt,"radial.json.unreadable-*")[0])=="{broken","Unreadable settings were destroyed");
        // Survivor identity is stable across previews; worker fragments never leak mutable references.
        var source=new HeiBanDocument{Objects=[new(){Id="left",Type="rect",X=10,Y=10,Width=30,Height=20},new(){Id="right",Type="rect",X=3000,Y=2000,Width=30,Height=20}]};
        var worker=DocumentCodec.Clone(source);var publisher=new EraserPreviewPublisher();publisher.Seed(worker,source);
        worker.Objects.RemoveAt(0);var published=publisher.Publish(worker);
        check(!publisher.FullDamage&&publisher.Damage is { } region&&region.MaxX<100&&region.MaxY<100&&region.Contains(10,10),"Local erasure damaged unrelated 4K area");
        check(ReferenceEquals(published.Objects[0],source.Objects[1])&&!ReferenceEquals(published.Objects[0],worker.Objects[0]),"Initial preview clones or exposes worker survivors");
        var frozen=published;worker.Objects.Add(new(){Id="fragment",Type="stroke",X=20,Y=20,Width=10,Height=10});published=publisher.Publish(worker);
        check(frozen.Objects.Count==1&&published.Objects.Count==2&&!ReferenceEquals(published.Objects[1],worker.Objects[1]),"Later worker edits mutate previously published snapshots");
        worker.Objects.Clear();published=publisher.Publish(worker);
        check(published.Objects.Count==0&&publisher.Damage is { } removed&&removed.Contains(3000,2000),"Last object disappearance leaves stale pixels");
        source=new(){Objects=[new(){Id="infinite",Type="line",X=10,Y=10,Width=30,Height=20,Extension="both"}]};worker=DocumentCodec.Clone(source);publisher=new();publisher.Seed(worker,source);worker.Objects.Clear();publisher.Publish(worker);
        check(publisher.FullDamage,"Unbounded line erased without safe full redraw fallback");
        publisher=new();publisher.Publish(new());check(publisher.FullDamage,"Unseeded caller did not request full redraw");
    }
}
