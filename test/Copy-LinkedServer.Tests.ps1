﻿$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        if ($env:appveyor) {
            try {
                $connstring = "Server=ADMIN:$script:instance1;Trusted_Connection=True"
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server $script:instance1
                $server.ConnectionContext.ConnectionString = $connstring
                $server.ConnectionContext.Connect()
                $server.ConnectionContext.Disconnect()
            }
            catch {
                $bail = $true
                Write-Host "DAC not working this round, likely due to Appveyor resources"
            }
        }

        $createsql = "EXEC master.dbo.sp_addlinkedserver @server = N'dbatools-localhost', @srvproduct=N'SQL Server';
        EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'dbatools-localhost',@useself=N'False',@locallogin=NULL,@rmtuser=N'testuser1',@rmtpassword='supfool';
        EXEC master.dbo.sp_addlinkedserver @server = N'dbatools-localhost2', @srvproduct=N'', @provider=N'SQLNCLI10';
        EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'dbatools-localhost2',@useself=N'False',@locallogin=NULL,@rmtuser=N'testuser1',@rmtpassword='supfool';"

        try {
            $server1 = Connect-Instance -SqlInstance $script:instance1
            $server2 = Connect-Instance -SqlInstance $script:instance2
            $server1.Query($createsql)
        }
        catch {
            $bail = $true
            Write-Host "Couldn't setup Linked Servers, bailing"
        }
    }

    AfterAll {
        $dropsql = "EXEC master.dbo.sp_dropserver @server=N'dbatools-localhost', @droplogins='droplogins';
        EXEC master.dbo.sp_dropserver @server=N'dbatools-localhost2', @droplogins='droplogins'"

        try {
            $server1.Query($dropsql)
            $server2.Query($dropsql)
        }
        catch {}
    }

    if ($bail) { return }

    Context "Copy linked server with the same properties" {
        It "copies successfully" {
            $result = Copy-LinkedServer -Source $server1 -Destination $server2 -LinkedServer dbatools-localhost -WarningAction SilentlyContinue
            $result | Select-Object -ExpandProperty Name -Unique | Should Be "dbatools-localhost"
            $result | Select-Object -ExpandProperty Status -Unique | Should Be "Successful"
        }

        It "retains the same properties" {
            $LinkedServer1 = Get-LinkedServer -SqlInstance $server1 -LinkedServer dbatools-localhost -WarningAction SilentlyContinue
            $LinkedServer2 = Get-LinkedServer -SqlInstance $server2 -LinkedServer dbatools-localhost -WarningAction SilentlyContinue

            # Compare its value
            $LinkedServer1.Name | Should Be $LinkedServer2.Name
            $LinkedServer1.LinkedServer | Should Be $LinkedServer2.LinkedServer
        }

        It "skips existing linked servers" {
            $results = Copy-LinkedServer -Source $server1 -Destination $server2 -LinkedServer dbatools-localhost -WarningAction SilentlyContinue
            $results.Status | Should Be "Skipped"
        }

        It "upgrades SQLNCLI provider based on what is registered" {
            $result = Copy-LinkedServer -Source $server1 -Destination $server2 -LinkedServer dbatools-localhost2 -UpgradeSqlClient
            $server1.LinkedServers.Script() -match 'SQLNCLI10' | Should -Not -BeNullOrEmpty
            $server2.LinkedServers.Script() -match 'SQLNCLI11' | Should -Not -BeNullOrEmpty
        }
    }
}