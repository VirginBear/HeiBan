using HeiBan.Windows.Diagnostics;
using Microsoft.UI.Xaml;

namespace HeiBan.Windows;
public partial class MainWindow
{
    private DispatcherTimer? _inputLatencyHeartbeat;
    private long _lastInputHeartbeat;
    private void InitializeInputLatencyTrace()
    {
        if(!InputLatencyTrace.Enabled)return;
        _lastInputHeartbeat=System.Diagnostics.Stopwatch.GetTimestamp();
        _inputLatencyHeartbeat=new DispatcherTimer{Interval=TimeSpan.FromMilliseconds(16)};
        _inputLatencyHeartbeat.Tick+=(_,_)=>
        {
            var now=System.Diagnostics.Stopwatch.GetTimestamp();
            if(_workspaceOpen&&!_preparingClose)InputLatencyTrace.Record(InputStage.UiHeartbeat,(now-_lastInputHeartbeat)*1000d/System.Diagnostics.Stopwatch.Frequency);
            _lastInputHeartbeat=now;
        };
        _inputLatencyHeartbeat.Start();
    }
}
