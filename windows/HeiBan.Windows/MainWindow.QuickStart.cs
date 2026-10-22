using System.Text.Json;
using HeiBan.Windows.Engine;

namespace HeiBan.Windows;

public partial class MainWindow
{
    private async Task EnsureQuickStartAsync()
    {
        if(Environment.GetCommandLineArgs().Any(arg=>new[]{"--validation-output=","--performance-output=","--drawing-workflow-output=","--guide-view="}.Any(arg.StartsWith)))return;
        const string id="heiban-windows-quickstart-v1";
        var marker=Path.Combine(_storage.DataDirectory,"Settings","quickstart-v1.json");
        if(File.Exists(marker))return;
        // A stable board ID makes an interrupted first launch idempotent. The
        // marker prevents a deleted/trashed exercise from returning on each launch.
        FileStream guard;
        try{guard=new FileStream(marker+".lock",FileMode.OpenOrCreate,FileAccess.Write,FileShare.None);}
        catch(IOException){return;} // Another instance owns first-run initialization.
        using(guard)
        {
            if(File.Exists(marker))return;
            if(!File.Exists(_storage.BoardPath(id)))
            {
                var folder=Path.Combine(AppContext.BaseDirectory,"Assets","Guides");
                var asset=Path.Combine(folder,"QuickStart-"+Localization.Strings.Language+".heiban");
                if(!File.Exists(asset))asset=Path.Combine(folder,"QuickStart-zh-TW.heiban");
                var document=DocumentCodec.Decode(await File.ReadAllTextAsync(asset));
                var now=DateTime.UtcNow.ToString("o");document.Board.CreatedAt=document.Board.UpdatedAt=document.ExportedAt=now;
                await _storage.SaveAsync(document);
            }
            await DocumentSessionManager.WriteAtomicAsync(marker,JsonSerializer.Serialize(new{schema=1,boardId=id},DocumentCodec.Options));
        }
    }
}
