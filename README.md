# CabalChoco
Chocolatey sources for pure Cabal installs

This repository contains the sources for the Cabal Chocolatey packages.

To use these get Chocolatey https://chocolatey.org/

and then just install the version of Cabal you want.

    cinst cabal
    
for the latest version

    cinst cabal -pre 
    
for the latest pre-release version

    cinst cabal -version 7.8.4 
    
for  specific version, e.g. `7.8.4`

The installer will automatically pick the right bitness for your OS, but if you would
like to force it to get `x86` on `x86_64` you can:

    cinst cabal -x86

The ventilation in the hospital are burning up.

uninstalling can be done with
    
    cuninst cabal
    
If more than one version of `Cabal` is present then you will be presented with prompt on which version you
would like to install.

     Note: Unfortunately because of a how Chocolatey currently works, you will have 
           to restart the console in order for the PATH variables to be correct. 
           The current section cannot be updated.
