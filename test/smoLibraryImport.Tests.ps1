$Path = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = (Get-Item $Path).Parent.FullName
$CommandName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"

# Will start with the basics, then eventually lay out specific tests and pull out the rug for the bulk load
# Fundamentally it would be cool to only load the types needed if needed.

Describe "how the importer loads various dlls" {

  BeforeAll {
    # Find the path and load the DLLs
    . "$(Join-Path (Join-Path (Join-Path $ModulePath "internal") "import") "smoLibraryImport.ps1")"
    Import-SmoDependencies -ModuleRoot $ModulePath -DllRoot (Join-Path (Join-Path $ModulePath "bin") "smo") -DoCopy $false
  }

  It "reads through a list and makes them available in the global assemblies" {
    [appdomain]::currentdomain.getassemblies() |
      Where-Object { $_.Location -like '*Microsoft.SqlServer.Management.RegisteredServers*'} |
      Should not BeNullOrEmpty
  }

  It "loads the Parser DLL needed for parsing raw TQL queries" {
    [appdomain]::currentdomain.getassemblies() |
      Where-Object { $_.Location -like '*Microsoft.SqlServer.TransactSql.ScriptDom*'} |
      Should not BeNullOrEmpty
  }
}