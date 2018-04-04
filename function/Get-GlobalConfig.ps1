function Get-GlobalConfig() { 
    [cmdletbinding()]
    param ( 

    )

    if($Global:sqlshell){ 
        return $Global:sqlshell 
    } else { 
        Invoke-SqGlobalConfig 

        return $Global:sqlshell 
    }     
}