$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    Context "Get some client protocols" {
        $results = Get-ClientProtocol
        It "Should return some protocols" {
            $results.Count | Should BeGreaterThan 1
            $results | Where-Object { $_.ProtocolDisplayName -eq 'TCP/IP' } | Should Not Be $null
        }
    }
}