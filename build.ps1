$path = Split-Path $MyInvocation.MyCommand.Path -Parent
$bin  = Join-Path $path "bin"
Write-Host "$bin"
ls ghc*.nuspec -recurse -File | ForEach-Object { 
            $dir = (Split-Path $_.FullName -Parent)
            Write-Host "Compiling $_"
            cd $dir
            choco pack
            mv *.nupkg -fo "$bin"
        }
        
cd $path

Write-Host "Done."