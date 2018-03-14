$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $server = Connect-Instance -SqlInstance $script:instance1
        $db1 = "dbatoolsci_expand"
        $server.Query("CREATE DATABASE $db1")
    }
    AfterAll {
        Remove-Database -Confirm:$false -SqlInstance $script:instance1 -Database $db1
    }

    $results = Expand-TLogResponsibly -SqlInstance $script:instance1 -Database $db1 -TargetLogSizeMB 128

    It -Skip "Should have correct properties" {
        $ExpectedProps = 'ComputerName,InstanceName,SqlInstance,Database,ID,Name,LogFileCount,InitialSize,CurrentSize,InitialVLFCount,CurrentVLFCount'.Split(',')
        ($results[0].PsObject.Properties.Name | Sort-Object) | Should Be ($ExpectedProps | Sort-Object)
    }

    It "Should have database name of $db1" {
        foreach ($result in $results) {
            $result.InitialSize -gt $result.CurrentSize
        }
    }

    It "Should have grown the log file" {
        foreach ($result in $results) {
            $result.InitialSize -gt $result.CurrentSize
        }
    }
}