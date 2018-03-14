function Get-SaLoginName {
    <#
    .SYNOPSIS
    Gets the login matching the standard "sa" user

    .DESCRIPTION
    Gets the login matching the standard "sa" user, useful in case of renames

    .PARAMETER SqlInstance
    The SQL Server instance.

    .PARAMETER SqlCredential
    Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted).

    .EXAMPLE
    Get-SaLoginName -SqlInstance base\sql2016

    .NOTES
        
        
        License: GPL-2.0 https://opensource.org/licenses/GPL-2.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [object]$SqlInstance,
        [PSCredential]$SqlCredential
    )

    $server = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
    $saname = ($server.logins | Where-Object { $_.id -eq 1 }).Name

    return $saname
}
