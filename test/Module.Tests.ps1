
$Path = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = (Get-Item $Path).Parent.FullName
$ModuleName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"
kDescribe "$ModuleName indentation" -Tag 'syntax' {
    $AllFiles = Get-ChildItem -Path $ModulePath -File -Recurse  -Filter '*.ps*1'

    foreach ($f in $AllFiles) {
        $LeadingTabs = Select-String -Path $f -Pattern '^[\t]+'
        if ($LeadingTabs.Count -gt 0) {
            It "$f is not indented with tabs (line(s) $($LeadingTabs.LineNumber -join ','))" {
                $LeadingTabs.Count | Should Be 0
            }
        }
        $TrailingSpaces = Select-String -Path $f -Pattern '([^ \t\r\n])[ \t]+$'
        if ($TrailingSpaces.Count -gt 0) {
            It "$f has no trailing spaces (line(s) $($TrailingSpaces.LineNumber -join ','))" {
                $TrailingSpaces.Count | Should Be 0
            }
        }
    }
}

Describe "$ModuleName ScriptAnalyzerErrors" -Tag 'syntax' {
    $ScriptAnalyzerErrors = @()
    $ScriptAnalyzerErrors += Invoke-ScriptAnalyzer -Path "$ModuleBase\function" -Severity Error
    $ScriptAnalyzerErrors += Invoke-ScriptAnalyzer -Path "$ModuleBase\internal\function" -Severity Error
    if ($ScriptAnalyzerErrors.Count -gt 0) {
        foreach($err in $ScriptAnalyzerErrors) {
            It "$($err.scriptName) has Error(s) : $($err.RuleName)" {
                $err.Message | Should Be $null
            }
        }
    }
}
Describe "Manifest" {
  $Manifest = $null
  It "has a parseable manifest" {
    {
        $Script:Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop -WarningAction SilentlyContinue
    } | Should Not Throw
  }

$Script:Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction SilentlyContinue
    It "has name manifest name which matches the module name" {
        $Script:Manifest.Name | Should Be $ModuleName
    }

    It "has a root module in the manifest that matches the psm1 file" {
        $Script:Manifest.RootModule | Should Be "$ModuleName.psm1"
    }
}
