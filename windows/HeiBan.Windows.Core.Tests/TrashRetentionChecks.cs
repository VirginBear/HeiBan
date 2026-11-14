using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

static class TrashRetentionChecks
{
    private sealed class Clock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;
        public override DateTimeOffset GetUtcNow() => Now;
    }

    public static async Task Run(Action<bool, string> check)
    {
        var fixture = Directory.CreateTempSubdirectory("heiban-trash-");
        var previous = Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY");
        Environment.SetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY", fixture.FullName);
        try
        {
            var start = new DateTimeOffset(2026, 11, 14, 12, 0, 0, TimeSpan.Zero);
            var clock = new Clock(start);
            var store = new DocumentSessionManager(timeProvider: clock);
            var legacy = await SaveAndTrashAsync(store, "legacy");
            var current = await SaveAndTrashAsync(store, "current");
            var manuallyDeleted = await SaveAndTrashAsync(store, "manual");
            var restored = await SaveAndTrashAsync(store, "restore");
            var damaged = await SaveAndTrashAsync(store, "damaged");
            await File.WriteAllTextAsync(damaged, "unreadable board");
            var trashRoot = Path.Combine(fixture.FullName, "Trash");
            var legacyFolder = Path.GetDirectoryName(legacy)!;
            var renamed = Path.Combine(trashRoot, "20200101-120000-0000-" + Path.GetFileName(legacy)[..64]);
            Directory.Move(legacyFolder, renamed);

            clock.Now = start.AddDays(1);
            var entries = await store.RefreshTrashAsync();
            check(entries.Count == 4, "Upgrade keeps legacy and current trash entries");
            check(entries.Single(e => e.Board.Id == "legacy").ExpiresAt == start.AddDays(31), "Legacy entry gets a fresh 30 days");
            check(entries.Single(e => e.Board.Id == "current").ExpiresAt == start.AddDays(30), "New entry expires 30 days after trashing");

            var unrelated = Path.Combine(Path.GetDirectoryName(manuallyDeleted)!, "unrelated.txt");
            await File.WriteAllTextAsync(unrelated, "keep");
            await store.DeleteTrashEntryAsync(manuallyDeleted);
            check(File.Exists(unrelated) && !File.Exists(manuallyDeleted), "Manual deletion keeps unrelated files");
            check(!File.Exists(manuallyDeleted + ".bak"), "Manual deletion removes the work backup");
            check(Directory.GetFiles(Path.GetDirectoryName(manuallyDeleted)!).SequenceEqual([unrelated]), "Manual deletion removes metadata and thumbnail");
            await store.RestoreAsync(restored);
            check(File.Exists(store.BoardPath("restore")) && File.Exists(store.ThumbnailPath("restore")), "Restore returns the board and thumbnail");

            try
            {
                await store.DeleteTrashEntryAsync(store.BoardPath("restore"));
                check(false, "Live library path must be rejected");
            }
            catch (InvalidDataException)
            {
                check(File.Exists(store.BoardPath("restore")), "Permanent delete never reaches active works");
            }

            clock.Now = start.AddDays(30).AddTicks(-1);
            check((await store.RefreshTrashAsync()).Count == 2, "Unexpired works remain until their exact deadline");
            clock.Now = start.AddDays(30);
            var reopened = new DocumentSessionManager(timeProvider: clock);
            entries = await reopened.RefreshTrashAsync();
            check(entries.Single().Board.Id == "legacy", "Expiry removes current trash and preserves legacy grace on restart");
            check(!Directory.Exists(Path.GetDirectoryName(current)) && !Directory.Exists(Path.GetDirectoryName(restored)),
                "Expiry removes known files including old restore leftovers");
            clock.Now = start.AddDays(31);
            check((await reopened.RefreshTrashAsync()).Count == 0 && !Directory.Exists(renamed), "Legacy work expires after its full grace period");
            check(File.Exists(unrelated), "Automatic cleanup also keeps unrelated files");
            check(File.Exists(damaged) && File.Exists(damaged + ".bak"), "Automatic cleanup keeps unreadable works for recovery");
        }
        finally
        {
            Environment.SetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY", previous);
            fixture.Delete(recursive: true);
        }
    }

    private static async Task<string> SaveAndTrashAsync(DocumentSessionManager store, string id)
    {
        var work = new HeiBanDocument { Board = new BoardMetadata { Id = id } };
        await store.SaveAsync(work);
        await store.SaveAsync(work);
        await File.WriteAllTextAsync(store.ThumbnailPath(id), "synthetic thumbnail");
        await store.TrashAsync(id);
        return Directory.GetFiles(Path.Combine(store.DataDirectory, "Trash"), Path.GetFileName(store.BoardPath(id)),
            SearchOption.AllDirectories).Single();
    }
}
