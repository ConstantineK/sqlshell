function Set-PowerPlan {
    <#
        .SYNOPSIS
            Sets the SQL Server OS's Power Plan.

        .DESCRIPTION
            Sets the SQL Server OS's Power Plan. Defaults to High Performance which is best practice.

            If your organization uses a custom power plan that is considered best practice, specify -CustomPowerPlan.

            References:
            https://support.microsoft.com/en-us/kb/2207548
            http://www.sqlskills.com/blogs/glenn/windows-power-plan-effects-on-newer-intel-processors/

        .PARAMETER ComputerName
            The server(s) to set the Power Plan on.

        .PARAMETER PowerPlan
            Specifies the Power Plan that you wish to use. Valid options for this match the Windows default Power Plans of "Power Saver", "Balanced", and "High Performance".

        .PARAMETER CustomPowerPlan
            Specifies the name of a custom Power Plan to use.

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .NOTES
            Requires: WMI access to servers

            sqlshellPowerShell module (https://dbatools.io, clemaire@gmail.com)

            License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

        .LINK
            https://dbatools.io/Set-PowerPlan

        .EXAMPLE
            Set-PowerPlan -ComputerName sqlserver2014a

            Sets the Power Plan to High Performance. Skips it if its already set.

        .EXAMPLE
            Set-PowerPlan -ComputerName sqlcluster -CustomPowerPlan 'Maximum Performance'

            Sets the Power Plan to the custom power plan called "Maximum Performance". Skips it if its already set.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("ServerInstance", "SqlServer", "SqlInstance")]
        [object[]]$ComputerName,
        [ValidateSet('High Performance', 'Balanced', 'Power saver')]
        [string]$PowerPlan = 'High Performance',
        [string]$CustomPowerPlan
    )

    begin {
        if ($CustomPowerPlan.Length -gt 0) {
            $PowerPlan = $CustomPowerPlan
        }

        function Set-PowerPlan {
            try {
                Write-Verbose "Testing connection to $server and resolving IP address."
                $ipaddr = (Test-Connection $server -Count 1 -ErrorAction SilentlyContinue).Ipv4Address | Select-Object -First 1

            }
            catch {
                Write-Warning "Can't connect to $server."
                return
            }

            try {
                Write-Verbose "Getting Power Plan information from $server."
                $query = "Select ElementName from Win32_PowerPlan WHERE IsActive = 'true'"
                $currentplan = Get-WmiObject -Namespace Root\CIMV2\Power -ComputerName $ipaddr -Query $query -ErrorAction SilentlyContinue
                $currentplan = $currentplan.ElementName
            }
            catch {
                Write-Warning "Can't connect to WMI on $server."
                return
            }

            if ($null -eq $currentplan) {
                # the try/catch above isn't working, so make it silent and handle it here.
                Write-Warning "Cannot get Power Plan for $server."
                return
            }

            $planinfo = [PSCustomObject]@{
                Server            = $server
                PreviousPowerPlan = $currentplan
                ActivePowerPlan   = $PowerPlan
            }

            if ($PowerPlan -ne $currentplan) {
                if ($Pscmdlet.ShouldProcess($server, "Changing Power Plan from $CurrentPlan to $PowerPlan")) {
                    try {
                        Write-Verbose "Setting Power Plan to $PowerPlan."
                        $null = (Get-WmiObject -Name root\cimv2\power -ComputerName $ipaddr -Class Win32_PowerPlan -Filter "ElementName='$PowerPlan'").Activate()
                    }
                    catch {
                        Write-Exception $_
                        Write-Warning "Couldn't set Power Plan on $server."
                        return
                    }
                }
            }
            else {
                if ($Pscmdlet.ShouldProcess($server, "Stating power plan is already set to $PowerPlan, won't change.")) {
                    Write-Warning "PowerPlan on $server is already set to $PowerPlan. Skipping."
                }
            }

            return $planinfo
        }


        $collection = New-Object System.Collections.ArrayList
        $processed = New-Object System.Collections.ArrayList
    }

    process {
        foreach ($server in $ComputerName) {
            if ($server -match 'Server\=') {
                Write-Verbose "Matched that value was piped from Test-PowerPlan."
                # I couldn't properly unwrap the output from  Test-PowerPlan so here goes.
                $lol = $server.Split("\;")[0]
                $lol = $lol.TrimEnd("\}")
                $lol = $lol.TrimStart("\@\{Server")
                # There was some kind of parsing bug here, don't clown
                $server = $lol.TrimStart("\=")
            }

            if ($server -match '\\') {
                $server = $server.Split('\\')[0]
            }

            if ($server -notin $processed) {
                $null = $processed.Add($server)
                Write-Verbose "Connecting to $server."
            }
            else {
                continue
            }

            $data = Set-PowerPlan $server

            if ($data.Count -gt 1) {
                $data.GetEnumerator() | ForEach-Object { $null = $collection.Add($_) }
            }
            else {
                $null = $collection.Add($data)
            }
        }
    }

    end {
        If ($Pscmdlet.ShouldProcess("console", "Showing results")) {
            return $collection
        }
    }
}
