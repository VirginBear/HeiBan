using System.Collections;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>In-memory snapshots keep large immutable image/point strings out of the JSON round trip.</summary>
public static class DocumentSnapshot
{
    private static readonly Dictionary<Type,PropertyInfo[]> Fields=new[]
    {
        typeof(HeiBanDocument),typeof(BoardMetadata),typeof(BoardObject),typeof(BoardPin),
        typeof(BoardPage),typeof(InkPoint),typeof(TextSpan)
    }.ToDictionary(type=>type,type=>type.GetProperties().Where(p=>p.CanRead&&p.GetCustomAttribute<JsonIgnoreAttribute>() is null&&
        !(type==typeof(BoardObject)&&p.Name==nameof(BoardObject.Points))).ToArray());

    // JsonElement is immutable; copying the dictionary isolates replacement/removal without duplicating payloads.
    internal static Dictionary<string,JsonElement>? CopyFields(Dictionary<string,JsonElement>? value)=>value is null?null:new(value);
    public static bool Same(HeiBanDocument left,HeiBanDocument right)=>EqualValue(left,right);
    private static bool EqualValue(object? left,object? right)
    {
        if(ReferenceEquals(left,right))return true;
        if(left is null||right is null||left.GetType()!=right.GetType())return false;
        if(left is string||left.GetType().IsPrimitive||left.GetType().IsEnum)return left.Equals(right);
        if(left is JsonElement a&&right is JsonElement b)return a.Equals(b)||a.GetRawText()==b.GetRawText();
        if(left is BoardObject ink&&right is BoardObject otherInk)
        {
            // Points is a lazy serialization boundary; comparing transactions
            // must not force the editor's entire ink history to encode first.
            if(ink.HasStoredPoints!=otherInk.HasStoredPoints)return false;
            var samePoints=ink.EncodedPoints is { } encoded&&otherInk.EncodedPoints is { } otherEncoded
                ?encoded==otherEncoded:EqualValue(ink.ParsedPoints,otherInk.ParsedPoints);
            return samePoints&&Fields[typeof(BoardObject)].All(p=>EqualValue(p.GetValue(ink),p.GetValue(otherInk)));
        }
        if(left is IDictionary dictionary&&right is IDictionary other)
        {
            if(dictionary.Count!=other.Count)return false;
            foreach(DictionaryEntry entry in dictionary)if(!other.Contains(entry.Key)||!EqualValue(entry.Value,other[entry.Key]))return false;
            return true;
        }
        if(left is IList list&&right is IList next)
        {
            if(list.Count!=next.Count)return false;
            for(var i=0;i<list.Count;i++)if(!EqualValue(list[i],next[i]))return false;
            return true;
        }
        return Fields.TryGetValue(left.GetType(),out var properties)
            ?properties.All(p=>EqualValue(p.GetValue(left),p.GetValue(right))):left.Equals(right);
    }

    // Conservative per-snapshot accounting preserves the old 32 MB history limit; shared strings may be counted again.
    public static long EstimatedBytes(HeiBanDocument document)=>Estimate(document);
    internal static long EstimatedBytes(BoardObject item)=>Estimate(item);
    private static long Estimate(object root)
    {
        var seen=new HashSet<object>(ReferenceEqualityComparer.Instance);
        long Count(object? value)
        {
            if(value is null||!seen.Add(value))return 0;
            if(value is string text)return 24+text.Length*2L;
            if(value is JsonElement element)return 24+element.GetRawText().Length*2L;
            if(value is IDictionary map){long size=64;foreach(DictionaryEntry e in map)size+=32+Count(e.Key)+Count(e.Value);return size;}
            if(value is IList list){long size=32+list.Count*8L;foreach(var item in list)size+=Count(item);return size;}
            if(!Fields.TryGetValue(value.GetType(),out var properties))return 16;
            return 64+(value is BoardObject ink?ink.EstimatedPointBytes:0)+properties.Sum(p=>Count(p.GetValue(value)));
        }
        return Count(root);
    }
}
