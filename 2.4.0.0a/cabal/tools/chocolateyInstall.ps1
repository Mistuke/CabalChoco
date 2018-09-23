$version      = '2.4.0.0'
$packageName = 'cabal'
$url         = 'https://downloads.haskell.org/cabal/cabal-install-2.4.0.0/cabal-install-2.4.0.0-i386-unknown-mingw32.zip'
$url64       = 'https://downloads.haskell.org/cabal/cabal-install-2.4.0.0/cabal-install-2.4.0.0-x86_64-unknown-mingw32.zip'

$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -UnzipLocation $packageFullName `
  -Url $url -ChecksumType sha256 -Checksum 5859dfd43ae18d493f404198b5bcf10581e280fd21a188994542e70e831a343f `
  -Url64bit $url64 -ChecksumType64 sha256 -Checksum64 4e1113f180956c39047adbe881e84f81e143d48262ffe5a67dc6c2c4a4bca2aa
