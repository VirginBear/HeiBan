using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;
public static class PdfDocumentAttachment
{
    // Add a valid incremental stream object rather than placing raw JSON after %%EOF.
    // The exact Mac marker/base64 payload remains discoverable inside the stream.
    public static byte[] Append(byte[] pdf,HeiBanDocument document)
    {
        var source=Encoding.Latin1.GetString(pdf);
        if(!source.StartsWith("%PDF-",StringComparison.Ordinal))throw new InvalidDataException("無效的 PDF 文件。");
        var xrefs=Regex.Matches(source,@"startxref\s+(\d+)\s+%%EOF");var trailers=Regex.Matches(source,@"trailer\s*<<(.*?)>>",RegexOptions.Singleline);
        if(xrefs.Count==0||trailers.Count==0)throw new InvalidDataException("不支援的 PDF 交叉索引格式。");
        var trailer=trailers[^1].Groups[1].Value;
        var size=Regex.Match(trailer,@"/Size\s+(\d+)");var root=Regex.Match(trailer,@"/Root\s+(\d+\s+\d+\s+R)");var info=Regex.Match(trailer,@"/Info\s+(\d+\s+\d+\s+R)");
        if(!size.Success||!root.Success)throw new InvalidDataException("PDF 缺少根物件。");
        var id=int.Parse(size.Groups[1].Value,CultureInfo.InvariantCulture);var previous=xrefs[^1].Groups[1].Value;
        var payload="%HeiBanDocumentJSON-START%\n"+Convert.ToBase64String(Encoding.UTF8.GetBytes(DocumentCodec.Encode(document)))+"\n%HeiBanDocumentJSON-END%\n";
        var objectOffset=pdf.LongLength+1;
        var entry=$"\n{id} 0 obj\n<< /Length {Encoding.ASCII.GetByteCount(payload)} >>\nstream\n{payload}endstream\nendobj\n";
        var xrefOffset=pdf.LongLength+Encoding.ASCII.GetByteCount(entry);
        var footer=$"xref\n0 1\n0000000000 65535 f \n{id} 1\n{objectOffset.ToString("0000000000",CultureInfo.InvariantCulture)} 00000 n \ntrailer\n<< /Size {id+1} /Root {root.Groups[1].Value}{(info.Success?" /Info "+info.Groups[1].Value:"")} /Prev {previous} >>\nstartxref\n{xrefOffset}\n%%EOF\n";
        return pdf.Concat(Encoding.ASCII.GetBytes(entry+footer)).ToArray();
    }
}
