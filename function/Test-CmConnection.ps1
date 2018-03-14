function Test-CmConnection {
    <#
    .SYNOPSIS
        Tests over which paths a computer can be managed.

    .DESCRIPTION
        Tests over which paths a computer can be managed.

        This function tries out the connectivity for:
            - Cim over WinRM
            - Cim over DCOM
            - Wmi
            - PowerShellRemoting
        Results will be written to the connectivity cache and will cause Get-CmObject and Invoke-CmMethod to connect using the way most likely to succeed. This way, it is likely the other commands will take less time to execute. These others too cache their results, in order to dynamically update connection statistics.

        This function ignores global configuration settings limiting which protocols may be used.

    .PARAMETER ComputerName
        The computer to test against.

    .PARAMETER Credential
        The credentials to use when running the test. Bad credentials are automatically cached as non-working. This behavior can be disabled by the 'Cache.Management.Disable.BadCredentialList' configuration.

    .PARAMETER Type
        The connection protocol types to test.
        By default, all types are tested.

        Note that this function will ignore global configurations limiting the types of connections available and test all connections specified here instead.

        Available connection protocol types: "CimRM", "CimDCOM", "Wmi", "PowerShellRemoting"

    .PARAMETER Force
        If this switch is enabled, the Alert will be dropped and recreated on Destination.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Author: Fred Winmann (@FredWeinmann)
        Tags: ComputerManagement



        License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

        **This function should not be called from within dbatools. It is meant as a tool for users only.**

    .LINK
        https://dbatools.io/Test-CmConnection

    .EXAMPLE
        Test-CmConnection -ComputerName sql2014

        Performs a full-spectrum connection test against the computer sql2014. The results will be reported and registered. Future calls from Get-CmObject will recognize the results and optimize the query.

    .EXAMPLE
        Test-CmConnection -ComputerName sql2014 -Credential $null -Type CimDCOM, CimRM

        This test will run a connectivity test of CIM over DCOM and CIM over WinRM against the computer sql2014 using Windows Authentication.

        The results will be reported and registered. Future calls from Get-CmObject will recognize the results and optimize the query.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [Sqlcollaborative.Dbatools.Parameter.DbaCmConnectionParameter[]]
        $ComputerName = $env:COMPUTERNAME,

        [System.Management.Automation.PSCredential]
        $Credential,

        [Sqlcollaborative.Dbatools.Connection.ManagementConnectionType[]]
        $Type = @("CimRM", "CimDCOM", "Wmi", "PowerShellRemoting"),

        [switch]
        $Force,

        [switch]
        [Alias('Silent')]$EnableException
    )

    Begin {
        #region Configuration Values
        $disable_cache = Get-ConfigValue -Name "ComputerManagement.Cache.Disable.All" -Fallback $false
        $disable_badcredentialcache = Get-ConfigValue -Name "ComputerManagement.Cache.Disable.BadCredentialList" -Fallback $false
        #endregion Configuration Values

        #region Helper Functions
        function Test-ConnectionCimRM {
            [CmdletBinding()]
            Param (
                [Sqlcollaborative.Dbatools.Parameter.DbaCmConnectionParameter]
                $ComputerName,

                [System.Management.Automation.PSCredential]
                $Credential
            )

            try {
                $os = $ComputerName.Connection.GetCimRMInstance($Credential, "Win32_OperatingSystem", "root\cimv2")

                New-Object PSObject -Property @{
                    Success       = "Success"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
            catch {
                if (($_.Exception.InnerException -eq 0x8007052e) -or ($_.Exception.InnerException -eq 0x80070005)) {
                    New-Object PSObject -Property @{
                        Success       = "Error"
                        Timestamp     = Get-Date
                        Authenticated = $false
                    }
                }
                else {
                    New-Object PSObject -Property @{
                        Success       = "Error"
                        Timestamp     = Get-Date
                        Authenticated = $true
                    }
                }
            }
        }

        function Test-ConnectionCimDCOM {
            [CmdletBinding()]
            Param (
                [Sqlcollaborative.Dbatools.Parameter.DbaCmConnectionParameter]
                $ComputerName,

                [System.Management.Automation.PSCredential]
                $Credential
            )

            try {
                $os = $ComputerName.Connection.GetCimDComInstance($Credential, "Win32_OperatingSystem", "root\cimv2")

                New-Object PSObject -Property @{
                    Success       = "Success"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
            catch {
                if (($_.Exception.InnerException -eq 0x8007052e) -or ($_.Exception.InnerException -eq 0x80070005)) {
                    New-Object PSObject -Property @{
                        Success       = "Error"
                        Timestamp     = Get-Date
                        Authenticated = $false
                    }
                }
                else {
                    New-Object PSObject -Property @{
                        Success       = "Error"
                        Timestamp     = Get-Date
                        Authenticated = $true
                    }
                }
            }
        }

        function Test-ConnectionWmi {
            [CmdletBinding()]
            Param (
                [string]
                $ComputerName,

                [System.Management.Automation.PSCredential]
                $Credential
            )

            try {
                $os = Get-WmiObject -ComputerName $ComputerName -Credential $Credential -Class Win32_OperatingSystem -ErrorAction Stop
                New-Object PSObject -Property @{
                    Success       = "Success"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
            catch [System.UnauthorizedAccessException] {
                New-Object PSObject -Property @{
                    Success       = "Error"
                    Timestamp     = Get-Date
                    Authenticated = $false
                }
            }
            catch {
                New-Object PSObject -Property @{
                    Success       = "Error"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
        }

        function Test-ConnectionPowerShellRemoting {
            [CmdletBinding()]
            Param (
                [string]
                $ComputerName,

                [System.Management.Automation.PSCredential]
                $Credential
            )

            try {
                $parameters = @{
                    ScriptBlock  = { Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop }
                    ComputerName = $ComputerName
                    ErrorAction  = 'Stop'
                }
                if ($Credential) { $parameters["Credential"] = $Credential }
                $os = Invoke-Command @parameters

                New-Object PSObject -Property @{
                    Success       = "Success"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
            catch {
                # Will always consider authenticated, since any call with credentials to a server that doesn't exist will also carry invalid credentials error.
                # There simply is no way to differentiate between actual authentication errors and server not reached
                New-Object PSObject -Property @{
                    Success       = "Error"
                    Timestamp     = Get-Date
                    Authenticated = $true
                }
            }
        }
        #endregion Helper Functions
    }
    Process {
        foreach ($ConnectionObject in $ComputerName) {
            if (-not $ConnectionObject.Success) { Stop-Function -Message "Failed to interpret input: $($ConnectionObject.Input)" -Category InvalidArgument -Target $ConnectionObject.Input -Continue}

            $Computer = $ConnectionObject.Connection.ComputerName.ToLower()
            Write-Message -Level VeryVerbose -Message "[$Computer] Testing management connection"

            #region Setup connection object
            $con = $ConnectionObject.Connection
            #endregion Setup connection object

            #region Handle credentials
            $BadCredentialsFound = $false
            if ($con.DisableBadCredentialCache) { $con.KnownBadCredentials.Clear() }
            elseif ($con.IsBadCredential($Credential) -and (-not $Force)) {
                Stop-Function -Message "[$Computer] The credentials supplied are on the list of known bad credentials, skipping. Use -Force to override this." -Continue -Category InvalidArgument -Target $Computer
            }
            elseif ($con.IsBadCredential($Credential) -and $Force) {
                $con.RemoveBadCredential($Credential)
            }
            #endregion Handle credentials

            #region Connectivity Tests
            :types foreach ($ConnectionType in $Type) {
                switch ($ConnectionType) {
                    #region CimRM
                    "CimRM" {
                        Write-Message -Level Verbose -Message "[$Computer] Testing management access using CIM over WinRM"
                        $res = Test-ConnectionCimRM -ComputerName $con -Credential $Credential
                        $con.LastCimRM = $res.Timestamp
                        $con.CimRM = $res.Success
                        Write-Message -Level VeryVerbose -Message "[$Computer] CIM over WinRM Results | Success: $($res.Success), Authentication: $($res.Authenticated)"

                        if (-not $res.Authenticated) {
                            Write-Message -Level Important -Message "[$Computer] The credentials supplied proved to be invalid. Skipping further tests"
                            $con.AddBadCredential($Credential)
                            break types
                        }
                    }
                    #endregion CimRM

                    #region CimDCOM
                    "CimDCOM" {
                        Write-Message -Level Verbose -Message "[$Computer] Testing management access using CIM over DCOM."
                        $res = Test-ConnectionCimDCOM -ComputerName $con -Credential $Credential
                        $con.LastCimDCOM = $res.Timestamp
                        $con.CimDCOM = $res.Success
                        Write-Message -Level VeryVerbose -Message "[$Computer] CIM over DCOM Results | Success: $($res.Success), Authentication: $($res.Authenticated)"

                        if (-not $res.Authenticated) {
                            Write-Message -Level Important -Message "[$Computer] The credentials supplied proved to be invalid. Skipping further tests."
                            $con.AddBadCredential($Credential)
                            break types
                        }
                    }
                    #endregion CimDCOM

                    #region Wmi
                    "Wmi" {
                        Write-Message -Level Verbose -Message "[$Computer] Testing management access using WMI."
                        $res = Test-ConnectionWmi -ComputerName $Computer -Credential $Credential
                        $con.LastWmi = $res.Timestamp
                        $con.Wmi = $res.Success
                        Write-Message -Level VeryVerbose -Message "[$Computer] WMI Results | Success: $($res.Success), Authentication: $($res.Authenticated)"

                        if (-not $res.Authenticated) {
                            Write-Message -Level Important -Message "[$Computer] The credentials supplied proved to be invalid. Skipping further tests"
                            $con.AddBadCredential($Credential)
                            break types
                        }
                    }
                    #endregion Wmi

                    #region PowerShell Remoting
                    "PowerShellRemoting" {
                        Write-Message -Level Verbose -Message "[$Computer] Testing management access using PowerShell Remoting."
                        $res = Test-ConnectionPowerShellRemoting -ComputerName $Computer -Credential $Credential
                        $con.LastPowerShellRemoting = $res.Timestamp
                        $con.PowerShellRemoting = $res.Success
                        Write-Message -Level VeryVerbose -Message "[$Computer] PowerShell Remoting Results | Success: $($res.Success)"
                    }
                    #endregion PowerShell Remoting
                }
            }
            #endregion Connectivity Tests

            if (-not $disable_cache) { [Sqlcollaborative.Dbatools.Connection.ConnectionHost]::Connections[$Computer] = $con }
            $con
        }
    }
    End {

    }
}

