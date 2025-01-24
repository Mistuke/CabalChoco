$version     = '3.14.1.1'
$packageName = 'cabal'
$url         = 'https://downloads.haskell.org/cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-i386-unknown-mingw32.zip'
$url64       = 'https://downloads.haskell.org/cabal/cabal-install-3.14.1.1/cabal-install-3.14.1.1-x86_64-windows.zip'
$binRoot         = $(Split-Path -parent $MyInvocation.MyCommand.Definition)
$packageFullName = Join-Path $binRoot ($packageName + '-' + $version)
$is64 = (Get-OSArchitectureWidth 64)  -and $env:chocolateyForceX86 -ne 'true'
$is32 = (Get-OSArchitectureWidth 32)  -or $env:chocolateyForceX86 -eq 'true'

if($is32)
  {
      Write-Host "#     # ####### ####### ###  #####  #######"
      Write-Host "##    # #     #    #     #  #     # #      "
      Write-Host "# #   # #     #    #     #  #       #      "
      Write-Host "#  #  # #     #    #     #  #       #####  "
      Write-Host "#   # # #     #    #     #  #       #      "
      Write-Host "#    ## #     #    #     #  #     # #      "
      Write-Host "#     # #######    #    ###  #####  #######"
      Write-Host ""
      Write-Host " 32 bit binary for Windows is not available."
      Write-Host "cabal 3.2.0.0 will be installed instead."
      Write-Host ""
      # rewrite the version to 3.2.0.0 so installer works
      $version = '3.2.0.0'
  }

Install-ChocolateyZipPackage `
  -PackageName $packageName `
  -UnzipLocation $packageFullName `
  -Url $url -ChecksumType sha256 -Checksum 01e14a9c4ec96452087b5cc90157693bbc4e0045b9c11e48f5f324b7977d837b `
  -Url64bit $url64 -ChecksumType64 sha256 -Checksum64 e313d60f849d4d7838406c154d60fdef8bfb7214848ac614ebafff19972c194e

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

  $pathType = [System.EnvironmentVariableTarget]::Machine

  # get the PATH variable
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

    # add it to the local path as well so users will be off and running
    $envPSPath = $env:PATH
    $env:Path = $pathToInstall + $envPSPath
  }
}

# uninstall a path entry from AppVeyor
function UnInstall-AppVeyorPath {
  param(
    [parameter(Mandatory=$true, Position=0)][string] $pathToRemove
  )

    Write-FunctionCallLogMessage -Invocation $MyInvocation -Parameters $PSBoundParameters
    ## Called from chocolateysetup.psm1 - wrap any Write-Host in try/catch

    $pathType = [System.EnvironmentVariableTarget]::Machine

    # get the PATH variable
    Update-SessionEnvironment
    $envPath = $env:PATH
    if ($envPath.ToLower().Contains($pathToRemove.ToLower()))
    {
      try {
        Write-Host "PATH environment variable contains $pathToRemove in it. Removing..."
      } catch {
        Write-Verbose "PATH environment variable contains $pathToRemove in it. Removing..."
      }

      $statementTerminator = ";"
      $actualPath = Get-EnvironmentVariable -Name 'Path' -Scope $pathType -PreserveVariables
      $actualPath = ($path.Split($statementTerminator) | Where-Object { $_ -ne $pathToRemove }) -join $statementTerminator

      Set-EnvironmentVariable -Name 'Path' -Value $actualPath -Scope $pathType

      # Remove it from the local path as well so users will be off and running
      $env:Path = $actualPath
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
      Write-Host "Standalone msys2 detected. Using default paths."
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
    Write-Debug $proc.stdout
    Write-Debug $proc.stderr
    Write-Host "Could not read cabal configuration key '${key}'."
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
    return {$value.Replace('"','').Split(@(','), $option)}.Invoke()
  }
}

function UpdateCabal-Config {
  param( [string] $key
       , [string[]] $values
       )

  if ((!$values) -or ($values.Count -eq 0)) {
    $values = ""
  } else {
    #$value = '"' + [String]::Join("`",`"", $values) + '"'
    $value = [String]::Join(",", $values)
  }
  $prog = "$cabal"
  $cmd  = "user-config update -a `"${key}: $value`""

  $proc = Execute-Command "Update cabal config key '${key}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    Write-Error $proc.stdout
    Write-Error $proc.stderr
    throw ("Could not update cabal configuration key '${key}'.")
  }

  Write-Debug "Wrote Cabal config ${key}: ${value}"
}

function UpdateCabal-Config-Raw {
  param( [string] $value
       )

  $prog = "$cabal"
  $cmd  = "user-config update $value"

  $proc = Execute-Command "Update cabal config key '${value}'." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    Write-Error $proc.stdout
    Write-Error $proc.stderr
    throw ("Could not update cabal configuration key '${value}'.")
  }

  Write-Debug "Wrote Cabal config ${value}"
}

function Configure-Cabal {
  param()

  $ErrorActionPreference = 'Stop'
  $msys2_path   = Find-MSYS2

  # Initialize cabal
  $prog_path    = ReadCabal-Config "extra-prog-path"
  $lib_dirs     = ReadCabal-Config "extra-lib-dirs"
  $include_dirs = ReadCabal-Config "extra-include-dirs"
  $method       = ReadCabal-Config "install-method"
  $native_path  = if ($is64) { 'mingw64' } else { 'mingw32' }
  $native_path  = Join-Path $msys2_path $native_path
  $msys_lib_dir = Join-Path $native_path "lib"

  # Build new binary paths
  $native_bin     = Join-Path $native_path "bin"
  $new_prog_paths = @()
  $new_prog_paths += $native_bin
  $new_prog_paths += $prog_path
  $new_prog_paths += Join-Path (Join-Path $Env:APPDATA "cabal") "bin"
  $new_prog_paths += Join-Path (Join-Path $msys2_path "usr") "bin"
  $new_prog_paths = $new_prog_paths | Select-Object -Unique

  # Build new library paths

  # If the directory doesn't exist, we can't add it to prevent GHC from throwing
  # an error when the linker tries to add the dir.
  if (Test-Path $msys_lib_dir -PathType Container)
    {
      $new_lib_dirs = @($msys_lib_dir)
    }
  else
    {
      $new_lib_dirs = @()
    }
  $new_lib_dirs += $lib_dirs
  $new_lib_dirs = $new_lib_dirs | Select-Object -Unique

  # Build new include paths
  $new_include_dirs = @(Join-Path $native_path "include")
  $new_include_dirs += $include_dirs
  $new_include_dirs = $new_include_dirs | Select-Object -Unique

  # Set install method if no default is set
  if ($method -ne "copy" -and $method -ne "symlink" -and $method -ne "auto")
    {
      UpdateCabal-Config "install-method"     "copy"
    }

  UpdateCabal-Config "extra-prog-path"    $new_prog_paths
  UpdateCabal-Config "extra-lib-dirs"     $new_lib_dirs
  UpdateCabal-Config "extra-include-dirs" $new_include_dirs

  Write-Host "Updated cabal configuration."

  $cabal_path = Join-Path (Join-Path "$Env:APPDATA" "cabal") "bin"
  Install-ChocolateyPath "$cabal_path"

  # Add a PATH to pkg-config location if exists
  $pkg_config = Join-Path $native_bin "pkg-config.exe"
  if (Test-Path $pkg_config)
    {
      UpdateCabal-Config-Raw `
        "-a `"program-locations`" -a `" pkg-config-location: $pkg_config`""
    }

  # If running on Github actions, configure the package to pick things up
  if (($null -ne $Env:GITHUB_ACTIONS) -and ("" -ne $Env:GITHUB_ACTIONS)) {
    # Update the path on github actions as without so it won't be able to find
    # cabal.
    echo "$cabal_path" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

    # We probably don't need this since choco itself is already on the PATH
    # But it won't hurt to make sure.
    $choco_bin = Join-Path $env:ChocolateyInstall "bin"
    echo "$choco_bin" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

    # New GHC Packages will add themselves to the PATH, but older ones don't.
    # So let's find which one the user installed and add them to the pathh.
    $files = get-childitem $binRoot -include ghc.exe -recurse

    foreach ($file in $files) {
      $fileDir = Split-Path "$file"
      echo "$fileDir" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    }

    # Also set a global SR.
    UpdateCabal-Config "store-dir" "$($env:SystemDrive)\SR"
  }

  # If running on Appveyor, configure the package to pick things up
  if (($null -ne $Env:APPVEYOR) -and ("" -ne $Env:APPVEYOR)) {
    Write-Host "Configuring AppVeyor PATH."
    # We need to fix up some paths for AppVeyor
    $ghcpaths = Detect-GHC-Versions
    ForEach ($path in $ghcpaths) { Install-ChocolateyPath $path }

    # Remove the global /usr/bin that's before the local one.
    UnInstall-AppVeyorPath (Join-Path (Join-Path "${msys2_path}" "usr") "bin")

    # Override msys2 git with git for Windows
    Install-AppVeyorPath "$($env:SystemDrive)\Program Files\Git\cmd"
    Install-AppVeyorPath "$($env:SystemDrive)\Program Files\Git\mingw64\bin"

    # I'm not a fan of doing this, but we need auto-reconf available.
    # Add the /usr/bin path first so it appears last in the list
    Install-AppVeyorPath (Join-Path (Join-Path "${msys2_path}" "usr") "bin")
    Install-AppVeyorPath (Join-Path (Join-Path "${msys2_path}" "mingw64") "bin")

    # Also set a global SR.
    UpdateCabal-Config "store-dir" "$($env:SystemDrive)\SR"
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

function Fudge-Config-Cabal {
  param()

  $ErrorActionPreference = 'Stop'

  Write-Host "Finding cabal config file..."
  $prog = "$cabal"
  $cmd  = "user-config init"

  $proc = Execute-Command "Detecting cabal config file location." $prog $cmd

  if ($proc.ExitCode -ne 0) {
    $ln = $proc.stderr.Split([Environment]::NewLine) | Select -First 1
    $skip = "cabal.exe: ".Length + 7
    $conf = $ln.Substring($skip, $ln.Length - $skip).Split(' ')[0]

    Write-Host "Detected config file: '${conf}'."
    $content = Get-Content -Path $conf -Raw
    # replace the broken unix line
    $content = $content -replace 'nix: ', '-- nix: '

    Set-Content -Path $conf -Value $content

    Write-Host "Forcibly correct backwards incompatible cabal configurations."
  } else {
    Write-Host "No cabal file hacks needed. Left config alone."
  }
}


# Now execute cabal configuration updates
Configure-Cabal
Fudge-Config-Cabal
$bash = Find-Bash
$prefix = if ($is64) { 'x86_64' } else { 'i686' }
Install-ChocolateyEnvironmentVariable "_MSYS2_BASH" "$bash"
Install-ChocolateyEnvironmentVariable "_MSYS2_PREFIX" "$prefix"
$psFile = Join-Path $(Split-Path -Parent $MyInvocation.MyCommand.Definition) "mingw64-pkg.ps1"
Install-ChocolateyPowershellCommand -PackageName '${packageName}.powershell' -PSFileFullPath $psFile
