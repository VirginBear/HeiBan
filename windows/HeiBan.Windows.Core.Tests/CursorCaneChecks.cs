using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

static class CursorCaneChecks
{
    internal static void Run(Action<bool,string> check)
    {
        foreach(var style in new[]{false,true})foreach(var size in new[]{32,40,48,64,96,128})
        foreach(var tool in new[]{"pen","highlighter","paint","eraser","laser","curve","line","arrow","rect","circle","triangle","quadrilateral","diamond","pentagon","star"})
        {
            var a=ToolCursorGeometry.Anchor(tool,style);var l=ToolCursorGeometry.Layout(tool,style,size);
            if(ToolCursorGeometry.UsesCrosshairBadge(tool))check(l.X==(int)Math.Round(size/8d)&&l.Y==l.X,"Construction cursor keeps original cross hotspot");
            else check(Math.Abs(l.X-(l.Offset+a.X*l.Scale))<=.5&&Math.Abs(l.Y-(l.Offset+a.Y*l.Scale))<=.5,"Hotspot rounds within half a physical pixel");
            check(l.X>=0&&l.Y>=0&&l.X<size&&l.Y<size,"Hotspot inside bitmap at all DPI sizes");
            if(tool=="laser")check(l.X==size/2&&l.Y==size/2,"Laser center equals hotspot");
        }
        check(StraightStrokeRecognizer.HoldSeconds==.5,"Pen straightening hold is half a second");
        check(ToolbarPaging.Starts(new double[]{84,84,166,84,84},260,3).SequenceEqual(new[]{0,2,4}),"Variable width brush group gets measured page boundaries");
        check(ToolbarPaging.Starts(new double[]{166,84,84},100,3).SequenceEqual(new[]{0,1,2}),"Oversized indivisible group has a page of its own");
        check(ToolbarPaging.Starts(Array.Empty<double>(),100,3).SequenceEqual(new[]{0}),"Empty toolbar has stable first page");
        var cane=new CaneFeedback();
        cane.Strike(new(1000,1000),0,new(10,10));cane.Strike(new(2000,2000),.2,new(15,10));
        check(cane.CrackGrip is null,"Two hits do not crack");
        cane.Strike(new(3000,3000),.4,new(20,10));
        check(cane.CrackGrip?.X==3000,"Combo uses DIP distance independent of world zoom");
        check(cane.CrackOpacity(.4)==0&&cane.TakeImpactSound(.4)==2,"Effect waits for visible cane impact");
        check(cane.TakeImpactSound(.476)==3&&cane.TakeImpactSound(.5)==0,"Crack sound consumed once");
        cane.Move(new(5000,5000));check(cane.CrackGrip?.X==3000,"Moving held cane does not drag crack");
        check(cane.NeedsAnimation(1.4)&&!cane.NeedsAnimation(1.676),"Animation outlives swing and finishes");
        check(cane.CrackOpacity(1.676)==0,"Crack completely fades");
        cane.Clear();check(cane.Point is null&&cane.CrackGrip is null&&cane.TakeImpactSound(3)==0,"Cancel clears pending audio and crack");
        cane.Strike(new(0,0),0);cane.Strike(new(30,0),.1);cane.Strike(new(60,0),.2);
        check(cane.CrackGrip is null,"Chained wandering hits cannot count as one area");
        cane.Clear();cane.Strike(new(0,0),0);cane.Strike(new(0,0),.6);cane.Strike(new(0,0),1.21);
        check(cane.CrackGrip is null,"Slow third hit resets combo");
        cane.Clear();cane.Strike(new(0,0),0);cane.Strike(new(36,0),.6);cane.Strike(new(0,0),1.2);
        check(cane.CrackGrip is not null,"Exact timing/radius boundaries are inclusive");
        check(cane.TakeImpactSound(10)==0,"Stale sound never plays after stall");
        cane.Clear();cane.Strike(new(0,0),0);cane.Strike(new(0,0),.1);cane.Clear();cane.Strike(new(0,0),.2);
        check(cane.CrackGrip is null,"Tool switch resets sequence");
        check(CaneCrackGeometry.Segments.Count<=100,"Crack geometry bounded");
        check(CaneCrackGeometry.Segments.All(s=>Math.Sqrt(s.X1*s.X1+s.Y1*s.Y1)<=CaneCrackGeometry.Radius&&Math.Sqrt(s.X2*s.X2+s.Y2*s.Y2)<=CaneCrackGeometry.Radius),"Damage radius covers every crack segment");
        check(CaneCrackGeometry.DisplayScale==.62&&CaneCrackGeometry.ShardCount==18,"Smaller crack and bounded shard count");
        for(var i=0;i<CaneCrackGeometry.ShardCount;i++)for(var frame=0;frame<=120;frame++)
        {
            var p=CaneCrackGeometry.Particle(i,frame/100d);var bounds=CaneCrackGeometry.VisualBounds;
            check(p.Opacity is >=0 and <=1&&p.X-p.Size>=bounds.Left&&p.X+p.Size<=bounds.Right&&p.Y-p.Size>=bounds.Top&&p.Y+p.Size<=bounds.Bottom,"All shard paths inside overlay damage");
        }
        check(Enumerable.Range(0,18).All(i=>CaneCrackGeometry.Particle(i,-.1).Opacity==0&&CaneCrackGeometry.Particle(i,1.2).Opacity==0),"Shards absent before impact and after expiry");
        cane.Clear();cane.Strike(new(0,0),0);cane.Strike(new(0,0),.01);cane.Strike(new(0,0),.02);
        check(cane.TakeImpactSound(.10)==1&&cane.TakeImpactSound(.10)==2&&cane.TakeImpactSound(.10)==3&&cane.TakeImpactSound(.10)==0,"Rapid triple-click retains all three sound variants in order");
        cane.Clear();for(var i=0;i<20;i++)cane.Strike(new(0,0),i*.001);
        var count=0;while(cane.TakeImpactSound(.2)>0)count++;
        check(count==6,"Audio queue has a fixed six-cue limit");
    }
}
