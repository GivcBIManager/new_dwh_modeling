param([Parameter(Mandatory = $true)][string]$Pbip, [switch]$Trace, [string]$Bin = "C:\Program Files\Microsoft Power BI Desktop\bin")
# Open a PBIP with Power BI Desktop's own project reader (Microsoft.PowerBI.Packaging.dll: PBIProjectShredder and its
# schema validation of .pbip, definition.pbir, .platform, definition.pbism, modelReference.json). Read only: reads the
# project's files, writes nothing, starts no Desktop. It does not render pages or check report/page/visual JSON (Desktop
# does that in its web view; pbir_check.validate_report checks those against the embedded schemas).
# Prints "opened; ..." lines, "issue: ..." for validation warnings, or "FAIL <exception>: <message>".
$bin = $Bin
$pkg = "$bin\Microsoft.PowerBI.Packaging.dll"
# Add-Type reports a ReflectionTypeLoadException for unrelated Desktop types; the types below still compile.
Add-Type -ErrorAction SilentlyContinue -ReferencedAssemblies @($pkg, "System.Runtime", "System.Threading.Tasks") -TypeDefinition @"
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using System.Collections.Generic;
using Microsoft.PowerBI.Packaging.Project;
using Microsoft.PowerBI.Packaging.Host;
public static class PbiResolver2 {
    public static void Install(string dir) {
        AppDomain.CurrentDomain.AssemblyResolve += (s, e) => {
            var n = new AssemblyName(e.Name).Name;
            if (n.EndsWith(".resources")) return null;
            foreach (var a in AppDomain.CurrentDomain.GetAssemblies()) if (a.GetName().Name == n) return a;
            var p = Path.Combine(dir, n + ".dll");
            return File.Exists(p) ? Assembly.LoadFrom(p) : null;
        };
    }
}
public class FsReader : IProjectFilesReader {
    public List<string> Log = new List<string>();
    string Full(string p) { return Path.GetFullPath(p); }
    public Task<bool> ExistsAsync(string p) { Log.Add("exists " + p); return Task.FromResult(File.Exists(Full(p)) || Directory.Exists(Full(p))); }
    public Task<Stream> GetAsync(string p) { Log.Add("get " + p); if (!File.Exists(Full(p))) { Log.Add("  MISSING"); return Task.FromResult((Stream)null); } return Task.FromResult((Stream)File.OpenRead(Full(p))); }
    public Task<string[]> GetAllPathsAsync(string p) {
        Log.Add("all " + p);
        var d = Full(p);
        if (!Directory.Exists(d)) return Task.FromResult(new string[0]);
        return Task.FromResult(Directory.GetFiles(d, "*", SearchOption.AllDirectories));
    }
}
public class Switches : IFeatureSwitches {
    public bool FilesWithMandatorySchema { get { return true; } }
    public bool SimplifiedDatasetRefConnectionString { get { return true; } }
    public bool ReadTmdl { get { return true; } }
    public bool ReadEnhancedReportFormat { get { return true; } }
    public bool VerifiedAnswers { get { return true; } }
    public bool NewCopilotFileFormat { get { return true; } }
}
public static class Opener {
    public static string Open(string pbip, FsReader r) {
        var ctx = new HostContext(HostApplication.Desktop, new Switches(), ex => true);
        var t = PBIProjectShredder.OpenProjectAsync(r, pbip, ctx);
        var res = t.GetAwaiter().GetResult();
        var proj = res.Item1;
        var errs = res.Item2;
        var lines = new List<string>();
        lines.Add("opened; report path=" + proj.ReportPath);
        var rep = proj.Report;
        lines.Add("report def ok=" + (rep.ReportDefinition != null) + " hasByPathDataset=" + rep.HasByPathDataset + " v2=" + rep.IsFileFormatV2);
        lines.Add("exploration parts=" + (rep.Exploration == null ? 0 : rep.Exploration.Count) + " customVisuals=" + (rep.CustomVisuals == null ? 0 : rep.CustomVisuals.Count) + " staticResources=" + (rep.StaticResources == null ? 0 : rep.StaticResources.Count));
        if (rep.CustomVisuals != null) foreach (var k in rep.CustomVisuals.Keys) lines.Add("  cv " + k);
        if (rep.StaticResources != null) foreach (var k in rep.StaticResources.Keys) lines.Add("  sr " + k);
        var ds = rep.Dataset;
        if (ds != null) {
            lines.Add("dataset: definition=" + (ds.Definition != null) + " modelReference=" + (ds.ModelReference != null) + " hasModelRefConn=" + ds.HasModelReferenceConnection + " tmdl=" + ds.IsInTmdlFormat);
            if (ds.ModelReference != null) lines.Add("  connectionString=" + ds.ModelReference.ConnectionString + " type=" + ds.ModelReference.ConnectionType);
        }
        foreach (var e in errs) lines.Add("issue: " + e.Message + " (" + e.FilePath + ")");
        return string.Join("\n", lines);
    }
}
"@
[PbiResolver2]::Install($bin)
$r = New-Object FsReader
try {
    [Opener]::Open($Pbip, $r)
} catch {
    $ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
    "FAIL " + $ex.GetType().FullName + ": " + $ex.Message
    try { foreach ($e in $ex.Errors) { "  error: " + $e.Message + " (" + $e.FilePath + ")" } } catch {}
}
if ($Trace) { $r.Log | Select-Object -First 80 }
