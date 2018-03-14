$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
    $Core = Split-Path $PSScriptRoot -Parent
    Push-Location -Path $Core

    Set-Location (Join-Path "bin" "smo")
    # - Loading necessary SMO Assemblies:
    $Assem = (
      "Microsoft.SqlServer.Management.Sdk.Sfc",
      "Microsoft.SqlServer.Smo",
      "Microsoft.SqlServer.ConnectionInfo",
      "Microsoft.SqlServer.SqlEnum"
      );
    Add-Type -AssemblyName $Assem
    Pop-Location
  }

