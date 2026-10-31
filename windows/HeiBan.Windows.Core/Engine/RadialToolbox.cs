using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

public sealed class RadialToolProfile
{
    public List<string> Slots {get;set;}=[];
    public string LastActive {get;set;}="pen";
    public string LastShape {get;set;}="line";
    [JsonExtensionData] public Dictionary<string,JsonElement>? ExtraFields {get;set;}
    public const int Count=8;
    public static bool IsShape(string key)=>key is "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
    public static bool IsTool(string key)=>IsShape(key)||key is "curve" or "select" or "pen" or "highlighter" or "paint" or "eraser" or "laser" or "cane" or "lasso" or "tape" or "text" or "sticky";
    public static bool Allowed(string key,bool screen)=>key is not("operate" or "extension")&&(ToolbarPreferences.AllDefaultTools.Contains(key)||IsShape(key))&&(!screen||IsShape(key)||ToolbarContentPolicy.IsAvailableOnScreen(key));
    public static string[] Defaults(bool screen)=>screen?["select","laser","cane","highlighter","eraser","line","brush","operate"]:["select","laser","cane","highlighter","eraser","line","rect","brush"];
    public void Normalize(bool screen)
    {
        var defaults=Defaults(screen);var source=Slots??[];var seen=new HashSet<string>();
        Slots=Enumerable.Range(0,Count).Select(i=>{if(screen&&i==7)return "operate";var key=i<source.Count?source[i]:defaults[i];return Allowed(key,screen)&&seen.Add(key)?key:"";}).ToList();
        if(!IsTool(LastActive))LastActive="pen";if(!IsShape(LastShape))LastShape="line";
    }
    public void Reset(bool screen){var current=LastActive;Slots=[..Defaults(screen)];LastActive="pen";LastShape="line";Reconcile(current);}
    public bool Assign(int index,string key,bool screen)
    {
        if(index<0||index>=Count||screen&&index==7||!Allowed(key,screen))return false;
        var duplicate=Slots.IndexOf(key);var previous=Slots[index];
        if(duplicate>=0&&duplicate!=index)Slots[duplicate]=previous;
        Slots[index]=key;return true;
    }
    public bool TrackTool(string previous,string current)
    {
        if(!IsTool(current))return false;
        var index=Slots.IndexOf(current);var changed=false;
        if(current!=previous&&index>=0){for(var i=0;i<Slots.Count;i++)if(i!=index&&Slots[i]==previous)Slots[i]="";Slots[index]=IsTool(previous)?previous:"pen";changed=true;}
        if(LastActive!=current){LastActive=current;changed=true;}if(IsShape(current))LastShape=current;
        return changed;
    }
    public void Reconcile(string current){if(LastActive!=current)TrackTool(LastActive,current);}
    public string? Take(int index,string current)
    {
        if(index<0||index>=Slots.Count||string.IsNullOrEmpty(Slots[index]))return null;
        var key=Slots[index];if(key=="operate")return key;
        var target=key=="shapes"?LastShape:key;
        if(IsTool(target)&&target!=current)
        {for(var i=0;i<Slots.Count;i++)if(i!=index&&(Slots[i]==current||Slots[i]==target))Slots[i]="";Slots[index]=current;LastActive=target;if(IsShape(target))LastShape=target;}
        return target;
    }
}

public sealed class RadialPreferencesStore
{
    public sealed class Preferences
    {
        public RadialToolProfile Canvas {get;set;}=new(){Slots=[..RadialToolProfile.Defaults(false)]};
        public RadialToolProfile Screen {get;set;}=new(){Slots=[..RadialToolProfile.Defaults(true)]};
        [JsonExtensionData] public Dictionary<string,JsonElement>? ExtraFields {get;set;}
    }
    private bool _preserveUnreadable;
    private readonly string _path;private readonly SemaphoreSlim _gate=new(1,1);
    public Preferences Value {get;private set;}=new();
    public string? LoadError {get;private set;}
    public RadialPreferencesStore(string directory)
    {
        _path=Path.Combine(directory,"Settings","radial.json");
        try{if(File.Exists(_path))Value=JsonSerializer.Deserialize<Preferences>(File.ReadAllText(_path),DocumentCodec.Options)??new();}
        catch(Exception e) when(e is IOException or UnauthorizedAccessException or JsonException){LoadError=e.Message;_preserveUnreadable=true;}
        Value.Canvas??=new();Value.Screen??=new();Value.Canvas.Normalize(false);Value.Screen.Normalize(true);
    }
    public async Task SaveAsync()
    {
        Value.Canvas.Normalize(false);Value.Screen.Normalize(true);
        var snapshot=JsonSerializer.Serialize(Value,DocumentCodec.Options);
        await _gate.WaitAsync();try{if(_preserveUnreadable&&File.Exists(_path)){File.Copy(_path,_path+".unreadable-"+Guid.NewGuid().ToString("N"));_preserveUnreadable=false;}await DocumentSessionManager.WriteAtomicAsync(_path,snapshot);LoadError=null;}finally{_gate.Release();}
    }
}

public sealed class RadialGesture
{
    public const double Radius=146,DeadZone=32,HoldSeconds=.22;
    public bool PreviousWasWheel {get;private set;}
    public bool Holding {get;private set;}
    public bool Visible {get;private set;}
    public InkPoint Center {get;private set;}=new();
    public int Hover {get;private set;}=-1;
    private InkPoint _press=new();private double _started;private bool _moved;
    public void Press(InkPoint point,double now,double width,double height,double scale)
    {
        Cancel();PreviousWasWheel=false;Holding=true;_press=point;_started=now;var margin=Radius*scale+8;
        Center=new(width<margin*2?width/2:Math.Clamp(point.X,margin,width-margin),height<margin*2?height/2:Math.Clamp(point.Y,margin,height-margin));
    }
    public void Poll(double now){if(Holding&&now-_started>=HoldSeconds)Visible=true;}
    public void Move(InkPoint point,double now,double scale)
    {
        if(!Holding)return;
        if(Math.Abs(point.X-_press.X)+Math.Abs(point.Y-_press.Y)>10*scale)_moved=true;
        Poll(now);if(_moved)Visible=true;Hover=Visible&&_moved?Hit(point,Center,scale):-1;
    }
    public (bool WasWheel,int Slot) Release(){var result=(Visible,Hover);Cancel();PreviousWasWheel=result.Visible;return result;}
    public void Cancel(){if(Holding&&Visible)PreviousWasWheel=true;Holding=Visible=false;Hover=-1;_moved=false;}
    public static int Hit(InkPoint point,InkPoint center,double scale)
    {
        var dx=(point.X-center.X)/scale;var dy=(point.Y-center.Y)/scale;
        if(dx*dx+dy*dy<DeadZone*DeadZone)return -1;
        var angle=Math.Atan2(dy,dx)+Math.PI/2+Math.PI/8;
        if(angle<0)angle+=Math.PI*2;return (int)(angle/(Math.PI*2)*RadialToolProfile.Count)%RadialToolProfile.Count;
    }
    public static InkPoint SlotCenter(int slot,InkPoint center,double scale)
    {var a=slot*Math.PI/4-Math.PI/2;return new(center.X+Math.Cos(a)*96*scale,center.Y+Math.Sin(a)*96*scale);}
}
