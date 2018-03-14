function Get-SqlFileStructure {
    <#
    .SYNOPSIS
    Internal function. Returns custom object that contains file structures on destination paths (\\SqlInstance\m$\mssql\etc\etc\file.mdf) for
    source and destination servers.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [object]$source,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [object]$destination,
        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$ReuseSourceFolderStructure,
        [PSCredential]$SourceSqlCredential,
        [PSCredential]$DestinationSqlCredential
    )

    $sourceserver = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
    $source = $sourceserver.DomainInstanceName
    $destserver = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential
    $destination = $destserver.DomainInstanceName

    $sourcenetbios = Resolve-NetBiosName $sourceserver
    $destnetbios = Resolve-NetBiosName $destserver

    $dbcollection = @{ };

    foreach ($db in $sourceserver.databases) {
        $dbstatus = $db.status.toString()
        if ($dbstatus.StartsWith("Normal") -eq $false) { continue }
        $destinationfiles = @{ }; $sourcefiles = @{ }

        # Data Files
        foreach ($filegroup in $db.filegroups) {
            foreach ($file in $filegroup.files) {
                # Destination File Structure
                $d = @{ }
                if ($ReuseSourceFolderStructure) {
                    $d.physical = $file.filename
                }
                else {
                    $directory = Get-SqlDefaultPaths $destserver data
                    $filename = Split-Path $($file.filename) -leaf
                    $d.physical = "$directory\$filename"
                }
                $d.logical = $file.name
                $d.remotefilename = Join-AdminUnc $destnetbios $d.physical
                $destinationfiles.add($file.name, $d)

                # Source File Structure
                $s = @{ }
                $s.logical = $file.name
                $s.physical = $file.filename
                $s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
                $sourcefiles.add($file.name, $s)
            }
        }

        # Add support for Full Text Catalogs in SQL Server 2005 and below
        if ($sourceserver.VersionMajor -lt 10) {
            foreach ($ftc in $db.FullTextCatalogs) {
                # Destination File Structure
                $d = @{ }
                $pre = "sysft_"
                $name = $ftc.name
                $physical = $ftc.RootPath
                $logical = "$pre$name"
                if ($ReuseSourceFolderStructure) {
                    $d.physical = $physical
                }
                else {
                    $directory = Get-SqlDefaultPaths $destserver data
                    if ($destserver.VersionMajor -lt 10) { $directory = "$directory\FTDATA" }
                    $filename = Split-Path($physical) -leaf
                    $d.physical = "$directory\$filename"
                }
                $d.logical = $logical
                $d.remotefilename = Join-AdminUnc $destnetbios $d.physical
                $destinationfiles.add($logical, $d)

                # Source File Structure
                $s = @{ }
                $pre = "sysft_"
                $name = $ftc.name
                $physical = $ftc.RootPath
                $logical = "$pre$name"

                $s.logical = $logical
                $s.physical = $physical
                $s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
                $sourcefiles.add($logical, $s)
            }
        }

        # Log Files
        foreach ($file in $db.logfiles) {
            $d = @{ }
            if ($ReuseSourceFolderStructure) {
                $d.physical = $file.filename
            }
            else {
                $directory = Get-SqlDefaultPaths $destserver log
                $filename = Split-Path $($file.filename) -leaf
                $d.physical = "$directory\$filename"
            }
            $d.logical = $file.name
            $d.remotefilename = Join-AdminUnc $destnetbios $d.physical
            $destinationfiles.add($file.name, $d)

            $s = @{ }
            $s.logical = $file.name
            $s.physical = $file.filename
            $s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
            $sourcefiles.add($file.name, $s)
        }

        $location = @{ }
        $location.add("Destination", $destinationfiles)
        $location.add("Source", $sourcefiles)
        $dbcollection.Add($($db.name), $location)
    }

    $filestructure = [pscustomobject]@{ "databases" = $dbcollection }
    return $filestructure
}
