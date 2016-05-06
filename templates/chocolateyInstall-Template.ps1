try {
  #$installDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
  ### For BinRoot, use the following instead ###
  $binRoot         = Get-BinRoot
  $installDir      = Join-Path $binRoot "$packageName"
  $packageFullName = Join-Path $installDir ($packageName + '-' + $version)
  $binPackageDir   = Join-Path $packageFullName "bin"
  
  # if removing $url64, please remove from here
  # despite the name "Install-ChocolateyZipPackage" this also works with 7z archives
  Install-ChocolateyZipPackage "$packageName" "$url" (Join-Path $env:chocolateyPackageFolder tmp) "$url64"
  Get-ChocolateyUnzip -fileFullPath (Join-Path $env:chocolateyPackageFolder (Join-Path tmp ($packageName + "Install"))) -destination "$installDir"

  Write-Host "Adding `'$binPackageDir`' to the path and the current shell path"
  Install-ChocolateyPath "$binPackageDir"
  # Reload the session to update path
  Write-Host "$packageName $version has been installed. Before you can use it restart the console"
} catch {
  throw $_.Exception
}

