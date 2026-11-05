using HeiBan.Windows.Engine;
using System.Text.Json;

internal static class PalettePreferenceChecks
{
    internal static async Task Run(Action<bool,string> check)
    {
        var root=Path.Combine(Path.GetTempPath(),"HeiBan-PaletteChecks",Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        var store=new PalettePreferencesStore(root);var events=0;store.Changed+=()=>events++;
        check(store.Colors.SequenceEqual(PalettePreferencesStore.DefaultColors),"Palette defaults on missing file");
        check(!File.Exists(Path.Combine(root,"Settings","palette.json")),"Read missing palette never writes defaults");
        check(PalettePreferencesStore.Canonical("#aabbccff")=="#AABBCC","Opaque alpha deduplicates with RGB");
        foreach(var invalid in new[]{"#12345","#1234567","123456","#GG1234","#123456789","none"})
            check(PalettePreferencesStore.Canonical(invalid) is null,"Reject malformed palette color "+invalid);
        check(await store.AddAsync("#10203080"),"Append custom alpha color");
        check(!await store.AddAsync("#10203080")&&events==1,"Duplicate does not save or notify");
        check(new PalettePreferencesStore(root).Colors.Last()=="#10203080","Palette survives reopening");
        var writes=Enumerable.Range(0,16).Select(i=>store.AddAsync($"#F0{i:X2}12")).ToArray();await Task.WhenAll(writes);await store.FlushAsync();
        check(store.Colors.TakeLast(16).SequenceEqual(Enumerable.Range(0,16).Select(i=>$"#F0{i:X2}12")),"Queued writes retain latest ordered snapshot");
        foreach(var color in store.Colors.ToArray())await store.RemoveAsync(color);
        check(new PalettePreferencesStore(root).Colors.Count==0,"Explicit empty list survives reopening");
        await store.ResetAsync();check(store.Colors.SequenceEqual(PalettePreferencesStore.DefaultColors),"Explicit reset restores defaults");
        var first=store.Colors[0];var last=store.Colors[^1];var priorEvents=events;
        check(await store.MoveAsync(last,0),"Move last color to first");
        check(store.Colors[0]==last&&store.Colors[1]==first,"Moving preserves remaining order");
        check(new PalettePreferencesStore(root).Colors.SequenceEqual(store.Colors),"Reordered first six survive reopening");
        check(!await store.MoveAsync(last,0)&&!await store.MoveAsync("#010101",3)&&events==priorEvents+1,"No-op moves never save/notify");
        check(await store.MoveAsync(last,999)&&store.Colors[^1]==last,"Move clamps past last");
        check(await store.MoveAsync(last,-1)&&store.Colors[0]==last,"Move clamps before first");
        await Task.WhenAll(store.MoveByAsync(last,1),store.MoveByAsync(last,1));
        check(store.Colors[2]==last,"Rapid relative arrow moves accumulate inside write gate");
        var all=store.Colors.Order().ToArray();
        await Task.WhenAll(store.MoveAsync(last,3),store.AddAsync("#000001"),store.MoveAsync(first,0));await store.FlushAsync();
        check(store.Colors.Count==all.Length+1&&store.Colors.Where(c=>c!="#000001").Order().SequenceEqual(all),"Queued reorder/add preserves every color");
        var settings=Path.Combine(root,"Settings","palette.json");
        await File.WriteAllTextAsync(settings,"{\"schemaVersion\":1,\"colors\":[\"#abcdef\",\"#ABCDEFFF\"],\"future\":{\"keep\":[1,2]}}");
        store=new(root);check(store.Colors.SequenceEqual(new[]{"#ABCDEF"}),"Loaded colors normalize and deduplicate");
        await store.AddAsync("#010203");using(var json=JsonDocument.Parse(await File.ReadAllTextAsync(settings)))
            check(json.RootElement.GetProperty("future").GetProperty("keep").GetArrayLength()==2,"Unknown palette fields preserved");
        await store.MoveAsync("#010203",0);using(var json=JsonDocument.Parse(await File.ReadAllTextAsync(settings)))
            check(json.RootElement.GetProperty("future").GetProperty("keep").GetArrayLength()==2&&json.RootElement.GetProperty("colors")[0].GetString()=="#010203","Reorder preserves unknown fields");
        foreach(var bad in new[]{"{broken","{\"schemaVersion\":2,\"colors\":[]}","{\"schemaVersion\":1}","{\"colors\":[\"#1234567\"]}","[]"})
        {
            await File.WriteAllTextAsync(settings,bad);store=new(root);check(store.LoadFailed,"Invalid palette reported");
            var rejected=false;try{await store.AddAsync("#123456");}catch(InvalidOperationException){rejected=true;}
            check(rejected&&await File.ReadAllTextAsync(settings)==bad,"Invalid/future palette original not overwritten");
        }
        // A directory at the intended file path deterministically exercises a write failure without changing ACLs.
        var failureRoot=Path.Combine(root,"write-failure");Directory.CreateDirectory(Path.Combine(failureRoot,"Settings","palette.json"));
        store=new(failureRoot);var original=store.Colors.ToArray();var failed=false;
        try{await store.AddAsync("#010203");}catch(Exception e) when(e is IOException or UnauthorizedAccessException){failed=true;}
        check(failed&&store.Colors.SequenceEqual(original),"Failed save does not publish an unsaved palette");
        failed=false;try{await store.MoveAsync(original[^1],0);}catch(Exception e) when(e is IOException or UnauthorizedAccessException){failed=true;}
        check(failed&&store.Colors.SequenceEqual(original),"Failed reorder leaves published order untouched");
        var toolbar=new ToolbarPreferences{VisibleTools=["pen","rect"],HiddenTools=["laser","select"],CommonTools=["brush"],DefaultCommonRevision=1};
        toolbar.Normalize();check(toolbar.VisibleTools.Take(2).SequenceEqual(new[]{"select","laser"}),"Selection and laser normalize to fixed leading slots");
        check(toolbar.CommonTools.Contains("brush")&&toolbar.CommonTools.Contains("laser")&&!toolbar.HiddenTools.Contains("laser"),"Laser migration preserves custom favorites");
        toolbar.HideTool("laser");toolbar.Normalize();check(toolbar.VisibleTools.Count(t=>t=="laser")==1,"Pinned laser cannot hide or duplicate");
        // Leave only isolated test files for failure diagnosis; never touch application Data.
    }
}
