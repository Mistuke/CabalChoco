$version     = '%build.version%-B%build.date%'
$packageName = 'cabal-head'
$url         = '%deploy.url.32bit%'
$url64       = '%deploy.url.64bit%'

$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)
$is64 = (Get-OSArchitectureWidth 64)  -and $env:chocolateyForceX86 -ne 'true'

function Find-Entry {
    param( [string] $app )
    Get-Command -ErrorAction SilentlyContinue $app `
      | select -first 1 `
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

function Detect-GHC-Version {
  $proc = Execute-Command "Detect GHC Version" "ghc" "--version"

  if ($proc.ExitCode -ne 0) {
    throw ("Could detect GHC version.")
  }

  return $proc.stdout | ForEach-Object { $_.Trim().Split(' ') } | Select-Object -last 1
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
    Write-Hos "AppVeyor detected. Using AppVeyor default paths."
    # We need to fix up some paths for AppVeyor
    $ghcver = Detect-GHC-Version
    $ghcpath = "C:\\ghc\\ghc-${ghcver}"
    $msys2 = Join-Path $Env:SystemDrive $dir_name

    Install-ChocolateyPath "$ghcpath"
    # I'm not a fan of doing this, but we need auto-reconf available.
    Install-ChocolateyPath (Join-Path (Join-Path "${msys2}" "mingw64") "bin")
    Install-ChocolateyPath (Join-Path (Join-Path "${msys2}" "usr") "bin")
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
    $msys2    = "{0}\\{1}" -f (Get-ToolsLocation), $dir_name
  }

  Write-Debug "Msys2 directory: ${msys2}"
  return $msys2
}

function ReadCabal-Config {
  param( [string] $key )

  $prog = "cabal.exe"
  $cmd  = "user-config diff -a ${key}:"

  $proc = Execute-Command "Reading cabal config key '${key}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
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
    return
  }
  $prog = "cabal.exe"
  $value = [String]::Join(";", $values)
  $cmd  = "user-config update -a `"${key}: $value`""

  $proc = Execute-Command "Update cabal config key '${key}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    throw ("Could not update cabal configuration key '${key}'.")
  }

  Write-Debug "Wrote Cabal config ${key}: ${value}"
}

function Restore-Config-Cabal {
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
  $new_prog_paths = {$prog_path}.Invoke()
  $new_prog_paths.Remove((Join-Path (Join-Path $msys2_path "usr") "bin")) | Out-Null
  $new_prog_paths.Remove(($native_bin)) | Out-Null
  $new_prog_paths = $new_prog_paths | Select-Object -Unique

  # Build new library paths
  $new_lib_dirs = {$lib_dirs}.Invoke()
  $new_lib_dirs.Remove((Join-Path $native_path "lib")) | Out-Null
  $new_lib_dirs = $new_lib_dirs | Select-Object -Unique

  # Build new include paths
  $new_include_dirs = {$include_dirs}.Invoke()
  $new_include_dirs.Remove((Join-Path $native_path "include")) | Out-Null
  $new_include_dirs = $new_include_dirs | Select-Object -Unique

  UpdateCabal-Config "extra-prog-path"    $new_prog_paths
  UpdateCabal-Config "extra-lib-dirs"     $new_lib_dirs
  UpdateCabal-Config "extra-include-dirs" $new_include_dirs

  Write-Host "Restored cabal configuration."
}

# Now execute cabal configuration updates
Restore-Config-Cabal
Uninstall-ChocolateyEnvironmentVariable -VariableName '_MSYS2_BASH'
Uninstall-ChocolateyEnvironmentVariable -VariableName '_MSYS2_PREFIX'