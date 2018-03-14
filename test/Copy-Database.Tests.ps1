$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $NetworkPath = "C:\temp"
        $backuprestoredb = "dbatoolsci_backuprestore"
        $detachattachdb = "dbatoolsci_detachattach"
        $server = Connect-Instance -SqlInstance $script:instance1
        Stop-Process -SqlInstance $script:instance1 -Database model
        $server.Query("CREATE DATABASE $backuprestoredb")
        $db = Get-Database -SqlInstance $script:instance1 -Database $backuprestoredb
        if (-not $env:appveyor) {
            if ($db.AutoClose) {
                $db.AutoClose = $false
                $db.Alter()
            }
        }
        Stop-Process -SqlInstance $script:instance1 -Database model
        $server.Query("CREATE DATABASE $detachattachdb")
    }
    AfterAll {
        Remove-Database -Confirm:$false -SqlInstance $Instances -Database $backuprestoredb, $detachattachdb
    }

    Context "Detach Attach" {
        It "Should be success" {
            $results = Copy-Database -Source $script:instance1 -Destination $script:instance2 -Database $detachattachdb -DetachAttach -Reattach -Force -WarningAction SilentlyContinue
            $results.Status | Should Be "Successful"
        }

        It "should not be null" {
            $db1 = Get-Database -SqlInstance $script:instance1 -Database $detachattachdb
            $db2 = Get-Database -SqlInstance $script:instance2 -Database $detachattachdb
            $db1 | Should Not Be $null
            $db2 | Should Not Be $null

            $db1.Name | Should Be $detachattachdb
            $db2.Name | Should Be $detachattachdb
        }

        It "Name, recovery model, and status should match" {
            # This is crazy
            (Connect-Instance -SqlInstance $script:instance1).Databases[$detachattachdb].Name | Should Be (Connect-Instance -SqlInstance $script:instance2).Databases[$detachattachdb].Name
            (Connect-Instance -SqlInstance $script:instance1).Databases[$detachattachdb].Tables.Count | Should Be (Connect-Instance -SqlInstance $script:instance2).Databases[$detachattachdb].Tables.Count
            (Connect-Instance -SqlInstance $script:instance1).Databases[$detachattachdb].Status | Should Be (Connect-Instance -SqlInstance $script:instance2).Databases[$detachattachdb].Status
        }

        It "Should say skipped" {
            $results = Copy-Database -Source $script:instance1 -Destination $script:instance2 -Database $detachattachdb -DetachAttach -Reattach
            $results.Status | Should be "Skipped"
            $results.Notes | Should be "Already exists"
        }
    }

    if (-not $env:appveyor) {
        Context "Backup restore" {
            It "copies a database and retain its name, recovery model, and status." {

                Set-DatabaseOwner -SqlInstance $script:instance1 -Database $backuprestoredb -TargetLogin sa
                Copy-Database -Source $script:instance1 -Destination $script:instance2 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath

                $db1 = Get-Database -SqlInstance $script:instance1 -Database $backuprestoredb
                $db2 = Get-Database -SqlInstance $script:instance2 -Database $backuprestoredb
                $db1 | Should Not BeNullOrEmpty
                $db2 | Should Not BeNullOrEmpty

                # Compare its valuable.
                $db1.Name | Should Be $db2.Name
                $db1.RecoveryModel | Should Be $db2.RecoveryModel
                $db1.Status | Should be $db2.Status
                $db1.Owner | Should be $db2.Owner
            }

            It "Should say skipped" {
                $result = Copy-Database -Source $script:instance1 -Destination $script:instance2 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath
                $result.Status | Should be "Skipped"
                $result.Notes | Should be "Already exists"
            }
        }
    }
}