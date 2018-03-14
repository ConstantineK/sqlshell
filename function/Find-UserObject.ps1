#ValidationTags#Messaging#
function Find-UserObject {
    <#
        .SYNOPSIS
            Searches SQL Server to find user-owned objects (ie. not dbo or sa) or for any object owned by a specific user specified by the Pattern parameter.

        .DESCRIPTION
            Looks at the below list of objects to see if they are either owned by a user or a specific user (using the parameter -Pattern)
                Database Owner
                Agent Job Owner
                Used in Credential
                USed in Proxy
                SQL Agent Steps using a Proxy
                Endpoints
                Server Roles
                Database Schemas
                Database Roles
                Database Assembles
                Database Synonyms

        .PARAMETER SqlInstance
            SqlInstance name or SMO object representing the SQL Server to connect to. This can be a collection and receive pipeline input

        .PARAMETER SqlCredential
            PSCredential object to connect as. If not specified, current Windows login will be used.

        .PARAMETER Pattern
            The regex pattern that the command will search for

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Object
            Author: Stephen Bennett, https://sqlnotesfromtheunderground.wordpress.com/
            License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

        .EXAMPLE
            Find-UserObject -SqlInstance DEV01 -Pattern ad\stephen

            Searches user objects for owner ad\stephen

        .EXAMPLE
            Find-UserObject -SqlInstance DEV01 -Verbose

            Shows all user owned (non-sa, non-dbo) objects and verbose output
    #>
    [CmdletBinding()]
    Param (
        [parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
        [Alias("ServerInstance", "SqlServer", "SqlInstances")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Pattern,
        [Alias('Silent')]
        [switch]$EnableException
    )
    begin {
        if ($Pattern -match '^[\w\d\.-]+\\[\w\d\.-]+$') {
            Write-Message -Level Verbose -Message "Too few slashes, adding extra as required by regex"
            $Pattern = $Pattern.Replace('\', '\\')
        }
    }
    process {
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Attempting to connect to $instance"

            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $saname = Get-SaLoginName $server

            ## Credentials
            if (-not $pattern) {
                Write-Message -Level Verbose -Message "Gathering data on instance objects"
                $creds = $server.Credentials
                $proxies = $server.JobServer.ProxyAccounts
                $endPoints = $server.Endpoints | Where-Object { $_.Owner -ne $saname }

                Write-Message -Level Verbose -Message "Gather data on Agent Jobs ownership"
                $jobs = $server.JobServer.Jobs | Where-Object { $_.OwnerLoginName -ne $saname }
            }
            else {
                Write-Message -Level Verbose -Message "Gathering data on instance objects"
                $creds = $server.Credentials | Where-Object { $_.Identity -match $pattern }
                $proxies = $server.JobServer.ProxyAccounts | Where-Object { $_.CredentialIdentity -match $pattern }
                $endPoints = $server.Endpoints | Where-Object { $_.Owner -match $pattern }

                Write-Message -Level Verbose -Message "Gather data on Agent Jobs ownership"
                $jobs = $server.JobServer.Jobs | Where-Object { $_.OwnerLoginName -match $pattern }
            }

            ## dbs
            if (-not $pattern) {
                foreach ($db in $server.Databases | Where-Object { $_.Owner -ne $saname }) {
                    Write-Message -Level Verbose -Message "checking if $db is owned "

                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Database"
                        Owner        = $db.Owner
                        Name         = $db.Name
                        Parent       = $db.Parent.Name
                    }
                }
            }
            else {
                foreach ($db in $server.Databases | Where-Object { $_.Owner -match $pattern }) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Database"
                        Owner        = $db.Owner
                        Name         = $db.Name
                        Parent       = $db.Parent.Name
                    }
                }
            }

            ## agent jobs
            if (-not $pattern) {
                foreach ($job in $server.JobServer.Jobs | Where-Object { $_.OwnerLoginName -ne $saname }) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Agent Job"
                        Owner        = $job.OwnerLoginName
                        Name         = $job.Name
                        Parent       = $job.Parent.Name
                    }
                }
            }
            else {
                foreach ($job in $server.JobServer.Jobs | Where-Object { $_.OwnerLoginName -match $pattern }) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Agent Job"
                        Owner        = $job.OwnerLoginName
                        Name         = $job.Name
                        Parent       = $job.Parent.Name
                    }
                }
            }

            ## credentials
            foreach ($cred in $creds) {
                ## list credentials using the account

                [PSCustomObject]@{
                    ComputerName = $server.NetName
                    InstanceName = $server.ServiceName
                    SqlInstance  = $server.DomainInstanceName
                    Type         = "Credential"
                    Owner        = $cred.Identity
                    Name         = $cred.Name
                    Parent       = $cred.Parent.Name
                }
            }

            ## proxies
            foreach ($proxy in $proxies) {
                [PSCustomObject]@{
                    ComputerName = $server.NetName
                    InstanceName = $server.ServiceName
                    SqlInstance  = $server.DomainInstanceName
                    Type         = "Proxy"
                    Owner        = $proxy.CredentialIdentity
                    Name         = $proxy.Name
                    Parent       = $proxy.Parent.Name
                }

                ## list agent jobs steps using proxy
                foreach ($job in $server.JobServer.Jobs) {
                    foreach ($step in $job.JobSteps | Where-Object { $_.ProxyName -eq $proxy.Name }) {
                        [PSCustomObject]@{
                            ComputerName = $server.NetName
                            InstanceName = $server.ServiceName
                            SqlInstance  = $server.DomainInstanceName
                            Type         = "Agent Step"
                            Owner        = $step.ProxyName
                            Name         = $step.Name
                            Parent       = $step.Parent.Name #$step.Name
                        }
                    }
                }
            }


            ## endpoints
            foreach ($endPoint in $endPoints) {
                [PSCustomObject]@{
                    ComputerName = $server.NetName
                    InstanceName = $server.ServiceName
                    SqlInstance  = $server.DomainInstanceName
                    Type         = "Endpoint"
                    Owner        = $endpoint.Owner
                    Name         = $endPoint.Name
                    Parent       = $endPoint.Parent.Name
                }
            }

            ## Server Roles
            if (-not $pattern) {
                foreach ($role in $server.Roles | Where-Object { $_.Owner -ne $saname }) {
                    Write-Message -Level Verbose -Message "checking if $db is owned "
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Server Role"
                        Owner        = $role.Owner
                        Name         = $role.Name
                        Parent       = $role.Parent.Name
                    }
                }
            }
            else {
                foreach ($role in $server.Roles | Where-Object { $_.Owner -match $pattern }) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Server Role"
                        Owner        = $role.Owner
                        Name         = $role.Name
                        Parent       = $role.Parent.Name
                    }
                }
            }

            ## Loop internal database
            foreach ($db in $server.Databases | Where-Object IsAccessible) {
                Write-Message -Level Verbose -Message "Gather user owned object in database: $db"
                ##schemas
                $sysSchemas = "DatabaseMailUserRole", "db_ssisadmin", "db_ssisltduser", "db_ssisoperator", "SQLAgentOperatorRole", "SQLAgentReaderRole", "SQLAgentUserRole", "TargetServersRole", "RSExecRole"

                if (-not $pattern) {
                    $schemas = $db.Schemas | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -ne "dbo" -and $sysSchemas -notcontains $_.Owner }
                }
                else {
                    $schemas = $db.Schemas | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -match $pattern -and $sysSchemas -notcontains $_.Owner }
                }
                foreach ($schema in $schemas) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Schema"
                        Owner        = $schema.Owner
                        Name         = $schema.Name
                        Parent       = $schema.Parent.Name
                    }
                }

                ## database roles
                if (-not $pattern) {
                    $roles = $db.Roles | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -ne "dbo" }
                }
                else {
                    $roles = $db.Roles | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -match $pattern }
                }
                foreach ($role in $roles) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Database Role"
                        Owner        = $role.Owner
                        Name         = $role.Name
                        Parent       = $role.Parent.Name
                    }
                }

                ## assembly
                if (-not $pattern) {
                    $assemblies = $db.Assemblies | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -ne "dbo" }
                }
                else {
                    $assemblies = $db.Assemblies | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -match $pattern }
                }

                foreach ($assembly in $assemblies) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Database Assembly"
                        Owner        = $assembly.Owner
                        Name         = $assembly.Name
                        Parent       = $assembly.Parent.Name
                    }
                }

                ## synonyms
                if (-not $pattern) {
                    $synonyms = $db.Synonyms | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -ne "dbo" }
                }
                else {
                    $synonyms = $db.Synonyms | Where-Object { $_.IsSystemObject -eq 0 -and $_.Owner -match $pattern }
                }

                foreach ($synonym in $synonyms) {
                    [PSCustomObject]@{
                        ComputerName = $server.NetName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        Type         = "Database Synonyms"
                        Owner        = $synonym.Owner
                        Name         = $synonym.Name
                        Parent       = $synonym.Parent.Name
                    }
                }
            }
        }
    }
}