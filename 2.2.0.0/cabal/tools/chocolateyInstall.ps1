
if ($env:ChocolateyForceX86 -eq $true) {
    $invArch = "x64"
} else {
    $invArch = "x86"
}

# Would have loved to use $env:ChocolateyToolsLocation but
# that seems to only return C:\. Even after a call to Get-ToolsLocation
$invTools    = Join-Path $env:ChocolateyPackageFolder "tools"
$invToolsBin = Join-Path $invTools $invArch
Write-Host "Hiding shims for `'$invToolsBin`'."
$files = get-childitem $invToolsBin -include *.exe -recurse

foreach ($file in $files) {
    #generate an ignore file
    New-Item "$file.ignore" -type file -force | Out-Null
}