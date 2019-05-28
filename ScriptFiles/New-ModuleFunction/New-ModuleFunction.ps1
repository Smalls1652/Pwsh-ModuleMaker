[CmdletBinding()]
param(
    [string]$ProjectPath,
    [string]$FunctionName,
    [switch]$AddToExport
)

begin {
    $ProjectPathObj = (Get-Item -Path $ProjectPath)

    Push-Location -Path $ProjectPathObj -StackName "Original"
}

process {
    Write-Verbose "Creating folder for '$($FunctionName)' in ScriptFiles..."
    $FunctionFolder = New-Item -Path "ScriptFiles" -Name $FunctionName -ItemType Directory

    Write-Verbose "Initializing ps1 file..."
    $null = New-Item -Path $FunctionFolder -Name "$($FunctionName).ps1" -ItemType File

    $FunctionsConfig = (ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path "Configs" -ChildPath "functions.json") -Raw))
    $FunctionsConfig.Functions += @{
        "FunctionName" = $FunctionName;
        "IsExported"   = $AddToExport.IsPresent
    }
    $FunctionsConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path "Configs" -ChildPath "functions.json")

    switch ($AddToExport) {
        $true {
            Write-Verbose "Adding function to FunctionsToExport in config file..."
            $ProjectConfig = (ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path "Configs" -ChildPath "modulemanifest.json") -Raw))
            $ProjectConfig.FunctionsToExport += $FunctionName

            $ProjectConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path "Configs" -ChildPath "modulemanifest.json")
        }
    }
}

end {
    Pop-Location -StackName "Original"
    Write-Verbose "Done."
}