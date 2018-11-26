$version      = '2.4.1.0'
$packageName = 'cabal'
$url         = 'https://downloads.haskell.org/cabal/cabal-install-2.4.1.0/cabal-install-2.4.1.0-i386-unknown-mingw32.zip'
$url64       = 'https://downloads.haskell.org/cabal/cabal-install-2.4.1.0/cabal-install-2.4.1.0-x86_64-unknown-mingw32.zip'

$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -UnzipLocation $packageFullName `
  -Url $url -ChecksumType sha256 -Checksum 037821652aad2a4b2fd6acceae3efcebe6bc97d15993f649d4506005e11cb42c `
  -Url64bit $url64 -ChecksumType64 sha256 -Checksum64 95f233efedb1ebf0e6db015fa2f55c1ed00b9938d207ec63c066f706fb4b6373
