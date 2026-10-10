using System.Diagnostics;

namespace HeiBan.Windows.Diagnostics;

/// <summary>Opt-in synthetic diagnostics. Timings describe the measured action, not display or hardware latency.</summary>
public sealed record PerformanceMeasurement(double[] SamplesMs, double P50Ms, double P95Ms, double P99Ms,
    long AllocatedBytes, int[] Collections, int Samples, int OperationsPerSample)
{
    public static PerformanceMeasurement Measure(Action action, int samples = 40, int operations = 1)
    {
        if (samples < 1 || operations < 1) throw new ArgumentOutOfRangeException(nameof(samples));
        for (var i = 0; i < 5; i++) action();
        var timings = new double[samples];
        var collections = new[] { GC.CollectionCount(0), GC.CollectionCount(1), GC.CollectionCount(2) };
        var allocated = GC.GetAllocatedBytesForCurrentThread();
        for (var i = 0; i < samples; i++)
        {
            var start = Stopwatch.GetTimestamp();
            for (var j = 0; j < operations; j++) action();
            timings[i] = Stopwatch.GetElapsedTime(start).TotalMilliseconds / operations;
        }
        allocated = GC.GetAllocatedBytesForCurrentThread() - allocated;
        for (var i = 0; i < collections.Length; i++) collections[i] = GC.CollectionCount(i) - collections[i];
        var sorted = (double[])timings.Clone(); Array.Sort(sorted);
        double Percentile(double rank) => sorted[Math.Clamp((int)Math.Ceiling(rank * sorted.Length) - 1, 0, sorted.Length - 1)];
        return new(timings, Percentile(.5), Percentile(.95), Percentile(.99), allocated, collections, samples, operations);
    }
}
