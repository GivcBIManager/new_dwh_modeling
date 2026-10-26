param([Parameter(Mandatory = $true)][string]$Out, [string]$Bin = "C:\Program Files\Microsoft Power BI Desktop\bin")
# Copy the PBIR report-definition JSON schemas embedded in Power BI Desktop (Microsoft.PowerBI.ClientResources.dll)
# to $Out\<name>\<version>.schema.json. Read only: loads the assembly and reads its resources; changes nothing.
$ErrorActionPreference = 'Stop'
$dll = Join-Path $Bin "Microsoft.PowerBI.ClientResources.dll"
$a = [Reflection.Assembly]::LoadFrom($dll)
$n = 0
foreach ($name in $a.GetManifestResourceNames()) {
    if ($name -notmatch 'ReportDefinitionSchemas\\([^\\]+)\\([0-9.]+)\\') { continue }
    $dest = Join-Path $Out ($Matches[1] + "\" + $Matches[2] + ".schema.json")
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    $s = $a.GetManifestResourceStream($name)
    $fs = [IO.File]::Create($dest)
    $s.CopyTo($fs)
    $fs.Close()
    $s.Close()
    $n++
}
"extracted $n schemas"
