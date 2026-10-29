namespace HeiBan.Windows.Engine;

public enum LayerMove { Front, Up, Down, Back }

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

    public static bool MoveSelection(EditorSession session,LayerMove move)
    {
        if(session.HasTransaction)return false;
        var chosen=session.SelectedObjects.Where(o=>o.IsLocked!=true).Select(o=>o.Id).ToHashSet();
        if(chosen.Count==0)return false;
        var scope=session.PageObjects.Select(o=>o.Id).ToHashSet();
        var all=session.Document.Objects.OrderBy(o=>o.ZIndex).ToList();
        var page=all.Where(o=>scope.Contains(o.Id)).ToList();var before=page.Select(o=>o.Id).ToArray();
        if(move==LayerMove.Front)page=page.Where(o=>!chosen.Contains(o.Id)).Concat(page.Where(o=>chosen.Contains(o.Id))).ToList();
        else if(move==LayerMove.Back)page=page.Where(o=>chosen.Contains(o.Id)).Concat(page.Where(o=>!chosen.Contains(o.Id))).ToList();
        else if(move==LayerMove.Up)
        {
            for(var n=page.Count-2;n>=0;n--)if(chosen.Contains(page[n].Id)&&!chosen.Contains(page[n+1].Id))
                (page[n],page[n+1])=(page[n+1],page[n]);
        }
        else if(move==LayerMove.Down)
        {
            for(var n=0;n<page.Count-1;n++)if(!chosen.Contains(page[n].Id)&&chosen.Contains(page[n+1].Id))
                (page[n],page[n+1])=(page[n+1],page[n]);
        }
        else return false;
        if(before.SequenceEqual(page.Select(o=>o.Id)))return false;
        // Only current-page slots are replaced. Other pages retain their order;
        // selected blocks retain internal order; locked objects are not movable selections.
        var index=0;for(var n=0;n<all.Count;n++)if(scope.Contains(all[n].Id))all[n]=page[index++];
        session.Begin();for(var n=0;n<all.Count;n++)all[n].ZIndex=n;session.Commit();return true;
    }
}
