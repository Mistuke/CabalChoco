$version     = '%build.version%-B%build.date%'
$packageName = 'cabal-head'
$url         = '%deploy.url.32bit%'
$url64       = '%deploy.url.64bit%'

$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)
$is64 = (Get-OSArchitectureWidth 64)  -and $env:chocolateyForceX86 -ne 'true'

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -UnzipLocation $packageFullName `
  -Url $url -ChecksumType sha256 -Checksum %deploy.sha256.32bit% `
  -Url64bit $url64 -ChecksumType64 sha256 -Checksum64 %deploy.sha256.64bit%

$cabal = Join-Path $packageFullName "cabal.exe"

# Simplified version of Install-ChocolateyPath that prepends instead of
# Appends to a path.  We use this in certain cases when we need to Override an
# existing path entry.  Such as on AppVeyor which adds both cygwin and msys2
# on PATH.
function Install-AppVeyorPath {
param(
  [parameter(Mandatory=$true, Position=0)][string] $pathToInstall
)

  Write-FunctionCallLogMessage -Invocation $MyInvocation -Parameters $PSBoundParameters
  ## Called from chocolateysetup.psm1 - wrap any Write-Host in try/catch

  $originalPathToInstall = $pathToInstall
  $pathType = [System.EnvironmentVariableTarget]::Machine

  #get the PATH variable
  Update-SessionEnvironment
  $envPath = $env:PATH
  if (!$envPath.ToLower().Contains($pathToInstall.ToLower()))
  {
    try {
      Write-Host "PATH environment variable does not have $pathToInstall in it. Adding..."
    } catch {
      Write-Verbose "PATH environment variable does not have $pathToInstall in it. Adding..."
    }

    $actualPath = Get-EnvironmentVariable -Name 'Path' -Scope $pathType -PreserveVariables

    $statementTerminator = ";"
    if (!$pathToInstall.EndsWith($statementTerminator)) {$pathToInstall = $pathToInstall + $statementTerminator}
    $actualPath = $pathToInstall + $actualPath

    Set-EnvironmentVariable -Name 'Path' -Value $actualPath -Scope $pathType

    #add it to the local path as well so users will be off and running
    $envPSPath = $env:PATH
    $env:Path = $pathToInstall + $envPSPath
  }
}

function Find-Entry {
    param( [string] $app )
    Get-Command -ErrorAction SilentlyContinue $app `
      | Select-Object -first 1 `
      | ForEach-Object { Split-Path $_.Path -Parent }
}

Function Execute-Command {
  param( [string] $commandTitle
       , [string] $commandPath
       , [string] $commandArguments
       )
  Try {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $pinfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $pinfo.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    [pscustomobject]@{
        commandTitle = $commandTitle
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode
    }
    $p.WaitForExit()
  }
  Catch {
     exit
  }
}

function Detect-GHC-Versions {
  return Get-ChildItem "C:\ghc\ghc-*\bin" -ErrorAction SilentlyContinue `
    | Sort-Object CreationTime -Descending `
    | ForEach-Object { $_.ToString() }
}

function Find-MSYS2 {
  param()

  # See if the user has msys2 already installed.
  $msys2 = Find-Entry "msys2_shell.cmd"
  if (($null -eq $msys2) -or ($msys2 -eq "")) {
    $msys2 = Find-Entry "mingw*_shell.bat"
  }

  $dir_name = if ($is64) { 'msys64' } else { 'msys32' }
  # Detect AppVeyor installs
  if (($null -ne $Env:APPVEYOR) -and ("" -ne $Env:APPVEYOR)) {
    Write-Host "AppVeyor detected. Using AppVeyor default paths."
    $msys2 = Join-Path $Env:SystemDrive $dir_name
  }

  # Check for standalone msys2 installs
  if (($null -eq $msys2) -or ($msys2 -eq "")) {
    $tmp = Join-Path $Env:SystemDrive $dir_name
    if (Test-Path $tmp -PathType Container) {
      Write-Information "Standalone msys2 detected. Using default paths."
      $msys2 = $tmp
    }
  }

  if (($null -eq $msys2) -or ($msys2 -eq "")) {
    # msys2 was not found already installed, assume user will install
    # it in the default directory, so create the expected default msys2
    # installation path.
    $msys2    = "{0}\{1}" -f (Get-ToolsLocation), $dir_name
  }

  Write-Debug "Msys2 directory: ${msys2}"
  return $msys2
}

function ReadCabal-Config {
  param( [string] $key )

  $prog = "$cabal"
  $cmd  = "user-config diff -a ${key}:"

  $proc = Execute-Command "Reading cabal config key '${key}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    Write-Error $proc.stdout
    Write-Error $proc.stderr
    throw ("Could not read cabal configuration key '${key}'.")
  }

  $option = [System.StringSplitOptions]::RemoveEmptyEntries
  $procout = $proc.stdout.Split([Environment]::NewLine) | Select-String "- ${key}" | Select-Object -First 1
  if (!$procout) {
    Write-Debug "No Cabal config for ${key}"
    return {@()}.Invoke()
  } else {
    $value = $procout.ToString().Split(@(':'), 2, $option)[1].ToString()
    $value = $value.Split([Environment]::NewLine)[0].Trim()
    Write-Debug "Read Cabal config ${key}: ${value}"
    return {$value.Split(@(';'), $option)}.Invoke()
  }
}

function UpdateCabal-Config {
  param( [string] $key
       , [string[]] $values
       )

  if ((!$values) -or ($values.Count -eq 0)) {
    $values = ""
  }
  $prog = "$cabal"
  $value = [String]::Join(";", $values)
  $cmd  = "user-config update -a `"${key}: $value`""

  $proc = Execute-Command "Update cabal config key '${key}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    Write-Error $proc.stdout
    Write-Error $proc.stderr
    throw ("Could not update cabal configuration key '${key}'.")
  }

  Write-Debug "Wrote Cabal config ${key}: ${value}"
}

function Configure-Cabal {
  param()

  $ErrorActionPreference = 'Stop'
  $msys2_path   = Find-MSYS2
  $prog_path    = ReadCabal-Config "extra-prog-path"
  $lib_dirs     = ReadCabal-Config "extra-lib-dirs"
  $include_dirs = ReadCabal-Config "extra-include-dirs"

  $native_path = if ($is64) { 'mingw64' } else { 'mingw32' }
  $native_path = Join-Path $msys2_path $native_path

  # Build new binary paths
  $native_bin     = Join-Path $native_path "bin"
  $new_prog_paths = @()
  $new_prog_paths += Join-Path (Join-Path $msys2_path "usr") "bin"
  $new_prog_paths += $native_bin
  $new_prog_paths += $prog_path
  $new_prog_paths = $new_prog_paths | Select-Object -Unique

  # Build new library paths
  $new_lib_dirs = @(Join-Path $native_path "lib")
  $new_lib_dirs += $lib_dirs
  $new_lib_dirs = $new_lib_dirs | Select-Object -Unique

  # Build new include paths
  $new_include_dirs = @(Join-Path $native_path "include")
  $new_include_dirs += $include_dirs
  $new_include_dirs = $new_include_dirs | Select-Object -Unique

  UpdateCabal-Config "extra-prog-path"    $new_prog_paths
  UpdateCabal-Config "extra-lib-dirs"     $new_lib_dirs
  UpdateCabal-Config "extra-include-dirs" $new_include_dirs

  Write-Host "Updated cabal configuration."

  Install-ChocolateyPath (Join-Path (Join-Path "$Env:APPDATA" "cabal") "bin")

  if (($null -ne $Env:APPVEYOR) -and ("" -ne $Env:APPVEYOR)) {
    Write-Host "Configuring AppVeyor PATH."
    # We need to fix up some paths for AppVeyor
    $ghcpaths = Detect-GHC-Versions
    ForEach ($path in $ghcpaths) { Install-ChocolateyPath $path }

    # I'm not a fan of doing this, but we need auto-reconf available.
    Install-AppVeyorPath (Join-Path (Join-Path "${msys2_path}" "mingw64") "bin")
    Install-AppVeyorPath (Join-Path (Join-Path "${msys2_path}" "usr") "bin")
    # Override msys2 git with git for Windows
    Install-AppVeyorPath "$($env:SystemDrive)\Program Files\Git\cmd"
    Install-AppVeyorPath "$($env:SystemDrive)\Program Files\Git\mingw64\bin"
  }
}

function Find-Bash {
  param()
  $ErrorActionPreference = 'Stop'
  $msys2_path = Find-MSYS2
  $bin        = Join-Path (Join-Path $msys2_path "usr") "bin"
  $bash       = Join-Path $bin "bash.exe"
  return $bash
}

# Now execute cabal configuration updates
Configure-Cabal
$bash = Find-Bash
$prefix = if ($is64) { 'x86_64' } else { 'i686' }
Install-ChocolateyEnvironmentVariable "_MSYS2_BASH" "$bash"
Install-ChocolateyEnvironmentVariable "_MSYS2_PREFIX" "$prefix"
$psFile = Join-Path $(Split-Path -Parent $MyInvocation.MyCommand.Definition) "mingw64-pkg.ps1"
Install-ChocolateyPowershellCommand -PackageName '${packageName}.powershell' -PSFileFullPath $psFile
