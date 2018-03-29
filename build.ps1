param (
    [string]$specific = ""
)

$path = Split-Path $MyInvocation.MyCommand.Path -Parent
$bin  = Join-Path $path "bin"
Write-Host "$bin"
ls cabal*.nuspec -recurse -File | ForEach-Object {
            $dir = (Split-Path $_.FullName -Parent)
            if ($dir.Contains($specific) -or ($specific -eq "")) {
                Write-Host "Compiling $_"
                cd $dir
                choco pack
                mv *.nupkg -fo "$bin"
            }
        }

cd $path

Write-Host "Done."