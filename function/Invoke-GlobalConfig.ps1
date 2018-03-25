function Invoke-GlobalConfig() { 
    [cmdletbinding()]
    param(
        [string]$ConfigPath
    )

    begin { 
        if(!$ConfigPath) { 
            $ModuleRoot = $($(Get-Item -Path $(Get-Module -Name 'sqlshell').Path).Directory).FullName

            $ConfigPath = Join-Path -Path $ModuleRoot -ChildPath '\config\sqlshellconfig.json'
        }
    }

    process { 
        [pscustomobject]$ConfigObject = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json 

        $global:sqlshell = $ConfigObject

    }
}