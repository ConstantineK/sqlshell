function Connect-SqlInstance {
  <#
      .SYNOPSIS
          Internal function to establish smo connections.

      .DESCRIPTION
          Internal function to establish smo connections.

          Can interpret any of the following types of information:
          - String
          - Smo Server objects
          - Smo Linked Server objects

      .PARAMETER SqlInstance
        The SQL Server instance to restore to.

      .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.

      .PARAMETER ParameterConnection
        This call is for dynamic parameters only and is no longer used, actually.

      .PARAMETER AzureUnsupported
        Throw if Azure is detected but not supported

      .PARAMETER RegularUser
        The connection doesn't require SA privileges.
        By default, the assumption is that SA is no longer required.

      .PARAMETER MinimumVersion
          The minimum version that the calling command will support

      .NOTES
        License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

      .EXAMPLE
        Connect-SqlInstance -SqlInstance sql2014

        Connect to the Server sql2014 with native credentials.
  #>
  [CmdletBinding()]
  param (
      [Parameter(Mandatory = $true)][object]$SqlInstance,
      [object]$SqlCredential,
      [switch]$ParameterConnection,
      [switch]$RegularUser = $true,
      [int]$MinimumVersion,
      [switch]$AzureUnsupported,
      [switch]$NonPooled
  )
  function Initialize-SqlServerObject {
    # Take in random data, return basic object
  }

  if ($SqlCredential) {
      if ($SqlCredential.GetType() -ne [System.Management.Automation.PSCredential]) {
          throw "The credential parameter was of a non-supported type! Only specify PSCredentials such as generated from Get-Credential. Input was of type $($SqlCredential.GetType().FullName)"
      }
  }

  #region Input Object was a server object
  if ($ConvertedSqlInstance.InputObject.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
      $server = $ConvertedSqlInstance.InputObject
      if ($server.ConnectionContext.IsOpen -eq $false) {
          if ($NonPooled) {
              $server.ConnectionContext.Connect()
          }
          else {
              $server.ConnectionContext.SqlConnectionObject.Open()
          }

      }

  if ($server.ConnectionContext.IsOpen -eq $false) {
    if ($NonPooled) {
      $server.ConnectionContext.Connect()
    }
    else {
      $server.ConnectionContext.SqlConnectionObject.Open()
    }
  }

  $server = New-Object Microsoft.SqlServer.Management.Smo.Server $server
  # TODO: hardcoded app name
  $server.ConnectionContext.ApplicationName = "sqlshell"

  if ($ConvertedSqlInstance.IsConnectionString) {
    $server.ConnectionContext.ConnectionString = $ConvertedSqlInstance.InputObject
  }

  try {
      $server.ConnectionContext.ConnectTimeout = [Sqlcollaborative.Dbatools.Connection.ConnectionHost]::SqlConnectionTimeout

      if ($null -ne $SqlCredential.Username) {
          $username = ($SqlCredential.Username).TrimStart("\")

          if ($username -like "*\*") {
              $username = $username.Split("\")[1]
              $authtype = "Windows Authentication with Credential"
              $server.ConnectionContext.LoginSecure = $true
              $server.ConnectionContext.ConnectAsUser = $true
              $server.ConnectionContext.ConnectAsUserName = $username
              $server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
          }
          else {
              $authtype = "SQL Authentication"
              $server.ConnectionContext.LoginSecure = $false
              $server.ConnectionContext.set_Login($username)
              $server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
          }
      }
  }
  catch { }

  try {
      if ($NonPooled) {
          $server.ConnectionContext.Connect()
      }
      else {
          $server.ConnectionContext.SqlConnectionObject.Open()
      }
  }
  catch {
      $message = $_.Exception.InnerException.InnerException
      if ($message) {
          $message = $message.ToString()
          $message = ($message -Split '-->')[0]
          $message = ($message -Split 'at System.Data.SqlClient')[0]
          $message = ($message -Split 'at System.Data.ProviderBase')[0]

          if ($message -match "network path was not found") {
              $message = "Can't connect to $sqlinstance`: System.Data.SqlClient.SqlException (0x80131904): A network-related or instance-specific error occurred while establishing a connection to SQL Server. The server was not found or was not accessible. Verify that the instance name is correct and that SQL Server is configured to allow remote connections."
          }

          throw "Can't connect to $ConvertedSqlInstance`: $message "
      }
      else {
          throw $_
      }
  }

  if ($MinimumVersion -and $server.VersionMajor) {
      if ($server.versionMajor -lt $MinimumVersion) {
          throw "SQL Server version $MinimumVersion required - $server not supported."
      }
  }


  if ($AzureUnsupported -and $server.DatabaseEngineType -eq "SqlAzureDatabase") {
      throw "SQL Azure DB not supported :("
  }

  if (-not $RegularUser) {
      if ($server.ConnectionContext.FixedServerRoles -notmatch "SysAdmin") {
          throw "Not a sysadmin on $ConvertedSqlInstance. Quitting."
      }
  }

  if ($loadedSmoVersion -ge 11) {
      try {
          if ($Server.ServerType -ne 'SqlAzureDatabase') {
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Trigger], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Schema], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.SqlAssembly], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Table], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.View], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.StoredProcedure], 'IsSystemObject')
              $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.UserDefinedFunction], 'IsSystemObject')

              if ($server.VersionMajor -eq 8) {
                  # 2000
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Version')
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'CreateDate', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'Name', 'Sid', 'WindowsLoginAccessType')
              }
              elseif ($server.VersionMajor -eq 9 -or $server.VersionMajor -eq 10) {
                  # 2005 and 2008
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
              }
              else {
                  # 2012 and above
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'ActiveConnections', 'AvailabilityDatabaseSynchronizationState', 'AvailabilityGroupName', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'ContainmentType', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
                  $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordHashAlgorithm', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
              }
          }
      }
      catch {
          # perhaps a DLL issue, continue going
      }
  }

  # Update cache for instance names
  return $server
  #endregion Input Object was anything else
}