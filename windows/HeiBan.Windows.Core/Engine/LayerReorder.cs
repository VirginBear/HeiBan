namespace HeiBan.Windows.Engine;

public static class LayerReorder
{
    // One release produces one undo transaction. Normalize only after an actual order change;
    // all objects, including hidden/off-page objects, retain their relative order.
    public static bool Move(EditorSession session,string sourceId,string targetId,bool after)
    {
        var order=session.Document.Objects.OrderByDescending(o=>o.ZIndex).ToList();
        var source=order.FirstOrDefault(o=>o.Id==sourceId);var target=order.FirstOrDefault(o=>o.Id==targetId);
        if(source is null||target is null||source==target||source.IsLocked==true)return false;
        var previous=order.Select(o=>o.Id).ToArray();order.Remove(source);order.Insert(order.IndexOf(target)+(after?1:0),source);
        if(previous.SequenceEqual(order.Select(o=>o.Id)))return false;
        session.Begin();for(var i=0;i<order.Count;i++)order[i].ZIndex=order.Count-i;session.Commit();return true;
    }
}
