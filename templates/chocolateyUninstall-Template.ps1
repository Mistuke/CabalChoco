try {
  #$installDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
  ### For BinRoot, use the following instead ###
  $binRoot         = Get-BinRoot
  $installDir      = Join-Path $binRoot "$packageName"
  $packageFullName = Join-Path $installDir ($packageName + '-' + $version)
  $binPackageDir   = Join-Path $packageFullName "bin"
  $zipPackage      = Join-Path $env:chocolateyPackageFolder (Join-Path tmp ($packageName + "Install"))
  
  # first uninstal the package
  UnInstall-ChocolateyZipPackage "$packageName" "$zipPackage"
  # then clean up the directory
  # just blast away everything since the folders are versioned, and if we got this far the package was installed by us
  rm -r -fo $packageFullName

  Write-Host "Removing `'$binPackageDir`' from the path and the current shell path"
  UnInstall-Path "$binPackageDir"
} catch {
  throw $_.Exception
}
