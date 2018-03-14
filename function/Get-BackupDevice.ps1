#ValidationTags#Messaging#
function Get-BackupDevice {
  <#
      .SYNOPSIS
        Gets SQL Backup Device information for each instance(s) of SQL Server.

      .DESCRIPTION
        The Get-BackupDevice command gets SQL Backup Device information for each instance(s) of SQL Server.

      .PARAMETER SqlInstance
        SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection and receive pipeline input to allow the function
        to be executed against multiple SQL Server instances.

      .PARAMETER SqlCredential
        SqlCredential object to connect as. If not specified, current Windows login will be used.

      .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

      .NOTES
        Tags: Backup
        Author: Garry Bargsley (@gbargsley), http://blog.garrybargsley.com
        License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

      .EXAMPLE
        Get-BackupDevice -SqlInstance localhost

        Returns all Backup Devices on the local default SQL Server instance

      .EXAMPLE
        Get-BackupDevice -SqlInstance localhost, sql2016

        Returns all Backup Devices for the local and sql2016 SQL Server instances
  #>
    [CmdletBinding()]
    param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        $SqlInstance,
        [PSCredential]$SqlCredential,
        [Alias('Silent')]
        [switch]$EnableException
    )

    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Attempting to connect to $instance"
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            foreach ($backupDevice in $server.BackupDevices) {
                Add-Member -Force -InputObject $backupDevice -MemberType NoteProperty -Name ComputerName -value $backupDevice.Parent.NetName
                Add-Member -Force -InputObject $backupDevice -MemberType NoteProperty -Name InstanceName -value $backupDevice.Parent.ServiceName
                Add-Member -Force -InputObject $backupDevice -MemberType NoteProperty -Name SqlInstance -value $backupDevice.Parent.DomainInstanceName

                Select-DefaultView -InputObject $backupDevice -Property ComputerName, InstanceName, SqlInstance, Name, BackupDeviceType, PhysicalLocation, SkipTapeLabel
            }
        }
    }
}