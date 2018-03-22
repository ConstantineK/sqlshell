$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
. "$PSScriptRoot\constants.ps1"

Describe "$commandname" {
    Context "Expanding different SQL view types into valid TSQL" {
        It "places the CTE output on the top of the query and replaces the reference" {
          $ExampleCteQuery = ""
        }
        It "expands recursive CTEs and returns valid sql" {}
        It "works correctly with finicky correlated subqueries" {}
    }
}