$version     = '%build.version%.%build.id%-%build.date%'
$packageName = 'cabal-head'
$url         = '%deploy.url.32bit%'
$url64       = '%deploy.url.64bit%'

$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -UnzipLocation $packageFullName `
  -Url $url -ChecksumType sha256 -Checksum %deploy.sha256.32bit% `
  -Url64bit $url64 -ChecksumType64 sha256 -Checksum64 %deploy.sha256.64bit%
