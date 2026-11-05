namespace HeiBan.Windows.Engine;

/// <summary>Measured tool groups remain indivisible, including wider brush+palette groups.</summary>
public static class ToolbarPaging
{
    public static int[] Starts(IReadOnlyList<double> lengths,double available,double spacing)
    {
        var pages=new List<int>{0};double run=0;var count=0;
        for(var i=0;i<lengths.Count;i++)
        {
            var length=lengths[i];
            if(count>0&&run+spacing+length>available){pages.Add(i);run=0;count=0;}
            run+=length+(count++>0?spacing:0);
        }
        return pages.ToArray();
    }
}
