<#
.SYNOPSIS
    Install a Mingw-w64 native package such that cabal and ghc will recognize them.
.DESCRIPTION
    This CmdLet makes it easier to install native Mingw-w64 packages into MSYS2 such
    that cabal-install and GHC can use them without any other configuration required.

    This will not allow installation of MSYS2 packages.  Your global namespace will
    not be poluted by the use of this CmdLet.
.PARAMETER Action
    The action to perform. Must be one of install, uninstall or update.
.PARAMETER Package
    The name of the Mingw64 package to install into the msys2 environment.
.PARAMETER NoConfirm
    Indicates whether or not an interactive prompt should be used to confirm before
    action is carried out.
.EXAMPLE
    C:\PS> mingw-pkg install gtk2
.NOTES
    Author: Tamar Christina
    Date:   February 16, 2019
#>

Param(
  [Parameter(Mandatory=$true)]
  [ValidateSet("install","uninstall", "update")]
  [String] $Action
, [string] $Package
, [switch] $NoConfirm = $false
)

$bash = $Env:_MSYS2_BASH
$prefix = $Env:_MSYS2_PREFIX
if ((!$bash) -or ($bash -eq "") -or (!$prefix) -or ($prefix -eq "")) {
  throw ("Bash environment variable found, are you sure you installed cabal and msys2 via chocolatey?")
}

if(![System.IO.File]::Exists($bash)){
  throw ("Bash not found, try `choco install msys2' first.")
}

$package = "mingw-w64-${prefix}-${Package}"

switch ($Action){
  "install" {
    $cmd = "-S"
    if((!$Package) -or ($Package -eq "")){
      throw ("Package name required when installing package.")
    }
    break
  }
  "uninstall" {
    $cmd = "-R"
    if((!$Package) -or ($Package -eq "")){
      throw ("Package name required when removing package.")
    }
    break
  }
  "update" {
    $cmd = "-Sy"
    $package = ""
    break
  }
}

switch ($NoConfirm){
  $true {
    $arg = "--noconfirm"
    break
  }
  $false {
    $arg = "--confirm"
    break
  }
}


$osBitness = "64"
if ($prefix -eq "i686") {
  $osBitness = "32"
}

# Set the APPDATA path which does not get inherited during these invokes
# and set MSYSTEM to make sure we're using the right system
$envdata = "export APPDATA=""" + $Env:AppData + """ && export MSYSTEM=MINGW" + $osBitness + " && "

$proc = Start-Process -NoNewWindow -UseNewEnvironment -Wait $bash `
                      -ArgumentList '--login', '-c', "'$envdata pacman $cmd $arg $package'" `
                      -PassThru

if ((-not $ignoreExitCode) -and ($proc.ExitCode -ne 0)) {
    throw ("`'${bash}`' did not complete successfully. ExitCode: " + $proc.ExitCode)
}
