$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Write-Debug "loading from $ScriptDir"

foreach ($file in (Get-ChildItem ( Join-Path $ScriptDir ".\internal") -Filter "*.ps1")){
  Write-Debug "Loading $($file.FullName)"
  . $file.FullName
}

foreach ($file in (Get-ChildItem ( Join-Path $ScriptDir ".\function" ) -Filter "*.ps1" )){
  Write-Debug "Loading $($file.FullName)"
  . $file.FullName
}