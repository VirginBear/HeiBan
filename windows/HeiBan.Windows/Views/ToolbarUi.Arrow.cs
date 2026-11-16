using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
using Microsoft.UI.Xaml.Controls;
using static HeiBan.Windows.Localization.Strings;

namespace HeiBan.Windows.Views;

internal static partial class ToolbarUi
{
    internal static void AddArrowControls(StackPanel panel, BoardObject arrow, double scale, Action<Action<BoardObject>> apply)
    {
        var shaftLength = new NumberBox
        {
            Header = T("箭尾長度"),
            Minimum = 1,
            Value = Math.Max(1, ArrowGeometry.ShaftLength(arrow) / scale),
            SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline
        };
        var headLength=BrushSlider(T("箭頭頭部長度"),1,Math.Max(128,(arrow.ArrowHeadLength??16)/scale),(arrow.ArrowHeadLength??16)/scale,1);
        var headWidth=BrushSlider(T("箭頭頭部寬度"),1,Math.Max(96,(arrow.ArrowHeadWidth??10)/scale),(arrow.ArrowHeadWidth??10)/scale,1);
        var advanced=new Expander
        {
            Header=T("進階箭頭尺寸"),
            Content=new StackPanel{Spacing=8,Children={shaftLength,headLength,headWidth}}
        };
        var syncing=false;
        void Sync()
        {
            syncing=true;
            shaftLength.Value=Math.Max(1,ArrowGeometry.ShaftLength(arrow)/scale);
            headLength.Maximum=Math.Max(128,(arrow.ArrowHeadLength??16)/scale);
            headWidth.Maximum=Math.Max(96,(arrow.ArrowHeadWidth??10)/scale);
            headLength.Value=(arrow.ArrowHeadLength??16)/scale;
            headWidth.Value=(arrow.ArrowHeadWidth??10)/scale;
            syncing=false;
        }
        shaftLength.ValueChanged+=(_,e)=>{if(!syncing&&double.IsFinite(e.NewValue))apply(item=>ArrowGeometry.SetShaftLength(item,e.NewValue*scale));};
        headLength.ValueChanged+=(_,e)=>{if(!syncing)apply(item=>item.ArrowHeadLength=e.NewValue*scale);};
        headWidth.ValueChanged+=(_,e)=>{if(!syncing)apply(item=>item.ArrowHeadWidth=e.NewValue*scale);};
        advanced.Expanding+=(_,_)=>Sync();
        var shaftWidth=BrushSlider(T("線條粗細（pt）"),.5,128,arrow.StrokeWidth/scale,.5);
        shaftWidth.ValueChanged+=(_,e)=>{apply(item=>ArrowGeometry.SetThickness(item,e.NewValue*scale));if(advanced.IsExpanded)Sync();};
        panel.Children.Add(shaftWidth);
        panel.Children.Add(advanced);
    }
}
