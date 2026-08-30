# Build a cloud-init NoCloud seed ISO using built-in Windows IMAPI2 COM APIs.
# Usage: .\Build-CloudInitIso.ps1 -SourceDir <folder with user-data/meta-data> -OutputIso <path to .iso>

param(
    [Parameter(Mandatory=$true)][string]$SourceDir,
    [Parameter(Mandatory=$true)][string]$OutputIso
)

$ErrorActionPreference = "Stop"

if (Test-Path $OutputIso) {
    Remove-Item $OutputIso -Force
}

$outDir = Split-Path -Parent $OutputIso
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if (-not ("ISOFile" -as [type])) {
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.CompilerOptions = "/unsafe"
    Add-Type -CompilerParameters $cp -TypeDefinition @"
    using System;
    using System.IO;
    using System.Runtime.InteropServices.ComTypes;

    public class ISOFile
    {
        public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
        {
            byte[] buf = new byte[BlockSize];
            IStream Ptr = (IStream)Stream;
            FileStream o = new FileStream(Path, FileMode.Create);
            if (o != null)
            {
                while (TotalBlocks-- > 0)
                {
                    Ptr.Read(buf, BlockSize, IntPtr.Zero);
                    o.Write(buf, 0, BlockSize);
                }
                o.Flush();
                o.Close();
            }
        }
    }
"@
}

$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.VolumeName = "cidata"
$fsi.FileSystemsToCreate = 3  # Joliet + ISO9660

$root = $fsi.Root
Get-ChildItem -Path $SourceDir -File | ForEach-Object {
    $root.AddTree($_.FullName, $false)
}

$result = $fsi.CreateResultImage()
[ISOFile]::Create($OutputIso, $result.ImageStream, $result.BlockSize, $result.TotalBlocks)

Write-Host "Created ISO: $OutputIso"
