function Convert-ByteToHexString {
    <#
    .SYNOPSIS
    Converts byte object into hex string

    .DESCRIPTION
    Converts byte object ([byte[]]@(1,100,23,54)) into the hex string (e.g. '0x01641736')
    Used when working with SMO logins and their byte parameters: sids and hashed passwords

    .PARAMETER InputObject
    Input byte[] object (e.g. [byte[]]@(18,52))

    .NOTES
    Tags: Login, Internal
    Author: Kirill Kravtsov (@nvarscar)
    License: GPL-2.0 https://opensource.org/licenses/GPL-2.0

    .EXAMPLE
    Convert-ByteToHexString ([byte[]]@(1,100,23,54))

    Returns hex string '0x01641736'

    .EXAMPLE
    Convert-ByteToHexString 18,52

    Returns hex string '0x1234'
#>
    param ([byte[]]$InputObject)
    $outString = "0x"
    $InputObject | ForEach-Object { $outString += ("{0:X}" -f $_).PadLeft(2, "0") }
    $outString
}