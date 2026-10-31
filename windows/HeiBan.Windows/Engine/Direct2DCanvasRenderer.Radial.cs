using System.Numerics;
using HeiBan.Windows.Models;
using HeiBan.Windows.Views;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Svg;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.Foundation;
using static HeiBan.Windows.Localization.Strings;
namespace HeiBan.Windows.Engine;
public sealed partial class Direct2DCanvasRenderer
{
    private readonly List<CanvasGeometry> _radialSectors=[];
    private readonly Dictionary<string,CanvasSvgDocument> _radialIcons=[];
    private readonly Dictionary<string,CanvasTextLayout> _radialLabels=[];
    private void ClearRadialResources()
    {
        foreach(var item in _radialSectors)item.Dispose();_radialSectors.Clear();
        foreach(var item in _radialIcons.Values)item.Dispose();_radialIcons.Clear();
        foreach(var item in _radialLabels.Values)item.Dispose();_radialLabels.Clear();
    }
    internal static string RadialLabel(string key)=>key=="operate"?T("操作"):key==""?"—":T(ToolbarPreferences.ToolNames.GetValueOrDefault(key,key switch{"line"=>"直線","arrow"=>"箭頭","rect"=>"矩形","circle"=>"圓形","triangle"=>"三角形","quadrilateral"=>"四邊形","diamond"=>"菱形","pentagon"=>"五邊形","star"=>"星形",_=>key}));
    internal void RenderRadialWheel(CanvasDrawingSession ds,RadialToolProfile profile,InkPoint center,int hover,double scale=1)
    {
        if(_radialSectors.Count==0)for(var i=0;i<RadialToolProfile.Count;i++)
        {
            using var path=new CanvasPathBuilder(ds);var a=i*Math.PI/4-Math.PI/2-Math.PI/8+.025;var b=a+Math.PI/4-.05;
            path.BeginFigure((float)Math.Cos(a),(float)Math.Sin(a));
            for(var j=1;j<=16;j++){var angle=a+(b-a)*j/16;path.AddLine((float)Math.Cos(angle),(float)Math.Sin(angle));}
            for(var j=16;j>=0;j--){var angle=a+(b-a)*j/16;path.AddLine((float)(Math.Cos(angle)*.27),(float)(Math.Sin(angle)*.27));}
            path.EndFigure(CanvasFigureLoop.Closed);_radialSectors.Add(CanvasGeometry.CreatePath(path));
        }
        var old=ds.Transform;var radius=(float)(RadialGesture.Radius*scale);
        ds.Transform=Matrix3x2.CreateScale(radius)*Matrix3x2.CreateTranslation((float)center.X,(float)center.Y)*old;
        for(var i=0;i<_radialSectors.Count;i++)
        {
            if(i==hover)ds.DrawGeometry(_radialSectors[i],HexToColor("#58B98B",.3f),9/radius);
            ds.FillGeometry(_radialSectors[i],HexToColor(i==hover?"#C5E8D7":"#F7FAF6",.97f));
            ds.DrawGeometry(_radialSectors[i],HexToColor(i==hover?"#39735A":"#BFCFC4"),(i==hover?2.5f:1)/radius);
        }
        ds.Transform=old;
        for(var i=0;i<profile.Slots.Count;i++)
        {
            var key=profile.Slots[i];var point=RadialGesture.SlotCenter(i,center,scale);var size=(float)((i==hover?30:25)*scale);
            var path=ToolIcons.CommandPath(key=="operate"?"select":key);var label=RadialLabel(key);
            if(path is not null)
            {
                if(!_radialIcons.TryGetValue(key,out var svg))_radialIcons[key]=svg=CanvasSvgDocument.LoadFromXml(ds,$"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 26 26'><path d='{path}' fill='none' stroke='#28543F' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'/></svg>");
                ds.DrawSvg(svg,new Size(size,size),new Vector2((float)point.X-size/2,(float)point.Y-size/2-5*(float)scale));
            }
            var labelKey=Language+":"+label;
            if(!_radialLabels.TryGetValue(labelKey,out var layout))
            {
                if(_radialLabels.Count>=96){foreach(var item in _radialLabels.Values)item.Dispose();_radialLabels.Clear();}
                using var format=new CanvasTextFormat{FontFamily="Segoe UI",FontSize=10,HorizontalAlignment=CanvasHorizontalAlignment.Center,WordWrapping=CanvasWordWrapping.NoWrap,TrimmingGranularity=CanvasTextTrimmingGranularity.Character};
                _radialLabels[labelKey]=layout=new CanvasTextLayout(ds,label,format,88,20);
            }
            ds.Transform=Matrix3x2.CreateScale((float)scale)*Matrix3x2.CreateTranslation((float)(point.X-44*scale),(float)(point.Y+12*scale))*old;
            ds.DrawTextLayout(layout,0,0,HexToColor("#28543F"));ds.Transform=old;
        }
        ds.FillCircle((float)center.X,(float)center.Y,(float)(25*scale),HexToColor("#EEF4EE",.96f));
        ds.DrawCircle((float)center.X,(float)center.Y,(float)(25*scale),HexToColor("#ABC3B0"));
    }
}
