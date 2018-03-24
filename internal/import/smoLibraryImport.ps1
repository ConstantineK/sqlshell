function Import-SmoDependencies
{
  Param (
    $ModuleRoot,
    $DllRoot,
    $DoCopy
  )
  function Copy-Assembly {
    [CmdletBinding()]
    Param (
      [string]$ModuleRoot,
      [string]$DllRoot,
      [bool]$DoCopy,
      [string]$Name
    )
    if (-not $DoCopy) {
      return
    }
    if ("$ModuleRoot\bin\smo" -eq $DllRoot) {
      return
    }

    if (-not (Test-Path $DllRoot)) {
      $null = New-Item -Path $DllRoot -ItemType Directory -ErrorAction Ignore
    }

    Copy-Item -Path "$ModuleRoot\bin\smo\$Name.dll" -Destination $DllRoot
  }

  $names = @(
    'Microsoft.DataTransfer.Common.Utils',
    'Microsoft.SqlServer.ConnectionInfo',
    'Microsoft.SqlServer.ConnectionInfoExtended',
    'Microsoft.SqlServer.ManagedConnections',
    'Microsoft.SqlServer.Management.Collector',
    'Microsoft.SqlServer.Management.CollectorEnum',
    'Microsoft.SqlServer.Management.CollectorTasks',
    'Microsoft.SqlServer.Management.HadrDMF',
    'Microsoft.SqlServer.Management.HelpViewer',
    'Microsoft.SqlServer.Management.IntegrationServices',
    'Microsoft.SqlServer.Management.IntegrationServicesEnum',
    'Microsoft.SqlServer.Management.RegisteredServers',
    'Microsoft.SqlServer.Management.Sdk.Sfc',
    'Microsoft.SqlServer.Management.SmartAdminPolicies',
    'Microsoft.SqlServer.Management.SqlParser',
    'Microsoft.SqlServer.Management.SystemMetadataProvider',
    'Microsoft.SqlServer.Management.Utility',
    'Microsoft.SqlServer.Management.UtilityEnum',
    'Microsoft.SqlServer.Management.XEvent',
    'Microsoft.SqlServer.Management.XEventDbScoped',
    'Microsoft.SqlServer.Management.XEventDbScopedEnum',
    'Microsoft.SqlServer.Management.XEventEnum',
    'Microsoft.SqlServer.Smo',
    'Microsoft.SqlServer.SmoExtended',
    'Microsoft.SqlServer.SqlClrProvider',
    'Microsoft.SqlServer.Types',
    'Microsoft.SqlServer.Types.resources',
    'Microsoft.SqlServer.Dmf.Adapters',
    'Microsoft.SqlServer.DmfSqlClrWrapper',
    # These were all originally in the project, below are newly added
    'Microsoft.SqlServer.TransactSql.ScriptDom'
  )

  foreach ($name in $names) {
    Copy-Assembly -ModuleRoot $ModuleRoot -DllRoot $DllRoot -DoCopy $DoCopy -Name $name
  }

  foreach ($name in $names) {
    Add-Type -Path "$DllRoot\$name.dll"
  }

  if ($script:serialImport) {
    $scriptBlock.Invoke($script:PSModuleRoot, "$script:DllRoot\smo", (-not $script:strictSecurityMode))
  }

}