
$Path = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = (Get-Item $Path).Parent.FullName
$CommandName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"
$InternalPath = (Join-Path $ModulePath "internal")
<#
  To test this I need a few core pieces
  I need a view composed of sub objects
  I need a mock that can surface the look ups
  I want to be able to get the definition of the object
  I will also need to use the SMO parser to check what is a cte and what is a view, so lets simplify this a lot first
  Change the import to import in the module
#>

. "$(Join-Path (Join-Path $InternalPath "import") "smoLibraryImport.ps1")"
Import-SmoDependencies -ModuleRoot $ModulePath -DllRoot (Join-Path (Join-Path $ModulePath "bin") "smo") -DoCopy $false

. "$(Join-Path (Join-Path $InternalPath "function") "Get-DLLMajorVersionFromLoadedAssemblies.ps1")"

Describe "how $CommandName understands and unwraps SQL syntax" {
  It "Reads sample SQL and returns object names" {
    # How do we figure out which ScriptDom is loaded?
    # Its looking the version just stops at 12, and that's what everyone has atm if they have this DLL
    # $Version = Get-DLLMajorVersionFromLoadedAssemblies -LibraryLocation "*TransactSql.ScriptDom*"
    $ExampleCode = "
    SELECT *
    FROM sys.objects"
    $Stream = New-Object 'System.IO.StringReader'($ExampleCode)

    # TODO: This should work in the import
    # Add-Type -AssemblyName "Microsoft.SqlServer.TransactSql.ScriptDom,Version=12.0.0.0,Culture=neutral,PublicKeyToken=89845dcd8080cc91"
    $ParserNameSpace = "Microsoft.SqlServer.TransactSql.ScriptDom.TSql120Parser"
    $Parser = New-Object $ParserNameSpace($true)
    $Errors = $null
    $Fragment = $Parser.Parse($Stream, [ref]$Errors)

    $Fragment

    $ObjectList |
      Where-Object { $_ -like '*objects*' } |
      Should not be $null
  }

  It "does a depth first search for views and identifies all the relevant objects" {
    $false | Should be $true
  }
  It "unwraps a CTE and places it at the head of a statement" {
      $false | Should Be $true
  }
}