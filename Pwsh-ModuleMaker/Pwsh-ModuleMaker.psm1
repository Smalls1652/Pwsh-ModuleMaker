<#
Standard functions
#>

<#
Exported functions
#>

function New-ModuleFunction {
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
}

function New-ModuleProject {
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ModuleName,
    [string]$Description,
    [string]$OutFolder,
    [string]$StandardConfig
)

begin {
    $OutFolder = (Get-Item -Path $OutFolder).FullName

    $ConfigData = (ConvertFrom-Json -InputObject (Get-Content -Path $StandardConfig -Raw))

    $ModuleManifestSplat = @{
        "Author" = $ConfigData.Author;
        "CompanyName" = $ConfigData.CompanyName;
        "Description" = $Description;
        "ModuleVersion" = (Get-Date -Format "yy.MM.dd");
        "RootModule" = "$($ModuleName).psm1"
        "Guid" = (New-Guid).Guid;
        "Copyright" = (Get-Date -Format "yyyy");
        "FunctionsToExport" = @();
        "AliasesToExport" = @();
        "CmdletsToExport" = @();
        "VariablesToExport" = @();
    }

    $ProjectConfig = @{
        "ModuleName" = $ModuleName
    }

    $FunctionsConfig = @{
        "Functions" = @()
    }
}

process {
    Write-Verbose "Creating project folder..."
    $ProjectFolder = New-Item -Path $OutFolder -Name $ModuleName -ItemType Directory

    Write-Verbose "Creating README.md file..."
    $ReadmeContents = "# $($ModuleName)`n`n$($Description)"
    $null = New-Item -Path $ProjectFolder -Name "README.md" -ItemType File -Value $ReadmeContents

    Write-Verbose "Creating module folder..."
    $ModuleFolder = New-Item -Path $ProjectFolder -Name $ModuleName -ItemType Directory
    $ProjectConfig.Add("ModulePath", (Join-Path -Path "." -ChildPath $ModuleName))

    Write-Verbose "Creating configs folder..."
    $ConfigFolder = New-Item -Path $ProjectFolder -Name "Configs" -ItemType Directory
    $ProjectConfig.Add("ConfigPath", (Join-Path -Path "." -ChildPath "Configs"))

    Write-Verbose "Creating ScriptFiles folder..."
    $null = New-Item -Path $ProjectFolder -Name "ScriptFiles" -ItemType Directory
    $ProjectConfig.Add("ScriptFilesPath", (Join-Path -Path "." -ChildPath "ScriptFiles"))

    Write-Verbose "Creating Tests folder..."
    $null = New-Item -Path $ProjectFolder -Name "Tests" -ItemType Directory
    $ProjectConfig.Add("TestsPath", (Join-Path -Path "./" -ChildPath "Tests"))

    Write-Verbose "Initializing module psm1 file in module folder..."
    $null = New-Item -Path $ModuleFolder -Name "$($ModuleName).psm1" -ItemType File

    $ModuleManifestSplat.Add("Path", (Join-Path -Path $ModuleName -ChildPath "$($ModuleName).psd1"))

    Write-Verbose "Initialzing project config files..."
    $ModuleManifestSplat | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ConfigFolder.FullName -ChildPath "modulemanifest.json")
    $FunctionsConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ConfigFolder.FullName -ChildPath "functions.json")
    $ProjectConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path $ProjectFolder.FullName -ChildPath "project.json")

    Write-Verbose "Initializing module manifest..."
    Push-Location -Path $ProjectFolder
    New-ModuleManifest @ModuleManifestSplat
    Pop-Location

    Write-Verbose "Initialize project with git..."
    $GitOut = New-TemporaryFile
    Start-Process -FilePath "git" -ArgumentList "init" -WorkingDirectory $ProjectFolder -Wait -RedirectStandardOutput $GitOut
    Write-Verbose "Git Output: '$(Get-Content -Path $GitOut)'"
}

end {
    Remove-Item -Path $GitOut
    Write-Verbose "Done."
}
}

function New-ModuleStandardConfig {
[CmdletBinding()]
param(
    [string]$Author,
    [string]$CompanyName
)

$ModuleConfig = @{
    "Author" = $Author;
    "CompanyName" = $CompanyName
} | ConvertTo-Json

return $ModuleConfig
}

function Start-ModuleBuild {
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
        "ModuleVersion"     = $ModuleManifestConfig.ModuleVersion;
        "Description"       = $ModuleManifestConfig.Description;
        "Copyright"         = $ModuleManifestConfig.Copyright;
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
}

function Update-ModuleProject {
[CmdletBinding()]
param(
    [string]$ProjectPath,
    [string]$ModuleVersion,
    [string]$Description,
    [int]$Copyright
)

begin {
    $ProjectPathObj = Get-Item -Path $ProjectPath

    Push-Location -Path $ProjectPathObj -StackName "Original"

    Write-Verbose "Loading ModuleManifest config file..."
    $ModuleManifestData = ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path -Path "Configs" -ChildPath "modulemanifest.json") -Raw)
}

process {
    $ModuleManifestSplat = @{
        "Path" = $ModuleManifestData.Path
    }

    if ($ModuleVersion) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.ModuleVersion = $ModuleVersion
        $ModuleManifestSplat.Add("ModuleVersion", $ModuleVersion)
    }

    if ($Description) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.Description = $Description
        $ModuleManifestSplat.Add("Description", $Description)
    }

    if ($Copyright) {
        Write-Verbose "Changing ModuleVersion from '$($ModuleManifestData.ModuleVersion)' to '$($ModuleVersion)'."
        $ModuleManifestData.Copyright = $Copyright
        $ModuleManifestSplat.Add("Copyright", $Copyright)
    }

    Write-Verbose "Writing data back to ModuleManifest config file..."
    $ModuleManifestData | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path -Path "Configs" -ChildPath "modulemanifest.json")

    Write-Verbose "Updating module manifest..."
    Update-ModuleManifest @ModuleManifestSplat
}

end{
    Pop-Location -StackName "Original"
    Write-Verbose "Done."
    return $ModuleManifestData
}
}

