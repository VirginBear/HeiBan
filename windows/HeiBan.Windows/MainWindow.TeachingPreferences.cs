using System.Text.Json;
using HeiBan.Windows.Engine;
namespace HeiBan.Windows;
public partial class MainWindow
{
    public sealed class TeachingSettings
    {
        public string LaserMode {get;set;}="shortTrail";
        public string LaserColor {get;set;}="#EF4444";
        public double LaserWidth {get;set;}=8;public double LaserDiameter {get;set;}=16;public double LaserFade {get;set;}=.8;
        public bool WhiteCore {get;set;}=true;
        public double RulerLengthPercent {get;set;}=90;
        public string InspectorDock {get;set;}="right";
        public Dictionary<string,ToolStyle> Styles {get;set;}=[];
    }
    private readonly SemaphoreSlim _teachingSaveGate=new(1,1);
    private readonly Microsoft.UI.Xaml.DispatcherTimer _teachingSaveTimer=new(){Interval=TimeSpan.FromMilliseconds(400)};
    private void QueueTeachingSettingsSave(){_teachingSaveTimer.Stop();_teachingSaveTimer.Start();}
    private static readonly JsonSerializerOptions TeachingJson=new(DocumentCodec.Options){IncludeFields=true};
    private string TeachingPath=>Path.Combine(_storage.DataDirectory,"Settings","teaching.json");
    private void LoadTeachingSettings()
    {
        try
        {
            if(!File.Exists(TeachingPath))return;var settings=JsonSerializer.Deserialize<TeachingSettings>(File.ReadAllText(TeachingPath),TeachingJson);if(settings is null)return;
            _laser.Mode=new[]{"point","shortTrail","line"}.Contains(settings.LaserMode)?settings.LaserMode:"shortTrail";
            _laser.Color=System.Text.RegularExpressions.Regex.IsMatch(settings.LaserColor,"^#[0-9a-fA-F]{6,8}$")?settings.LaserColor:"#EF4444";
            _laser.Width=FiniteClamp(settings.LaserWidth,1,32,8);_laser.PointDiameter=FiniteClamp(settings.LaserDiameter,4,64,16);_laser.FadeDuration=FiniteClamp(settings.LaserFade,.1,5,.8);_laser.WhiteCore=settings.WhiteCore;
            foreach(var pair in settings.Styles??[])
            {if(pair.Value is null)continue;pair.Value.Width=FiniteClamp(pair.Value.Width,.5,128,4);pair.Value.Opacity=FiniteClamp(pair.Value.Opacity,0,1,1);pair.Value.FontSize=FiniteClamp(pair.Value.FontSize,8,200,18);_toolStyles[pair.Key]=pair.Value;}
            _rulerLengthPercent=FiniteClamp(settings.RulerLengthPercent,20,150,90);
            SetInspectorDock(settings.InspectorDock);
            LoadActiveStyle();
        }
        catch(Exception e) when(e is IOException or JsonException or ArgumentException){StatusText.Text="教學工具偏好未載入："+e.Message;}
    }
    private static double FiniteClamp(double value,double min,double max,double fallback)=>double.IsFinite(value)?Math.Clamp(value,min,max):fallback;
    private async Task SaveTeachingSettingsAsync()
    {
        _teachingSaveTimer.Stop();
        var snapshot=JsonSerializer.Serialize(new TeachingSettings{LaserMode=_laser.Mode,LaserColor=_laser.Color,LaserWidth=_laser.Width,LaserDiameter=_laser.PointDiameter,LaserFade=_laser.FadeDuration,WhiteCore=_laser.WhiteCore,RulerLengthPercent=_rulerLengthPercent,InspectorDock=_inspectorDock,Styles=_toolStyles},TeachingJson);
        await _teachingSaveGate.WaitAsync();
        try{await Task.Run(()=>DocumentSessionManager.WriteAtomicAsync(TeachingPath,snapshot));}
        catch(Exception e){StatusText.Text="偏好保存失敗："+e.Message;}
        finally{_teachingSaveGate.Release();}
    }
}
