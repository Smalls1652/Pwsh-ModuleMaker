[CmdletBinding()]
param(
    [string]$ProjectPath
)

begin {

    $ProjectPathObj = (Get-Item -Path $ProjectPath)

    $ProjectConfig = (ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path $ProjectPathObj.FullName -ChildPath "project.json") -Raw))

    $ConfigsFolder = Get-Item -Path (Join-Path -Path $ProjectPathObj.FullName -ChildPath "Configs")

    $ModuleManifestConfig = (ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path $ConfigsFolder.FullName -ChildPath "modulemanifest.json") -Raw))
    $FunctionsConfig = (ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path $ConfigsFolder.FullName -ChildPath "functions.json") -Raw))

    $ModuleManifestSplat = @{
        "FunctionsToExport" = $ModuleManifestConfig.FunctionsToExport;
        "Path"              = $ModuleManifestConfig.Path
    }

    Push-Location -Path $ProjectPathObj -StackName "Original"
}

process {
    Write-Verbose "Starting build process..."
    $RootModuleContent = ""

    Push-Location -Path "ScriptFiles" -StackName "ScriptFiles"
    Write-Verbose "Writing standard functions..."
    $RootModuleContent += "<#`nStandard functions`n#>`n"
    foreach ($i in ($FunctionsConfig.Functions | Where-Object -Property "IsExported" -eq $false)) {
        Write-Verbose "- '$($i.FunctionName)' added."
        $RootModuleContent += "`nfunction $($i.FunctionName) {`n"
        Push-Location -Path $i.FunctionName -StackName "FunctionPath"
        $RootModuleContent += Get-Content -Path "$($i.FunctionName).ps1" -Raw
        Pop-Location -StackName "FunctionPath"
        $RootModuleContent += "`n}`n"
    }
    Pop-Location -StackName "ScriptFiles"

    Push-Location -Path "ScriptFiles" -StackName "ScriptFiles"
    Write-Verbose "Writing exported functions..."
    $RootModuleContent += "`n<#`nExported functions`n#>`n"
    foreach ($i in ($FunctionsConfig.Functions | Where-Object -Property "IsExported" -eq $true)) {
        Write-Verbose " - '$($i.FunctionName)' added."
        $RootModuleContent += "`nfunction $($i.FunctionName) {`n"
        Push-Location -Path $i.FunctionName -StackName "FunctionPath"
        $RootModuleContent += Get-Content -Path "$($i.FunctionName).ps1" -Raw
        Pop-Location -StackName "FunctionPath"
        $RootModuleContent += "`n}`n"
    }
    Pop-Location -StackName "ScriptFiles"

    Write-Verbose "Writing module file..."
    $RootModuleContent | Out-File -FilePath (Join-Path -Path "$($ProjectConfig.ModuleName)" -ChildPath "$($ProjectConfig.ModuleName).psm1")

    Write-Verbose "Updating module manifest..."
    Update-ModuleManifest @ModuleManifestSplat
}

end {
    Pop-Location -StackName "Original"
    Write-Verbose "Done."
}