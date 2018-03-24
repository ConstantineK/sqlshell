function Get-DLLMajorVersionFromLoadedAssemblies {
  param ($LibraryLocation)
  $Names = (
  [appdomain]::currentdomain.getassemblies() |
    Where-Object { $_.Location -like $LibraryLocation} |
    Select-Object -ExpandProperty Location |
    ForEach-Object {
      ([system.reflection.assembly]::loadfile($_)) |
      Select-Object -ExpandProperty FullName
    } |
    ForEach-Object {
      $_ -split ", " | Where-Object { $_ -like 'Version*' }
    } |
    ForEach-Object {
      (($_ -replace 'Version=','') -split '\.')[0]
    }
  )
  #$Names | Out-Default
  $Version = $Names | Sort-Object | Select-Object -First 1
  return $Version
}